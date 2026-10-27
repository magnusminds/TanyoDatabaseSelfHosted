-- =============================================================================
-- SP Name   : OwnerDashboardDealerTarget
-- Module    : Owner Dashboard - Dealer Targets ("Who Is Hitting Their Target?")
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : One row per dealer (CustomerTypeId = 4) with a monthly target
--             set (Customers.MonthlyTarget > 0):
--               DealerId, DealerName, MonthlyTarget, AchievedAmount, AchievementPct
--
-- KPI Logic (documented for owner's team):
--   MonthlyTarget  = single value stored on the dealer's Customers row
--                    (applies to every month; no per-month history).
--   AchievedAmount = SUM(Orders.AmountBeforeGST) of the dealer's OWN approved
--                    orders (Status >= 2, excl. 6 Cancelled / 8 Lost) with an
--                    ApprovedDate inside the selected month; 0 when none.
--                    Orders merely referred by the dealer are NOT counted.
--   AchievementPct = Achieved / Target * 100 (0 when target is 0).
--   Ordered by AchievedAmount DESC (the top-10 display cap is applied in BL).
-- =============================================================================

CREATE  PROCEDURE [dbo].[OwnerDashboardDealerTarget]
    @TenantId INT,
    @Month    INT,
    @Year     INT
WITH ENCRYPTION
AS
BEGIN
    BEGIN TRY
        SET NOCOUNT ON;

        DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
        DECLARE @MonthEnd   DATE = EOMONTH(@MonthStart);

        SELECT
            c.CustomerId                                                              AS DealerId,
            ISNULL(NULLIF(LTRIM(RTRIM(c.FirstName + ISNULL(' ' + c.LastName, ''))), ''), 'Dealer') AS DealerName,
            ISNULL(c.MonthlyTarget, 0)                                   AS MonthlyTarget,
            ISNULL(o.AchievedAmount, 0)                                               AS AchievedAmount,
            CASE WHEN CAST(c.MonthlyTarget AS DECIMAL(18, 2)) > 0
                 THEN (ISNULL(o.AchievedAmount, 0) * 100.0) / CAST(c.MonthlyTarget AS DECIMAL(18, 2))
                 ELSE 0 END                                                           AS AchievementPct
        FROM dbo.Customers c WITH (NOLOCK)
        OUTER APPLY
        (
            SELECT SUM(CAST(od.AmountBeforeGST AS DECIMAL(18, 2))) AS AchievedAmount
            FROM dbo.Orders od WITH (NOLOCK)
            WHERE od.CustomerID = c.CustomerId
              AND od.TenantId = @TenantId
              AND od.IsArchive = 0
              AND od.Status >= 2 AND od.Status NOT IN (6, 8)   -- Won (Approved, InProgress, Completed, Delivered, MaterialReceive)
              AND CAST(od.ApprovedDate AS DATE) BETWEEN @MonthStart AND @MonthEnd
        ) o
        WHERE c.TenantId = @TenantId
          AND c.IsDeleted = 0
          AND c.CustomerTypeId = 4                          -- CustomerTypeEnum.Dealer
          AND c.MonthlyTarget > 0
        ORDER BY ISNULL(o.AchievedAmount, 0) DESC, c.FirstName;
    END TRY

    BEGIN CATCH
        IF @@TRANCOUNT > 0 
        ROLLBACK;

        DECLARE @ObjectName VARCHAR(500), @ErrorMsg NVARCHAR(4000);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName, @ErrorMsg = @ErrorMsg;
        THROW;
    END CATCH

END;

GO

