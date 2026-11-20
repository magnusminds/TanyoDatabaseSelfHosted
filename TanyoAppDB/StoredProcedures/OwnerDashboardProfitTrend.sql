-- =============================================================================
-- SP Name   : OwnerDashboardProfitTrend
-- Module    : Owner Dashboard - Profit trend daily bar chart (poster style)
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : One row per day of the month with that day's GROSS profit
--             (daily approved sales - daily COGS from order items).
-- Notes     : Expense tracking is out of scope in Phase 1, so this is gross
--             level profit, consistent with OwnerDashboardProfit.
-- =============================================================================

CREATE   PROCEDURE [dbo].[OwnerDashboardProfitTrend]
    @TenantId INT,
    @Month    INT,
    @Year     INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    DECLARE @MonthStart  DATE = DATEFROMPARTS(@Year, @Month, 1);
    DECLARE @DaysInMonth INT  = DAY(EOMONTH(@MonthStart));

    ;WITH DailySales AS
    (
        SELECT CAST(o.ApprovedDate AS DATE)                              AS ApprovedDay,
               SUM(CAST(o.AmountBeforeGST AS DECIMAL(18, 2)))            AS NetSales
        FROM dbo.Orders o WITH (NOLOCK)
        WHERE o.TenantId = @TenantId
          AND o.IsArchive = 0
          AND o.Status >= 2 AND o.Status NOT IN (6, 8)
          AND YEAR(o.ApprovedDate) = @Year AND MONTH(o.ApprovedDate) = @Month
        GROUP BY CAST(o.ApprovedDate AS DATE)
    ),
    DailyCogs AS
    (
        SELECT CAST(o.ApprovedDate AS DATE) AS ApprovedDay,
               SUM(CAST(p.CostPrice * ISNULL(osi.Quantity, 0) AS DECIMAL(18, 2))) AS Cogs
        FROM dbo.Orders o WITH (NOLOCK)
        INNER JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
        INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
        WHERE o.TenantId = @TenantId
          AND o.IsArchive = 0
          AND o.Status >= 2 AND o.Status NOT IN (6, 8)
          AND YEAR(o.ApprovedDate) = @Year AND MONTH(o.ApprovedDate) = @Month
        GROUP BY CAST(o.ApprovedDate AS DATE)
    ),
    Calendar AS
    (
        SELECT TOP (@DaysInMonth)
               DATEADD(DAY, ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1, @MonthStart) AS [Day]
        FROM sys.objects a CROSS JOIN sys.objects b
    )
    SELECT
        DAY(c.[Day])                                                     AS [Day],
        ISNULL(ds.NetSales, 0) - ISNULL(dc.Cogs, 0)                      AS GrossProfit
    FROM Calendar c
    LEFT JOIN DailySales ds ON ds.ApprovedDay = c.[Day]
    LEFT JOIN DailyCogs dc ON dc.ApprovedDay = c.[Day]
    ORDER BY c.[Day];

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

