

-- =============================================  
-- Author  : MagnusMinds  
-- Create date : 10-07-2025  
-- Description : ListProductBytenant  
-- =============================================  
/*  
	EXEC [dbo].[ListProductCatalog_V3]  
	   @TenantId = 2
	  ,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
*/
CREATE      PROCEDURE [dbo].[ListProductCatalog_V3] (
	@TenantId INT
	,@RoleId nvarchar(MAX)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	BEGIN
		IF NOT EXISTS (
				SELECT 1
				FROM AspNetRoleClaims arc
				INNER JOIN AspNetRoles ar ON ar.Id = arc.RoleId
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
						FROM AspNetRoleClaims arc
						INNER JOIN AspNetRoles ar ON ar.Id = arc.RoleId
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
			--,p.CoverImage AS ProductImage
			,RIGHT(
				LEFT(p.CoverImage, 
					 CASE 
					   WHEN CHARINDEX('?', p.CoverImage) > 0 
					   THEN CHARINDEX('?', p.CoverImage) - 1 
					   ELSE LEN(p.CoverImage) 
					 END
				), 
				CHARINDEX('/', REVERSE(LEFT(p.CoverImage, 
					 CASE 
					   WHEN CHARINDEX('?', p.CoverImage) > 0 
					   THEN CHARINDEX('?', p.CoverImage) - 1 
					   ELSE LEN(p.CoverImage) 
					 END))) - 1
			  ) AS ProductImage
			--,RIGHT(p.CoverImage, CHARINDEX('/', REVERSE(p.CoverImage)) - 1) AS ProductImage
			,CASE 
				WHEN @HasWholesalerPrice = 0
					THEN p.RetailerPrice
				ELSE p.WholesalerPrice
				END AS OriginalPrice
			,CASE 
				WHEN @HasWholesalerPrice = 1
					THEN p.WholesalerPrice
				WHEN RetailOfferPrice IS NOT NULL
					THEN RetailOfferPrice
				ELSE 
					RetailerPrice
				END AS SalesPrice
			--,ISNULL(CASE 
			--	WHEN ofr.OfferId IS NOT NULL
			--		THEN	
			--				CASE 
			--						WHEN @HasWholesalerPrice = 0
			--							THEN p.RetailOfferPrice
			--						ELSE p.WholesalerOfferPrice
			--						END
			--		ELSE CASE 
			--			WHEN @HasWholesalerPrice = 0
			--				THEN p.RetailerPrice
			--			ELSE p.WholesalerPrice
			--			END
			--	END,0) AS SalesPrice
			,p.Height AS Height
			,p.Width AS Width
			,p.Depth AS Depth
			,p.Diameter AS Diameter
			,p.Features AS [Description]
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
					THEN o.OfferTitle
				ELSE NULL
				END AS OfferTitle
			,CAST(ofr.OfferId AS BIGINT) AS OfferId
			,'' AS ShareURL
			,@ProductSubjectTypeId AS SubjectTypeId
			,c.IsVisibleInAddOn AS IsPartOfAddOn
		FROM dbo.Products p WITH (NOLOCK)
		INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
			AND c.IsDeleted = 0
			AND c.TenantId = p.TenantId
			AND p.TenantId = @TenantId
			AND p.Status = 1
		LEFT JOIN ProductOffers ofr ON p.ProductId = ofr.ProductId
		LEFT JOIN Offers o ON o.OfferId = ofr.OfferId
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

