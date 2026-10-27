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

	DECLARE @Today DATE = CAST(GETDATE() AS DATE);
	DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
	DECLARE @MonthEnd DATE = EOMONTH(@MonthStart);;

	WITH StockPerProduct
	AS (
		SELECT p.ProductId
			,SUM(CAST(pq.Quantity AS DECIMAL(18, 2))) AS QtyOnHand
			,SUM(CAST(pq.Quantity AS DECIMAL(18, 2)) * CAST(p.CostPrice AS DECIMAL(18, 2))) AS StockValue
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
			,DATEDIFF(DAY, ISNULL(ls.LastSaleDate, sp.FirstInward), @Today) AS DaysSinceSale
		FROM (
			SELECT sp.ProductId
				,sp.StockValue
				,(
					SELECT MIN(pq2.QuantityDate)
					FROM dbo.ProductQuantities pq2 WITH (NOLOCK)
					WHERE pq2.ProductId = sp.ProductId
					) AS FirstInward
			FROM StockPerProduct sp
			) sp
		LEFT JOIN LastSale ls ON ls.ProductId = sp.ProductId
		)
	SELECT (
			SELECT ISNULL(SUM(StockValue), 0)
			FROM StockPerProduct
			) AS TotalStockValue
		,(
			SELECT ISNULL(SUM(avs.StockValue), 0)
			FROM AgedStock avs
			WHERE avs.DaysSinceSale <= 30
			) AS FastMovingValue
		,(
			SELECT ISNULL(SUM(avs.StockValue), 0)
			FROM AgedStock avs
			WHERE avs.DaysSinceSale > 30
				AND avs.DaysSinceSale <= 60
			) AS MediumMovingValue
		,(
			SELECT ISNULL(SUM(avs.StockValue), 0)
			FROM AgedStock avs
			WHERE avs.DaysSinceSale > 60
				AND avs.DaysSinceSale <= 120
			) AS SlowMovingValue
		,(
			SELECT ISNULL(SUM(avs.StockValue), 0)
			FROM AgedStock avs
			WHERE avs.DaysSinceSale > 120
			) AS DeadStockValue
		,(
			SELECT ISNULL(SUM(c.Cogs), 0)
			FROM dbo.Orders o WITH (NOLOCK)
			JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
			OUTER APPLY (
				SELECT CAST(CASE osi.SubjectTypeId
							WHEN 1
								THEN p.CostPrice
							ELSE 0
							END * ISNULL(osi.Quantity, 0) AS DECIMAL(18, 2)) AS Cogs
				FROM dbo.Products p WITH (NOLOCK)
				WHERE (
						osi.SubjectTypeId = 1
						AND p.ProductId = osi.SubjectId
						)
				) c
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 2
				AND o.Status NOT IN (
					6
					,8
					)
				AND o.ApprovedDate BETWEEN @MonthStart
					AND @MonthEnd
			) / NULLIF((
				SELECT ISNULL(SUM(StockValue), 0)
				FROM StockPerProduct
				), 0) AS StockTurnover;
END;

GO

