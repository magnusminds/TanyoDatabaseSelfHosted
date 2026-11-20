/*
	EXEC [dbo].[ReportAttendanceDetailByUserID] 
		@UserID  = 4528
		,@StartDate = '2025-10-01'
		,@EndDate = '2025-10-31'
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE   PROC [dbo].[ReportAttendanceDetailByUserID] (
	@UserID BIGINT
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
	IF OBJECT_ID('tempdb..#Tmp_Attendance') IS NOT NULL
		DROP TABLE #Tmp_Attendance;

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
		)

	DECLARE @FullName VARCHAR(200)
	DECLARE @StartDateTime DATETIME = CAST(@StartDate AS VARCHAR(10)) + ' 00:00:00.001'
	DECLARE @EndDateTime DATETIME = CAST(@EndDate AS VARCHAR(10)) + ' 23:59:59.997'

	SELECT @FullName = FirstName + ' ' + LastName
	FROM dbo.AspNetUsers WITH (NOLOCK)
	WHERE UserID = @UserID

	-- If FullName is null, return only column names
	IF @FullName IS NULL
	BEGIN
		SELECT CAST(NULL AS BIGINT) AS UserId
			,CAST(NULL AS VARCHAR(200)) AS UserName
			,CAST(NULL AS DATE) AS [Date]
			,CAST(NULL AS DATETIME) AS StartTime
			,CAST(NULL AS DATETIME) AS EndTime
			,CAST(NULL AS INT) AS TotalPunchInOut
			,CAST(NULL AS INT) AS TotalBreakInOut
			,CAST(NULL AS VARCHAR(20)) AS [TotalHours]
			,CAST(NULL AS VARCHAR(20)) AS [TotalBreak]
			,CAST(NULL AS VARCHAR(20)) AS [ActualHours]
			,CAST(NULL AS INT) AS TotalCount
			,CAST(NULL AS VARCHAR) AS InLatitude
			,CAST(NULL AS VARCHAR) AS InLongitude
			,CAST(NULL AS VARCHAR) AS OutLatitude
			,CAST(NULL AS VARCHAR) AS OutLongitude
		WHERE 1 = 0;

		RETURN;
	END;

	INSERT INTO #Tmp_Attendance (
		AttendanceId
		,UserId
		,StartDate
		,EndDate
		,Type
		,CreatedDate
		,InLatitude
		,InLongitude
		,OutLatitude
		,OutLongitude
		)
	SELECT AttendanceId
		,UserId
		,StartDate
		,EndDate
		,Type
		,CreatedDate
		,InLatitude
		,InLongitude
		,OutLatitude
		,OutLongitude
	FROM Attendance WITH (NOLOCK)
	WHERE UserId = @UserID
		AND CreatedDate BETWEEN @StartDateTime
			AND @EndDateTime;

	WITH ListDates (AllDates)
	AS (
		SELECT @StartDate AS DATE
		
		UNION ALL
		
		SELECT DATEADD(DAY, 1, AllDates)
		FROM ListDates
		WHERE AllDates < @EndDate
		)
		,x
	AS (
		SELECT @UserID AS UserId
			,CAST(a.CreatedDate AS DATE) AS [Date]
			,SUM(IIF(a.Type = 0, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0)) AS [TotalHours]
			,SUM(IIF(a.Type = 1, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0)) AS [TotalBreak]
			,SUM(IIF(a.Type = 0, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0)) - SUM(IIF(a.Type = 1, DATEDIFF(MINUTE, a.StartDate, a.EndDate), 0)) AS [ActualHours]
			,SUM(IIF(a.Type = 0, 1, 0)) AS [TotalPunchInOut]
			,SUM(IIF(a.Type = 1, 1, 0)) AS [TotalBreakInOut]
			,(
				SELECT b.StartDate
				FROM #Tmp_Attendance AS b
				WHERE b.AttendanceId = MIN(a.AttendanceId)
				) AS [StartDate]
			,(
				SELECT TOP 1 c.EndDate
				FROM #Tmp_Attendance AS c
				WHERE c.AttendanceId = (
						SELECT MAX(b.AttendanceId)
						FROM #Tmp_Attendance b
						WHERE b.Type = 0
							AND CAST(b.CreatedDate AS DATE) = CAST(a.CreatedDate AS DATE)
						)
				ORDER BY c.AttendanceId DESC
				) AS [EndDate]
			,(
				SELECT b.InLatitude
				FROM #Tmp_Attendance AS b
				WHERE b.AttendanceId = MIN(a.AttendanceId)
				) AS [InLatitude]
			,(
				SELECT TOP 1 c.InLongitude
				FROM #Tmp_Attendance AS c
				WHERE c.AttendanceId = (
						SELECT MAX(b.AttendanceId)
						FROM #Tmp_Attendance b
						WHERE b.Type = 0
							AND CAST(b.CreatedDate AS DATE) = CAST(a.CreatedDate AS DATE)
						)
				ORDER BY c.AttendanceId DESC
				) AS [InLongitude]
			,(
				SELECT b.OutLatitude
				FROM #Tmp_Attendance AS b
				WHERE b.AttendanceId = MIN(a.AttendanceId)
				) AS [OutLatitude]
			,(
				SELECT TOP 1 c.OutLongitude
				FROM #Tmp_Attendance AS c
				WHERE c.AttendanceId = (
						SELECT MAX(b.AttendanceId)
						FROM #Tmp_Attendance b
						WHERE b.Type = 0
							AND CAST(b.CreatedDate AS DATE) = CAST(a.CreatedDate AS DATE)
						)
				ORDER BY c.AttendanceId DESC
				) AS [OutLongitude]
		FROM #Tmp_Attendance a WITH (NOLOCK)
		GROUP BY CAST(a.CreatedDate AS DATE)
		)
	SELECT @UserID AS UserId
		,@FullName AS [UserName]
		,ISNULL(x.StartDate, ld.AllDates) AS [Date]
		,x.StartDate AS StartTime
		,x.EndDate AS EndTime
		,ISNULL(x.InLatitude, '') AS InLatitude
		,ISNULL(x.InLongitude, '') AS InLongitude
		,ISNULL(x.OutLatitude, '') AS OutLatitude
		,ISNULL(x.OutLongitude, '') AS OutLongitude
		,ISNULL(x.TotalPunchInOut, 0) AS TotalPunchInOut
		,ISNULL(x.TotalBreakInOut, 0) AS TotalBreakInOut
		,ISNULL(dbo.MinutesToDuration(x.TotalHours), 'NA') AS [TotalHours]
		,ISNULL(dbo.MinutesToDuration(x.TotalBreak), 'NA') AS [TotalBreak]
		,ISNULL(dbo.MinutesToDuration(x.ActualHours), 'NA') AS [ActualHours]
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		,ld.AllDates
	FROM ListDates ld
	LEFT JOIN x ON ld.AllDates = x.DATE
	ORDER BY ld.AllDates DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY
	OPTION (MAXRECURSION 0);

	IF OBJECT_ID('tempdb..#Tmp_Attendance') IS NOT NULL
		DROP TABLE #Tmp_Attendance;

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

