/*
	EXEC [dbo].[ReportAttendanceSummary]
		@UserID = 3243
		,@StartDate = '2024-05-01'
		,@EndDate = '2024-05-31'
		,@TenantID = 7
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE PROC [dbo].[ReportAttendanceSummary]
(
	@UserID BIGINT = NULL
	,@StartDate DATE
	,@EndDate DATE
	,@TenantID INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;


	BEGIN TRY
	WITH ListDates(AllDates) AS 
	(   
		SELECT @StartDate AS DATE
		UNION ALL
		SELECT DATEADD(DAY, 1, AllDates)
		FROM ListDates 
		WHERE AllDates < @EndDate
	), cteTotalDays AS (
		SELECT SUM(IIF(DATEPART(DW, AllDates) NOT IN (1,7), 1, 0)) AS TotalWorkingDays
			,SUM(IIF(DATEPART(DW, AllDates) IN (1,7), 1, 0)) AS TotalNonWorkingDays
			,COUNT(AllDates) AS TotalDays
		FROM ListDates
	), cteHolidays AS (
		SELECT COUNT(HolidayID) AS TotalHolidays
		FROM Holidays WITH (NOLOCK)
		WHERE Date BETWEEN @StartDate AND @EndDate
		AND IsActive = 1
		AND TenantId = @TenantID
	), cteTotalLeaves AS (
		SELECT la.UserID
			,SUM(IIF(lad.LeaveType = 1, 1, 0.5)) AS TotalDays
		FROM LeaveApplicationDetails lad WITH (NOLOCK)
		INNER JOIN LeaveApplications la WITH (NOLOCK) ON la.LeaveApplicationID = lad.LeaveApplicationID
		INNER JOIN UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = la.UserID
		WHERE lad.LeaveDate BETWEEN @StartDate AND @EndDate
		AND la.Status = 2
		AND utm.TenantId = @TenantID
		AND lad.LeaveType IN (1,2,3)
		GROUP BY la.UserID
	)
	SELECT au.UserId
		,au.FirstName + ' ' + au.LastName AS UserName
		,dbo.MinutesToDuration(SUM(IIF(a.Type = 0, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0))) AS [TotalHours]
		,dbo.MinutesToDuration(SUM(IIF(a.Type = 1, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0))) AS [TotalBreak]
		,dbo.MinutesToDuration(SUM(IIF(a.Type = 0, DATEDIFF(MINUTE,a.StartDate,a.EndDate), 0)) - SUM(IIF(a.Type = 1, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0))) AS [ActualHours]
		,SUM(IIF(a.Type = 0, 1 , 0)) AS [TotalPunchInOut]
		,SUM(IIF(a.Type = 1, 1 , 0)) AS [TotalBreakInOut]
		,MIN(d.TotalWorkingDays) - MIN(h.TotalHolidays) - ISNULL(SUM(DISTINCT l.TotalDays), 0) AS TotalWorkingDays
		,CAST(CAST(((SUM(IIF(a.Type = 0, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0)) - SUM(IIF(a.Type = 1, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0))) / 60) / 8.0 AS NUMERIC(18, 2)) AS VARCHAR(50)) AS [ActualWorkingDays]
		--,dbo.MinutesToDuration((SUM(IIF(a.Type = 0, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0)) - SUM(IIF(a.Type = 1, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0))) / 8) AS [ActualWorkingDays]
		,ISNULL(SUM(DISTINCT l.TotalDays), 0) AS TotalLeaves
		,MIN(h.TotalHolidays) AS TotalHolidays
		,MIN(d.TotalNonWorkingDays) AS TotalNonWorkingDays
		,MIN(d.TotalDays) AS TotalDays
        ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM AspNetUsers au WITH (NOLOCK)
	INNER JOIN UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = au.UserId
	LEFT JOIN Attendance a WITH (NOLOCK) ON a.UserId = au.UserId
		AND CAST(a.StartDate AS DATE) >= @StartDate
		AND CAST(a.EndDate AS DATE) <= @EndDate
	LEFT JOIN cteTotalLeaves l ON l.UserID = au.UserId
	CROSS JOIN cteHolidays h
	CROSS JOIN cteTotalDays d
	WHERE utm.TenantId = @TenantID
	AND (@UserID IS NULL OR au.UserId = @UserID)
	GROUP BY au.UserId, au.FirstName + ' ' + au.LastName
	ORDER BY [UserName]
	OFFSET(@PageIndex - 1) * @PageSize ROWS
	FETCH NEXT @PageSize ROWS ONLY;

	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

