/*
    EXEC [dbo].[GetFollowUpLeadsHammer] @Now = GETDATE(), @ReleaseDate = '2026-11-18'

    Auto hammer follow-up reminders for open inquiries created on or after @ReleaseDate.
    First reminder 24 hours after lead creation, then every 15 minutes until the salesman
    adds a follow-up with a comment. Reminders to the salesman are limited by the tenant's
    FollowUpLeadsAutoReminderTimes (0 = unlimited); every 4th reminder also goes to the
    salesman's reporting manager. Fires only inside the tenant's working-time window
    (OrganizationTimings) for the current IST weekday.

    ReminderTarget: 1 = salesman, 2 = manager.
*/
CREATE OR ALTER PROCEDURE [dbo].[GetFollowUpLeadsHammer]
    @Now DATETIME2 = NULL,
    @ReleaseDate DATE = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
    IF @Now IS NULL SET @Now = GETDATE();
    IF @ReleaseDate IS NULL SET @ReleaseDate = '2026-11-18'; -- change at deployment if needed

    DECLARE @IstNow DATETIME2 = DATEADD(MINUTE, 330, @Now);        -- UTC -> IST (server stores UTC)
    DECLARE @IstDate DATE = CAST(@IstNow AS DATE);
    DECLARE @IstWeekDay INT = ((DATEPART(WEEKDAY, @IstDate) + @@DATEFIRST - 2) % 7); -- 0 = Sunday, .NET convention

    IF OBJECT_ID('tempdb..#LeadReminderSchedule') IS NOT NULL DROP TABLE #LeadReminderSchedule;
    IF OBJECT_ID('tempdb..#TenantConfig') IS NOT NULL DROP TABLE #TenantConfig;
    IF OBJECT_ID('tempdb..#WorkingHours') IS NOT NULL DROP TABLE #WorkingHours;

    -- Per-tenant hammer cap (0 = unlimited). NOTE: FollowUpLeadsAutoReminderTimes remaining 0/no value counts as unlimited.
    SELECT TenantId, ISNULL(NULLIF(FollowUpLeadsAutoReminderTimes, 0), 2147483647) AS ReminderCap
    INTO #TenantConfig
    FROM dbo.TenantConfigurations WITH (NOLOCK);

    -- Working-hours window for this tenant on this IST weekday (only IsEnabled rows count).
    SELECT TenantId, StartTime, EndTime
    INTO #WorkingHours
    FROM dbo.OrganizationTimings WITH (NOLOCK)
    WHERE IsEnabled = 1
      AND DayOfWeek = @IstWeekDay;

    -- Per-lead summary: salesman, manager, reminder start (24h after creation).
    SELECT
        l.LeadId,
        l.TenantId,
        l.SalesmanId,
        ISNULL(ed.ReportingTo, 0) AS ManagerUserId,
        DATEADD(HOUR, 24, l.CreatedDate) AS ReminderStartAt
    INTO #LeadReminderSchedule
    FROM dbo.Leads l WITH (NOLOCK)
    INNER JOIN #TenantConfig tc WITH (NOLOCK) ON tc.TenantId = l.TenantId
    LEFT JOIN dbo.EmployeeDetails ed WITH (NOLOCK)
        ON ed.UserID = l.SalesmanId
    WHERE
      l.Status <> 6                     -- status 6 = Closed/Rejected; skip closed leads
      AND l.SalesmanId > 0
      AND CAST(l.CreatedDate AS DATE) >= @ReleaseDate
      AND NOT EXISTS (                      -- hammer stops once a follow-up WITH a comment exists
            SELECT 1 FROM dbo.FollowUpLeads ful WITH (NOLOCK)
            WHERE ful.LeadId = l.LeadId
              AND ful.FollowUpComment IS NOT NULL
              AND LTRIM(RTRIM(ful.FollowUpComment)) <> '');

    ;WITH ReminderSlots AS (
        SELECT
            lrs.LeadId,
            lrs.TenantId,
            lrs.SalesmanId,
            lrs.ManagerUserId,
            lrs.ReminderStartAt,
            tc.ReminderCap,
            V.N AS SalesmanReminderIndex,
            DATEADD(MINUTE, 15 * V.N, lrs.ReminderStartAt) AS SalesmanReminderAt
        FROM #LeadReminderSchedule lrs
        INNER JOIN #TenantConfig tc ON tc.TenantId = lrs.TenantId
        CROSS JOIN (
            SELECT TOP (200000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) - 1 AS N
            FROM sys.all_objects a CROSS JOIN sys.all_objects b
        ) V
        WHERE V.N < tc.ReminderCap
          -- bound the numbers set to ticks actually due (max one row per 15-min slot since start),
          -- never the full 200k envelope per lead
          AND V.N <= DATEDIFF(MINUTE, lrs.ReminderStartAt, @Now) / 15
          AND DATEADD(MINUTE, 15 * V.N, lrs.ReminderStartAt) <= @Now
    )
    SELECT
        RS.LeadId,
        CAST(NULL AS DATE)          AS FollowUpDate,
        CAST(NULL AS NVARCHAR(MAX)) AS FollowUpComment,
        SA.RegisteredFCMToken       AS RegisteredFCMToken,
        RS.TenantId,
        T.TenantName,
        RS.SalesmanId,
        SA.RegisteredFCMToken       AS SalesmanFcmToken,
        RS.ManagerUserId,
        MA.RegisteredFCMToken       AS ManagerFcmToken,
        (SELECT COUNT_BIG(*) FROM dbo.FollowUpLeads ful WITH (NOLOCK)
          WHERE ful.LeadId = RS.LeadId) AS FollowUpCount,
        RS.ReminderStartAt,
        CASE WHEN RS.SalesmanReminderIndex = 0 THEN 1 ELSE 0 END AS IsNewInquiryFirstReminder,
        RS.SalesmanReminderIndex,
        RS.SalesmanReminderAt,
        l.CreatedDate,
        l.Status                    AS LeadStatus,
        1                           AS ReminderTarget          -- 1 = salesman push
    FROM ReminderSlots RS
    INNER JOIN dbo.Leads l WITH (NOLOCK) ON l.LeadId = RS.LeadId
    INNER JOIN dbo.Tenants T WITH (NOLOCK) ON T.TenantId = RS.TenantId AND T.IsDeleted = 0
    INNER JOIN AspNetUsers SA WITH (NOLOCK) ON SA.UserId = RS.SalesmanId AND SA.IsDeleted = 0
    LEFT JOIN AspNetUsers MA WITH (NOLOCK) ON MA.UserId = RS.ManagerUserId AND MA.IsDeleted = 0
    WHERE SA.RegisteredFCMToken IS NOT NULL AND SA.RegisteredFCMToken <> ''
      -- working-hours gate: the IST time-of-day must be inside the tenant's window for today
      AND EXISTS (
            SELECT 1 FROM #WorkingHours wh
            WHERE wh.TenantId = RS.TenantId
              AND CAST(@IstNow AS TIME) >= wh.StartTime
              AND CAST(@IstNow AS TIME) <= wh.EndTime)
    UNION ALL
    -- manager escalation rows: every 4th salesman reminder (index 4, 8, 12, ...), IN ADDITION
    -- to the salesman. Manager gets them regardless of the cap; salesman rows are capped by x.
    SELECT
        RS.LeadId,
        CAST(NULL AS DATE),
        CAST(NULL AS NVARCHAR(MAX)),
        MA.RegisteredFCMToken,
        RS.TenantId,
        T.TenantName,
        RS.SalesmanId,
        SA.RegisteredFCMToken,
        RS.ManagerUserId,
        MA.RegisteredFCMToken,
        (SELECT COUNT_BIG(*) FROM dbo.FollowUpLeads ful WITH (NOLOCK)
          WHERE ful.LeadId = RS.LeadId) AS FollowUpCount,
        RS.ReminderStartAt,
        CASE WHEN RS.SalesmanReminderIndex = 0 THEN 1 ELSE 0 END,
        RS.SalesmanReminderIndex,
        RS.SalesmanReminderAt,
        l.CreatedDate,
        l.Status,
        2                           AS ReminderTarget          -- 2 = manager escalation push
    FROM ReminderSlots RS
    INNER JOIN dbo.Leads l WITH (NOLOCK) ON l.LeadId = RS.LeadId
    INNER JOIN dbo.Tenants T WITH (NOLOCK) ON T.TenantId = RS.TenantId AND T.IsDeleted = 0
    INNER JOIN AspNetUsers SA WITH (NOLOCK) ON SA.UserId = RS.SalesmanId AND SA.IsDeleted = 0
    INNER JOIN AspNetUsers MA WITH (NOLOCK) ON MA.UserId = RS.ManagerUserId AND MA.IsDeleted = 0
    WHERE RS.SalesmanReminderIndex % 4 = 3        -- every 4th reminder: 4th, 8th, 12th ... (0-based: 3, 7, 11 ...)
      AND MA.RegisteredFCMToken IS NOT NULL AND MA.RegisteredFCMToken <> ''
      AND EXISTS (
            SELECT 1 FROM #WorkingHours wh
            WHERE wh.TenantId = RS.TenantId
              AND CAST(@IstNow AS TIME) >= wh.StartTime
              AND CAST(@IstNow AS TIME) <= wh.EndTime);
    END TRY
    BEGIN CATCH
        DECLARE @ObjectName VARCHAR(500), @ErrorMsg NVARCHAR(4000);
        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();
        EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName, @ErrorMsg = @ErrorMsg;
        THROW;
    END CATCH
END
