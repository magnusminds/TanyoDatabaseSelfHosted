-- =============================================================================
-- SP Name   : OwnerDashboardPipeline
-- Module    : Owner Dashboard - Pipeline ("Lead to Order Funnel")
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : Funnel stage counts + stage-wise conversions for the period.
--
-- KPI Logic:
--   NewLeads        = Leads created in period.
--   WalkIns         = CustomerVisits in period.
--   QuotationsGiven = Orders created in period with Status >= 1 (quote issued).
--   OrdersWon       = Orders won in period (Status >= 2, excl. Canceled/Declined).
--   LeadToWalkInPct = WalkIns / NewLeads * 100.
--   WalkInToQuotePct= QuotationsGiven / WalkIns * 100.
--   QuoteConversionPct = OrdersWon / QuotationsGiven * 100.
--   LeadConversionPct  = OrdersWon / NewLeads * 100 (end-to-end).
-- =============================================================================

CREATE   PROCEDURE [dbo].[OwnerDashboardPipeline]
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

    ;WITH Funnel AS
    (
        SELECT (
			SELECT Count(1)
			FROM dbo.Leads l WITH (NOLOCK)
			WHERE l.TenantId = @TenantId
				AND l.STATUS <> 6
				AND l.CreatedDate BETWEEN @MonthStart AND @MonthEnd
			) AS NewLeads
		,(
			SELECT Count(1)
			FROM dbo.CustomerVisits cv WITH (NOLOCK)
			INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = cv.CustomerId
				AND c.IsDeleted = 0
			WHERE c.TenantId = @TenantId
				AND cv.CreatedDate BETWEEN @MonthStart AND @MonthEnd
			) AS WalkIns
		,(
			SELECT Count(1)
			FROM dbo.Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 1
				AND o.CreatedDate BETWEEN @MonthStart AND @MonthEnd
			) AS QuotationsGiven
		,(
			SELECT Count(1)
			FROM dbo.Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 2 AND o.Status NOT IN (6, 8)
				AND o.ApprovedDate BETWEEN @MonthStart AND @MonthEnd
			) AS OrdersWon
    )
    SELECT
        f.NewLeads,
        f.WalkIns,
        f.QuotationsGiven,
        f.OrdersWon,
        CASE WHEN f.NewLeads > 0 THEN (f.OrdersWon * 100.0) / f.NewLeads ELSE 0 END          AS LeadConversionPct,
        CASE WHEN f.QuotationsGiven > 0 THEN (f.OrdersWon * 100.0) / f.QuotationsGiven ELSE 0 END
                                                                                             AS QuoteConversionPct,
        CASE WHEN f.NewLeads > 0 THEN (f.WalkIns * 100.0) / f.NewLeads ELSE 0 END            AS LeadToWalkInPct,
        CASE WHEN f.WalkIns > 0 THEN (f.QuotationsGiven * 100.0) / f.WalkIns ELSE 0 END      AS WalkInToQuotePct
    FROM Funnel f;

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

