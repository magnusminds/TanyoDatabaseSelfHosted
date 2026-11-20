CREATE PROCEDURE [dbo].[ReportConsolidatedPODetailsByVendor] (
	@TenantId INT
	,@VendorId INT = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@POStatus NVARCHAR(50)
	,@ExpectedDeliveryDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'TotalQuantity'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DROP TABLE IF EXISTS #LookupValue
		
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
			);

	WITH FilteredData
	AS (
		SELECT PO.POProductId
			,PO.PONumber
			,PO.VendorId
			,V.VendorName
			,PT.ProductId
			,PT.ProductTitle
			,POI.Quantity
			,POI.UnitPrice
			,CONCAT (
				POI.Width
				,' x '
				,POI.Height
				,' x '
				,POI.Depth
				) Dimensions
			,CT.IsSellByPerSQFT
			,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18, 2)) * POI.Quantity AS TotalSQFT
			,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18, 2)) * POI.Quantity AS TotalPieces
			,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18, 2)) * POI.Quantity AS TotalWeight
			,CT.CategoryTypeId
			,PO.CreatedDate
			,PO.ExpectedDeliveryDate
			,PO.OrderDate
			,PO.STATUS
		FROM POProducts PO
		INNER JOIN POProductItems POI ON PO.POProductId = POI.POProductId
		INNER JOIN Products PT ON PT.ProductId = POI.ProductId
		INNER JOIN Categories CT ON PT.CategoryId = CT.CategoryId
		INNER JOIN Vendors V ON V.VendorId = PO.VendorId
		OUTER APPLY (
			SELECT MAX(CASE 
						WHEN LKV.LookupValueName = 'SQFT in BOX'
							THEN TRY_CAST(PCF.CustomValue AS NUMERIC(18, 2))
						END) AS SQFTinBOXValue
				,MAX(CASE 
						WHEN LKV.LookupValueName = 'Pieces in BOX'
							THEN TRY_CAST(PCF.CustomValue AS NUMERIC(18, 2))
						END) AS PiecesinBOXValue
				,MAX(CASE 
						WHEN LKV.LookupValueName = 'Weight in BOX'
							THEN TRY_CAST(PCF.CustomValue AS NUMERIC(18, 2))
						END) AS WeightinBOXValue
			FROM ProductCustomFields PCF
			INNER JOIN #LookupValue LKV ON PCF.LookupValueId = LKV.LookupValueId
			WHERE PCF.ProductId = PT.ProductId
				AND PCF.IsDeleted = 0
			) PCF_AGG
		WHERE PO.IsDeleted = 0
			AND PO.TenantId = @TenantId
			AND (
				@VendorId IS NULL
				OR PO.VendorId = @VendorId
				)
			AND (
				@FromDate IS NULL
				OR PO.OrderDate >= @FromDate
				)
			AND (
				@ToDate IS NULL
				OR PO.OrderDate <= @ToDate
				)
			AND (
				@POStatus IS NULL
				OR PO.STATUS IN (
					SELECT CAST(value AS INT)
					FROM STRING_SPLIT(@POStatus, ',')
					)
				)
			AND (
				@ExpectedDeliveryDate IS NULL
				OR PO.ExpectedDeliveryDate = @ExpectedDeliveryDate
				)
		)
	SELECT FD.VendorId
		,FD.VendorName
		,FD.ProductId
		,FD.ProductTitle
		,SUM(FD.Quantity) AS TotalQuantity
		,(
			SELECT FD2.POProductId
				,FD2.PONumber
				,FD2.Quantity
				,FD2.ExpectedDeliveryDate
				,FD2.OrderDate
				,FD2.UnitPrice
				,FD2.Dimensions
				,FD2.IsSellByPerSQFT
				,CAST(CASE 
						WHEN FD2.CategoryTypeId = 2
							THEN 1
						ELSE 0
						END AS BIT) AS IsFabric
				,TotalSQFT
				,TotalPieces
				,TotalWeight
				,FD2.STATUS
			FROM FilteredData FD2
			WHERE FD2.VendorId = FD.VendorId
				AND FD2.ProductId = FD.ProductId
			FOR JSON PATH
				,INCLUDE_NULL_VALUES
			) AS Details
		,COUNT(*) OVER () AS TotalCount
	FROM FilteredData FD
	GROUP BY FD.VendorId
		,FD.VendorName
		,FD.ProductId
		,FD.ProductTitle
	ORDER BY CASE 
			WHEN @SortBy = 'VendorName'
				AND @SortOrder = 'ASC'
				THEN VendorName
			END ASC
		,CASE 
			WHEN @SortBy = 'VendorName'
				AND @SortOrder = 'DESC'
				THEN VendorName
			END DESC
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'ASC'
				THEN ProductTitle
			END ASC
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'DESC'
				THEN ProductTitle
			END DESC
		,CASE 
			WHEN @SortBy = 'TotalQuantity'
				AND @SortOrder = 'ASC'
				THEN SUM(FD.Quantity)
			END ASC
		,CASE 
			WHEN @SortBy = 'TotalQuantity'
				AND @SortOrder = 'DESC'
				THEN SUM(FD.Quantity)
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

