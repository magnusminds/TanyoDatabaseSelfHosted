--[GetProducts] @TenantId=1, @RoleId='555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
CREATE PROCEDURE [dbo].[GetProducts_v1] (
	@TenantId INT
	,@CategoryId BIGINT = NULL
	,@RoleId VARCHAR(100)
	,@ProductTitle VARCHAR(100) = NULL
	,@ModelNo VARCHAR(100) = NULL
	,@PublishStatus INT = NULL
	,@OfferDataId INT = NULL
	,@UpdateFromDate DATE = NULL
	,@UpdateToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = '10'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	DECLARE @ProductSubjectTypeId INT;
	DECLARE @dt DATE
	SELECT @dt = CAST(GETDATE() AS DATE)

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId
		AND IsDeleted = 0

	BEGIN TRY

		DECLARE @Products AS TABLE (ProductID BIGINT, TotalCount INT)

		
		INSERT INTO @Products(ProductID, TotalCount)
		SELECT p.ProductId 
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM dbo.Products AS p WITH (NOLOCK)
		INNER JOIN dbo.Categories AS t WITH (NOLOCK) ON p.CategoryId = t.CategoryId
		INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
		LEFT JOIN dbo.ProductQuantities AS ia WITH (NOLOCK) ON p.ProductId = ia.ProductId
		LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId
		WHERE p.TenantId = @TenantId
			AND p.STATUS <> 3
			AND (
				@PublishStatus IS NULL
				OR p.STATUS = @PublishStatus
				)
			AND (
				ISNULL(@ModelNo, '') = ''
				OR p.ModelNo LIKE  '%' + @ModelNo + + '%'
				)
			AND (
				ISNULL(@CategoryId, - 1) = - 1
				OR p.CategoryId = @CategoryId
				)
			AND (
				ISNULL(@ProductTitle, '') = ''
				OR p.ProductTitle LIKE  '%' + @ProductTitle + '%'
				)
			AND (
				ISNULL(@OfferDataId, - 1) = - 1
				OR ofr.OfferId = @OfferDataId
				)
			AND (
				@UpdateFromDate IS NULL
				OR @UpdateToDate IS NULL
				OR p.UpdatedDate BETWEEN @UpdateFromDate
					AND @UpdateToDate
				)
		ORDER BY CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN t.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN t.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN p.ProductTitle
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN p.ProductTitle
				END DESC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN p.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN p.ModelNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CostPrice'
					AND @SortOrder = 'ASC'
					THEN ROUND(p.CostPrice, 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'CostPrice'
					AND @SortOrder = 'DESC'
					THEN ROUND(p.CostPrice, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'UpdatedDate'
					AND @SortOrder = 'ASC'
					THEN p.UpdatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'UpdatedDate'
					AND @SortOrder = 'DESC'
					THEN p.UpdatedDate
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;

		SELECT p.ProductId
			,CAST(CONVERT(BIGINT, t.CategoryId) AS INT) AS CategoryId
			,t.CategoryName
			,p.ProductTitle
			,ROUND(p.CostPrice, 0) AS CostPrice
			,p.WholesalerPrice [WholeSalerPrice]
			,p.RetailerPrice [RetailerPrice]
			,CASE 
				WHEN ofr.OfferId IS NOT NULL
					THEN p.RetailOfferPrice ELSE 0
				END [OfferPrice]
			,p.CoverImage CoverImage
			,p.ModelNo
			,p.STATUS
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
			,ISNULL(ia.Quantity, 0) AS InStock
			--,0 AS ReadyToDelivered
			--,0 AS Inquiry
			,ISNULL((SELECT SUM(os.Quantity)
				FROM dbo.Orders AS o WITH (NOLOCK) 
				INNER JOIN dbo.OrderSetItems AS os WITH (NOLOCK) ON os.OrderId = o.OrderId
				WHERE os.ItemStatus = 2
					and o.TenantId = @TenantId
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							and os.SubjectId = p.ProductId
				),0)
				AS ReadyToDelivered
			,ISNULL((SELECT SUM(os.Quantity)
				FROM dbo.Orders AS o WITH (NOLOCK) 
				INNER JOIN dbo.OrderSetItems AS os WITH (NOLOCK) ON os.OrderId = o.OrderId
				WHERE p.ProductId = os.SubjectId
				and o.TenantId = @TenantId
				AND o.STATUS = 0
				AND os.IsDeleted != 1
				AND o.STATUS != 9
				AND os.SubjectTypeId = @ProductSubjectTypeId
						),0) AS Inquiry
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM dbo.Products AS p WITH (NOLOCK)
		INNER JOIN @Products x ON x.ProductID = p.ProductId
		INNER JOIN dbo.Categories AS t WITH (NOLOCK) ON p.CategoryId = t.CategoryId
		INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
		LEFT JOIN dbo.ProductQuantities AS ia WITH (NOLOCK) ON p.ProductId = ia.ProductId
		LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId
		WHERE p.TenantId = @TenantId
			AND p.STATUS <> 3
			AND (
				@PublishStatus IS NULL
				OR p.STATUS = @PublishStatus
				)
			AND (
				ISNULL(@ModelNo, '') = ''
				OR p.ModelNo LIKE  '%' + @ModelNo + + '%'
				)
			AND (
				ISNULL(@CategoryId, - 1) = - 1
				OR p.CategoryId = @CategoryId
				)
			AND (
				ISNULL(@ProductTitle, '') = ''
				OR p.ProductTitle LIKE  '%' + @ProductTitle + '%'
				)
			AND (
				ISNULL(@OfferDataId, - 1) = - 1
				OR ofr.OfferId = @OfferDataId
				)
			AND (
				@UpdateFromDate IS NULL
				OR @UpdateToDate IS NULL
				OR p.UpdatedDate BETWEEN @UpdateFromDate
					AND @UpdateToDate
				)
		ORDER BY CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN t.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN t.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN p.ProductTitle
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN p.ProductTitle
				END DESC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN p.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN p.ModelNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CostPrice'
					AND @SortOrder = 'ASC'
					THEN ROUND(p.CostPrice, 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'CostPrice'
					AND @SortOrder = 'DESC'
					THEN ROUND(p.CostPrice, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'UpdatedDate'
					AND @SortOrder = 'ASC'
					THEN p.UpdatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'UpdatedDate'
					AND @SortOrder = 'DESC'
					THEN p.UpdatedDate
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;

	END TRY

BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

