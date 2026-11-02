/*
	EXEC [dbo].[ListProductsDownload]
		@TenantId = 2
		,@CategoryId = -1
		,@ParentCategoryId = NULL
		,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
		,@IsOfferedProduct = 0
		,@ProductTitle = NULL
		,@ModelNo = NULL
		,@PublishStatus = 1
		,@OfferDataId = NULL
		,@UpdateFromDate = NULL
		,@UpdateToDate = NULL
		,@VendorId = -1
		,@FromPrice = NULL
		,@ToPrice = -1
		,@Quantity = NULL
		,@StockFilterOperation = -1
		,@CategoryTypeId = 2

*/
CREATE   PROCEDURE [dbo].[ListProductsDownload] (
    @TenantId INT
    ,@CategoryId BIGINT = NULL
    ,@RoleId VARCHAR(100)
    ,@ProductTitle VARCHAR(100) = NULL
    ,@ModelNo VARCHAR(100) = NULL
    ,@PublishStatus INT = NULL
    ,@OfferDataId INT = NULL
    ,@UpdateFromDate DATE = NULL
    ,@UpdateToDate DATE = NULL
    ,@VendorId BIGINT = NULL
    ,@FromPrice INT = NULL
    ,@ToPrice INT = NULL
    ,@IsOfferedProduct BIT = 0
    ,@Quantity NUMERIC(18,2) = NULL
    ,@StockFilterOperation VARCHAR(5) = NULL
    ,@CategoryTypeId BIGINT = NULL
    ,@ParentCategoryId BIGINT = NULL
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dt DATE
    SELECT @dt = CAST(GETDATE() AS DATE)

    DECLARE @ProductSubjectTypeId INT
    SELECT @ProductSubjectTypeId = SubjectTypeId
    FROM SubjectTypes WITH (NOLOCK)
    WHERE SubjectTypeName = 'Products'
        AND TenantId = @TenantId
        AND IsDeleted = 0

    DECLARE @sql             NVARCHAR(MAX)
    DECLARE @paramDef        NVARCHAR(MAX)
    DECLARE @where           NVARCHAR(MAX)
    DECLARE @offerJoin       NVARCHAR(MAX)
    DECLARE @offerWhere      NVARCHAR(MAX) = N''

    IF @IsOfferedProduct = 0
    BEGIN
        SET @offerJoin = N'LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId'
    
        IF @OfferDataId IS NOT NULL
        BEGIN
            IF @OfferDataId = -2
                SET @offerWhere = N' AND ofr.OfferId IS NULL'
            ELSE IF @OfferDataId <> -1
                SET @offerWhere = N' AND ofr.OfferId = @OfferDataId'
        END
    END
    ELSE  -- @IsOfferedProduct = 1
    BEGIN
        -- INNER JOIN always — this alone restricts to offered products only
        -- -1, -2, NULL are all "no further filter" sentinels in this branch
        SET @offerJoin  = N'INNER JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId'
        SET @offerWhere = N''
    
        IF @OfferDataId IS NOT NULL AND @OfferDataId NOT IN (-1, -2)
            SET @offerWhere = N' AND ofr.OfferId = @OfferDataId'
    END

    SET @sql = N'
    SELECT p.ProductId
        ,CAST(CONVERT(BIGINT, t.CategoryId) AS INT) AS CategoryId
        ,t.CategoryName
        ,p.ProductTitle
        ,pv.VendorName
        ,ROUND(p.CostPrice, 0) AS CostPrice
        ,p.WholesalerPrice AS [WholeSalerPrice]
        ,p.RetailerPrice AS [RetailerPrice]
        ,ISNULL(p.RetailOfferPrice, 0) AS [OfferPrice]
        ,p.CoverImage AS CoverImage
        ,p.ModelNo
        ,p.STATUS
        ,CASE WHEN p.UpdatedBy   IS NOT NULL THEN p.UpdatedBy   ELSE p.CreatedBy   END AS UpdatedBy
        ,CASE WHEN p.UpdatedDate IS NOT NULL THEN p.UpdatedDate ELSE p.CreatedDate END AS CreatedDate
        ,ofr.OfferId
        ,ofr.OfferCode AS OfferCode
        ,pq.Quantity
        ,CASE
            WHEN ofr.OfferId IS NOT NULL
                AND ofr.StartDate <= @dt
                AND ofr.EndDate   >= @dt
                THEN CAST(0 AS BIT)
            ELSE CAST(1 AS BIT)
         END AS ExpiredOffer
        ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
        ,stock.InStock
        ,stock.Inquiry
        ,stock.ReadyToDelivered
        ,stock.OnHold
        ,p.Width
        ,p.Height
        ,p.Depth
        ,p.Diameter
        ,p.DimensionUnitId
    FROM dbo.Products AS p WITH (NOLOCK)
    INNER JOIN dbo.ProductQuantities AS pq WITH (NOLOCK) ON p.ProductId = pq.ProductId
    INNER JOIN dbo.Categories        AS t  WITH (NOLOCK) ON p.CategoryId = t.CategoryId
    --INNER JOIN dbo.AspNetUsers       AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
    ' + @offerJoin + N'
    LEFT JOIN (
        SELECT pvm.ProductId, STRING_AGG(v.VendorName, '', '') AS VendorName
        FROM dbo.ProductVendorMapping AS pvm
        INNER JOIN dbo.Vendors AS v ON pvm.VendorId = v.VendorId
        WHERE (@VendorId IS NULL OR pvm.VendorId = @VendorId)
        GROUP BY pvm.ProductId
    ) AS pv ON p.ProductId = pv.ProductId
    OUTER APPLY (
        SELECT
             CAST(ISNULL(ia.Quantity, 0) AS NUMERIC(18,2)) AS InStock
            ,CAST(ISNULL(inquiry.Qty,          0) AS NUMERIC(18,2)) AS Inquiry
            ,CAST(ISNULL(ReadyToDelivered.Qty, 0) AS NUMERIC(18,2)) AS ReadyToDelivered
            ,CAST(ISNULL(OnHold.Qty,           0) AS NUMERIC(18,2)) AS OnHold
        FROM ProductQuantities ia WITH (NOLOCK)
        LEFT JOIN (
            SELECT vi.SubjectId, SUM(vi.Quantity) AS Qty
            FROM vw_InquiryItems vi WITH (NOLOCK)
            WHERE vi.TenantId = @TenantId AND vi.SubjectTypeId = @ProductSubjectTypeId
            GROUP BY vi.SubjectId
        ) inquiry          ON inquiry.SubjectId          = p.ProductId
        LEFT JOIN (
            SELECT vi.SubjectId, SUM(vi.Quantity) AS Qty
            FROM vw_ReadyToDeliveredItems vi WITH (NOLOCK)
            WHERE vi.TenantId = @TenantId AND vi.SubjectTypeId = @ProductSubjectTypeId
            GROUP BY vi.SubjectId
        ) ReadyToDelivered  ON ReadyToDelivered.SubjectId = p.ProductId
        LEFT JOIN (
            SELECT vi.SubjectId, SUM(vi.Quantity) AS Qty
            FROM vw_HoldItems vi WITH (NOLOCK)
            WHERE vi.TenantId = @TenantId AND vi.HoldUptoDate > SYSDATETIMEOFFSET()
            GROUP BY vi.SubjectId
        ) OnHold            ON OnHold.SubjectId           = p.ProductId
        WHERE ia.ProductId = p.ProductId
    ) AS stock
    '

    SET @where = N'
    WHERE p.TenantId = @TenantId
        AND p.STATUS <> 3
        AND t.TenantId = @TenantId
    '

    SET @where += @offerWhere


    IF @FromPrice IS NOT NULL AND @FromPrice <> -1
        SET @where += N' AND p.RetailerPrice >= @FromPrice'

    IF @ToPrice IS NOT NULL AND @ToPrice <> -1
        SET @where += N' AND p.RetailerPrice <= @ToPrice'

    -- Status
    IF @PublishStatus IS NOT NULL
        SET @where += N' AND p.STATUS = @PublishStatus'

    -- Category type
    IF @CategoryTypeId IS NOT NULL
        SET @where += N' AND t.CategoryTypeId = @CategoryTypeId'

    -- Model no
    IF ISNULL(@ModelNo, '') <> ''
        SET @where += N' AND p.ModelNo LIKE ''%'' + @ModelNo + ''%'''

    -- Product title
    IF ISNULL(@ProductTitle, '') <> ''
        SET @where += N' AND p.ProductTitle LIKE ''%'' + @ProductTitle + ''%'''

    -- Date range
    IF @UpdateFromDate IS NOT NULL AND @UpdateToDate IS NOT NULL
        SET @where += N' AND p.UpdatedDate BETWEEN @UpdateFromDate AND @UpdateToDate'

    -- Vendor
    IF ISNULL(@VendorId, -1) <> -1
        SET @where += N'
        AND EXISTS (
            SELECT 1 FROM dbo.ProductVendorMapping AS pvm
            WHERE pvm.ProductId = p.ProductId AND pvm.VendorId = @VendorId
        )'

    -- Stock / quantity
    IF @Quantity IS NOT NULL AND @StockFilterOperation IS NOT NULL
    BEGIN
        IF @StockFilterOperation = '='
            SET @where += N' AND pq.Quantity = @Quantity'
        ELSE IF @StockFilterOperation = '>='
            SET @where += N' AND pq.Quantity >= @Quantity'
        ELSE IF @StockFilterOperation = '<='
            SET @where += N' AND pq.Quantity <= @Quantity'
    END

    -- Category
    IF @CategoryId IS NOT NULL AND @CategoryId <> -1
    BEGIN
        SET @where += N' AND p.CategoryId = @CategoryId'
    END
    ELSE IF @ParentCategoryId IS NOT NULL AND @ParentCategoryId <> -1
    BEGIN
        SET @where += N'
        AND (
            (
                EXISTS (
                    SELECT 1 FROM dbo.Categories AS pcat WITH (NOLOCK)
                    WHERE pcat.CategoryId        = @ParentCategoryId
                        AND pcat.ParentCategoryId IS NULL
                        AND pcat.TenantId         = @TenantId
                )
                AND (p.CategoryId = @ParentCategoryId OR t.ParentCategoryId = @ParentCategoryId)
            )
            OR
            (
                NOT EXISTS (
                    SELECT 1 FROM dbo.Categories AS pcat WITH (NOLOCK)
                    WHERE pcat.CategoryId        = @ParentCategoryId
                        AND pcat.ParentCategoryId IS NULL
                        AND pcat.TenantId         = @TenantId
                )
                AND p.CategoryId = @ParentCategoryId
            )
        )'
    END


    SET @sql = @sql + @where + N'
    ORDER BY t.CategoryName, p.ProductTitle
    OPTION (RECOMPILE)'


    SET @paramDef = N'
         @TenantId               INT
        ,@dt                     DATE
        ,@ProductSubjectTypeId   INT
        ,@CategoryId             BIGINT
        ,@RoleId                 VARCHAR(100)
        ,@ProductTitle           VARCHAR(100)
        ,@ModelNo                VARCHAR(100)
        ,@PublishStatus          INT
        ,@OfferDataId            INT
        ,@UpdateFromDate         DATE
        ,@UpdateToDate           DATE
        ,@VendorId               BIGINT
        ,@FromPrice              INT
        ,@ToPrice                INT
        ,@IsOfferedProduct       BIT
        ,@Quantity               NUMERIC(18,2)
        ,@StockFilterOperation   VARCHAR(5)
        ,@CategoryTypeId         BIGINT
        ,@ParentCategoryId       BIGINT
    '

    BEGIN TRY
        EXEC sp_executesql
             @sql
            ,@paramDef
            ,@TenantId             = @TenantId
            ,@dt                   = @dt
            ,@ProductSubjectTypeId = @ProductSubjectTypeId
            ,@CategoryId           = @CategoryId
            ,@RoleId               = @RoleId
            ,@ProductTitle         = @ProductTitle
            ,@ModelNo              = @ModelNo
            ,@PublishStatus        = @PublishStatus
            ,@OfferDataId          = @OfferDataId
            ,@UpdateFromDate       = @UpdateFromDate
            ,@UpdateToDate         = @UpdateToDate
            ,@VendorId             = @VendorId
            ,@FromPrice            = @FromPrice
            ,@ToPrice              = @ToPrice
            ,@IsOfferedProduct     = @IsOfferedProduct
            ,@Quantity             = @Quantity
            ,@StockFilterOperation = @StockFilterOperation
            ,@CategoryTypeId       = @CategoryTypeId
            ,@ParentCategoryId     = @ParentCategoryId
    END TRY
    BEGIN CATCH
       DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ObjectName VARCHAR(500)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()
			,@ObjectName = OBJECT_NAME(@@PROCID)

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				)
    END CATCH
END

GO

