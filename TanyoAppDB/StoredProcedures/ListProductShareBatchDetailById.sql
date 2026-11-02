/*
	EXEC dbo.ListProductShareBatchDetailById
		@BatchId = 63
		,@Status = -1
		,@PageIndex = 1
		,@PageSize = 1000
*/
CREATE   PROC [dbo].[ListProductShareBatchDetailById]
(
	@BatchId INT
	,@Status INT = -1
	,@PageIndex INT = 1
	,@PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;

	SELECT bd.Id AS BatchDetailId
		,CAST(ca.CategoryId AS VARCHAR) CategoryId
		,ca.CategoryName
		,bd.ProductId
		,p.ProductTitle
		,p.ModelNo
		,p.Width AS ProductWidth
		,p.Height AS ProductHeight
		,p.Depth AS ProductDepth
		,p.DimensionUnitId
		,p.CoverImage AS ProductImage
		,bd.WholesalerPrice
		,bd.CustomerId
		,c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
		,c.CustomerTypeId
		,c.PhoneNumber
		,bd.TagId
		,l.LabelName AS TagName
		,l.ColorCode AS TagColorCode
		,bd.ToTenantId
		,t.TenantName
		,bd.Status
		,ISNULL(bd.UpdatedDate, bd.CreatedDate) AS LastModifiedOn
		,CASE 
			WHEN vt.DisplayStockToDealer = 1 THEN pq.Quantity
			ELSE 0
		END AS InStock
		,vt.DisplayStockToDealer AS DisplayStockToDealer
		,au.FirstName + ' ' + au.LastName AS SharedBy
		,bd.CreatedDate AS SharedDate
		,au.IsActive AS IsSharedByActive
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM dbo.ProductShareBatchDetail bd WITH (NOLOCK)
	INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = bd.CreatedBy 
	INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = bd.ProductId
		AND p.Status <> 3
	INNER JOIN dbo.Categories ca WITH (NOLOCK) ON ca.CategoryId = p.CategoryId
		AND ca.IsDeleted = 0
	INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = bd.CustomerId
		AND c.IsDeleted = 0
	LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = bd.TagId
		AND l.IsDeleted = 0
	LEFT JOIN dbo.Tenants t WITH (NOLOCK) ON t.TenantId = bd.ToTenantId
		AND t.IsDeleted = 0
	LEFT JOIN dbo.ProductQuantities pq WITH (NOLOCK) ON pq.ProductId = bd.ProductId
	LEFT JOIN dbo.Tenants vt WITH (NOLOCK) ON vt.TenantId = bd.TenantId
	WHERE bd.BatchId = @BatchId
	AND (@Status = -1 OR bd.Status = @Status)
	ORDER BY bd.Id
	OFFSET(@PageIndex - 1) * @PageSize ROWS
	FETCH NEXT @PageSize ROWS ONLY;
END

GO

