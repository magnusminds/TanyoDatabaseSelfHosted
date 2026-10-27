/*  
EXEC [dbo].[GetProductsByCategoryAndTenant]  
 @TenantId = 2,  
    @CategoryId = 10704,  
    @hosturl = 'https://localhost:7253',   
 @PageIndex = 1,  
 @PageSize = 50  
*/
CREATE PROCEDURE [dbo].[GetProductsByCategoryAndTenant] (
	@TenantId INT
	,@CategoryId INT
	,@hosturl VARCHAR(255)
	,@PageIndex INT = 1
	,@PageSize INT = 50
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SET @PageIndex = ISNULL(@PageIndex, 1);
		SET @PageSize = ISNULL(@PageSize, 5000);

		SELECT P.ProductId
			,p.ProductTitle AS ProductTitle
			,p.ModelNo AS ProductModelNo
			,c.CategoryName AS CatagoriesName
			,p.Height AS Height
			,p.Width AS Width
			,p.Depth AS Depth
			,p.Diameter AS Diameter
			,p.Features AS Description
			,p.WholesalerPrice AS WholesaleCostPrice
			,p.RetailerPrice AS RetailerCostPrice
			,ISNULL((
					SELECT PIM.ImagePath
					FROM ProductImages PIM WITH (NOLOCK)
					WHERE PIM.ProductId = p.ProductId
					FOR JSON PATH
					), '[]') AS ProductImage
			,ISNULL(p.CoverImage, @hosturl + '/images/No-coverimage.png') AS ProductCoverImage
			,ISNULL(tf.OrganizationType, 'Furniture') AS TenantOrganizationType
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
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM Categories c WITH (NOLOCK)
		INNER JOIN Products p WITH (NOLOCK) ON c.CategoryId = p.CategoryId
		INNER JOIN Tenants t WITH (NOLOCK) ON t.tenantId = @TenantId
		INNER JOIN ProductQuantities pq WITH (NOLOCK) ON p.ProductId = pq.ProductId
		LEFT JOIN TenantInfo AS tf WITH (NOLOCK) ON tf.TenantInfoId = t.TenantInfoId
		WHERE (
				c.CategoryId = @CategoryId
				OR C.ParentCategoryId = @CategoryId
				)
			AND p.Status = 1
			AND c.TenantId = @TenantId
		ORDER BY p.ProductId OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ObjectName VARCHAR(100)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()
			,@ObjectName = OBJECT_NAME(@@PROCID)

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage
	END CATCH
END

GO

