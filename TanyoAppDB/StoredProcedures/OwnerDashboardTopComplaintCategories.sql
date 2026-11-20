-- =============================================================================
-- SP Name   : OwnerDashboardTopComplaintCategories
-- Module    : Owner Dashboard - Customer (Top Complaint Categories)
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : Ranked complaint list for the period.
--
-- KPI Logic:
--   NOTE: The Complains table has no dedicated "Category" column in Phase 1.
--         Complaints are grouped by their Title as the closest available
--         category proxy. Top 5 returned. When a category field is added to
--         the complaint module later, replace cp.Title with cp.Category.
-- =============================================================================

CREATE   PROCEDURE [dbo].[OwnerDashboardTopComplaintCategories]
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

    SELECT TOP 5
        cp.Title AS CategoryName
        ,Count(1) AS ComplaintCount
    FROM dbo.Complains cp WITH (NOLOCK)
    WHERE cp.TenantId = @TenantId
    AND cp.Status <> 4 -- exclude Deleted
    AND cp.CreatedDate >= @MonthStart
    AND cp.CreatedDate <= @MonthEnd
    GROUP BY cp.Title
    ORDER BY ComplaintCount DESC;

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

