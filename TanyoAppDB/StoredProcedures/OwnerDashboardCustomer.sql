-- =============================================================================
-- SP Name   : OwnerDashboardCustomer
-- Module    : Owner Dashboard - Customer ("Are They Coming Back?")
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : Leads / walk-ins / quotations / orders won, conversion rates,
--             repeat ratio, customer type breakup and open complaints.
--
-- KPI Logic:
--   NewLeads            = Leads created in period (excl. deleted).
--   WalkIns             = CustomerVisits in period (tenant via Customers join).
--   QuotationsGiven     = Orders CREATED in period with Status >= 1
--                         (formal quote/proposal issued; Inquiry-only records
--                         excluded). Approved+ orders are a subset of these.
--   OrdersWon           = Orders won in period (Status >= 2, excl. Canceled/Declined).
--   LeadConversionPct   = OrdersWon / NewLeads * 100.
--   QuoteConversionPct  = OrdersWon / QuotationsGiven * 100.
--   RepeatCustomerPct   = Repeat orders (customer's 2nd+ approved order at the
--                         time of the order) / total approved orders * 100.
--   NewCustomers        = Distinct customers whose FIRST EVER approved order
--                         falls in the period.
--   RepeatCustomers     = Distinct customers with an order in period AND more
--                         than one approved order ever.
--   ReferralCustomers   = Distinct customers in period whose order has
--                         RefferedBy set.
--   OpenComplaints      = Complaints Status IN (1 Open, 2 InProgress).
-- =============================================================================

CREATE   PROCEDURE [dbo].[OwnerDashboardCustomer]
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

    ;WITH LeadData AS
    (
        SELECT COUNT(l.LeadId) AS NewLeads
        FROM dbo.Leads l WITH (NOLOCK)
        WHERE l.TenantId = @TenantId
          AND l.Status <> 6
          AND l.CreatedDate BETWEEN @MonthStart AND @MonthEnd
    ),
    VisitData AS
    (
        SELECT COUNT(cv.CustomerVisitId) AS WalkIns
        FROM dbo.CustomerVisits cv WITH (NOLOCK)
        INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = cv.CustomerId
            AND c.IsDeleted = 0
        WHERE c.TenantId = @TenantId
          AND cv.CreatedDate BETWEEN @MonthStart AND @MonthEnd
    ),
    QuoteData AS
    (
        SELECT COUNT(o.OrderId) AS QuotationsGiven
        FROM dbo.Orders o WITH (NOLOCK)
        WHERE o.TenantId = @TenantId
          AND o.IsArchive = 0
          AND o.Status >= 1                                             -- quote issued+
          AND o.CreatedDate BETWEEN @MonthStart AND @MonthEnd
    ),
    WonData AS
    (
        SELECT COUNT(o.OrderId) AS OrdersWon
        FROM dbo.Orders o WITH (NOLOCK)
        WHERE o.TenantId = @TenantId
          AND o.IsArchive = 0
          AND o.Status >= 2 AND o.Status NOT IN (6, 8)        -- Won
          AND o.ApprovedDate IS NOT NULL
          AND o.ApprovedDate BETWEEN @MonthStart AND @MonthEnd
    ),
    AllApproved AS
    (
        SELECT o.OrderId, o.CustomerID, o.RefferedBy,
               CAST(o.ApprovedDate AS DATE)                              AS ApprovedOrderDate,
               ROW_NUMBER() OVER (PARTITION BY o.CustomerID ORDER BY o.ApprovedDate, o.OrderId) AS OrderSeq
        FROM dbo.Orders o WITH (NOLOCK)
        WHERE o.TenantId = @TenantId
          AND o.IsArchive = 0
          AND o.Status >= 2 AND o.Status NOT IN (6, 8)
          AND o.ApprovedDate IS NOT NULL
    ),
    RepeatData AS
    (
        SELECT
            COUNT(CASE WHEN aa.OrderSeq > 1 THEN 1 END)                AS RepeatOrders,
            Count(1)                                                   AS TotalPeriodOrders
        FROM AllApproved aa
        WHERE aa.ApprovedOrderDate BETWEEN @MonthStart AND @MonthEnd
    ),
    CustomerBreakup AS
    (
        SELECT
            (SELECT COUNT(DISTINCT firstOrd.CustomerID)
             FROM (SELECT CustomerID, MIN(CAST(ApprovedDate AS DATE)) AS FirstOrderDate
                   FROM dbo.Orders WITH (NOLOCK)
                    WHERE TenantId = @TenantId AND IsArchive = 0 AND Status >= 2 AND Status NOT IN (6, 8) AND ApprovedDate IS NOT NULL
                   GROUP BY CustomerID) firstOrd
             WHERE firstOrd.FirstOrderDate BETWEEN CAST(@MonthStart AS DATE) AND @MonthEnd)
                                                                         AS NewCustomers,
            (SELECT COUNT(DISTINCT aa.CustomerID)
             FROM AllApproved aa
             WHERE CAST(aa.ApprovedOrderDate AS DATE) BETWEEN CAST(@MonthStart AS DATE) AND @MonthEnd
               AND aa.OrderSeq > 1)                                      AS RepeatCustomers,
            (SELECT COUNT(DISTINCT aa.CustomerID)
             FROM AllApproved aa
             WHERE CAST(aa.ApprovedOrderDate AS DATE) BETWEEN CAST(@MonthStart AS DATE) AND @MonthEnd
               AND aa.RefferedBy IS NOT NULL)                            AS ReferralCustomers
    )
    SELECT
        ld.NewLeads,
        vd.WalkIns,
        ISNULL(q.QuotationsGiven, 0)                                                AS QuotationsGiven,
        ISNULL(w.OrdersWon, 0)                                                      AS OrdersWon,
        CASE WHEN ld.NewLeads > 0 THEN (ISNULL(w.OrdersWon, 0) * 100.0) / ld.NewLeads ELSE 0 END
                                                                                    AS LeadConversionPct,
        CASE WHEN ISNULL(q.QuotationsGiven, 0) > 0
             THEN (ISNULL(w.OrdersWon, 0) * 100.0) / q.QuotationsGiven ELSE 0 END
                                                                                    AS QuotationConversionPct,
        CASE WHEN ISNULL(r.TotalPeriodOrders, 0) > 0
             THEN (ISNULL(r.RepeatOrders, 0) * 100.0) / r.TotalPeriodOrders ELSE 0 END
                                                                                    AS RepeatCustomerPct,
        cb.NewCustomers,
        cb.RepeatCustomers,
        cb.ReferralCustomers,
        (SELECT Count(1) FROM dbo.Complains cp WITH (NOLOCK)
         WHERE cp.TenantId = @TenantId AND cp.Status IN (1, 2))                     AS OpenComplaints,
        (SELECT COUNT(DISTINCT fl.LeadId)
         FROM dbo.FollowUpLeads fl WITH (NOLOCK)
         JOIN dbo.Leads l WITH (NOLOCK) ON l.LeadId = fl.LeadId
         WHERE l.TenantId = @TenantId AND l.Status NOT IN (4, 5, 6)
           AND fl.FollowUpDate IS NOT NULL AND fl.FollowUpDate <= GETDATE()) AS PendingFollowUps
    FROM LeadData ld
    CROSS JOIN VisitData vd
    LEFT JOIN QuoteData q ON 1 = 1
    LEFT JOIN WonData w ON 1 = 1
    CROSS JOIN RepeatData r
    CROSS JOIN CustomerBreakup cb;

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

