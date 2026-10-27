/*    
 EXEC [dbo].[ListProductCatalog_V7]    
    @TenantId = 2  
   ,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'  
*/
CREATE PROCEDURE [dbo].[ListProductCatalog_V7] (
	@TenantId INT
	,@RoleId NVARCHAR(MAX)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
	BEGIN
		IF NOT EXISTS (
				SELECT 1
					FROM AspNetRoleClaims arc WITH (NOLOCK)
					INNER JOIN AspNetRoles ar WITH (NOLOCK) ON ar.Id = arc.RoleId
					AND ar.TenantId = @TenantId
					AND ar.Id = @RoleId
				)
		BEGIN
			RAISERROR (
					'User does not belongs to tenant'
					,15
					,1
					)

			RETURN
		END

		DECLARE @dt DATE

		SELECT @dt = CAST(GETDATE() AS DATE)

		DECLARE @ProductSubjectTypeId INT

		SELECT @ProductSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
			AND st.SubjectTypeName = 'Products'

		DECLARE @HasWholesalerPrice BIT = 0;

		SELECT @HasWholesalerPrice = CASE 
				WHEN EXISTS (
						SELECT 1
							FROM AspNetRoleClaims arc WITH (NOLOCK)
							INNER JOIN AspNetRoles ar WITH (NOLOCK) ON ar.Id = arc.RoleId
							AND ar.TenantId = @TenantId
							AND ar.Id = @RoleId
							AND arc.ClaimValue IN (
								'Permissions.App.Order.WholeselerPrice'
								,'Permissions.General.Order.WholeselerPrice'
								)
						)
					THEN 1
				ELSE 0
				END

		DECLARE @IsAllowDiscount BIT = 1;

		SELECT @IsAllowDiscount = IsAllowDiscount
		FROM TenantConfigurations WITH (NOLOCK)
		WHERE TenantId = @TenantId

		SELECT p.ProductId AS ProductId
			,p.ProductTitle AS ProductTitle
			,p.ModelNo AS ModelNo
			,ISNULL(CT.CategoryId, c.CategoryId) AS CategoryId
			,ISNULL(CT.CategoryName, c.CategoryName) AS CategoryName
			--,p.CoverImage AS ProductImage  
			,RIGHT(LEFT(p.CoverImage, CASE 
						WHEN CHARINDEX('?', p.CoverImage) > 0
							THEN CHARINDEX('?', p.CoverImage) - 1
						ELSE LEN(p.CoverImage)
						END), CHARINDEX('/', REVERSE(LEFT(p.CoverImage, CASE 
								WHEN CHARINDEX('?', p.CoverImage) > 0
									THEN CHARINDEX('?', p.CoverImage) - 1
								ELSE LEN(p.CoverImage)
								END))) - 1) AS ProductImage
			--,RIGHT(p.CoverImage, CHARINDEX('/', REVERSE(p.CoverImage)) - 1) AS ProductImage  
			,CASE 
				WHEN @HasWholesalerPrice = 0
					THEN p.RetailerPrice
				ELSE p.WholesalerPrice
				END AS OriginalPrice
			,ISNULL(CASE 
					WHEN ofr.OfferId IS NOT NULL
						THEN CASE 
								WHEN @HasWholesalerPrice = 0
									THEN p.RetailOfferPrice
								ELSE p.WholesalerOfferPrice
								END
					ELSE CASE 
							WHEN @HasWholesalerPrice = 0
								THEN p.RetailerPrice
							ELSE p.WholesalerPrice
							END
					END, 0) AS SalesPrice
			,p.Height AS Height
			,p.Width AS Width
			,p.Depth AS Depth
			,p.Diameter AS Diameter
			,p.Features AS [Description]
			,p.Features AS [Features]
			,p.FabricNeeded AS FabricNeeded
			,CAST(CASE 
					WHEN @IsAllowDiscount = 0
						THEN 0
					WHEN ofr.OfferId IS NOT NULL
						AND @HasWholesalerPrice = 0
						THEN 1
					ELSE 0
					END AS BIT) AS OfferTag
			,CASE 
				WHEN @IsAllowDiscount = 0
					THEN NULL
				WHEN @HasWholesalerPrice = 1
					THEN NULL
				WHEN ofr.OfferId IS NOT NULL
					THEN ofr.OfferCode
				ELSE ''
				END AS OfferCode
			,CASE 
				WHEN @IsAllowDiscount = 0
					THEN NULL
				WHEN ofr.OfferId IS NOT NULL
					AND @HasWholesalerPrice = 0
					THEN ofr.OfferPercentage
				ELSE NULL
				END AS OfferPercentage
			,CASE 
				WHEN @IsAllowDiscount = 0
					THEN NULL
				WHEN ofr.OfferId IS NOT NULL
					AND @HasWholesalerPrice = 0
					THEN ofr.OfferTitle
				ELSE NULL
				END AS OfferTitle
			,CASE 
				WHEN @IsAllowDiscount = 0
					THEN NULL
				WHEN ofr.OfferId IS NOT NULL
					AND @HasWholesalerPrice = 0
					THEN CAST(ofr.OfferId AS BIGINT)
				ELSE NULL
				END AS OfferId
			--,'' AS ShareURL  
			,@ProductSubjectTypeId AS SubjectTypeId
			,c.IsVisibleInAddOn AS IsPartOfAddOn
			,c.IsSellByPerSQFT AS IsSellByPerSQFT
			,prodBrand.LookupValueName AS ProductBrand
			,prodColor.LookupValueName AS ProductColour
			,prodMaterial.LookupValueName AS ProductMaterial
			,PQ.Quantity AS InStock
				,ISNULL((
						SELECT STRING_AGG(CAST(qbw.WarehouseId AS VARCHAR(20)), ',') WITHIN
						GROUP (
								ORDER BY qbw.WarehouseId
								)
						FROM dbo.ProductQuantitiesByWarehouse qbw WITH (NOLOCK)
						INNER JOIN dbo.Warehouse w WITH (NOLOCK) ON w.Id = qbw.WarehouseId
							AND w.TenantId = @TenantId
							AND w.IsDeleted = 0
						WHERE qbw.ProductId = p.ProductId
							AND qbw.Quantity > 0
						), '') AS WarehouseIds
			,'' AS ImageColorCode
			,CASE 
				WHEN CT.CategoryId IS NOT NULL
					THEN c.CategoryId
				ELSE NULL
				END AS SubCategoryId
			,CASE 
				WHEN CT.CategoryId IS NOT NULL
					THEN c.CategoryName
				ELSE NULL
				END AS SubCategoryName
			,p.RetailerPrice
			,p.WholesalerPrice
		FROM dbo.Products p WITH (NOLOCK)
		INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
			AND c.IsDeleted = 0
			AND c.TenantId = p.TenantId
			AND p.TenantId = @TenantId
			AND p.Status = 1
			AND c.CategoryTypeId = 1 -- 1 = Products, 2 = Fabrics  
		INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = P.ProductId
		LEFT JOIN Categories CT WITH (NOLOCK) ON CT.CategoryId = C.ParentCategoryId
		LEFT JOIN (
			SELECT ofm.ProductId
				,o.OfferID
				,o.OfferCode
				,o.OfferPercentage
				,o.OfferTitle
			FROM OfferProductMapping ofm
			INNER JOIN Offers o ON ofm.OfferId = o.OfferId
				AND o.TenantId = @TenantId
				AND o.IsDeleted = 0
				AND o.IsPublished = 1
				AND o.StartDate <= @dt
				AND o.EndDate >= @dt
			) ofr ON p.ProductId = ofr.ProductId
		LEFT JOIN dbo.LookupValues prodBrand WITH (NOLOCK) ON p.ProductBrandId = prodBrand.LookupValueId
		LEFT JOIN dbo.LookupValues prodColor WITH (NOLOCK) ON p.ProductColourId = prodColor.LookupValueId
		LEFT JOIN dbo.LookupValues prodMaterial WITH (NOLOCK) ON p.ProductMaterialId = prodMaterial.LookupValueId
		WHERE (
				(
					p.IsVisibleToWholesalers = 1 -- ON → Wholesalers only  
					AND @HasWholesalerPrice = 1
					)
				OR p.IsVisibleToWholesalers = 0
				)
	END
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

