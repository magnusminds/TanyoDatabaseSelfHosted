/*  
	EXEC [dbo].[ListProductCatalog_V6]  
	   @TenantId = 2
	  ,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
*/
CREATE   PROCEDURE [dbo].[ListProductCatalog_V6] (
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
							AND arc.ClaimValue = 'Permissions.App.Order.WholeselerPrice'
						)
					THEN 1
				ELSE 0
				END

		SELECT p.ProductId AS ProductId
			,p.ProductTitle AS ProductTitle
			,p.ModelNo AS ModelNo
			,c.CategoryId AS CategoryId
			,c.CategoryName AS CategoryName
			,RIGHT(LEFT(p.CoverImage, CASE 
						WHEN CHARINDEX('?', p.CoverImage) > 0
							THEN CHARINDEX('?', p.CoverImage) - 1
						ELSE LEN(p.CoverImage)
						END), CHARINDEX('/', REVERSE(LEFT(p.CoverImage, CASE 
								WHEN CHARINDEX('?', p.CoverImage) > 0
									THEN CHARINDEX('?', p.CoverImage) - 1
								ELSE LEN(p.CoverImage)
								END))) - 1) AS ProductImage
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
					WHEN ofr.OfferId IS NOT NULL
						THEN 1
					ELSE 0
					END AS BIT) AS OfferTag
			,CASE 
				WHEN ofr.OfferId IS NOT NULL
					THEN ofr.OfferCode
				ELSE ''
				END AS OfferCode
			,CASE 
				WHEN ofr.OfferId IS NOT NULL
					THEN ofr.OfferPercentage
				ELSE NULL
				END AS OfferPercentage
			,CASE 
				WHEN ofr.OfferId IS NOT NULL
					THEN ofr.OfferTitle
				ELSE NULL
				END AS OfferTitle
			,CAST(ofr.OfferId AS BIGINT) AS OfferId
			,@ProductSubjectTypeId AS SubjectTypeId
			,c.IsVisibleInAddOn AS IsPartOfAddOn
			,c.IsSellByPerSQFT AS IsSellByPerSQFT
			,prodBrand.LookupValueName AS ProductBrand
			,prodColor.LookupValueName AS ProductColour
			,prodMaterial.LookupValueName AS ProductMaterial
			,PQ.Quantity AS InStock
		FROM dbo.Products p WITH (NOLOCK)
		INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
			AND c.IsDeleted = 0
			AND c.TenantId = p.TenantId
			AND p.TenantId = @TenantId
			AND p.STATUS = 1
		INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = P.ProductId
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

