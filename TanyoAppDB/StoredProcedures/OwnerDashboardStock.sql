-- =============================================================================
-- SP Name   : OwnerDashboardStock
-- Module    : Owner Dashboard - Stock ("What Is My Stock Status?")
-- Params    : @TenantId INT, @Month INT, @Year INT, optional threshold overrides
-- Returns   : Total stock value + movement-class buckets by days since last
--             sale (poster style donut) + stock turnover ratio.
--
-- Movement buckets (days since last sale; inward date when never sold):
--   FastMovingValue   <= 30
--   MediumMovingValue  31 - 60
--   SlowMovingValue    61 - 120
--   DeadStockValue     > 120
--
-- StockTurnover = COGS of @Month/@Year / TotalStockValue (times/month).
-- =============================================================================
CREATE PROCEDURE [dbo].[OwnerDashboardStock] 
	@TenantId INT
	,@Month INT
	,@Year INT
	,@SlowMovingDays INT = 60
	,@DeadStockDays INT = 120
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @Today DATE = CAST(GETDATE() AS DATE);
		DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
		DECLARE @MonthEnd DATE = EOMONTH(@MonthStart);;

		WITH StockPerProduct
		AS (
			SELECT p.ProductId
				,SUM(CAST(pq.Quantity AS DECIMAL(18, 2))) AS QtyOnHand
				,SUM(CAST(pq.Quantity AS DECIMAL(18, 2)) * CAST(p.CostPrice AS DECIMAL(18, 2))) AS StockValue
				,MIN(pq.QuantityDate) AS FirstInwardDate
			FROM dbo.ProductQuantities pq WITH (NOLOCK)
			INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = pq.ProductId
				AND p.Status <> 3
			WHERE p.TenantId = @TenantId
				AND pq.Quantity > 0
			GROUP BY p.ProductId
			)
			,LastSale
		AS (
			SELECT il.ProductId
				,MAX(il.CreatedDate) AS LastSaleDate
			FROM dbo.InventoryLogs il WITH (NOLOCK)
			INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = il.ProductId
				AND p.Status <> 3
			WHERE p.TenantId = @TenantId
				AND il.OrderNo IS NOT NULL
			GROUP BY il.ProductId
			)
			,AgedStock
		AS (
			SELECT sp.ProductId
				,sp.StockValue
				,DATEDIFF(DAY, ISNULL(ls.LastSaleDate, sp.FirstInwardDate), @Today) AS DaysSinceSale
			FROM StockPerProduct sp
			LEFT JOIN LastSale ls ON ls.ProductId = sp.ProductId
			)
			,StockSummary
		AS (
			SELECT ISNULL(SUM(StockValue), 0) AS TotalStockValue
				,ISNULL(SUM(CASE 
							WHEN DaysSinceSale <= 30
								THEN StockValue
							ELSE 0
							END), 0) AS FastMovingValue
				,ISNULL(SUM(CASE 
							WHEN DaysSinceSale > 30
								AND DaysSinceSale <= 60
								THEN StockValue
							ELSE 0
							END), 0) AS MediumMovingValue
				,ISNULL(SUM(CASE 
							WHEN DaysSinceSale > 60
								AND DaysSinceSale <= 120
								THEN StockValue
							ELSE 0
							END), 0) AS SlowMovingValue
				,ISNULL(SUM(CASE 
							WHEN DaysSinceSale > 120
								THEN StockValue
							ELSE 0
							END), 0) AS DeadStockValue
			FROM AgedStock
			)
			,MonthlyCOGS
		AS (
			SELECT ISNULL(SUM(CAST(CASE 
								WHEN osi.SubjectTypeId = 1
									THEN p.CostPrice
								ELSE 0
								END * ISNULL(osi.Quantity, 0) AS DECIMAL(18, 2))), 0) AS Cogs
			FROM dbo.Orders o WITH (NOLOCK)
			INNER JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
			LEFT JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
				AND osi.SubjectTypeId = 1
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 2
				AND o.Status NOT IN (
					6
					,8
					)
				AND o.ApprovedDate BETWEEN @MonthStart
					AND @MonthEnd
			)
		SELECT ss.TotalStockValue
			,ss.FastMovingValue
			,ss.MediumMovingValue
			,ss.SlowMovingValue
			,ss.DeadStockValue
			,mc.Cogs / NULLIF(ss.TotalStockValue, 0) AS StockTurnover
		FROM StockSummary ss
		CROSS JOIN MonthlyCOGS mc;
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END;
GO

