-- =============================================================================
-- SP Name   : OwnerDashboardProfit
-- Module    : Owner Dashboard - Profit ("Are We Making Money?")
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : Gross sales, COGS, gross profit and margin % for the period.
--
-- KPI Logic:
--   NOTE: Expense tracking is NOT part of Phase 1 (owner decision) - profit is
--         reported at GROSS level only.
--   GrossSales     = SUM(Orders.AmountBeforeGST) of approved orders in period
--                    (pre-tax value, consistent with existing dashboards).
--   COGS           = SUM(item cost x qty) over OrderSetItems of those orders.
--                    Item type resolved per-tenant via SubjectTypes lookup:
--                    'Products' -> Products.CostPrice,
--                    'Fabrics'  -> Fabrics.UnitPrice.
--   GrossProfit    = GrossSales - COGS.
--   GrossMarginPct = GrossProfit / GrossSales * 100 (0 when no sales).
-- =============================================================================

CREATE   PROCEDURE [dbo].[OwnerDashboardProfit]
    @TenantId INT,
    @Month    INT,
    @Year     INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @MonthEnd   DATE = EOMONTH(@MonthStart);

    ;WITH PeriodOrders AS
    (
        SELECT o.OrderId,
               o.AmountBeforeGST AS NetSales
        FROM dbo.Orders o WITH (NOLOCK)
        WHERE o.TenantId = @TenantId
          AND o.IsArchive = 0
          AND o.Status >= 2 AND o.Status NOT IN (6, 8)        -- Won
          AND o.ApprovedDate BETWEEN @MonthStart AND @MonthEnd
    ),
    CogsPerOrder AS
    (
        SELECT osi.OrderId,
               SUM(CAST(p.CostPrice * osi.Quantity AS DECIMAL(18, 2)))                  AS Cogs
        FROM dbo.OrderSetItems osi WITH (NOLOCK)
        INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
        INNER JOIN PeriodOrders po ON po.OrderId = osi.OrderId
        GROUP BY osi.OrderId
    )
    SELECT
        ISNULL(SUM(po.NetSales), 0)                                                 AS GrossSales,
        ISNULL(SUM(c.Cogs), 0)                                                      AS COGS,
        ISNULL(SUM(po.NetSales), 0) - ISNULL(SUM(c.Cogs), 0)                        AS GrossProfit,
        CASE WHEN ISNULL(SUM(po.NetSales), 0) > 0
             THEN ((ISNULL(SUM(po.NetSales), 0) - ISNULL(SUM(c.Cogs), 0)) * 100.0)
                  / SUM(po.NetSales)
             ELSE 0 END                                                             AS GrossMarginPct
    FROM PeriodOrders po
    LEFT JOIN CogsPerOrder c ON c.OrderId = po.OrderId;

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

