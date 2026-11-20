/* 

EXEC ListPOProductByVendor
@TenantId = 131
,@VendorId = 33

*/
CREATE   PROC [dbo].[ListPOProductByVendor] (
	@TenantId BIGINT
	,@VendorId BIGINT
	,@Search VARCHAR(50) = NULL
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
    IF EXISTS
	(
		SELECT 1
		FROM Tenants T WITH (NOLOCK)
		INNER JOIN VendorAddresses VA WITH (NOLOCK)
			ON VA.VendorId = @VendorId
			AND VA.IsDeleted = 0
		WHERE T.TenantId = @TenantId
			AND LTRIM(RTRIM(ISNULL(T.State, ''))) <> ''
			AND LTRIM(RTRIM(ISNULL(VA.State, ''))) <> ''
			AND LTRIM(RTRIM(T.State)) <> LTRIM(RTRIM(VA.State))
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
	AND LKV.LookupValueName IN ('SQFT in BOX'
								,'Pieces in BOX'
								,'Weight in BOX') 

	SELECT p.ProductId
		,p.ProductTitle
		,p.ModelNo
		,p.CoverImage AS ProductImage
		,CASE 
			WHEN p.STATUS = 1
				THEN CAST(1 AS BIT)
			WHEN p.STATUS = 2
				THEN CAST(0 AS BIT)
			ELSE NULL
			END AS IsPublished
		,ISNULL(pvm.VendorModelNo, p.ModelNo) AS VendorModelNo
		,CASE WHEN C.IsSellByPerSQFT = 1 THEN  ISNULL(pvm.VendorProductPrice, 0) * ISNULL(PCF_AGG.SQFTinBOXValue, 0) ELSE ISNULL(pvm.VendorProductPrice, 0) END AS VendorProductPrice
		,CAST(
			CASE
				WHEN ISNULL(V.VendorTenantID,0) > 0
					 AND ISNULL(V.AcceptRejectStatus,0) = 1
					 AND VendorProduct.ProductId IS NOT NULL
				THEN 1
				ELSE 0
			END
			AS BIT) AS IsVenodrProductActive
		,ISNULL(VendorProduct.Quantity,0) AS AvailableStockInVendor
		,CAST(
			CASE 
				WHEN c.CategoryTypeId = 2 THEN 1
				ELSE 0
			END 
		AS BIT) AS IsFabric
		,p.Width
		,p.Height
		,p.Depth
		,p.Diameter
		,c.IsSellByPerSQFT
		,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18,2)) AS SQFTinBOX
		,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18,2)) AS TotalSQFT
		,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18,2)) AS PiecesinBOX
		,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18,2)) AS TotalPieces
		,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18,2)) AS WeightinBOX
		,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18,2)) AS TotalWeight
		
		,CAST(CASE
		    WHEN PCF_AGG.SQFTinBOXValue IS NOT NULL
		    THEN ISNULL(PVM.VendorProductPrice,0)
		    ELSE 0
		END AS NUMERIC(18,2)) AS PerSQFTRate
		,v.GSTType
		,@IsInterState AS IsInterState
		,c.GST
		,CAST(
			CASE
				WHEN ISNULL(v.VendorTenantID, 0) > 0
					 AND ISNULL(v.AcceptRejectStatus, 0) = 1
				THEN 1
				ELSE 0
			END
		AS BIT) AS IsVendorUsingTanyo
	FROM ProductVendorMapping pvm WITH (NOLOCK)
	INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = pvm.ProductId
	INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
	INNER JOIN Vendors v WITH (NOLOCK) ON v.VendorId = pvm.VendorId
		AND v.TenantId = p.TenantId
	OUTER APPLY (
	    SELECT 
	        MAX(CASE WHEN LKV.LookupValueName = 'SQFT in BOX' THEN PCF.CustomValue END) AS SQFTinBOXValue,
	        MAX(CASE WHEN LKV.LookupValueName = 'Pieces in BOX' THEN PCF.CustomValue END) AS PiecesinBOXValue,
	        MAX(CASE WHEN LKV.LookupValueName = 'Weight in BOX' THEN PCF.CustomValue END) AS WeightinBOXValue
	    FROM ProductCustomFields PCF
	    INNER JOIN #LookupValue LKV ON PCF.LookupValueId = LKV.LookupValueId
	    WHERE PCF.ProductId = p.ProductId
	      AND PCF.IsDeleted = 0
	) PCF_AGG
	OUTER APPLY
	(
		SELECT TOP (1)
			VP.ProductId
			,PQ.Quantity
			,VP.Status
		FROM Products VP WITH (NOLOCK)
		INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = VP.ProductId
		WHERE VP.TenantId = V.VendorTenantID
		  AND VP.Status = 1
		  AND
		  (
				(PVM.VendorProductId IS NOT NULL
				 AND VP.ProductId = PVM.VendorProductId)

			 OR (
					(PVM.VendorProductId IS NULL OR PVM.VendorProductId = 0)
					AND ISNULL(PVM.VendorModelNo,'') <> ''
					AND VP.ModelNo = PVM.VendorModelNo
				)
		  )
		ORDER BY
			CASE
				WHEN VP.ProductId = PVM.VendorProductId THEN 1
				ELSE 2
			END
	) VendorProduct
	WHERE p.TenantId = @TenantId
		AND p.STATUS = 1
		AND pvm.VendorId = @VendorId
		AND pvm.IsDeleted = 0
		AND (
			@Search IS NULL
			OR @Search = ''
			OR p.ModelNo LIKE '%' + @Search + '%'
			OR p.ProductTitle LIKE '%' + @Search + '%'
			)
	ORDER BY 2

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

