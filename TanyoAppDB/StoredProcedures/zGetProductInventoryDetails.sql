/*

EXEC GetProductInventoryDetails
 @TenantId =2
 ,@CategoryId = -1
 ,@ModelNo = NULL
 ,@QuantityDate = NULL
 ,@Quantity =NULL
 ,@StockFilterOperation = NULL
 ,@WarehouseId = NULL
 ,@PageSize = 120000
 ,@SortBy = 'ProductTitle'
 ,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[zGetProductInventoryDetails] (
	@TenantId BIGINT
	,@CategoryId INT = - 1
	,@ProductTitle VARCHAR(200) = NULL
	,@ModelNo VARCHAR(200) = NULL
	,@QuantityDate DATETIMEOFFSET = NULL
	,@Quantity [NUMERIC](18, 2) = NULL
	,@StockFilterOperation VARCHAR(5) = NULL
	,@WarehouseId BIGINT = NULL
	,@PageSize INT = 50
	,@PageIndex INT = 1
	,@SortBy VARCHAR(50) = 'ProductTitle'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#BaseProducts') IS NOT NULL
		DROP TABLE #BaseProducts

	IF OBJECT_ID('tempdb..#ReadyToDeliver') IS NOT NULL
		DROP TABLE #ReadyToDeliver

	IF OBJECT_ID('tempdb..#Inquiry') IS NOT NULL
		DROP TABLE #Inquiry

	IF OBJECT_ID('tempdb..#OnHold') IS NOT NULL
		DROP TABLE #OnHold

	IF OBJECT_ID('tempdb..#WarehouseQty') IS NOT NULL
		DROP TABLE #WarehouseQty

	IF OBJECT_ID('tempdb..#InStock') IS NOT NULL
		DROP TABLE #InStock

	CREATE TABLE #InStock (
		ProductId BIGINT
		,InStock [NUMERIC](18, 2)
		);

	DECLARE @dt DATETIMEOFFSET = SYSDATETIMEOFFSET();
	DECLARE @ProductSubjectTypeId INT;

	IF (@QuantityDate IS NOT NULL)
	BEGIN
		DECLARE @FromQuantityDateTime DATETIMEOFFSET = CAST(CAST(@QuantityDate AS VARCHAR(10)) + ' 00:00:00.0000001 +05:30' AS DATETIMEOFFSET)
			,@ToQuantityDateTime DATETIMEOFFSET = CAST(CAST(@QuantityDate AS VARCHAR(10)) + ' 23:59:59.9999999 +05:30' AS DATETIMEOFFSET)
	END

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT PQ.ProductQuantityId
		,PQ.ProductId
	INTO #BaseProducts
	FROM ProductQuantities PQ WITH (NOLOCK)
	INNER JOIN Products P WITH (NOLOCK) ON P.ProductId = PQ.ProductId
	WHERE P.TenantId = @TenantId
		AND P.STATUS <> 3
		AND (
			@CategoryId = - 1
			OR P.CategoryId = @CategoryId
			)
		AND (
			@ProductTitle IS NULL
			OR P.ProductTitle LIKE '%' + @ProductTitle + '%'
			)
		AND (
			@ModelNo IS NULL
			OR P.ModelNo LIKE '%' + @ModelNo + '%'
			)
		AND (
			@QuantityDate IS NULL
			OR PQ.QuantityDate BETWEEN @FromQuantityDateTime
				AND @ToQuantityDateTime
			);

	SELECT OS.SubjectId AS ProductId
		,SUM(OS.Quantity) AS ReadyToDelivered
	INTO #ReadyToDeliver
	FROM Orders O WITH (NOLOCK)
	INNER JOIN OrderSetItems OS WITH (NOLOCK) ON OS.OrderId = O.OrderId
	INNER JOIN #BaseProducts BP ON BP.ProductId = OS.SubjectId
	WHERE O.TenantId = @TenantId
		AND o.STATUS IN (
			2
			,3
			)
		AND os.IsDeleted = 0
		AND os.SubjectTypeId = @ProductSubjectTypeId
	GROUP BY os.SubjectId;

	SELECT os.SubjectId AS ProductId
		,SUM(os.Quantity) AS Inquiry
	INTO #Inquiry
	FROM Orders O WITH (NOLOCK)
	INNER JOIN OrderSetItems OS WITH (NOLOCK) ON OS.OrderId = O.OrderId
	INNER JOIN #BaseProducts BP ON BP.ProductId = OS.SubjectId
	WHERE O.TenantId = @TenantId
		AND O.STATUS = 0
		AND OS.IsDeleted = 0
		AND OS.SubjectTypeId = @ProductSubjectTypeId
	GROUP BY OS.SubjectId;

	SELECT OSI.SubjectId AS ProductId
		,SUM(SOH.Quantity) AS OnHold
	INTO #OnHold
	FROM StockOnHold SOH WITH (NOLOCK)
	INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = SOH.OrderSetItemId
	INNER JOIN Orders o WITH (NOLOCK) ON O.OrderId = SOH.OrderId
	INNER JOIN #BaseProducts BP ON BP.ProductId = OSI.SubjectId
	WHERE O.TenantId = @TenantId
		AND O.STATUS = 0
		AND OSI.IsDeleted = 0
		AND SOH.IsStockOnHold = 1
		AND OSI.IsQuantityOnHold = 1
		AND SOH.HoldUptoDate > @dt
	GROUP BY OSI.SubjectId;

	CREATE TABLE #WarehouseQty (
		ProductId BIGINT
		,Quantity [NUMERIC](18, 2)
		)

	IF @WarehouseId IS NOT NULL
	BEGIN
		INSERT INTO #WarehouseQty
		SELECT PQBW.ProductId
			,SUM(Quantity)
		FROM ProductQuantitiesByWarehouse PQBW WITH (NOLOCK)
		INNER JOIN #BaseProducts BP ON BP.ProductId = PQBW.ProductId
		WHERE WarehouseId = @WarehouseId
		GROUP BY PQBW.ProductId;
	END

	IF @WarehouseId IS NOT NULL
	BEGIN
		INSERT INTO #InStock (
			ProductId
			,InStock
			)
		SELECT ide.ProductId
			,SUM(ide.Quantity)
		FROM InwardDetailsEntry IDE WITH (NOLOCK)
		INNER JOIN #BaseProducts BP ON BP.ProductId = IDE.ProductId
		LEFT JOIN InwardEntry IE WITH (NOLOCK) ON IE.InwardId = IDE.InwardId
		WHERE IDE.IsDeleted = 0
			AND IDE.WarehouseId = @WarehouseId
			AND (
				IE.TenantId = @TenantId
				OR IDE.InwardId = 0
				)
		GROUP BY IDE.ProductId;
	END
	ELSE
	BEGIN
		INSERT INTO #InStock (
			ProductId
			,InStock
			)
		SELECT PQ.ProductId
			,PQ.Quantity
		FROM ProductQuantities PQ WITH (NOLOCK)
		INNER JOIN #BaseProducts BP ON BP.ProductId = PQ.ProductId
	END

	SELECT PQ.ProductQuantityId
		,P.ProductId
		,P.ProductTitle
		,P.CategoryId
		,C.CategoryName
		,PQ.QuantityDate
		,IIF(@WarehouseId IS NULL, PQ.Quantity, WQ.Quantity) AS Quantity
		,ISNULL(RD.ReadyToDelivered, 0) AS ReadyToDelivered
		,ISNULL(IQ.Inquiry, 0) AS Inquiry
		,ISNULL(OH.OnHold, 0) AS OnHold
		,ISNULL(ISK.InStock, 0) AS InStock
		,PQ.MinimumLimit
		,P.ModelNo
		,PQ.LastModifiedBy
		,U.FirstName + ' ' + U.LastName AS LastModifiedByName
		,PQ.LastModifiedDate
		,PQ.LastModifiedUTCDate
		,ISNULL(P.CoverImage, '/images/no-coverimage.png') AS CoverImage
		,COUNT(*) OVER () AS TotalCount
	FROM ProductQuantities PQ WITH (NOLOCK)
	INNER JOIN Products P WITH (NOLOCK) ON P.ProductId = PQ.ProductId
	INNER JOIN Categories C WITH (NOLOCK) ON C.CategoryId = P.CategoryId
	INNER JOIN AspNetUsers U WITH (NOLOCK) ON U.UserId = PQ.LastModifiedBy
	INNER JOIN #BaseProducts BP ON BP.ProductId = PQ.ProductId
	LEFT JOIN #ReadyToDeliver RD ON RD.ProductId = P.ProductId
	LEFT JOIN #Inquiry IQ ON IQ.ProductId = P.ProductId
	LEFT JOIN #OnHold OH ON OH.ProductId = P.ProductId
	LEFT JOIN #WarehouseQty WQ ON WQ.ProductId = P.ProductId
	LEFT JOIN #InStock ISK ON ISK.ProductId = P.ProductId
	WHERE P.TenantId = @TenantId
		AND P.STATUS <> 3
		AND C.IsDeleted = 0
		AND C.CategoryTypeId = 1
		AND (
			@CategoryId = - 1
			OR P.CategoryId = @CategoryId
			)
		AND (
			@ProductTitle IS NULL
			OR P.ProductTitle LIKE '%' + @ProductTitle + '%'
			)
		AND (
			@ModelNo IS NULL
			OR P.ModelNo LIKE '%' + @ModelNo + '%'
			)
		AND (
			@QuantityDate IS NULL
			OR PQ.QuantityDate BETWEEN @FromQuantityDateTime
				AND @ToQuantityDateTime
			)
		AND (
			@Quantity IS NULL
			OR @StockFilterOperation IS NULL
			OR (
				(
					@StockFilterOperation = '='
					AND @WarehouseId IS NULL
					AND PQ.Quantity = @Quantity
					)
				OR (
					@StockFilterOperation = '>='
					AND @WarehouseId IS NULL
					AND PQ.Quantity >= @Quantity
					)
				OR (
					@StockFilterOperation = '<='
					AND @WarehouseId IS NULL
					AND PQ.Quantity <= @Quantity
					)
				OR (
					@StockFilterOperation = '='
					AND @WarehouseId IS NOT NULL
					AND WQ.Quantity = @Quantity
					)
				OR (
					@StockFilterOperation = '>='
					AND @WarehouseId IS NOT NULL
					AND WQ.Quantity >= @Quantity
					)
				OR (
					@StockFilterOperation = '<='
					AND @WarehouseId IS NOT NULL
					AND WQ.Quantity <= @Quantity
					)
				)
			)
		AND (
			@WarehouseId IS NULL
			OR EXISTS (
				SELECT 1
				FROM ProductQuantitiesByWarehouse PQBW
				WHERE PQBW.ProductId = PQ.ProductId
					AND PQBW.WarehouseId = @WarehouseId
				)
			)
	ORDER BY CASE 
			WHEN @SortBy = 'lastModifiedByName'
				AND @SortOrder = 'ASC'
				THEN U.FirstName + ' ' + U.LastName
			END
		,CASE 
			WHEN @SortBy = 'lastModifiedByName'
				AND @SortOrder = 'DESC'
				THEN U.FirstName + ' ' + U.LastName
			END DESC
		,CASE 
			WHEN @SortBy = 'quantityDateFormat'
				AND @SortOrder = 'ASC'
				THEN QuantityDate
			END
		,CASE 
			WHEN @SortBy = 'quantityDateFormat'
				AND @SortOrder = 'DESC'
				THEN QuantityDate
			END DESC
		,CASE 
			WHEN @SortBy = 'lastModifiedDateFormat'
				AND @SortOrder = 'ASC'
				THEN LastModifiedDate
			END
		,CASE 
			WHEN @SortBy = 'lastModifiedDateFormat'
				AND @SortOrder = 'DESC'
				THEN LastModifiedDate
			END DESC
		,CASE 
			WHEN @SortBy = 'CategoryName'
				AND @SortOrder = 'ASC'
				THEN CategoryName
			END
		,CASE 
			WHEN @SortBy = 'CategoryName'
				AND @SortOrder = 'DESC'
				THEN CategoryName
			END DESC
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'ASC'
				THEN ProductTitle
			END
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'DESC'
				THEN ProductTitle
			END DESC
		,CASE 
			WHEN @SortBy = 'ModelNo'
				AND @SortOrder = 'ASC'
				THEN ModelNo
			END
		,CASE 
			WHEN @SortBy = 'ModelNo'
				AND @SortOrder = 'DESC'
				THEN ModelNo
			END DESC
		,CASE 
			WHEN @SortBy = 'Quantity'
				AND @SortOrder = 'ASC'
				THEN IIF(@WarehouseId IS NULL, PQ.Quantity, WQ.Quantity)
			END
		,CASE 
			WHEN @SortBy = 'Quantity'
				AND @SortOrder = 'DESC'
				THEN IIF(@WarehouseId IS NULL, PQ.Quantity, WQ.Quantity)
			END DESC
		,CASE 
			WHEN @SortBy = 'ReOrderPoint'
				AND @SortOrder = 'ASC'
				THEN MinimumLimit
			END
		,CASE 
			WHEN @SortBy = 'ReOrderPoint'
				AND @SortOrder = 'DESC'
				THEN MinimumLimit
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY;
END

GO

