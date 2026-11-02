/*
	EXEC dbo.ListReceivedSharedProduct
		@ToTenantId = 103
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE   PROC [dbo].[ListReceivedSharedProduct] (
	@ToTenantId INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT bd.Id AS BatchDetailId
		,b.BatchNo
		,b.Title
		,bd.ProductId
		,p.ProductTitle
		,p.ModelNo
		,p.Width AS ProductWidth
		,p.Height AS ProductHeight
		,p.Depth AS ProductDepth
		,p.DimensionUnitId
		,bd.WholesalerPrice
		,bd.TenantId
		,t.TenantName
		,bd.STATUS
		,ISNULL(bd.UpdatedDate, bd.CreatedDate) AS LastModifiedOn
		,ISNULL(p.CoverImage, '') AS ProductImage
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		,CASE 
			WHEN t.DisplayStockToDealer = 1
				THEN pq.Quantity
			ELSE 0
			END AS InStock
		,t.DisplayStockToDealer AS DisplayStockToDealer
	FROM dbo.ProductShareBatchDetail bd WITH (NOLOCK)
	INNER JOIN dbo.ProductShareBatch b WITH (NOLOCK) ON b.Id = bd.BatchId
	INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = bd.ProductId
		AND p.STATUS <> 3
	INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = bd.CustomerId
		AND c.IsDeleted = 0
	LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = bd.TagId
		AND l.IsDeleted = 0
	LEFT JOIN dbo.Tenants t WITH (NOLOCK) ON t.TenantId = bd.TenantId
		AND t.IsDeleted = 0
	LEFT JOIN ProductQuantities pq WITH (NOLOCK) ON pq.ProductId = bd.ProductId
	WHERE bd.ToTenantId = @ToTenantId
		AND bd.STATUS = 0
	ORDER BY bd.Id OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY;
END

GO

