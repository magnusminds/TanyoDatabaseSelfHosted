/*
	EXEC dbo.ListReceivedSharedProductHistory
		@ToTenantId = 126
		,@PageIndex = 1
		,@PageSize = 1000
*/
CREATE PROC [dbo].[ListReceivedSharedProductHistory] (
	@ToTenantId INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;;

	WITH CTE
	AS (
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
			,bd.WholesalerPrice AS RequestedPrice
			,bd.TenantId
			,t.TenantName
			,bd.STATUS
			,ROW_NUMBER() OVER (
				PARTITION BY bd.Id ORDER BY p1.ProductId DESC
				) AS RowNum
			,CASE 
				WHEN bd.STATUS = 1
					THEN p1.ProductId
				ELSE 0
				END AS DealerProductId
			,CASE 
				WHEN bd.STATUS = 1
					THEN p1.ModelNo
				ELSE ''
				END AS DealerModelNo
			,CASE 
				WHEN bd.STATUS = 1
					THEN p1.ProductTitle
				ELSE ''
				END AS DealerProductTitle
			,CASE 
				WHEN bd.STATUS = 1
					THEN p1.CostPrice
				ELSE 0
				END AS DealerCostPrice
			,CASE 
				WHEN bd.STATUS = 1
					THEN ISNULL(p1.CoverImage, '')
				ELSE ISNULL(p.CoverImage, '')
				END AS DealerProductImage
			,ISNULL(bd.UpdatedDate, bd.CreatedDate) AS LastModifiedOn
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
		INNER JOIN dbo.Tenants t WITH (NOLOCK) ON t.TenantId = bd.TenantId
			AND t.IsDeleted = 0
		INNER JOIN dbo.ProductVendorMapping pvm WITH (NOLOCK) ON pvm.VendorProductId = bd.ProductId
			AND pvm.CreatedBy IS NOT NULL
		LEFT JOIN ProductQuantities pq WITH (NOLOCK) ON pq.ProductId = bd.ProductId
		INNER JOIN dbo.Products p1 WITH (NOLOCK) ON pvm.ProductId = p1.ProductId
			AND p1.TenantId = @ToTenantId
			AND pvm.VendorId = p1.VendorId
			AND p1.STATUS <> 3
		WHERE bd.ToTenantId = @ToTenantId
			AND bd.STATUS <> 0
		)
	SELECT *
		,COUNT(*) OVER () AS TotalCount
	FROM CTE
	WHERE RowNum = 1
	ORDER BY BatchDetailId DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY;
END

GO

