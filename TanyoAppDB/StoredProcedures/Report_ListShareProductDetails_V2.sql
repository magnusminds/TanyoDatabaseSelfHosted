/*
	EXEC dbo.Report_ListShareProductDetails_V2
		@TenantId = 102
		,@BatchId = 177
		,@PageIndex = 1
		,@PageSize = 50
		,@SortBy = 'Status'
		,@SortOrder = 'ASC'
*/
CREATE   PROC [dbo].[Report_ListShareProductDetails_V2] 
( 
	@TenantId INT
	,@BatchId INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(100) = 'CustomerName'
	,@SortOrder VARCHAR(4) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT bd.Id AS BatchDetailId
			,c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,p.CoverImage AS ProductImage
			,p.ProductTitle AS ProductTitle
			,p.ModelNo
			,ca.CategoryName AS CategoryName
			,bd.WholesalerPrice AS ProductSharedPrice
			,bd.Status
			,COUNT(1) OVER () AS TotalCount
		FROM dbo.ProductShareBatchDetail bd WITH (NOLOCK)
		LEFT JOIN dbo.ProductShareBatch b WITH (NOLOCK) ON bd.BatchId = b.Id
		INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = bd.ProductId
			AND p.STATUS <> 3
		INNER JOIN dbo.Categories ca WITH (NOLOCK) ON ca.CategoryId = p.CategoryId
			AND ca.IsDeleted = 0
		INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = bd.CustomerId
			AND c.IsDeleted = 0
		LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = bd.TagId
			AND l.IsDeleted = 0
		LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = bd.CreatedBy
		WHERE bd.TenantId = @TenantId      
			AND (@BatchId IS NULL OR bd.BatchId = @BatchId)
		ORDER BY     
			CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN c.FirstName + ' ' + ISNULL(c.LastName, '') END ASC,    
			CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN c.FirstName + ' ' + ISNULL(c.LastName, '') END DESC, 
			CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle END ASC,    
			CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC,    
			CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN p.ModelNo END ASC,    
			CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN p.ModelNo END DESC,    
			CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN ca.CategoryName END ASC,  
			CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN ca.CategoryName END DESC,  
			CASE WHEN @SortBy = 'ProductSharedPrice' AND @SortOrder = 'ASC' THEN bd.WholesalerPrice END ASC,    
			CASE WHEN @SortBy = 'ProductSharedPrice' AND @SortOrder = 'DESC' THEN bd.WholesalerPrice END DESC,
			CASE WHEN @SortBy = 'Status' AND @SortOrder = 'ASC' THEN bd.Status END ASC,    
			CASE WHEN @SortBy = 'Status' AND @SortOrder = 'DESC' THEN bd.Status END DESC,
		c.FirstName + ' ' + ISNULL(c.LastName, '') ASC          
		OFFSET (@PageIndex - 1) * @PageSize ROWS      
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

