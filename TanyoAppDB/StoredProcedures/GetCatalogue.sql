/*
EXEC [dbo].[GetCatalogue]
	  @CategoryId = 7
	 ,@RoleId = '0FC94370-F8D9-4AAD-8314-98140AEDE101'
	 ,@Offer = '0'
	 ,@Search = ''
	 ,@TenantId = 1
	 ,@PageIndex = 1
	 ,@PageSize = 66
	 ,@SortBy = 'PriceHighToLow'
	 ,@SortOrder = 'DESC'
	 ,@PriceFrom = 5000
	 ,@PriceTo = 25000
*/
CREATE PROCEDURE [dbo].[GetCatalogue] (
	@CategoryId INT
	,@RoleId VARCHAR(MAX)
	,@Offer VARCHAR(MAX) = ''
	,@Search VARCHAR(MAX) = ''
	,@TenantId INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(100) = ''
	,@SortOrder VARCHAR(100) = ''
	,@PriceFrom DECIMAL(18, 2) = NULL
	,@PriceTo DECIMAL(18, 2) = NULL
	,@ProductIDs VARCHAR(MAX) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN
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
							FROM AspNetRoleClaims WITH (NOLOCK)
							WHERE RoleId = @RoleId
								AND ClaimValue IN (
									'Permissions.App.Order.WholeselerPrice'
									,'Permissions.General.Order.WholeselerPrice'
									)
							)
						THEN 1
					ELSE 0
					END

			DECLARE @ProductIDTable TABLE (ProductID BIGINT)

			IF @ProductIDs IS NOT NULL
			BEGIN
				INSERT INTO @ProductIDTable (ProductID)
				SELECT value
				FROM STRING_SPLIT(@ProductIDs, ',')
			END

			DROP TABLE IF EXISTS #TempTableProducts

				CREATE TABLE #TempTableProducts (
					ProductId BIGINT NOT NULL PRIMARY KEY
					,CategoryName VARCHAR(50) NOT NULL
					,ProductPrice NUMERIC(18, 2) NOT NULL
					,OfferPrice NUMERIC(18, 2) NULL
					,OfferId INT NULL
					,LastModifiedDate DATETIME
					,OfferTag BIT
					,OfferCode VARCHAR(50)
					,OfferPercentage INT
					,OfferTitle VARCHAR(50)
					)

			INSERT INTO #TempTableProducts (
				ProductId
				,CategoryName
				,ProductPrice
				,OfferPrice
				,OfferId
				,LastModifiedDate
				,OfferTag
				,OfferCode
				,OfferPercentage
				,OfferTitle
				)
			SELECT p.ProductId
				,c.CategoryName
				,CASE 
					WHEN @HasWholesalerPrice = 0
						THEN p.RetailerPrice
					ELSE p.WholesalerPrice
					END
				--,CASE WHEN o.OfferId IS NOT NULL THEN dbo.CalculateTotalOfferAmount((CASE WHEN @HasWholesalerPrice = 0 THEN p.RetailerPrice ELSE p.WholesalerPrice END), o.OfferPercentage) END
				,CASE 
					WHEN @HasWholesalerPrice = 0
						THEN p.RetailOfferPrice
					ELSE p.WholesalerOfferPrice
					END
				,o.OfferId
				,ISNULL(p.UpdatedUTCDate, p.CreatedUTCDate)
				,CASE 
					WHEN o.OfferId IS NOT NULL
						THEN CAST(1 AS BIT)
					ELSE CAST(0 AS BIT)
					END AS OfferTag
				,CASE 
					WHEN o.OfferId IS NOT NULL
						THEN o.OfferCode
					ELSE ''
					END AS OfferCode
				,CASE 
					WHEN o.OfferId IS NOT NULL
						THEN o.OfferPercentage
					ELSE NULL
					END AS OfferPercentage
				,CASE 
					WHEN o.OfferId IS NOT NULL
						THEN o.OfferTitle
					ELSE NULL
					END AS OfferTitle
			FROM dbo.Products p WITH (NOLOCK)
			INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
				AND c.IsDeleted = 0
			LEFT JOIN OfferProductMapping ofm ON p.ProductId = ofm.ProductId
			LEFT JOIN Offers o ON ofm.OfferId = o.OfferId
				AND o.TenantId = @TenantId
				AND o.IsDeleted = 0
				AND o.IsPublished = 1
			WHERE p.TenantId = @TenantId
				AND p.Status = 1
				AND p.CategoryId = @CategoryId
				AND (
					@Offer = 0
					OR (
						@Offer = 1
						AND o.StartDate <= @dt
						AND o.EndDate >= @dt
						)
					)
				AND (
					@ProductIDs IS NULL
					OR EXISTS (
						SELECT ProductID
						FROM @ProductIDTable
						WHERE p.ProductId = ProductID
						)
					)
				--AND (@PriceFrom IS NULL 
				--	OR CASE 
				--		WHEN @Offer = 1 AND o.OfferId IS NOT NULL
				--			THEN dbo.CalculateTotalOfferAmount((CASE WHEN @HasWholesalerPrice = 0 THEN p.RetailerPrice ELSE p.WholesalerPrice END), o.OfferPercentage)
				--		ELSE CASE WHEN @HasWholesalerPrice = 0 THEN p.RetailerPrice ELSE p.WholesalerPrice END
				--		END >= @PriceFrom
				--	)
				--AND (@PriceTo IS NULL 
				--	OR CASE 
				--		WHEN @Offer = 1 AND o.OfferId IS NOT NULL
				--			THEN dbo.CalculateTotalOfferAmount((CASE WHEN @HasWholesalerPrice = 0 THEN p.RetailerPrice ELSE p.WholesalerPrice END), o.OfferPercentage)
				--		ELSE CASE WHEN @HasWholesalerPrice = 0 THEN p.RetailerPrice ELSE p.WholesalerPrice END
				--		END <= @PriceTo
				--	)
				AND (
					@Search IS NULL
					OR @Search = ''
					OR (
						--p.ProductTitle LIKE '%' + @Search + '%'
						--OR p.ModelNo LIKE '%' + @Search + '%'
						--OR 
						CONCAT (
							p.ProductTitle
							,' - '
							,p.ModelNo
							) LIKE '%' + @Search + '%'
						)
					)

			DECLARE @cnt INT

			SELECT @cnt = COUNT(1)
			FROM #TempTableProducts

			SELECT CAST(p.CategoryId AS BIGINT) AS CategoryId
				,tp.CategoryName AS CategoryName
				,p.ProductId AS ProductId
				,p.ProductTitle AS ProductTitle
				,p.ModelNo AS ModelNo
				,p.CoverImage AS ProductImage
				,CASE 
					WHEN tp.OfferId IS NOT NULL
						THEN tp.OfferPrice
					ELSE tp.ProductPrice
					END AS CostPrice
				,p.Height AS Height
				,p.Width AS Width
				,p.Depth AS Depth
				,p.Diameter AS Diameter
				,p.Features AS [Description]
				,p.FabricNeeded AS FabricNeeded
				,tp.ProductPrice AS OriginalPrice
				,p.CostPrice AS InstantCostPrice
				,@ProductSubjectTypeId AS SubjectTypeId
				,tp.OfferTag
				,ISNULL(tp.OfferCode, '') AS OfferCode
				,tp.OfferPercentage AS OfferPercentage
				,tp.OfferTitle AS OfferTitle
				,tp.OfferId AS OfferId
				,@cnt AS TotalCount
			FROM dbo.Products p WITH (NOLOCK)
			INNER JOIN #TempTableProducts tp ON tp.ProductId = p.Productid
			--LEFT JOIN Offers o ON tp.OfferId = o.OfferId
			ORDER BY tp.LastModifiedDate
				,CASE 
					WHEN @SortBy = 'CategoryId'
						AND @SortOrder = 'ASC'
						THEN p.CategoryId
					END ASC
				,CASE 
					WHEN @SortBy = 'CategoryId'
						AND @SortOrder = 'DESC'
						THEN p.CategoryId
					END DESC
				,CASE 
					WHEN @SortBy = 'WhatsNew'
						AND @SortOrder = 'ASC'
						THEN p.CreatedDate
					END ASC
				,CASE 
					WHEN @SortBy = 'WhatsNew'
						AND @SortOrder = 'DESC'
						THEN p.CreatedDate
					END DESC
				,CASE 
					WHEN @SortBy = 'PriceHighToLow'
						AND @SortOrder = 'DESC'
						THEN tp.ProductPrice
					END DESC
				,CASE 
					WHEN @SortBy = 'PriceLowToHigh'
						AND @SortOrder = 'ASC'
						THEN tp.ProductPrice
					END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY;
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

