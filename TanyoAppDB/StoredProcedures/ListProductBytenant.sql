-- =============================================  
-- Author  : MagnusMinds  
-- Create date : 13-05-2025  
-- Description : ListProductBytenant  
-- =============================================  
/*  
EXEC [dbo].[ListProductBytenant]  
   @TenantId = 84
  ,@RoleId = N'30EE75B3-B26F-4D61-A91B-51C7E78E422E' with recompile
*/
CREATE PROCEDURE [dbo].[ListProductBytenant] (
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
								AND arc.ClaimValue IN (
									'Permissions.App.Order.WholeselerPrice'
									,'Permissions.General.Order.WholeselerPrice'
									)
							)
						THEN 1
					ELSE 0
					END

			SELECT p.ProductId AS ProductId
				,p.ProductTitle AS ProductTitle
				,p.ModelNo AS ModelNo
				,c.CategoryId AS CategoryId
				,c.CategoryName AS CategoryName
				,p.CoverImage AS ProductImage
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
				,'' AS ShareURL
				,@ProductSubjectTypeId AS SubjectTypeId
			FROM dbo.Products p WITH (NOLOCK)
			INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
				AND c.IsDeleted = 0
				AND c.TenantId = p.TenantId
				AND p.TenantId = @TenantId
				AND p.Status = 1
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
				) ofr ON p.ProductId = ofr.ProductId
				--LEFT JOIN (
				--	SELECT x.ProductId
				--		,x.ImagePath
				--	FROM (
				--		SELECT im.ProductId
				--			,im.ImagePath
				--			,ROW_NUMBER() OVER (
				--				PARTITION BY im.ProductId ORDER BY im.IsCover DESC
				--					,im.CreatedUTCDate DESC
				--				) AS RowID
				--		FROM ProductImages im WITH (NOLOCK)
				--		INNER JOIN Products tp ON tp.ProductId = im.Productid
				--			AND tp.TenantId = @TenantId
				--		) x
				--	WHERE x.RowID = 1
				--	) tpi ON tpi.ProductId = p.ProductId
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

