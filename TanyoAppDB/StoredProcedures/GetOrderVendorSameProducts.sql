/*
EXEC GetOrderVendorSameProducts
	@OrderId = 63170,
	@VendorId = 33 ,
	@OrderSetItemId = 65866,
	@IsAll = 1
*/
CREATE PROCEDURE [dbo].[GetOrderVendorSameProducts] 
	 @OrderId BIGINT
	,@VendorId BIGINT
	,@OrderSetItemId BIGINT
	,@IsAll BIT = 0
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DROP TABLE IF EXISTS #LookupValue

		DECLARE @TenantId INT

		SELECT @TenantId = TenantId
		FROM Orders WITH (NOLOCK)
		WHERE OrderId = @OrderId

		SELECT LKV.*
		INTO #LookupValue
		FROM Lookups LK WITH (NOLOCK)
		INNER JOIN LookupValues LKV ON LK.LookupId = LKV.LookupId
		WHERE LK.TenantId = @TenantId
			AND LK.IsDeleted = 0
			AND LKV.IsDeleted = 0
			AND LK.LookupName = 'ProductCustomLabel'
			AND LKV.LookupValueName IN (
				'SQFT in BOX'
				,'Pieces in BOX'
				,'Weight in BOX'
				)

		SELECT osi.SubjectId AS ProductId
			,p.ProductTitle
			,p.ModelNo
			,osi.ProductImage AS CoverImage
			,osi.Quantity
			,osi.Comment AS Remarks
			,osi.OrderSetItemId
			,ISNULL(osi.Width, osi.InstantWidth) AS Width
			,ISNULL(osi.Height, osi.InstantHeight) AS Height
			,ISNULL(osi.Depth, osi.InstantDepth) AS Depth
			,ISNULL(osi.Diameter, osi.InstantDiameter) AS Diameter
			--,ISNULL(pvm.VendorProductPrice, 0) AS VendorProductPrice
			,CASE 
				WHEN C.IsSellByPerSQFT = 1
					THEN ISNULL(pvm.VendorProductPrice, 0) * ISNULL(PCF_AGG.SQFTinBOXValue, 0)
				ELSE ISNULL(pvm.VendorProductPrice, 0)
				END AS VendorProductPrice
			,CAST(CASE 
					WHEN c.CategoryTypeId = 2
						THEN 1
					ELSE 0
					END AS BIT) AS IsFabric
			,c.IsSellByPerSQFT
			,(
				SELECT OrderSetItemImageId
					,FileURL
					,FileType
				FROM OrderSetItemImages WITH (NOLOCK)
				WHERE OrderSetItemId = osi.OrderSetItemId
					AND FileType = 'Image'
				FOR JSON PATH
				) AS OrderSetItemImages
			,(
				SELECT OrderSetItemImageId
					,FileURL
					,FileType
				FROM OrderSetItemImages WITH (NOLOCK)
				WHERE OrderSetItemId = osi.OrderSetItemId
					AND FileType = 'Audio'
				FOR JSON PATH
				) AS OrderSetItemAudios
			,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18, 2)) AS SQFTinBOX
			,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) * osi.Quantity AS NUMERIC(18, 2)) AS TotalSQFT
			,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18, 2)) AS PiecesinBOX
			,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) * osi.Quantity AS NUMERIC(18, 2)) AS TotalPieces
			,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18, 2)) AS WeightinBOX
			,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) * osi.Quantity AS NUMERIC(18, 2)) AS TotalWeight
			,CAST(CASE 
					WHEN PCF_AGG.SQFTinBOXValue IS NOT NULL
						THEN ISNULL(PVM.VendorProductPrice, 0)
					ELSE 0
					END AS NUMERIC(18, 2)) AS PerSQFTRate
			,v.GSTType AS VendorGSTType
			,c.GST AS CategoryGST
			,CAST(CASE 
					WHEN LTRIM(RTRIM(ISNULL(TN.STATE, ''))) = ''
						THEN 0
					WHEN LTRIM(RTRIM(ISNULL(VA.STATE, ''))) = ''
						THEN 0
					WHEN LTRIM(RTRIM(TN.STATE)) <> LTRIM(RTRIM(VA.STATE))
						THEN 1
					ELSE 0
					END AS BIT) AS IsVendorInterState
			,CAST(CASE 
					WHEN ISNULL(V.VendorTenantID, 0) > 0
						AND ISNULL(V.AcceptRejectStatus, 0) = 1
						THEN 1
					ELSE 0
					END AS BIT) AS IsVendorUsingTanyo
			,CAST(CASE 
					WHEN ISNULL(V.VendorTenantID, 0) > 0
						AND ISNULL(V.AcceptRejectStatus, 0) = 1
						AND VendorProduct.ProductId IS NOT NULL
						THEN 1
					ELSE 0
					END AS BIT) AS IsVendorProductActive
			,ISNULL(VendorProduct.Quantity, 0) AS AvailableStockInVendor
			,ISNULL(pvm.VendorModelNo, p.ModelNo) AS VendorModelNo
		FROM OrderSetItems AS osi WITH (NOLOCK)
		INNER JOIN ProductVendorMapping AS pvm WITH (NOLOCK) ON osi.SubjectId = pvm.ProductId
			AND pvm.VendorId = @VendorId --and pvm.IsDefault = 1
		INNER JOIN Vendors AS v WITH (NOLOCK) ON pvm.VendorId = v.VendorId
		INNER JOIN Products AS p WITH (NOLOCK) ON osi.SubjectId = p.ProductId
		INNER JOIN Categories AS c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
		LEFT JOIN Tenants TN WITH (NOLOCK) ON TN.TenantId = @TenantId
		LEFT JOIN VendorAddresses VA WITH (NOLOCK) ON VA.VendorId = v.VendorId
			AND VA.IsDeleted = 0
		OUTER APPLY (
			SELECT MAX(CASE 
						WHEN LKV.LookupValueName = 'SQFT in BOX'
							THEN CAST(PCF.CustomValue AS NUMERIC(18, 2))
						END) AS SQFTinBOXValue
				,MAX(CASE 
						WHEN LKV.LookupValueName = 'Pieces in BOX'
							THEN CAST(PCF.CustomValue AS NUMERIC(18, 2))
						END) AS PiecesinBOXValue
				,MAX(CASE 
						WHEN LKV.LookupValueName = 'Weight in BOX'
							THEN CAST(PCF.CustomValue AS NUMERIC(18, 2))
						END) AS WeightinBOXValue
			FROM ProductCustomFields PCF
			INNER JOIN #LookupValue LKV ON PCF.LookupValueId = LKV.LookupValueId
			WHERE PCF.ProductId = p.ProductId
				AND PCF.IsDeleted = 0
			) PCF_AGG
		OUTER APPLY (
			SELECT TOP (1) VP.ProductId
				,PQ.Quantity
				,VP.Status
			FROM Products VP WITH (NOLOCK)
			INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = VP.ProductId
			WHERE VP.TenantId = V.VendorTenantID
				AND VP.Status = 1
				AND (
					(
						PVM.VendorProductId IS NOT NULL
						AND PVM.VendorProductId > 0
						AND VP.ProductId = PVM.VendorProductId
						)
					OR (
						(
							PVM.VendorProductId IS NULL
							OR PVM.VendorProductId = 0
							)
						AND ISNULL(PVM.VendorModelNo, '') <> ''
						AND VP.ModelNo = PVM.VendorModelNo
						)
					)
			ORDER BY CASE 
					WHEN VP.ProductId = PVM.VendorProductId
						THEN 1
					ELSE 2
					END
			) VendorProduct
		WHERE osi.OrderId = @OrderId
			--AND osi.OrderSetItemId != @OrderSetItemId 
			AND osi.IsDeleted = 0
			AND (
				@IsAll = 1
				OR osi.OrderSetItemId != @OrderSetItemId
				);
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

