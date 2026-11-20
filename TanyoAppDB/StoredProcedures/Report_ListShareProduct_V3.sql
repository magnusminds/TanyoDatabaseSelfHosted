/*
    EXEC dbo.Report_ListShareProduct_V3
        @TenantId   = 2,
        @SharedBy   = NULL,
        @CustomerId = NULL,
        @FromDate   = '04-01-2026',
        @ToDate     = '04-09-2026',
        @PageIndex  = 1,
        @PageSize   = 25,
        @SortBy     = 'SharedDate',
        @SortOrder  = 'DESC'
*/
CREATE   PROC [dbo].[Report_ListShareProduct_V3] (
	@TenantId INT
	,@SharedBy INT = NULL
	,@CustomerId INT = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(100) = 'SharedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT b.Id AS BatchId
			,ISNULL(b.UpdatedDate, b.CreatedDate) AS SharedDate
			,au.FirstName + ' ' + au.LastName + CASE 
				WHEN au.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS SharedBy
			,c.FirstName + ' ' + ISNULL(c.LastName, '') AS DealerName
			,p.CoverImage AS ProductImage
			,p.ProductTitle
			,p.ModelNo
			,ca.CategoryName
			,bd.WholesalerPrice AS ProductSharedPrice
			,bd.Status
			,COUNT(1) OVER () AS TotalCount
		FROM dbo.ProductShareBatchDetail bd WITH (NOLOCK)
		LEFT JOIN dbo.ProductShareBatch b WITH (NOLOCK) ON bd.BatchId = b.Id
		INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = b.CreatedBy
		INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = bd.ProductId
			AND p.STATUS <> 3
		INNER JOIN dbo.Categories ca WITH (NOLOCK) ON ca.CategoryId = p.CategoryId
			AND ca.IsDeleted = 0
		INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = bd.CustomerId
			AND c.IsDeleted = 0
		LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = bd.TagId
			AND l.IsDeleted = 0
		WHERE bd.TenantId = @TenantId
			AND (
				@SharedBy IS NULL
				OR b.CreatedBy = @SharedBy
				)
			AND (
				@CustomerId IS NULL
				OR bd.CustomerId = @CustomerId
				)
			AND (
				@FromDate IS NULL
				OR b.CreatedDate >= @FromDate
				)
			AND (
				@ToDate IS NULL
				OR b.CreatedDate < DATEADD(DAY, 1, @ToDate)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'SharedDate'
					AND @SortOrder = 'ASC'
					THEN ISNULL(b.UpdatedDate, b.CreatedDate)
				END ASC
			,CASE 
				WHEN @SortBy = 'SharedDate'
					AND @SortOrder = 'DESC'
					THEN ISNULL(b.UpdatedDate, b.CreatedDate)
				END DESC
			,CASE 
				WHEN @SortBy = 'SharedBy'
					AND @SortOrder = 'ASC'
					THEN au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END
				END ASC
			,CASE 
				WHEN @SortBy = 'SharedBy'
					AND @SortOrder = 'DESC'
					THEN au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END
				END DESC
			,CASE 
				WHEN @SortBy = 'DealerName'
					AND @SortOrder = 'ASC'
					THEN c.FirstName + ' ' + ISNULL(c.LastName, '')
				END ASC
			,CASE 
				WHEN @SortBy = 'DealerName'
					AND @SortOrder = 'DESC'
					THEN c.FirstName + ' ' + ISNULL(c.LastName, '')
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
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN ca.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN ca.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductSharedPrice'
					AND @SortOrder = 'ASC'
					THEN bd.WholesalerPrice
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductSharedPrice'
					AND @SortOrder = 'DESC'
					THEN bd.WholesalerPrice
				END DESC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'ASC'
					THEN bd.Status
				END ASC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'DESC'
					THEN bd.Status
				END DESC
			,ISNULL(b.UpdatedDate, b.CreatedDate) DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

