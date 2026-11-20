CREATE PROCEDURE [dbo].[GetProductDetails] (
	@TenantId INT
	,@PageNumber INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'Category'
	,@SortOrder VARCHAR(4) = 'DESC'
    ,@ModelNo VARCHAR(100) = NULL
    ,@Category VARCHAR(100) = NULL
    ,@Search VARCHAR(200) = NULL
    ,@MinPrice DECIMAL(18,2) = NULL
    ,@MaxPrice DECIMAL(18,2) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF @PageSize > 100
		SET @PageSize = 100

	SELECT PT.ProductId
		,CT.CategoryName AS Category
		,PT.ModelNo AS ModelNo
		,PT.ProductTitle AS Title
		,CONCAT (
			PT.Height
			,' x '
			,PT.Width
			,' x '
			,PT.Depth
			) Dimensions
		,(
			SELECT 
				PIM.ImagePath,
				CASE 
					WHEN PIM.ImagePath = PT.CoverImage THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
				END AS IsMain
			FROM ProductImages PIM WITH (NOLOCK)
			WHERE PT.ProductId = PIM.ProductId
			FOR JSON PATH
			) AS Images
		,PT.RetailerPrice AS RetailPrice
		,ISNULL(PT.RetailOfferPrice, 0) AS OfferPrice
		,PQ.Quantity AS QuantityInStock
		,COUNT(*) OVER () AS TotalRecords
        ,PT.Features AS ShortDescription
		,PT.Features AS LongDescription
		,PT.ModelNo AS SKU
        ,PT.Height
		,PT.Width
		,PT.Depth
	FROM Products PT WITH (NOLOCK)
	INNER JOIN Categories CT WITH (NOLOCK) ON CT.CategoryId = PT.CategoryId
		AND PT.TenantId = CT.TenantId
		AND CT.IsDeleted = 0
		AND CT.CategoryTypeId = 1
	INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = PT.ProductId
	WHERE PT.TenantId = @TenantId
		AND PT.Status = 1
		AND (
			@ModelNo IS NULL
			OR LOWER(PT.ModelNo) = LOWER(@ModelNo)
			)
		AND (
			@Category IS NULL
			OR CT.CategoryName = @Category
			)
		AND (
			@Search IS NULL
			OR PT.ProductTitle LIKE '%' + @Search + '%'
			OR PT.Features LIKE '%' + @Search + '%'
			)
		AND (
			@MinPrice IS NULL
			OR PT.RetailerPrice >= @MinPrice
			)
		AND (
			@MaxPrice IS NULL
			OR PT.RetailerPrice <= @MaxPrice
			)
	ORDER BY CASE 
			WHEN @SortBy = 'Category'
				AND @SortOrder = 'ASC'
				THEN CT.CategoryName
			END ASC
		,CASE 
			WHEN @SortBy = 'Category'
				AND @SortOrder = 'DESC'
				THEN CT.CategoryName
			END DESC
		,CASE 
			WHEN @SortBy = 'ModelNo'
				AND @SortOrder = 'ASC'
				THEN PT.ModelNo
			END ASC
		,CASE 
			WHEN @SortBy = 'ModelNo'
				AND @SortOrder = 'DESC'
				THEN PT.ModelNo
			END DESC
		,CASE 
			WHEN @SortBy = 'Title'
				AND @SortOrder = 'ASC'
				THEN PT.ProductTitle
			END ASC
		,CASE 
			WHEN @SortBy = 'Title'
				AND @SortOrder = 'DESC'
				THEN PT.ProductTitle
			END DESC
		,CASE 
			WHEN @SortBy = 'RetailerPrice'
				AND @SortOrder = 'ASC'
				THEN PT.RetailerPrice
			END ASC
		,CASE 
			WHEN @SortBy = 'RetailerPrice'
				AND @SortOrder = 'DESC'
				THEN PT.RetailerPrice
			END DESC
		,CASE 
			WHEN @SortBy = 'OfferPrice'
				AND @SortOrder = 'ASC'
				THEN PT.RetailOfferPrice
			END ASC
		,CASE 
			WHEN @SortBy = 'OfferPrice'
				AND @SortOrder = 'DESC'
				THEN PT.RetailOfferPrice
			END DESC 
		,CASE 
			WHEN @SortBy = 'Quantity'
				AND @SortOrder = 'ASC'
				THEN PQ.Quantity
			END ASC
		,CASE 
			WHEN @SortBy = 'Quantity'
				AND @SortOrder = 'DESC'
				THEN PQ.Quantity
			END DESC 
		,CASE 
			WHEN @SortBy = 'SKU'
				AND @SortOrder = 'ASC'
				THEN PT.ModelNo
			END ASC
		,CASE 
			WHEN @SortBy = 'SKU'
				AND @SortOrder = 'DESC'
				THEN PT.ModelNo
			END DESC OFFSET(@PageNumber - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY

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

