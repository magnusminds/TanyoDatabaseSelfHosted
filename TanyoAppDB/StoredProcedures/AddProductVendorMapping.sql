CREATE PROCEDURE [dbo].[AddProductVendorMapping]
(
    @TenantId        BIGINT,
    @UserId          BIGINT,
    @POProductId     BIGINT,
    @ProductMappings NVARCHAR(MAX)
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE
            @VendorId      BIGINT,
            @Date          DATETIMEOFFSET = SYSDATETIMEOFFSET(),
            @DateUTC       DATETIMEOFFSET = SYSUTCDATETIME(),
            @ReturnMessage VARCHAR(255),
            @IsInterState  BIT = 0;

        -------------------------------------------------------
        -- Get VendorId from JSON
        -------------------------------------------------------
        SELECT @VendorId = VendorId
        FROM OPENJSON(@ProductMappings)
        WITH (VendorId BIGINT);

        -------------------------------------------------------
        -- Determine Inter-State status (Tenant State <> Vendor State)
        -------------------------------------------------------
        SELECT 
            @IsInterState = CASE 
                WHEN LTRIM(RTRIM(T.State)) <> LTRIM(RTRIM(V.State)) 
                     AND T.State IS NOT NULL 
                     AND V.State IS NOT NULL 
                     AND T.State <> '' 
                     AND V.State <> '' 
                THEN 1 
                ELSE 0 
            END
        FROM Tenants T WITH (NOLOCK)
        CROSS JOIN Vendors V WITH (NOLOCK)
        WHERE T.TenantId = @TenantId
          AND V.VendorId = @VendorId;

        -------------------------------------------------------
        -- Temp table for Product Mapping JSON
        -------------------------------------------------------
        IF OBJECT_ID('tempdb..#ProductMappings') IS NOT NULL
            DROP TABLE #ProductMappings;

        CREATE TABLE #ProductMappings
        (
            ProductId          BIGINT,
            IsDefault          BIT,
            VendorProductPrice NUMERIC(18,2),
            VendorModelNo      VARCHAR(100),
            POProductItemId    BIGINT PRIMARY KEY 
        );

        -------------------------------------------------------
        -- Parse Products JSON
        -------------------------------------------------------
        INSERT INTO #ProductMappings
        (
            ProductId,
            IsDefault,
            VendorProductPrice,
            VendorModelNo,
            POProductItemId
        )
        SELECT
            ProductId,
            IsDefault,
            VendorProductPrice,
            VendorModelNo,
            POProductItemId
        FROM OPENJSON(@ProductMappings, '$.Products')
        WITH
        (
            ProductId          BIGINT,
            IsDefault          BIT,
            VendorProductPrice NUMERIC(18,2),
            VendorModelNo      VARCHAR(100),
            POProductItemId    BIGINT 
        );

        -------------------------------------------------------
        -- Update Existing Product Vendor Mappings
        -------------------------------------------------------
        UPDATE PVM
        SET
            PVM.IsDefault      = CASE WHEN PVM.VendorId = @VendorId THEN PM.IsDefault ELSE 0 END,
            PVM.UpdatedBy      = @UserId,
            PVM.UpdatedDate    = @Date,
            PVM.UpdatedUTCDate = @DateUTC
        FROM ProductVendorMapping PVM
        INNER JOIN 
        (
            SELECT 
                ProductId,
                MAX(CAST(IsDefault AS TINYINT)) AS IsDefault
            FROM #ProductMappings
            GROUP BY ProductId
        ) PM
            ON PM.ProductId = PVM.ProductId
        INNER JOIN Products P WITH (NOLOCK)
            ON P.ProductId = PM.ProductId
           AND P.TenantId  = @TenantId
        WHERE
            PVM.VendorId = @VendorId                            
            OR (PVM.VendorId <> @VendorId AND PM.IsDefault = 1);

        -------------------------------------------------------
        -- Insert New Product Vendor Mapping
        -------------------------------------------------------
        INSERT INTO ProductVendorMapping
        (
            ProductId,
            VendorId,
            IsDefault,
            VendorProductId,
            IsDeleted,
            CreatedBy,
            CreatedDate,
            CreatedUTCDate,
            VendorModelNo,
            VendorProductPrice
        )
        SELECT
            PM.ProductId,
            @VendorId,
            PM.IsDefault,
            PM.ProductId,
            0,
            @UserId,
            @Date,
            @DateUTC,
            PM.VendorModelNo,
            PM.VendorProductPrice
        FROM 
        (
            SELECT 
                ProductId,
                VendorModelNo,
                VendorProductPrice,
                IsDefault,
                ROW_NUMBER() OVER (
                    PARTITION BY ProductId 
                    ORDER BY IsDefault DESC, POProductItemId DESC
                ) AS Rn
            FROM #ProductMappings
        ) PM
        INNER JOIN Products P WITH (NOLOCK)
            ON P.ProductId = PM.ProductId
           AND P.TenantId  = @TenantId
        WHERE PM.Rn = 1
          AND NOT EXISTS
        (
            SELECT 1
            FROM ProductVendorMapping PVM WITH (NOLOCK)
            WHERE PVM.ProductId = PM.ProductId
              AND PVM.VendorId  = @VendorId
        );

        -------------------------------------------------------
        -- Recalculate & Update POProductItems with GST Logic
        -------------------------------------------------------
        ;WITH GST_Calculations AS
        (
            SELECT 
                PPI.POProductItemId,
                PM.VendorModelNo,
                PM.VendorProductPrice AS NewUnitPrice,
                
                -- Line product amount (Qty * UnitPrice) rounded to 2 decimals
                ROUND(PPI.Quantity * PM.VendorProductPrice, 2) AS LineProductAmount,
                
                -- Category GST % with fallback logic
                ISNULL(C.GST, 18) AS GstRate,
                
                -- Header GST Type (true = Exclusive, false = Inclusive)
                ISNULL(PO.GSTType, 1) AS GSTType
            FROM POProductItems PPI
            INNER JOIN #ProductMappings PM 
                ON PPI.POProductItemId = PM.POProductItemId
            INNER JOIN POProducts PO WITH (NOLOCK) 
                ON PO.POProductId = PPI.POProductId
            LEFT JOIN Products P WITH (NOLOCK) 
                ON P.ProductId = PPI.ProductId
            LEFT JOIN Categories C WITH (NOLOCK) 
                ON C.CategoryId = P.CategoryId
        ),
        Base_Amounts AS
        (
            SELECT 
                POProductItemId,
                VendorModelNo,
                NewUnitPrice,
                GstRate,
                GSTType,
                LineProductAmount,
                CASE 
                    -- GST Exclusive: ROUND(LineProductAmount)
                    WHEN GSTType = 1 THEN ROUND(LineProductAmount, 0)
                    -- GST Inclusive: ROUND(LineProductAmount * 100 / (100 + GST%))
                    ELSE ROUND((LineProductAmount * 100.0) / (100.0 + GstRate), 0)
                END AS AmountBeforeGST
            FROM GST_Calculations
        ),
        Tax_Calculations AS
        (
            SELECT 
                POProductItemId,
                VendorModelNo,
                NewUnitPrice,
                GstRate,
                GSTType,
                LineProductAmount,
                AmountBeforeGST,
                -- Total Tax Amount for the line
                (AmountBeforeGST * GstRate / 100.0) AS TaxAmount
            FROM Base_Amounts
        ),
        Final_Line_Totals AS
        (
            SELECT 
                POProductItemId,
                VendorModelNo,
                NewUnitPrice,
                GstRate,
                AmountBeforeGST,
                
                -- Inter-state vs Intra-state breakdown
                CASE WHEN @IsInterState = 1 THEN TaxAmount ELSE 0 END AS IGSTAmount,
                CASE WHEN @IsInterState = 0 THEN TaxAmount / 2.0 ELSE 0 END AS CGSTAmount,
                CASE WHEN @IsInterState = 0 THEN TaxAmount / 2.0 ELSE 0 END AS SGSTAmount,
                
                -- Line total calculation
                CASE 
                    WHEN GSTType = 1 THEN ROUND(AmountBeforeGST + TaxAmount, 0)
                    ELSE ROUND(AmountBeforeGST + TaxAmount, 0)
                END AS LineTotalAmount
            FROM Tax_Calculations
        )
        UPDATE PPI
        SET 
            PPI.VendorModelNo   = FLT.VendorModelNo,
            PPI.UnitPrice       = FLT.NewUnitPrice,
            PPI.GST             = FLT.GstRate,
            --PPI.AmountBeforeGST = FLT.AmountBeforeGST,
            PPI.CGSTAmount      = FLT.CGSTAmount,
            PPI.SGSTAmount      = FLT.SGSTAmount,
            PPI.IGSTAmount      = FLT.IGSTAmount
            --PPI.TotalAmount     = FLT.LineTotalAmount
        FROM POProductItems PPI
        INNER JOIN Final_Line_Totals FLT 
            ON PPI.POProductItemId = FLT.POProductItemId;

        DECLARE @TotalAmount DECIMAL(18, 2)
		DECLARE @AmountBeforeGST DECIMAL(18, 2)
        DECLARE @IGSTAmount DECIMAL(18, 2)
        DECLARE @CGSTAmount DECIMAL(18, 2)
        DECLARE @SGSTAmount DECIMAL(18, 2)
        
        SELECT @TotalAmount = SUM(TotalAmount)
				,@AmountBeforeGST = SUM(AmountBeforeGST)
                ,@IGSTAmount = SUM(IGSTAmount)
                ,@CGSTAmount = SUM(CGSTAmount)
                ,@SGSTAmount = SUM(SGSTAmount)
		FROM dbo.POProductItems poi
		WHERE poi.POProductId = @POProductId

		UPDATE dbo.POProducts
		SET TotalAmount = @TotalAmount
			,AmountBeforeGST = @AmountBeforeGST
            ,IGSTAmount = @IGSTAmount
            ,CGSTAmount = @CGSTAmount
            ,SGSTAmount = @SGSTAmount
		WHERE POProductId = @POProductId

        SET @ReturnMessage = 'Product vendor mapped successfully.';

        SELECT
            1               AS Status,
            @ReturnMessage   AS Message;

    END TRY

    BEGIN CATCH

        DECLARE
            @ObjectName VARCHAR(500),
            @ErrorMsg   VARCHAR(MAX);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg   = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
            @ObjectName = @ObjectName,
            @ErrorMsg   = @ErrorMsg;

    END CATCH
END

GO

