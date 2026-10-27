/*
SELECT * FROM Vendors WHERE TenantId = 2
	EXEC [dbo].[ListPOProductByVendor_V2]
		 @TenantId = 2
    ,@VendorId = 4
    ,@Search = NULL
	,@IsAddOn = NULL
*/
CREATE PROCEDURE [dbo].[ListPOProductByVendor_V2] (
	@TenantId BIGINT
	,@VendorId BIGINT
	,@Search VARCHAR(100) = NULL
	,@IsAddOn BIT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DROP TABLE IF EXISTS #LookupValue

		DECLARE @VendorTenantId INT
				,@IsInterState BIT = 0;

		SELECT @VendorTenantId = VendorTenantID
		FROM Vendors WITH (NOLOCK)
		WHERE VendorId = @VendorId

		-- Calculate Inter/Intra State
		IF EXISTS (
				SELECT 1
				FROM Tenants T WITH (NOLOCK)
				INNER JOIN VendorAddresses VA WITH (NOLOCK) ON VA.VendorId = @VendorId
					AND VA.IsDeleted = 0
				WHERE T.TenantId = @TenantId
					AND LTRIM(RTRIM(ISNULL(T.STATE, ''))) <> ''
					AND LTRIM(RTRIM(ISNULL(VA.STATE, ''))) <> ''
					AND LTRIM(RTRIM(T.STATE)) <> LTRIM(RTRIM(VA.STATE))
				)
		BEGIN
			SET @IsInterState = 1;
		END
		ELSE
		BEGIN
			SET @IsInterState = 0;
		END

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

		SELECT p.ProductId
			,p.ProductTitle
			,p.ModelNo
			,p.CoverImage AS ProductImage
			,CASE 
				WHEN p.Status = 1
					THEN CAST(1 AS BIT)
				WHEN p.Status = 2
					THEN CAST(0 AS BIT)
				ELSE NULL
				END AS IsPublished
			,ISNULL(pvm.VendorModelNo, p.ModelNo) AS VendorModelNo
			,CASE 
				WHEN C.IsSellByPerSQFT = 1
					THEN ISNULL(pvm.VendorProductPrice, 0) * ISNULL(PCF_AGG.SQFTinBOXValue, 0)
				ELSE ISNULL(pvm.VendorProductPrice, 0)
				END AS VendorProductPrice
			,CAST(CASE 
					WHEN ISNULL(V.VendorTenantID, 0) > 0
						AND ISNULL(V.AcceptRejectStatus, 0) = 1
						AND VendorProduct.ProductId IS NOT NULL
						THEN 1
					ELSE 0
					END AS BIT) AS IsVenodrProductActive
			,ISNULL(VendorProduct.Quantity, 0) AS AvailableStockInVendor
			,CAST(CASE 
					WHEN c.CategoryTypeId = 2
						THEN 1
					ELSE 0
					END AS BIT) AS IsFabric
			,p.Width
			,p.Height
			,p.Depth
			,p.Diameter
			,c.IsSellByPerSQFT
			,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18, 2)) AS SQFTinBOX
			,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18, 2)) AS TotalSQFT
			,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18, 2)) AS PiecesinBOX
			,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18, 2)) AS TotalPieces
			,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18, 2)) AS WeightinBOX
			,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18, 2)) AS TotalWeight
			,CAST(CASE 
					WHEN PCF_AGG.SQFTinBOXValue IS NOT NULL
						THEN ISNULL(PVM.VendorProductPrice, 0)
					ELSE 0
					END AS NUMERIC(18, 2)) AS PerSQFTRate
			,CAST(ISNULL(v.GSTType, 1) AS BIT) GSTType
			,@IsInterState AS IsInterState
			,c.GST
			,CAST(CASE 
					WHEN ISNULL(v.VendorTenantID, 0) > 0
						AND ISNULL(v.AcceptRejectStatus, 0) = 1
						THEN 1
					ELSE 0
					END AS BIT) AS IsVendorUsingTanyo
			,CAST(CASE 
					WHEN pvm.ProductId IS NOT NULL
						THEN 1
					ELSE 0
					END AS BIT) AS IsMapped --1 IsMapped with Vendor, 2 Not mapped with Product
			,c.IsManufacturing
		FROM Products p WITH (NOLOCK)
		INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
		LEFT JOIN ProductVendorMapping pvm WITH (NOLOCK) ON pvm.ProductId = p.ProductId
			AND pvm.VendorId = @VendorId
			AND pvm.IsDeleted = 0
		LEFT JOIN Vendors v WITH (NOLOCK) ON v.VendorId = pvm.VendorId
			AND v.TenantId = p.TenantId
		OUTER APPLY (
			SELECT MAX(CASE 
						WHEN LKV.LookupValueName = 'SQFT in BOX'
							THEN PCF.CustomValue
						END) AS SQFTinBOXValue
				,MAX(CASE 
						WHEN LKV.LookupValueName = 'Pieces in BOX'
							THEN PCF.CustomValue
						END) AS PiecesinBOXValue
				,MAX(CASE 
						WHEN LKV.LookupValueName = 'Weight in BOX'
							THEN PCF.CustomValue
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
		WHERE p.TenantId = @TenantId
			AND p.Status = 1
			AND (
				NULLIF(@Search, '') IS NULL
				OR p.ModelNo LIKE '%' + @Search + '%'
				OR p.ProductTitle LIKE '%' + @Search + '%'
				)
			AND (
				@IsAddOn IS NULL
				OR @IsAddOn = 0
				OR c.IsVisibleInAddOn = @IsAddOn
				)
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

