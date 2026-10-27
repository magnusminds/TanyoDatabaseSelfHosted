-- =============================================================================
-- SP Name   : OwnerDashboardCash
-- Module    : Owner Dashboard - Cash ("Are We Collecting?")
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : Today/MTD collection, outstanding breakdown, aging buckets.
--
-- KPI Logic:
--   TodayCollection  = SUM(approved payments) received today.
--   MTDCollection    = SUM(approved payments) received in @Month/@Year.
--   TotalOutstanding = SUM(invoice - paid) on won orders with balance > 0.
--   OverdueOutstanding= Outstanding on orders approved > 30 days ago.
--   DueNext7Days     = Outstanding on orders with DeliveryDate in next 7 days.
--   Aging buckets    = Outstanding split by days since ApprovedDate.
-- =============================================================================
CREATE PROCEDURE [dbo].[OwnerDashboardCash] 
@TenantId INT
	,@Month INT
	,@Year INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Today DATE = CAST(GETDATE() AS DATE);
	DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
	DECLARE @MonthEnd DATE = EOMONTH(@MonthStart);;

	WITH ApprovedOrders
	AS (
		SELECT o.OrderId
			,CAST(o.TotalAmount AS DECIMAL(18, 2)) AS InvoiceValue
			,o.DeliveryDate
			,o.ApprovedDate
		FROM dbo.Orders o WITH (NOLOCK)
		WHERE o.TenantId = @TenantId
			AND o.IsArchive = 0
			AND o.Status >= 2
			AND o.Status NOT IN (
				6
				,8
				) -- Won
		)
		,PaidPerOrder
	AS (
		SELECT p.OrderId
			,SUM(CAST(p.ReceivedAmount AS DECIMAL(18, 2))) AS Paid
		FROM dbo.Payments p WITH (NOLOCK)
		WHERE p.TenantId = @TenantId
			AND p.IsDeleted = 0
			AND p.PaymentStatus = 1 -- Approved payment
			AND p.OrderId IS NOT NULL
		GROUP BY p.OrderId
		)
		,Outstanding
	AS (
		SELECT ao.OrderId
			,ao.InvoiceValue
			,ao.DeliveryDate
			,ao.ApprovedDate
			,ao.InvoiceValue - ISNULL(po.Paid, 0) AS Balance
		FROM ApprovedOrders ao
		LEFT JOIN PaidPerOrder po ON po.OrderId = ao.OrderId
		WHERE ao.InvoiceValue - ISNULL(po.Paid, 0) > 0
		)
	SELECT (
			SELECT ISNULL(SUM(CAST(p.ReceivedAmount AS DECIMAL(18, 2))), 0)
			FROM dbo.Payments p WITH (NOLOCK)
			WHERE p.TenantId = @TenantId
				AND p.IsDeleted = 0
				AND p.PaymentStatus = 1
				AND CAST(p.ReceivedDate AS DATE) = @Today
			) AS TodayCollection
		,(
			SELECT ISNULL(SUM(CAST(p.ReceivedAmount AS DECIMAL(18, 2))), 0)
			FROM dbo.Payments p WITH (NOLOCK)
			WHERE p.TenantId = @TenantId
				AND p.IsDeleted = 0
				AND p.PaymentStatus = 1
				AND CAST(p.ReceivedDate AS DATE) BETWEEN @MonthStart
					AND @MonthEnd
			) AS MTDCollection
		,ISNULL(SUM(o.Balance), 0) AS TotalOutstanding
		,ISNULL(SUM(CASE 
					WHEN DATEDIFF(DAY, o.ApprovedDate, @Today) > 30
						THEN o.Balance
					ELSE 0
					END), 0) AS OverdueOutstanding
		,ISNULL(SUM(CASE 
					WHEN o.DeliveryDate IS NOT NULL
						AND o.DeliveryDate >= @Today
						AND o.DeliveryDate < DATEADD(DAY, 7, @Today)
						THEN o.Balance
					ELSE 0
					END), 0) AS DueNext7Days
		,ISNULL(SUM(CASE 
					WHEN DATEDIFF(DAY, o.ApprovedDate, @Today) <= 30
						THEN o.Balance
					ELSE 0
					END), 0) AS Aging0To30
		,ISNULL(SUM(CASE 
					WHEN DATEDIFF(DAY, o.ApprovedDate, @Today) BETWEEN 31
							AND 60
						THEN o.Balance
					ELSE 0
					END), 0) AS Aging31To60
		,ISNULL(SUM(CASE 
					WHEN DATEDIFF(DAY, o.ApprovedDate, @Today) BETWEEN 61
							AND 90
						THEN o.Balance
					ELSE 0
					END), 0) AS Aging61To90
		,ISNULL(SUM(CASE 
					WHEN DATEDIFF(DAY, o.ApprovedDate, @Today) > 90
						THEN o.Balance
					ELSE 0
					END), 0) AS Aging90Plus
	FROM Outstanding o
	JOIN dbo.Orders ao WITH (NOLOCK) ON ao.OrderId = o.OrderId;
END;

GO

