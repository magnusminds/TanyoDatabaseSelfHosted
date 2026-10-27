/*  
EXEC GetProductsByCatalogueId  
    @CatalogueId = 26,  
    @TenantId = 2,  
    @HostUrl = 'https://devapp.tanyo.in/'  
*/
CREATE PROCEDURE [dbo].[GetProductsByCatalogueId] (
	@CatalogueId BIGINT
	,@TenantId INT
	,@HostUrl NVARCHAR(500)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT p.ProductId
		,p.ProductTitle
		,p.ModelNo AS ProductModelNo
		,c.CategoryName AS CatagoriesName
		,ISNULL((
				SELECT pi.ImagePath AS ImagePath
				FROM dbo.ProductImages pi WITH (NOLOCK)
				WHERE pi.ProductId = p.ProductId
					AND pi.IsVideo = 0
				ORDER BY pi.IsCover DESC
					,pi.ProductImageID
				FOR JSON PATH
				), '[]') AS ProductImage
		,ISNULL(p.CoverImage, @HostUrl + 'images/No-coverimage.png') AS ProductCoverImage
		,p.Height
		,p.Width
		,p.Depth
		,p.Diameter
		,p.WholesalerPrice AS WholesaleCostPrice
		,p.RetailerPrice AS RetailerCostPrice
		,p.Features AS Description
		,'' AS TenantOrganizationType
		,pq.Quantity AS InStock
		,p.ProductBrandId
		,p.ProductColourId
		,p.ProductMaterialId
		,p.CategoryId AS SubCategoryId
		,CASE 
			WHEN EXISTS (
					SELECT 1
					FROM OfferProductMapping opm WITH (NOLOCK)
					WHERE opm.ProductId = p.ProductId
					)
				THEN 1
			ELSE 0
			END AS HasOffer
		,(
			SELECT TOP 1 pm.ImageColorCode
			FROM ProductImages pm WITH (NOLOCK)
			WHERE pm.ProductId = p.ProductId
				AND pm.IsCover = 1
			) AS ImageColorCode
		,0 AS TotalCount
	FROM dbo.CatalogueDetails cd WITH (NOLOCK)
	INNER JOIN dbo.Catalogue cat WITH (NOLOCK) ON cat.CatalogueId = cd.CatalogueId
		AND cat.IsDeleted = 0
		AND cat.TenantId = @TenantId
	INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = cd.ProductId
		AND p.TenantId = @TenantId
		AND p.Status <> 3
	INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
		AND c.IsDeleted = 0
		AND c.TenantId = @TenantId
	INNER JOIN dbo.ProductQuantities pq WITH (NOLOCK) ON p.ProductId = pq.ProductId
	--OUTER APPLY (  
	-- SELECT TOP 1 pi.ImagePath  
	-- FROM dbo.ProductImages pi WITH (NOLOCK)  
	-- WHERE pi.ProductId = p.ProductId  
	--  AND pi.IsCover = 1  
	-- ORDER BY pi.ProductImageID  
	--) coverImg  
	WHERE cd.CatalogueId = @CatalogueId
		AND cd.IsDeleted = 0
	ORDER BY c.CategoryName
		,p.ProductTitle;
END

GO

