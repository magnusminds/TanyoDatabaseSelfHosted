/*
EXEC [dbo].[ListProducts]
    @TenantId = 2,
	@RoleId = 'Admin',
    @PageIndex = 1,
    @PageSize = 100;
*/
CREATE   PROCEDURE [dbo].[ListProducts] (
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
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = '10'
	,@SortOrder VARCHAR(50) = 'DESC'
	,@IsOfferedProduct BIT = 0
	,@Quantity INT = NULL
	,@StockFilterOperation VARCHAR(5) = NULL
	,@CategoryTypeId BIGINT = 1
	,@ParentCategoryId BIGINT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @dt DATE

	SELECT @dt = CAST(GETDATE() AS DATE)

	BEGIN TRY
		DECLARE @selectquery NVARCHAR(max) = ''
		DECLARE @wherecodition NVARCHAR(max) = ''
		DECLARE @OrderByquery NVARCHAR(max) = ''
		DECLARE @Query NVARCHAR(max) = ''
		DECLARE @AddsOnQuery NVARCHAR(max) = ''
		DECLARE @AddsOnWhereQuery NVARCHAR(max) = ''
		DECLARE @params NVARCHAR(100) = N'@ProductTitle VARCHAR(100), @ModelNo VARCHAR(100) OUTPUT';

		IF (@IsOfferedProduct = 0)
		BEGIN
			SELECT @AddsOnQuery = 'LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId'

			IF @OfferDataId IS NOT NULL
			BEGIN
				IF @OfferDataId = - 2
					SET @AddsOnWhereQuery = @AddsOnWhereQuery + ' AND ofr.OfferId IS NULL';
				ELSE IF @OfferDataId <> - 1
					SET @AddsOnWhereQuery = @AddsOnWhereQuery + ' AND ofr.OfferId =' + CAST(@OfferDataId AS VARCHAR(10));
			END
		END
		ELSE
		BEGIN
			SELECT @AddsOnQuery = 'INNER JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId'

			IF @OfferDataId IN (
					- 1
					,- 2
					)
				SET @AddsOnWhereQuery = @AddsOnWhereQuery + ' AND ofr.OfferId = ' + CAST(@OfferDataId AS VARCHAR(10));
		END

		SET @selectquery = 'SELECT p.ProductId
				,CAST(CONVERT(BIGINT, t.CategoryId) AS INT) AS CategoryId
				,t.CategoryName
				,p.ProductTitle
				,REPLACE(p.VendorNames, '','', '',<BR>'') AS VendorNames
				,ROUND(p.CostPrice,2) AS CostPrice
				,p.WholesalerPrice AS [WholeSalerPrice]
				,p.RetailerPrice AS [RetailerPrice]
				,ISNULL(p.RetailOfferPrice, 0) [OfferPrice]
				,ISNULL(p.CoverImage, '''') CoverImage
				,p.ModelNo
				,p.Status
				,CASE 
					WHEN p.UpdatedBy IS NOT NULL
						THEN p.UpdatedBy
					ELSE p.CreatedBy
					END AS UpdatedBy
				,CASE 
					WHEN p.UpdatedDate IS NOT NULL
						THEN p.UpdatedDate
					ELSE p.CreatedDate
					END AS CreatedDate
				,ofr.OfferId
				,ofr.OfferCode as OfferCode
				,pq.Quantity
				,CASE 
					WHEN ofr.OfferId IS NOT NULL 
							AND ofr.StartDate <= ''' + ISNULL(CAST(@dt AS VARCHAR(20)), '') + '''
							AND ofr.EndDate >= ''' + ISNULL(CAST(@dt AS VARCHAR(20)), '') + 
			'''
						THEN CAST(0 AS BIT)
					ELSE CAST(1 AS BIT)
				END AS ExpiredOffer
				,t.IsSellByPerSQFT
				,ISNULL(ofr.OfferPercentage, 0) AS OfferPercentage
				,p.Height
				,p.Width
				,p.Depth
				,p.Diameter
				,p.DimensionUnitId
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM dbo.Products AS p WITH (NOLOCK)
			INNER JOIN dbo.ProductQuantities AS pq WITH (NOLOCK) ON p.ProductId = pq.ProductId
			INNER JOIN dbo.Categories AS t WITH (NOLOCK) ON p.CategoryId = t.CategoryId
			' + @AddsOnQuery + '			
			'
		SET @wherecodition = '
			WHERE p.TenantId = ' + CAST(@TenantId AS VARCHAR(20)) + '
			AND p.STATUS <> 3
			AND t.TenantId = ' + CAST(@TenantId AS VARCHAR(20)) + ' 
			' + @AddsOnWhereQuery

		IF @FromPrice IS NOT NULL
			AND @FromPrice <> - 1
			SET @wherecodition = @wherecodition + ' AND p.RetailerPrice >= ' + CAST(@FromPrice AS VARCHAR(20));

		IF @ToPrice IS NOT NULL
			AND @ToPrice <> - 1
			SET @wherecodition = @wherecodition + ' AND p.RetailerPrice <= ' + CAST(@ToPrice AS VARCHAR(20));

		IF @PublishStatus IS NOT NULL
			SET @wherecodition = @wherecodition + ' AND p.Status = ' + CAST(@PublishStatus AS VARCHAR(10));

		IF @ModelNo IS NOT NULL
			AND LTRIM(RTRIM(@ModelNo)) <> ''
			SET @wherecodition = @wherecodition + ' AND p.ModelNo LIKE ''%''+ @ModelNo + ''%'''

		IF @ParentCategoryId IS NOT NULL
			AND @ParentCategoryId <> - 1
			AND (
				@CategoryId IS NULL
				OR @CategoryId = - 1
				)
		BEGIN
			IF EXISTS (
					SELECT 1
					FROM dbo.Categories
					WHERE CategoryId = @ParentCategoryId
						AND ParentCategoryId IS NULL
					)
			BEGIN
				SET @wherecodition = @wherecodition + ' AND (t.CategoryId = ' + CAST(@ParentCategoryId AS VARCHAR(10)) + ' OR t.ParentCategoryId = ' + CAST(@ParentCategoryId AS VARCHAR(10)) + ')';
			END
			ELSE
			BEGIN
				SET @wherecodition = @wherecodition + ' AND t.CategoryId = ' + CAST(@ParentCategoryId AS VARCHAR(10));
			END
		END
		ELSE IF @CategoryId IS NOT NULL
			AND @CategoryId <> - 1
		BEGIN
			SET @wherecodition = @wherecodition + ' AND t.CategoryId = ' + CAST(@CategoryId AS VARCHAR(10));
		END

		IF @ProductTitle IS NOT NULL
			AND LTRIM(RTRIM(@ProductTitle)) <> ''
			SET @wherecodition = @wherecodition + ' AND p.ProductTitle LIKE ''%''+ @ProductTitle + ''%'''

		IF @UpdateFromDate IS NOT NULL
			AND @UpdateToDate IS NOT NULL
			SET @wherecodition = @wherecodition + ' AND p.UpdatedDate BETWEEN ''' + CAST(@UpdateFromDate AS VARCHAR(20)) + ''' AND ''' + CAST(@UpdateToDate AS VARCHAR(20)) + ''''

		IF @VendorId IS NOT NULL
			AND @VendorId <> - 1
			SET @wherecodition = @wherecodition + ' AND EXISTS (
					SELECT 1 FROM dbo.ProductVendorMapping AS pvm WITH (NOLOCK)
					WHERE pvm.ProductId = p.ProductId
					AND pvm.VendorId = ' + CAST(@VendorId AS VARCHAR(10)) + '
				)'

		IF @Quantity IS NOT NULL
			AND @StockFilterOperation IS NOT NULL
		BEGIN
			IF @StockFilterOperation = '='
				SET @wherecodition = @wherecodition + ' AND pq.Quantity = ' + CAST(@Quantity AS VARCHAR(10));
			ELSE IF @StockFilterOperation = '>='
				SET @wherecodition = @wherecodition + ' AND pq.Quantity >= ' + CAST(@Quantity AS VARCHAR(10));
			ELSE IF @StockFilterOperation = '<='
				SET @wherecodition = @wherecodition + ' AND pq.Quantity <= ' + CAST(@Quantity AS VARCHAR(10));
		END

		IF @CategoryTypeId IS NOT NULL
		BEGIN
			SET @wherecodition = @wherecodition + ' AND t.CategoryTypeId = ' + CAST(@CategoryTypeId AS VARCHAR(10))
		END

		IF @SortBy = 'CategoryName'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY t.CategoryName ASC';
		END
		ELSE IF @SortBy = 'CategoryName'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY t.CategoryName DESC';
		END
		ELSE IF @SortBy = 'ProductTitle'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.ProductTitle ASC';
		END
		ELSE IF @SortBy = 'ProductTitle'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.ProductTitle DESC';
		END
		ELSE IF @SortBy = 'ModelNo'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.ModelNo ASC';
		END
		ELSE IF @SortBy = 'ModelNo'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.ModelNo DESC';
		END
		ELSE IF @SortBy = 'CostPrice'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.CostPrice ASC';
		END
		ELSE IF @SortBy = 'CostPrice'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.CostPrice DESC';
		END
		ELSE IF @SortBy = 'UpdatedDate'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.UpdatedDate ASC';
		END
		ELSE IF @SortBy = 'UpdatedDate'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.UpdatedDate DESC';
		END
		ELSE IF @SortBy = 'RetailerPrice'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.RetailerPrice ASC';
		END
		ELSE IF @SortBy = 'RetailerPrice'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.RetailerPrice DESC';
		END
		ELSE IF @SortBy = 'OfferPrice'
			AND @SortOrder = 'ASC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.RetailOfferPrice ASC';
		END
		ELSE IF @SortBy = 'OfferPrice'
			AND @SortOrder = 'DESC'
		BEGIN
			SET @OrderByquery += ' ORDER BY p.RetailOfferPrice DESC';
		END
		ELSE
		BEGIN
			-- Default Order
			SET @OrderByquery += ' ORDER BY p.ProductId DESC';
		END

		SET @OrderByquery += '
				OFFSET(' + CAST(@PageIndex AS VARCHAR(20)) + ' - 1) * ' + CAST(@PageSize AS VARCHAR(20)) + ' ROWS
				FETCH NEXT ' + CAST(@PageSize AS VARCHAR(20)) + ' ROWS ONLY'

		SELECT @Query = @selectquery + @wherecodition + @OrderByquery

		EXEC sp_executesql @Query
			,@params
			,@ProductTitle = @ProductTitle
			,@ModelNo = @ModelNo
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ObjectName VARCHAR(500)

		SET @ObjectName = OBJECT_NAME(@@PROCID)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

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

