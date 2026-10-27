/*
EXEC GetProductByQRScan
	@Id = 95094
	,@TenantId  = 2
	,@UserId  = 4486
	,@Type = NULL
*/
CREATE PROCEDURE [dbo].[GetProductByQRScan] (
	@Id BIGINT
	,@TenantId INT
	,@UserId INT
	,@Type VARCHAR(128) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @SubjectTypeId INT = 0
			,@IsWholesaler BIT = 0;

		DROP TABLE IF EXISTS #ProductList;

		DROP TABLE IF EXISTS #OfferDetails;

		CREATE TABLE #ProductList (ProductId BIGINT)

		IF @Type = 'ProductSet'
		BEGIN
			INSERT INTO #ProductList (ProductId)
			SELECT ProductId
			FROM ProductSetItems WITH (NOLOCK)
			WHERE ProductSetId = @Id
		END
		ELSE
		BEGIN
			INSERT INTO #ProductList (ProductId)
			SELECT ProductId
			FROM Products WITH (NOLOCK)
			WHERE ProductId = @Id
				AND TenantId = @TenantId;
		END

		SELECT @SubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId;

		IF EXISTS (
				SELECT 1
				FROM AspNetUsers AU WITH (NOLOCK)
				INNER JOIN AspNetUserRoles UR WITH (NOLOCK) ON AU.Id = UR.UserId
				INNER JOIN AspNetRoleClaims RC WITH (NOLOCK) ON UR.RoleId = RC.RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.WholeselerPrice'
						,'Permissions.General.Order.WholeselerPrice'
						)
				WHERE AU.UserId = @UserId
					AND AU.IsDeleted = 0
				)
		BEGIN
			SET @IsWholesaler = 1
		END

		CREATE TABLE #OfferDetails (
			ProductId BIGINT
			,OfferId INT
			,OfferPercentage INT
			,OfferTitle VARCHAR(50)
			,OfferCode VARCHAR(50)
			,OfferTag BIT
			)

		IF (@IsWholesaler = 0)
		BEGIN
			INSERT INTO #OfferDetails (
				ProductId
				,OfferId
				,OfferPercentage
				,OfferTitle
				,OfferCode
				,OfferTag
				)
			SELECT OPM.ProductId
				,O.OfferId
				,O.OfferPercentage
				,O.OfferTitle
				,O.OfferCode
				,CAST(1 AS BIT) AS OfferTag
			FROM OfferProductMapping OPM
			INNER JOIN Offers O ON O.OfferId = OPM.OfferId
			INNER JOIN #ProductList PL ON PL.ProductId = OPM.ProductId
			WHERE CAST(GETUTCDATE() AS DATE) BETWEEN O.StartDate
					AND O.EndDate;
		END

		SELECT P.ProductId
			,P.CategoryId
			,C.CategoryName
			,ISNULL(C.IsManufacturing, 0) AS IsManufacturing
			,ISNULL(C.IsSellByPerSQFT, 0) AS IsSellByPerSQFT
			,P.ProductTitle
			,P.ModelNo
			,P.Width
			,P.Height
			,P.Depth
			,P.Diameter
			,P.FabricNeeded AS UsedFabric
			,P.FabricNeeded
			,P.IsVisibleToWholesalers
			,P.TotalDaysToPrepare
			,ISNULL(P.Features, '') AS Features
			,ISNULL(P.Features, '') AS Description
			,CASE 
				WHEN @IsWholesaler = 1
					THEN P.WholesalerPrice
				ELSE P.RetailerPrice
				END AS OriginalPrice
			,CASE 
				WHEN @IsWholesaler = 0
					AND OD.OfferId IS NOT NULL
					THEN ISNULL(P.RetailOfferPrice, P.RetailerPrice - (P.RetailerPrice * OD.OfferPercentage / 100))
				WHEN @IsWholesaler = 1
					THEN P.WholesalerPrice
				ELSE P.RetailerPrice
				END AS CostPrice
			,ISNULL(P.Comments, '') AS Comments
			,ISNULL(P.QRImage, '') AS QRImage
			,RIGHT(LEFT(PIM.ImagePath, CASE 
						WHEN CHARINDEX('?', PIM.ImagePath) > 0
							THEN CHARINDEX('?', PIM.ImagePath) - 1
						ELSE LEN(PIM.ImagePath)
						END), CHARINDEX('/', REVERSE(LEFT(PIM.ImagePath, CASE 
								WHEN CHARINDEX('?', PIM.ImagePath) > 0
									THEN CHARINDEX('?', PIM.ImagePath) - 1
								ELSE LEN(PIM.ImagePath)
								END))) - 1) AS ProductImage
			,@SubjectTypeId AS SubjectTypeId
			,CASE 
				WHEN ISNULL(PQ.Quantity, 0) > 0
					THEN 'In Stock'
				ELSE 'Out of Stock'
				END + ' [' + CAST(ISNULL(PQ.Quantity, 0) AS VARCHAR(20)) + ']' AS [Availability]
			,CAST(CASE 
					WHEN P.Status = 1
						THEN 1
					ELSE 0
					END AS BIT) AS IsProductPublished
			,ISNULL(P.HSNNo, '') AS HSNNo
			,ISNULL(LM.LookupValueName, '') AS ProductMaterial
			,ISNULL(LC.LookupValueName, '') AS ProductColour
			,ISNULL(LB.LookupValueName, '') AS ProductBrand
			,ISNULL(OD.OfferId, 0) AS OfferId
			,ISNULL(OD.OfferTag, 0) AS OfferTag
			,ISNULL(OD.OfferCode, '') AS OfferCode
			,ISNULL(OD.OfferPercentage, 0) AS OfferPercentage
			,ISNULL(OD.OfferTitle, '') AS OfferTitle
			,CAST(CASE 
					WHEN C.CategoryTypeId = 2
						THEN 1
					ELSE 0
					END AS BIT) AS IsFabric
		FROM Products P WITH (NOLOCK)
		INNER JOIN #ProductList PL ON PL.ProductId = P.ProductId
		INNER JOIN Categories C WITH (NOLOCK) ON C.CategoryId = P.CategoryId
		LEFT JOIN ProductImages PIM WITH (NOLOCK) ON PIM.ProductId = P.ProductId
		INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = P.ProductId
		LEFT JOIN #OfferDetails OD ON OD.ProductId = P.ProductId
		LEFT JOIN LookupValues LM ON LM.LookupValueId = P.ProductMaterialId
		LEFT JOIN LookupValues LC ON LC.LookupValueId = P.ProductColourId
		LEFT JOIN LookupValues LB ON LB.LookupValueId = P.ProductBrandId
		WHERE P.TenantId = @TenantId
			AND P.Status <> 3
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

