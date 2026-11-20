/*
	EXEC [dbo].[ReportAttendanceDetail] 
		@UserID  = NULL,       
		@TenantId  = 2,            
		@StartDate   = '2025-08-27',
		@EndDate   = '2025-09-01',
		@PageIndex  = 1,
		@PageSize  = 50
*/
CREATE   PROCEDURE [dbo].[ReportAttendanceDetail] (
	@UserID BIGINT = NULL
	,@TenantId BIGINT
	,@StartDate DATE
	,@EndDate DATE
	,@PageIndex INT = 1
	,@PageSize INT = 50
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF @UserID = ''
	BEGIN
		SET @UserID = NULL
	END

	IF OBJECT_ID('tempdb..#Tmp_Attendance') IS NOT NULL
		DROP TABLE #Tmp_Attendance;

	IF OBJECT_ID('tempdb..#Users') IS NOT NULL
		DROP TABLE #Users;

	CREATE TABLE #Users (
		UserId BIGINT PRIMARY KEY
		,UserName VARCHAR(200)
		);

	INSERT INTO #Users (
		UserId
		,UserName
		)
	SELECT U.UserID
		,U.FirstName + ' ' + U.LastName
	FROM AspNetUsers U WITH (NOLOCK)
	INNER JOIN UserTenantMapping UTM WITH (NOLOCK) ON U.UserID = UTM.UserId
		AND UTM.TenantId = @TenantId
	WHERE (
			@UserID IS NULL
			OR U.UserID = @UserID
			);

	CREATE TABLE #Tmp_Attendance (
		AttendanceId BIGINT PRIMARY KEY
		,UserId BIGINT
		,StartDate DATETIME
		,EndDate DATETIME
		,Type BIT
		,CreatedDate DATETIME
		,InLatitude VARCHAR(100)
		,InLongitude VARCHAR(100)
		,OutLatitude VARCHAR(100)
		,OutLongitude VARCHAR(100)
		);

	DECLARE @StartDateTime DATETIME = DATEADD(MILLISECOND, 1, CAST(@StartDate AS DATETIME));
	DECLARE @EndDateTime DATETIME = DATEADD(MILLISECOND, - 3, DATEADD(DAY, 1, CAST(@EndDate AS DATETIME)));

	INSERT INTO #Tmp_Attendance
	SELECT ATD.AttendanceId
		,ATD.UserId
		,ATD.StartDate
		,ATD.EndDate
		,ATD.Type
		,ATD.CreatedDate
		,ATD.InLatitude
		,ATD.InLongitude
		,ATD.OutLatitude
		,ATD.OutLongitude
	FROM Attendance ATD WITH (NOLOCK)
	INNER JOIN #Users U ON ATD.UserId = U.UserId
	WHERE ATD.CreatedDate BETWEEN @StartDateTime
			AND @EndDateTime;;

	WITH ListDates
	AS (
		SELECT @StartDate AS AllDates
		
		UNION ALL
		
		SELECT DATEADD(DAY, 1, AllDates)
		FROM ListDates
		WHERE AllDates < @EndDate
		)
		,Calc
	AS (
		SELECT A.UserId
			,CAST(A.CreatedDate AS DATE) AS [Date]
			,SUM(IIF(A.Type = 0, DATEDIFF(MINUTE, A.StartDate, A.EndDate), 0)) AS TotalHours
			,SUM(IIF(A.Type = 1, DATEDIFF(MINUTE, A.StartDate, A.EndDate), 0)) AS TotalBreak
			,SUM(IIF(A.Type = 0, 1, 0)) AS TotalPunchInOut
			,SUM(IIF(A.Type = 1, 1, 0)) AS TotalBreakInOut
			,(
				SELECT TOP 1 StartDate
				FROM #Tmp_Attendance
				WHERE UserId = A.UserId
					AND CAST(CreatedDate AS DATE) = CAST(A.CreatedDate AS DATE)
				ORDER BY AttendanceId ASC
				) AS StartTime
			,(
				SELECT TOP 1 EndDate
				FROM #Tmp_Attendance
				WHERE UserId = A.UserId
					AND Type = 0
					AND CAST(CreatedDate AS DATE) = CAST(A.CreatedDate AS DATE)
				ORDER BY AttendanceId DESC
				) AS EndTime
			,(
				SELECT TOP 1 InLatitude
				FROM #Tmp_Attendance
				WHERE UserId = A.UserId
					AND CAST(CreatedDate AS DATE) = CAST(A.CreatedDate AS DATE)
				ORDER BY AttendanceId ASC
				) AS InLatitude
			,(
				SELECT TOP 1 InLongitude
				FROM #Tmp_Attendance
				WHERE UserId = A.UserId
					AND Type = 0
					AND CAST(CreatedDate AS DATE) = CAST(A.CreatedDate AS DATE)
				ORDER BY AttendanceId ASC
				) AS InLongitude
			,(
				SELECT TOP 1 OutLatitude
				FROM #Tmp_Attendance
				WHERE UserId = A.UserId
					AND CAST(CreatedDate AS DATE) = CAST(A.CreatedDate AS DATE)
				ORDER BY AttendanceId DESC
				) AS OutLatitude
			,(
				SELECT TOP 1 OutLongitude
				FROM #Tmp_Attendance
				WHERE UserId = A.UserId
					AND Type = 0
					AND CAST(CreatedDate AS DATE) = CAST(A.CreatedDate AS DATE)
				ORDER BY AttendanceId DESC
				) AS OutLongitude
		FROM #Tmp_Attendance A
		GROUP BY A.UserId
			,CAST(A.CreatedDate AS DATE)
		)
	SELECT U.UserId
		,U.UserName
		,LD.AllDates AS [Date]
		,C.StartTime
		,C.EndTime
		,ISNULL(C.InLatitude, '') AS InLatitude
		,ISNULL(C.InLongitude, '') AS InLongitude
		,ISNULL(C.OutLatitude, '') AS OutLatitude
		,ISNULL(C.OutLongitude, '') AS OutLongitude
		,ISNULL(C.TotalPunchInOut, 0) AS TotalPunchInOut
		,ISNULL(C.TotalBreakInOut, 0) AS TotalBreakInOut
		,ISNULL(dbo.MinutesToDuration(C.TotalHours), 'NA') AS TotalHours
		,ISNULL(dbo.MinutesToDuration(C.TotalBreak), 'NA') AS TotalBreak
		,ISNULL(dbo.MinutesToDuration(C.TotalHours - C.TotalBreak), 'NA') AS ActualHours
		,COUNT(*) OVER () AS TotalCount
		,LD.AllDates
	FROM #Users U
	CROSS JOIN ListDates LD
	LEFT JOIN Calc C ON C.UserId = U.UserId
		AND C.DATE = LD.AllDates
	ORDER BY U.UserName
		,LD.AllDates DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY
	OPTION (MAXRECURSION 0);

	DROP TABLE #Tmp_Attendance;

	DROP TABLE #Users;

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

