/*
	EXEC ReportProductInventoryByWarehouse
	@TenantId  = 2
	,@CategoryId  = NULL
	,@WarehouseId  = NULL 
	,@ProductModelNo  = NULL
	,@ProductTitle  = NULL
	,@PageIndex  = 1
	,@PageSize  = 100
	,@SortBy  = 'Quantity'
	,@SortOrder = 'DESC'


*/

CREATE PROCEDURE ReportProductInventoryByWarehouse
(
@TenantId INT 
,@CategoryId BIGINT = NULL
,@WarehouseId BIGINT = NULL 
,@ProductModelNo VARCHAR (100) = NULL
,@ProductTitle VARCHAR (150) = NULL
,@PageIndex INT = 1
,@PageSize INT = 100
,@SortBy VARCHAR(50) = 'Quantity'
,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN


	BEGIN TRY
	SELECT PT.ProductId
		   ,PT.CategoryId
		   ,PT.ProductTitle
		   ,PT.ModelNo
		   ,CT.CategoryName
		   ,WH.Id AS WarehouseId
		   ,WH.Name AS WarehouseName
		   ,PQBW.Quantity
		   ,COUNT(*) OVER() AS TotalCount
	FROM ProductQuantitiesByWarehouse PQBW WITH (NOLOCK)
	INNER JOIN Products PT WITH (NOLOCK) ON PT.ProductId = PQBW.ProductId
	INNER JOIN Categories CT WITH (NOLOCK) ON PT.CategoryId = CT.CategoryId AND CT.IsDeleted = 0
	INNER JOIN Warehouse WH WITH (NOLOCK) ON WH.Id = PQBW.WarehouseId
	WHERE PT.TenantId = @TenantId
	AND PT.STATUS <> 3
	AND (
	CT.CategoryId = @CategoryId
	OR @CategoryId IS NULL
	)
	AND (
	WH.Id = @WarehouseId
	OR @WarehouseId IS NULL
	)
	AND (
	PT.ModelNo LIKE '%' + @ProductModelNo + '%'
	OR @ProductModelNo IS NULL
	)
	AND (
	PT.ProductTitle LIKE '%' + @ProductTitle + '%'
	OR @ProductTitle IS NULL
	)
	ORDER BY CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'ASC'
				THEN PT.ProductTitle
			END ASC
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'DESC'
				THEN PT.ProductTitle
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
			WHEN @SortBy = 'CategoryName'
				AND @SortOrder = 'ASC'
				THEN CT.CategoryName
			END ASC
		,CASE 
			WHEN @SortBy = 'CategoryName'
				AND @SortOrder = 'DESC'
				THEN CT.CategoryName
			END DESC
		,CASE 
			WHEN @SortBy = 'Quantity'
				AND @SortOrder = 'ASC'
				THEN PQBW.Quantity
			END ASC
		,CASE 
			WHEN @SortBy = 'Quantity'
				AND @SortOrder = 'DESC'
				THEN PQBW.Quantity
			END DESC
		,CASE 
			WHEN @SortBy = 'WarehouseName'
				AND @SortOrder = 'ASC'
				THEN WH.Name
			END ASC
		,CASE 
			WHEN @SortBy = 'WarehouseName'
				AND @SortOrder = 'DESC'
				THEN WH.Name
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

