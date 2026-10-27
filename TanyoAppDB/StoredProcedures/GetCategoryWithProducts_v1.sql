/*
EXEC GetCategoryWithProducts_v1
@TenantId = 84
,@RoleId = ''
,@OfferApplied = 0
,@PriceFrom = NULL
,@PriceTo= NULL
,@PageIndex = 1
,@PageSize = 30
*/
CREATE PROCEDURE [dbo].[GetCategoryWithProducts_v1] (
	@TenantId INT
	,@RoleId NVARCHAR(50)
	,@OfferApplied BIT = 0
	,@CategoryID NVARCHAR(MAX) = NULL
	,@PriceFrom DECIMAL(18, 2) = NULL
	,@PriceTo DECIMAL(18, 2) = NULL
	,@SortBy VARCHAR(50) = 'CostPrice'
	,@SortOrder VARCHAR(4) = 'DESC'
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@ProductIDs VARCHAR(MAX) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
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

		DECLARE @CategoryIDTable TABLE (
			CategoryId INT
			,CategoryName VARCHAR(50)
			)

		INSERT INTO @CategoryIDTable (
			CategoryId
			,CategoryName
			)
		SELECT c.CategoryId
			,c.CategoryName
		FROM Categories AS c WITH (NOLOCK)
		WHERE c.TenantId = @TenantId
			AND (
				@CategoryID IS NULL
				OR c.CategoryId IN (
					SELECT value
					FROM STRING_SPLIT(@CategoryID, ',')
					)
				)
			AND c.IsDeleted = 0

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
				,CategoryId BIGINT NOT NULL
				,CategoryName VARCHAR(50) NOT NULL
				,ProductPrice NUMERIC(18, 2) NOT NULL
				,OfferPrice NUMERIC(18, 2) NULL
				,OfferId INT NULL
				,LastModifiedDate DATETIME
				)

		INSERT INTO #TempTableProducts (
			ProductId
			,CategoryId
			,CategoryName
			,ProductPrice
			,OfferPrice
			,OfferId
			,LastModifiedDate
			)
		SELECT p.ProductId
			,c.CategoryId
			,c.CategoryName
			,CASE 
				WHEN @HasWholesalerPrice = 0
					THEN p.RetailerPrice
				ELSE p.WholesalerPrice
				END
			,p.RetailOfferPrice
			,o.OfferId
			,ISNULL(p.UpdatedUTCDate, p.CreatedUTCDate)
		FROM dbo.Products p WITH (NOLOCK)
		INNER JOIN @CategoryIDTable c ON c.CategoryId = p.CategoryId
		LEFT JOIN (
			SELECT ofm.ProductId
				,o.OfferID
				,o.OfferCode
				,o.OfferPercentage
				,o.OfferTitle
				,o.StartDate
				,o.EndDate
			FROM OfferProductMapping ofm
			INNER JOIN Offers o ON ofm.OfferId = o.OfferId
				AND o.TenantId = @TenantId
				AND o.IsDeleted = 0
				AND o.IsPublished = 1
			) o ON p.ProductId = o.ProductId
		WHERE p.TenantId = @TenantId
			AND p.Status = 1
			AND (
				@OfferApplied = 0
				OR (
					@OfferApplied = 1
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
			AND (
				@PriceFrom IS NULL
				OR CASE 
					WHEN @OfferApplied = 1
						AND o.OfferId IS NOT NULL
						THEN p.RetailOfferPrice
					ELSE CASE 
							WHEN @HasWholesalerPrice = 0
								THEN p.RetailerPrice
							ELSE p.WholesalerPrice
							END
					END >= @PriceFrom
				)
			AND (
				@PriceTo IS NULL
				OR CASE 
					WHEN @OfferApplied = 1
						AND o.OfferId IS NOT NULL
						THEN RetailOfferPrice
					ELSE CASE 
							WHEN @HasWholesalerPrice = 0
								THEN p.RetailerPrice
							ELSE p.WholesalerPrice
							END
					END <= @PriceTo
				)

		SELECT c.CategoryId
			,c.CategoryName + ' (' + CAST((
					SELECT COUNT(tp.ProductId)
					FROM #TempTableProducts tp
					WHERE tp.CategoryId = c.CategoryId
					) AS VARCHAR(1000)) + ')' AS CategoryName
			,(
				SELECT TOP 5 CAST(p.CategoryId AS BIGINT) AS CategoryId
					,tp.CategoryName AS CategoryName
					,p.ProductId AS ProductId
					,p.ProductTitle AS ProductTitle
					,p.ModelNo AS ModelNo
					,p.CoverImage AS CoverImage
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
					,CASE 
						WHEN tp.OfferId IS NOT NULL
							THEN CAST(1 AS BIT)
						ELSE CAST(0 AS BIT)
						END AS OfferTag
					,CASE 
						WHEN tp.OfferId IS NOT NULL
							THEN o.OfferCode
						ELSE ''
						END AS OfferCode
					,CASE 
						WHEN tp.OfferId IS NOT NULL
							THEN o.OfferPercentage
						ELSE NULL
						END AS OfferPercentage
					,CASE 
						WHEN tp.OfferId IS NOT NULL
							THEN o.OfferTitle
						ELSE NULL
						END AS OfferTitle
					,CASE 
						WHEN tp.OfferId IS NOT NULL
							THEN o.OfferId
						ELSE NULL
						END AS OfferId
					,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				FROM dbo.Products p WITH (NOLOCK)
				INNER JOIN #TempTableProducts tp ON tp.ProductId = p.Productid
				LEFT JOIN Offers o ON tp.OfferId = o.OfferId
				WHERE p.CategoryId = c.CategoryId
				ORDER BY tp.LastModifiedDate
					,CASE 
						WHEN @SortBy = 'CostPrice'
							AND @SortOrder = 'ASC'
							THEN tp.ProductPrice
						END ASC
					,CASE 
						WHEN @SortBy = 'CostPrice'
							AND @SortOrder = 'DESC'
							THEN tp.ProductPrice
						END DESC
				FOR JSON PATH
				) AS productListThumbnails
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM @CategoryIDTable c
		WHERE EXISTS (
				SELECT tp.CategoryId
				FROM #TempTableProducts tp
				WHERE tp.CategoryId = c.CategoryId
				)
		ORDER BY c.CategoryName OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
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

