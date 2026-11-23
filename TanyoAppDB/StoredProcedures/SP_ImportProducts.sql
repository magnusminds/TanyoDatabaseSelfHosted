CREATE PROCEDURE [dbo].[SP_ImportProducts] (
	@WrkProductID BIGINT
	,@UserId INT
	,@TotalRecords INT
	,@ProcessStartDate DATETIMEOFFSET = NULL
	,@ProcessEndDate DATETIMEOFFSET = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

BEGIN TRY

	BEGIN TRAN SP_ImportProducts

	DROP TABLE IF EXISTS #Vendors

	DROP TABLE IF EXISTS #VendorList
	
	DECLARE @TenantId BIGINT
	DECLARE @AllowDuplicateProductModelNo BIT
	DECLARE @VendorName VARCHAR(MAX)
		,@UnMappedVendorName VARCHAR(MAX)
		,@CategoryName VARCHAR(MAX)
		,@ProductTitle VARCHAR(MAX)
		,@ModelNo VARCHAR(MAX)
		,@CostPrice VARCHAR(MAX)
		,@RetailerPrice VARCHAR(MAX)
		,@WholesalerPrice VARCHAR(MAX)
		,@StockQty VARCHAR(MAX)
		,@CategoryId INT
		,@ErrorMessage VARCHAR(MAX) = ''
		,@WrkImportFileID BIGINT
		,@Width VARCHAR(MAX)
		,@Height VARCHAR(MAX)
		,@Depth VARCHAR(MAX)
		,@Diameter VARCHAR(MAX)
		,@Unit VARCHAR(250)
		,@DimensionUnitId INT
		,@WarehouseName VARCHAR(MAX)
		,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtUTC DATETIME = GETUTCDATE()
		,@NewProductId BIGINT
		,@WarehouseId BIGINT
		,@MaxDimension DECIMAL(18,2) = 9999.99
		,@TempDecimal DECIMAL(18,2)
		,@TenantLogo VARCHAR (MAX)
		,@ProductSubjectType INT
		,@CategoryTypeId BIGINT
		,@IsPriceAutoCalculated BIT
	DECLARE @Success INT
		DECLARE @Failed INT

	SELECT TOP 1 @TenantId = TenantId
	FROM WrkImportFiles WIF WITH (NOLOCK)
	INNER JOIN WrkProducts WP WITH (NOLOCK) ON WIF.WrkImportFileID = WP.WrkImportFileID
	WHERE WP.WrkProductID = @WrkProductID

	SELECT @AllowDuplicateProductModelNo = AllowDuplicateProductModelNo
	,@TenantLogo = LogoPath
	FROM Tenants WITH (NOLOCK)
	WHERE TenantId = @TenantId

	SELECT @WarehouseId = Id
	FROM Warehouse WITH (NOLOCK)
	WHERE Name = 'Other'
		AND TenantId = @TenantId

	SELECT @ProductSubjectType = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
	AND TenantId = @TenantId

	SELECT @WrkImportFileID = WrkImportFileID
		,@VendorName = VendorName
		,@CategoryName = CategoryName
		,@ProductTitle = ProductTitle
		,@ModelNo = ModelNo
		,@CostPrice = CostPrice
		,@RetailerPrice = RetailerPrice
		,@WholesalerPrice = WholesalerPrice
		,@StockQty = StockQty
		,@Width = Width
		,@Height = Height
		,@Depth = Depth
		,@Diameter = Diameter
		,@Unit = TRIM(Unit)
		,@WarehouseName = WarehouseName
	FROM WrkProducts WITH (NOLOCK)
	WHERE WrkProductID = @WrkProductID

	SELECT TOP 1 @DimensionUnitId = LV.LookupValueId
	FROM LookupValues LV WITH (NOLOCK)
	INNER JOIN Lookups L WITH (NOLOCK) ON L.LookupId = LV.LookupId
	WHERE L.LookupName = 'Unit'
		AND L.TenantId = @TenantId
		AND L.IsDeleted = 0
		AND LV.IsDeleted = 0
		AND (
			LV.LookupValueName = @Unit
			OR (
				(ISNULL(@Unit, '') = '' OR @Unit IN ('Inches', 'Inch', 'in'))
				AND LV.LookupValueName IN ('Inches', 'Inch', 'in')
				)
			)
	ORDER BY CASE WHEN LV.LookupValueName = @Unit THEN 0 ELSE 1 END
		,LV.LookupValueId

	IF ISNULL(@VendorName,'') <> ''
	BEGIN
		IF EXISTS (
				SELECT value
				FROM STRING_SPLIT(@VendorName, ',') V
				WHERE NOT EXISTS (
						SELECT 1
						FROM Vendors VD
						WHERE VD.VendorName = LTRIM(RTRIM(V.value))
							AND TenantId = @TenantId
						)
				)
		BEGIN
			SELECT @UnMappedVendorName = STRING_AGG(V.value, ',')
			FROM STRING_SPLIT(@VendorName, ',') V
			WHERE NOT EXISTS (
					SELECT 1
					FROM Vendors VD
					WHERE VD.VendorName = LTRIM(RTRIM(V.value))
					AND TenantId = @TenantId
					)

			SET @ErrorMessage = @UnMappedVendorName + ' Vendor does not exist. '


		END

			SELECT TRIM (V.value) AS VendorName
			INTO #VendorList
			FROM STRING_SPLIT(@VendorName, ',') V

			IF EXISTS (
						    SELECT 1
						    FROM #VendorList
						    WHERE PATINDEX('%[^A-Za-z0-9&./()'' -]%', VendorName) > 0
					)
			BEGIN

			    SET @ErrorMessage = @ErrorMessage + 'Vendor name contains invalid characters. ';
			    
			END
	END
	SELECT @CategoryId = CategoryId
	,@CategoryTypeId = CategoryTypeId
	FROM Categories WITH (NOLOCK)
	WHERE CategoryName = @CategoryName
		AND TenantId = @TenantId
		AND IsDeleted = 0

	IF @CategoryId IS NULL
		SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Category does not exist. '

	IF ISNULL(@ProductTitle, '') = ''
		SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Product Title is required. '

	IF ISNULL(@ModelNo, '') = ''
		SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'ModelNo is required. '
	ELSE
	BEGIN
		IF CHARINDEX(' ', @ModelNo) > 0
			SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'ModelNo does not allow white space. '

		IF LEN(@ModelNo) > 100
			SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Maximum length of ModelNo is 100 characters. '

		IF PATINDEX('%[^a-zA-Z0-9/_-]%', @ModelNo) > 0
		    SET @ErrorMessage = @ErrorMessage + 'ModelNo allows only letters, numbers, -, / and _. '


		IF @AllowDuplicateProductModelNo = 0
		BEGIN
			IF EXISTS (
					SELECT 1
					FROM Products
					WHERE ModelNo = @ModelNo
					and TenantId = @TenantId
					AND Status <> 3
					)
				SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'ModelNo already exists. '
		END

		IF EXISTS (
				SELECT 1
				FROM Products
				WHERE ModelNo = @ModelNo
					AND ProductTitle = @ProductTitle
					AND CategoryId = @CategoryId
					AND TenantId = @TenantId
					AND Status <> 3
				)
		BEGIN
			SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Product already exists. '
		END
	END

	IF ISNULL(@Width,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@Width AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Width allows only numeric values. '
	    ELSE IF @TempDecimal > @MaxDimension
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Width exceeds the limit of 9999.99. '
	END

	IF ISNULL(@Height,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@Height AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Height allows only numeric values. '
	    ELSE IF @TempDecimal > @MaxDimension
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Height exceeds the limit of 9999.99. '
	END

	IF ISNULL(@Depth,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@Depth AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Depth allows only numeric values. '
	    ELSE IF @TempDecimal > @MaxDimension
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Depth exceeds the limit of 9999.99. '
	END

	IF ISNULL(@Diameter,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@Diameter AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Diameter allows only numeric values. '
	    ELSE IF @TempDecimal > @MaxDimension
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Diameter exceeds the limit of 9999.99. '
	END

	IF ISNULL(@Unit, '') <> '' AND @DimensionUnitId IS NULL
		SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Unit ''' + @Unit + ''' does not exist. '

	IF ISNULL(@CostPrice,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@CostPrice AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Cost Price allows only numeric values. '
	    ELSE IF @TempDecimal < 0
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Cost Price cannot be negative. '
	END

	IF ISNULL(@RetailerPrice,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@RetailerPrice AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Retailer Price allows only numeric values. '
	    ELSE IF @TempDecimal < 0
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Retailer Price cannot be negative. '
	END

	IF ISNULL(@WholesalerPrice,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@WholesalerPrice AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Wholesaler Price allows only numeric values. '
	    ELSE IF @TempDecimal < 0
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Wholesaler Price cannot be negative. '
	END

	IF ISNULL(@StockQty,'') <> ''
	BEGIN
	    SET @TempDecimal = TRY_CAST(@StockQty AS DECIMAL(18,2))
	
	    IF @TempDecimal IS NULL
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Stock Quantity allows only numeric values. '
	    ELSE IF @TempDecimal < 0
	        SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Stock Quantity cannot be negative. '
	END

	IF ISNULL(@CategoryTypeId,0) <> 1
	BEGIN

	     SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Only product records can be processed using this module. Please use the appropriate module for fabric. '

	END

	IF @ErrorMessage = ''
	BEGIN
		INSERT INTO Products (
			CategoryId
			,ProductTitle
			,ModelNo
			,Width
			,Height
			,Depth
			,Diameter
			,DimensionUnitId
			--,CostPrice
			--,RetailerPrice
			--,WholesalerPrice
			--,IsPriceAutoCalculated
			,VendorNames
			,TenantId
			,Status
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			)
		SELECT @CategoryId
			,TRIM(@ProductTitle)
			,TRIM(@ModelNo)
			,CASE 
					WHEN @Width IS NULL OR @Width = '' OR CAST(NULLIF(@Width,'') AS NUMERIC(18, 2)) = 0
						THEN 1
					ELSE CAST(@Width AS NUMERIC(18, 2))
					END
			,CASE 
					WHEN @Height IS NULL OR @Height = '' OR CAST(NULLIF(@Height,'') AS NUMERIC(18, 2)) = 0
						THEN 1
					ELSE CAST(@Height AS NUMERIC(18, 2))
					END
			,CASE 
					WHEN @Depth IS NULL OR @Depth = '' OR CAST(NULLIF(@Depth,'') AS NUMERIC(18, 2)) = 0
						THEN 1
					ELSE CAST(@Depth AS NUMERIC(18, 2))
					END
			,CASE 
					WHEN @Diameter IS NULL OR @Diameter = '' OR CAST(NULLIF(@Diameter,'') AS NUMERIC(18, 2)) = 0
						THEN 1
					ELSE CAST(@Diameter AS NUMERIC(18, 2))
					END
			,@DimensionUnitId
			--,ISNULL(TRY_CAST(@CostPrice AS numeric(18, 2)),0)
			--,ISNULL(TRY_CAST(@RetailerPrice AS numeric(18, 2)),0)
			--,ISNULL(TRY_CAST(@WholesalerPrice AS numeric(18, 2)),0)
			--,CASE 
			--	WHEN ISNULL(TRY_CAST(@RetailerPrice AS numeric(18, 2)),0) > 0
			--		OR ISNULL(TRY_CAST(@WholesalerPrice AS numeric(18, 2)),0) > 0
			--		THEN 0
			--	ELSE 1
			--	END AS IsPriceAutoCalculated
			,@VendorName AS VendorNames
			,CAST(@TenantId AS INT)
			,2 AS Status
			,TRY_CAST(@UserId AS INT) CreatedBy
			,@dt CreatedDate
			,@dtUTC CreatedUTCDate

		SET @NewProductId = SCOPE_IDENTITY()

		SET @IsPriceAutoCalculated = 0

		SET @CostPrice = ISNULL(TRY_CAST(@CostPrice AS NUMERIC(18, 2)),0)
		SET @RetailerPrice = ISNULL(TRY_CAST(@RetailerPrice AS NUMERIC(18, 2)),0)
		SET @WholesalerPrice = ISNULL(TRY_CAST(@WholesalerPrice AS NUMERIC(18, 2)),0)
		SET @IsPriceAutoCalculated = CASE 
										WHEN ISNULL(TRY_CAST(@RetailerPrice AS NUMERIC(18, 2)),0) > 0
											OR ISNULL(TRY_CAST(@WholesalerPrice AS NUMERIC(18, 2)),0) > 0
											THEN 0
										ELSE 1
										END
		DECLARE @Status INT
			,@Message VARCHAR(500)

		EXEC dbo.PopulateProductPriceById
			@ProductId = @NewProductId
			,@UserId = @UserId
			,@TenantId = @TenantId
			,@CostPrice = @CostPrice
			,@RetailerPrice = @RetailerPrice
			,@WholesalerPrice = @WholesalerPrice
			,@IsPriceAutoCalculated = @IsPriceAutoCalculated
			,@Status = @Status OUTPUT
			,@Message = @Message OUTPUT

		INSERT INTO ProductQuantities (
			ProductId
			,QuantityDate
			,Quantity
			,LastModifiedBy
			,LastModifiedDate
			,LastModifiedUTCDate
			,MinimumLimit
			)
		SELECT @NewProductId
			,@dt
			,ISNULL(TRY_CAST(@StockQty AS NUMERIC(18,2)),0)
			,TRY_CAST(@UserId AS BIGINT)
			,@dt
			,@dtUTC
			,0

		INSERT INTO ProductQuantitiesByWarehouse (
			ProductId
			,WarehouseId
			,QuantityDate
			,Quantity
			,LastModifiedBy
			,LastModifiedDate
			,LastModifiedUTCDate
			)
		SELECT @NewProductId
			,@WarehouseId
			,@dt
			,ISNULL(TRY_CAST(@StockQty AS NUMERIC(18,2)),0)
			,TRY_CAST(@UserId AS BIGINT)
			,@dt
			,@dtUTC
		
		SELECT DISTINCT VendorId
			,TRIM(value) AS VendorName
			,ROW_NUMBER() OVER(Order by VendorId) AS ID
		INTO #Vendors
		FROM STRING_SPLIT(@VendorName, ',') V
		INNER JOIN Vendors VD ON VD.VendorName = TRIM(V.value)
			AND TenantId = @TenantId
		
		IF ISNULL(@VendorName,'') <> '' 
		BEGIN

			INSERT INTO ProductVendorMapping (
				ProductId
				,VendorId
				,IsDefault
				,VendorProductId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,VendorModelNo
				,VendorProductPrice
				)
			SELECT @NewProductId
				,VendorId
				,CASE 
					WHEN ID = 1
						THEN 1
					ELSE 0
					END IsDefault
				,NULL VendorProductId
				,0
				,TRY_CAST(@UserId AS BIGINT)
				,@dt
				,@dtUTC
				,NULL VendorModelNo
				,NULL VendorProductPrice
			FROM #Vendors
		END


		UPDATE WrkProducts
		SET Status = 2
			,ErrorMessage = NULL
		WHERE WrkProductID = @WrkProductID

		IF ISNULL(TRY_CAST(@StockQty AS numeric(18,2)),0) > 0 AND ISNULL(@NewProductId,0) > 0
		BEGIN

			INSERT INTO InventoryLogs
			(
			
			ProductId
			,WarehouseId
			,Description
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			
			)
			SELECT @NewProductId
			,@WarehouseId
			,'Inventory has been updated from 0.00 to ' + CAST(ISNULL(TRY_CAST(@StockQty AS NUMERIC(18,2)),0) AS VARCHAR(100)) + ' ( +' + @StockQty + ' ) ' + 'by import file.'
			,TRY_CAST(@UserId AS INT)
			,@dt
			,@dtUTC

		END

		IF ISNULL(@NewProductId, 0) > 0
			BEGIN
				EXEC dbo.SaveActivityLog 
				     @SubjectTypeId = @ProductSubjectType
					,@SubjectId = @NewProductId
					,@Description = 'Product Created by import file.'
					,@Action = 'CREATE'
					,@CreatedBy = @UserId
					,@CreatedDate = @dt
					,@CreatedUTCDate = @dtUTC;
			END

		CREATE TABLE #TempResponse

		(
		Status	BIT
		,Message VARCHAR(128)
		,Data VARCHAR(2056)	
		,Error VARCHAR(2056)	
		
		)
		INSERT INTO #TempResponse

		EXEC UpdateProductPriceByCategory 
		@TenantID = @TenantID
		,@CategoryID = @CategoryID
		,@ProductID = @NewProductId
 


	END
	ELSE
	BEGIN
		UPDATE WrkProducts
		SET Status = 3
			,ErrorMessage = @ErrorMessage
		WHERE WrkProductID = @WrkProductID
	END


		--	SELECT @Success = SUM(CASE 
		--			WHEN Status = 2
		--				THEN 1
		--			ELSE 0
		--			END)
		--	,@Failed = SUM(CASE 
		--			WHEN Status = 3
		--				THEN 1
		--			ELSE 0
		--			END)
		--FROM WrkProducts 
		--WHERE WrkImportFileID = @WrkImportFileID

		UPDATE WrkImportFiles
		SET Success = CASE WHEN @ErrorMessage = '' THEN ISNULL(Success,0) + 1 else ISNULL(Success,0) END 
			,Failed = CASE WHEN @ErrorMessage = '' then ISNULL(Failed,0)  else ISNULL(Failed,0) + 1 END
			,Status = 2
			,TotalRecords = @TotalRecords
			,ProcessStartDate = CASE WHEN @ProcessStartDate IS NULL THEN ProcessStartDate ELSE @ProcessStartDate END
			,ProcessEndDate = CASE WHEN @ProcessEndDate IS NULL THEN ProcessEndDate ELSE @ProcessEndDate END
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @DTUTC
		WHERE WrkImportFileID = @WrkImportFileID



	SELECT @NewProductId AS ProductId
	,@TenantId AS TenantId
	,CASE WHEN @ErrorMessage = '' THEN @TenantLogo ELSE NULL END AS TenantLogo
	,NULLIF(@ErrorMessage,'') AS ErrorMessage

	COMMIT TRAN SP_ImportProducts;

END TRY

BEGIN CATCH

	IF @@TRANCOUNT >0
		ROLLBACK TRAN SP_ImportProducts;

    DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog 
			 @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

	SELECT NULL AS ProductId
	,@TenantId AS TenantId
	,NULL AS TenantLogo
	,ERROR_MESSAGE() AS ErrorMessage


END CATCH

END

GO

