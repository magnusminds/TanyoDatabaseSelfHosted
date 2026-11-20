/*
    EXEC [dbo].[ReportProductNegativeOrders]
        @TenantId = 2
        ,@CategoryId = NULL
        ,@ProductTitle = NULL
        ,@ModelNo = NULL
        ,@PageIndex = 1
        ,@PageSize = 250
        ,@SortBy = 'ProductCategory'
        ,@SortOrder = 'ASC'
        ,@InventoryDate = NULL
*/
CREATE   PROCEDURE [dbo].[ReportProductNegativeOrders] (
	@TenantId INT
	,@CategoryId BIGINT = NULL
	,@ProductTitle VARCHAR(150) = NULL
	,@ModelNo VARCHAR(100) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'ProductCategory'
	,@SortOrder VARCHAR(50) = 'ASC'
	,@InventoryDate DATE = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @SubjectTypeId INT;
		DECLARE @FromDate DATETIMEOFFSET
		DECLARE @ToDate DATETIMEOFFSET

		IF @InventoryDate IS NOT NULL
		BEGIN
			SET @FromDate = CAST(CAST(@InventoryDate AS VARCHAR(10)) + ' 00:00:00.0000001 +05:30' AS DATETIMEOFFSET)
			SET @ToDate = CAST(CAST(@InventoryDate AS VARCHAR(10)) + ' 23:59:59.9999999 +05:30' AS DATETIMEOFFSET)
		END

		-- Get SubjectTypeId for Products
		SELECT @SubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantId
			AND st.SubjectTypeName = 'Products';

		-- Main Query
		SELECT p.ProductId AS ProductId
			,c.CategoryName AS CategoryName
			,p.ProductTitle AS ProductTitle
			,p.ModelNo AS ModelNo
			,CAST(SUM(os.Quantity) AS NUMERIC(18,2)) AS OrderedQuantity
			,pq.Quantity AS InStockQuantity
			,COUNT(1) OVER () AS TotalCount
		FROM Products p WITH (NOLOCK)
		INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
			AND c.IsFixedPrice = 1
		INNER JOIN ProductQuantities pq WITH (NOLOCK) ON pq.ProductId = p.ProductId
		LEFT JOIN OrderSetItems os WITH (NOLOCK) ON os.SubjectId = p.ProductId
			AND os.SubjectTypeId = @SubjectTypeId
		LEFT JOIN Orders o WITH (NOLOCK) ON o.OrderId = os.OrderId
			AND o.TenantId = @TenantId
		WHERE p.TenantId = @TenantId
			AND p.STATUS = 1
			AND pq.Quantity < 0
			AND os.IsDeleted = 0
			AND (
				o.STATUS IN (
					2
					,3
					,4
					,7
					)
				OR o.STATUS IS NULL
				) --Approved, InProgress, Completed, MaterialReceive
			AND (
				@InventoryDate IS NULL
				OR (
					PQ.LastModifiedDate >= @FromDate
					AND PQ.LastModifiedDate <= @ToDate
					)
				)
			AND (
				@CategoryId IS NULL
				OR p.CategoryId = @CategoryId
				)
			AND (
				@ProductTitle IS NULL
				OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
				)
			AND (
				@ModelNo IS NULL
				OR p.ModelNo LIKE '%' + @ModelNo + '%'
				)
		GROUP BY c.CategoryName
			,p.ProductTitle
			,p.ModelNo
			,pq.Quantity
			,p.ProductId
		ORDER BY CASE 
				WHEN @SortBy = 'ProductCategory'
					AND @SortOrder = 'ASC'
					THEN c.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductCategory'
					AND @SortOrder = 'DESC'
					THEN c.CategoryName
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
				WHEN @SortBy = 'Quantity'
					AND @SortOrder = 'ASC'
					THEN SUM(os.Quantity)
				END ASC
			,CASE 
				WHEN @SortBy = 'Quantity'
					AND @SortOrder = 'DESC'
					THEN SUM(os.Quantity)
				END DESC
			,CASE 
				WHEN @SortBy = 'InStockQuantity'
					AND @SortOrder = 'ASC'
					THEN pq.Quantity
				END ASC
			,CASE 
				WHEN @SortBy = 'InStockQuantity'
					AND @SortOrder = 'DESC'
					THEN pq.Quantity
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

