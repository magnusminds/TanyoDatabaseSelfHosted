-- =============================================================================
-- SP Name   : OwnerDashboardPeople
-- Module    : Owner Dashboard - People ("Is My Team Productive?")
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : One row per sales rep: target, achievement, orders, collection,
--             conversion, attendance % and pending follow-ups.
--
-- KPI Logic:
--   Rep universe  = Active tenant users who are NOT manufacturing roles
--                   (Contractor/StoreManager/Supervisor role names excluded,
--                   mirroring UserBL.salesmandropdown()).
--   MonthlyTarget = SalesTargets row for rep + month (0 when unset).
--   Achieved      = SUM(AmountBeforeGST) of approved orders (period).
--   Collection    = SUM(approved Payments) on that rep's orders (MTD).
--   LeadConversion= Rep approved orders / rep new leads * 100.
--   AttendancePct = Distinct punch-in days / working days elapsed so far
--                   (full month when viewing a past month), capped at 100.
--   PendingFollowUps = Open leads of the rep with a follow-up due on/before
--                      today (lead status not Disqualified/Closed/Deleted).
-- =============================================================================
CREATE PROCEDURE [dbo].[OwnerDashboardPeople] 
	 @TenantId INT
	,@Month INT
	,@Year INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @MonthStart DATETIME = DATEFROMPARTS(@Year, @Month, 1);
		DECLARE @MonthEnd DATETIME = EOMONTH(@MonthStart);
		DECLARE @Today DATE = CAST(GETDATE() AS DATE);
		DECLARE @RangeEnd DATE = CASE 
				WHEN @Year < YEAR(@Today)
					OR (
						@Year = YEAR(@Today)
						AND @Month < MONTH(@Today)
						)
					THEN CAST(@MonthEnd AS DATE)
				WHEN @Year = YEAR(@Today)
					AND @Month = MONTH(@Today)
					THEN @Today
				ELSE @Today -- future months: 0 via CASE below
				END;
		-- Working days = weekdays (Mon-Fri) only, excludes weekends
		DECLARE @WorkingDays INT = CASE 
				WHEN @Year > YEAR(@Today)
					OR (
						@Year = YEAR(@Today)
						AND @Month > MONTH(@Today)
						)
					THEN 0
				ELSE (
						SELECT COUNT(*)
						FROM (
							SELECT TOP (DATEDIFF(DAY, @MonthStart, @RangeEnd) + 1) DATEADD(DAY, ROW_NUMBER() OVER (
										ORDER BY (
												SELECT NULL
												)
										) - 1, @MonthStart) AS d
							FROM sys.objects
							) days
						WHERE DATEPART(WEEKDAY, days.d) NOT IN (
								1
								,7
								)
						)
				END;

		WITH Reps
		AS (
			SELECT u.UserId
				,u.FirstName + ' ' + u.LastName AS RepName
			FROM dbo.AspNetUsers u WITH (NOLOCK)
			INNER JOIN dbo.UserTenantMapping utm WITH (NOLOCK) ON utm.UserID = u.UserId
			INNER JOIN dbo.AspNetUserRoles ur WITH (NOLOCK) ON ur.UserId = u.Id
			INNER JOIN dbo.AspNetRoles ar WITH (NOLOCK) ON ar.Id = ur.RoleId
			WHERE utm.TenantId = @TenantId
				AND u.IsActive = 1
				AND u.IsDeleted = 0
				AND REPLACE(ar.Name, '_' + CAST(@TenantId AS VARCHAR(10)), '') NOT IN (
					'Contractor'
					,'StoreManager'
					,'Supervisor'
					)
			)
			,SalesPerRep
		AS (
			SELECT o.SalesmanId
				,SUM(o.AmountBeforeGST) AS AchievedAmount
				,COUNT(o.OrderId) AS OrderCount
			FROM dbo.Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 2
				AND o.Status NOT IN (
					6
					,8
					)
				AND o.ApprovedDate IS NOT NULL
				AND o.ApprovedDate BETWEEN @MonthStart
					AND @MonthEnd
			GROUP BY o.SalesmanId
			)
			,CollectionPerRep
		AS (
			SELECT o.SalesmanId
				,SUM(p.ReceivedAmount) AS CollectionAmount
			FROM dbo.Payments p WITH (NOLOCK)
			INNER JOIN dbo.Orders o WITH (NOLOCK) ON o.OrderId = p.OrderId
			WHERE p.TenantId = @TenantId
				AND p.IsDeleted = 0
				AND p.PaymentStatus = 1
				AND o.SalesmanId IS NOT NULL
				AND YEAR(p.ReceivedDate) = @Year
				AND MONTH(p.ReceivedDate) = @Month
			GROUP BY o.SalesmanId
			)
			,LeadsPerRep
		AS (
			SELECT l.SalesmanId
				,COUNT(l.LeadId) AS NewLeadsCount
			FROM dbo.Leads l WITH (NOLOCK)
			WHERE l.TenantId = @TenantId
				AND l.Status <> 6
				AND l.SalesmanId IS NOT NULL
				AND l.CreatedDate BETWEEN @MonthStart
					AND @MonthEnd
			GROUP BY l.SalesmanId
			)
			,AttendancePerRep
		AS (
			SELECT a.UserId
				,COUNT(DISTINCT CAST(a.StartDate AS DATE)) AS PresentDays
			FROM dbo.Attendance a WITH (NOLOCK)
			WHERE a.Type = 0 -- Punching (not Break)
				AND CAST(a.StartDate AS DATE) = @Today
			GROUP BY a.UserId
			)
			,FollowUpsPerRep
		AS (
			SELECT l.SalesmanId
				,COUNT(DISTINCT fl.LeadId) AS PendingFollowUps
			FROM dbo.FollowUpLeads fl WITH (NOLOCK)
			INNER JOIN dbo.Leads l WITH (NOLOCK) ON l.LeadId = fl.LeadId
			WHERE l.TenantId = @TenantId
				AND l.Status NOT IN (
					4
					,5
					,6
					) -- not Disqualified/Closed/Deleted
				AND l.SalesmanId IS NOT NULL
				AND fl.FollowUpDate IS NOT NULL
				AND fl.FollowUpDate <= @Today
			GROUP BY l.SalesmanId
			)
			,TargetPerRep
		AS (
			SELECT u.UserId
				,ISNULL(u.SalesTarget, 0) AS MonthlyTarget
			FROM dbo.AspNetUsers u WITH (NOLOCK)
			JOIN dbo.UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = u.UserId
			WHERE utm.TenantId = @TenantId
				AND utm.IsDeleted = 0
				AND u.IsActive = 1
				AND u.IsDeleted = 0
			)
		SELECT rp.UserId
			,rp.RepName
			,ISNULL(t.MonthlyTarget, 0) AS MonthlyTarget
			,ISNULL(s.AchievedAmount, 0) AS AchievedAmount
			,CASE 
				WHEN ISNULL(t.MonthlyTarget, 0) > 0
					THEN (ISNULL(s.AchievedAmount, 0) * 100.0) / t.MonthlyTarget
				ELSE 0
				END AS AchievementPct
			,ISNULL(s.OrderCount, 0) AS OrderCount
			,ISNULL(c.CollectionAmount, 0) AS CollectionAmount
			,ISNULL(ld.NewLeadsCount, 0) AS NewLeadsCount
			,CASE 
				WHEN ISNULL(ld.NewLeadsCount, 0) > 0
					THEN (ISNULL(s.OrderCount, 0) * 100.0) / ld.NewLeadsCount
				ELSE 0
				END AS LeadConversionPct
			,CASE 
				WHEN @WorkingDays > 0
					THEN CASE 
							WHEN (ISNULL(at.PresentDays, 0) * 100.0) / @WorkingDays > 100
								THEN 100
							ELSE (ISNULL(at.PresentDays, 0) * 100.0) / @WorkingDays
							END
				ELSE 0
				END AS AttendancePct
			,ISNULL(fu.PendingFollowUps, 0) AS PendingFollowUps
		FROM Reps rp
		LEFT JOIN TargetPerRep t ON t.UserId = rp.UserId
		LEFT JOIN SalesPerRep s ON s.SalesmanId = rp.UserId
		LEFT JOIN CollectionPerRep c ON c.SalesmanId = rp.UserId
		LEFT JOIN LeadsPerRep ld ON ld.SalesmanId = rp.UserId
		LEFT JOIN AttendancePerRep at ON at.UserId = rp.UserId
		LEFT JOIN FollowUpsPerRep fu ON fu.SalesmanId = rp.UserId
		ORDER BY ISNULL(s.AchievedAmount, 0) DESC;
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

