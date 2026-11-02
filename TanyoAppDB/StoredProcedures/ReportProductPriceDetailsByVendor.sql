/*
EXEC ReportProductPriceDetailsByVendor
	 @TenantId = 125
	,@ProductId = 62300
	,@VendorIds = '8,10'
	,@FromDate = NULL
	,@ToDate = NULL
	,@POStatus = '0,1,2'
	,@PageIndex = 1
	,@PageSize = 25
	,@SortBy = 'CreatedDate'
	,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[ReportProductPriceDetailsByVendor] (
	@TenantId BIGINT
	,@ProductId BIGINT
	,@VendorIds VARCHAR(MAX)
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@POStatus VARCHAR(MAX) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @FromDt DATETIMEOFFSET = CAST(CAST(@FromDate AS VARCHAR(128)) + ' 00:00:00.0000001 +05:30' AS DATETIMEOFFSET)
			,@ToDt DATETIMEOFFSET = CAST(CAST(@ToDate AS VARCHAR(128)) + ' 23:59:59.9999999 +05:30' AS DATETIMEOFFSET)

		SELECT PO.PONumber
			,PO.CreatedDate AS POCreatedOn
			,POT.Quantity
			,POT.UnitPrice AS BuyUnitPrice
			,PO.Status AS [Status]
			,V.VendorName
			,PT.ProductTitle
			,PT.ModelNo
			,PT.Width
			,PT.Height
			,PT.Depth
			,PT.Diameter
			,PT.DimensionUnitId
			,PT.CoverImage
			,SUM(POT.UnitPrice * POT.Quantity) OVER () / SUM(POT.Quantity) OVER () AS AverageUnitPrice
			,COUNT(*) OVER () AS TotalCount
		FROM POProducts PO WITH (NOLOCK)
		INNER JOIN POProductItems POT WITH (NOLOCK) ON PO.POProductId = POT.POProductId
		INNER JOIN Vendors V WITH (NOLOCK) ON V.VendorId = PO.VendorId
		INNER JOIN Products PT WITH (NOLOCK) ON PT.ProductId = POT.ProductId
			AND PO.TenantId = PT.TenantId
		WHERE PO.TenantId = @TenantId
			AND POT.ProductId = @ProductId
			AND PO.VendorId IN (
				SELECT CAST(value AS BIGINT)
				FROM STRING_SPLIT(@VendorIds, ',')
				)
			AND (
				@POStatus IS NULL
				OR PO.Status IN (
					SELECT CAST(value AS INT)
					FROM STRING_SPLIT(@POStatus, ',')
					)
				)
			AND (
				(
					@FromDate IS NULL
					OR @ToDate IS NULL
					)
				OR PO.CreatedDate BETWEEN @FromDt
					AND @ToDt
				)
		ORDER BY CASE 
				WHEN @SortBy = 'CreatedDate'
					AND @SortOrder = 'ASC'
					THEN PO.CreatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'CreatedDate'
					AND @SortOrder = 'DESC'
					THEN PO.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'UnitPrice'
					AND @SortOrder = 'ASC'
					THEN POT.UnitPrice
				END ASC
			,CASE 
				WHEN @SortBy = 'UnitPrice'
					AND @SortOrder = 'DESC'
					THEN POT.UnitPrice
				END DESC
			,CASE 
				WHEN @SortBy = 'Quantity'
					AND @SortOrder = 'ASC'
					THEN POT.Quantity
				END ASC
			,CASE 
				WHEN @SortBy = 'Quantity'
					AND @SortOrder = 'DESC'
					THEN POT.Quantity
				END DESC
			,CASE 
				WHEN @SortBy = 'VendorName'
					AND @SortOrder = 'ASC'
					THEN V.VendorName
				END ASC
			,CASE 
				WHEN @SortBy = 'VendorName'
					AND @SortOrder = 'DESC'
					THEN V.VendorName
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY
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

