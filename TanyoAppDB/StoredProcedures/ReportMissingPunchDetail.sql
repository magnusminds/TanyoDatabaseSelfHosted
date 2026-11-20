
/*
    EXEC [dbo].[ReportMissingPunchDetail]
        @TenantId = 125,
        @StartDate = '2025-08-27',
        @EndDate = '2025-09-06',
        @UserID = NULL,
        @MissingType = NULL, 
        @PageIndex = 1,
        @PageSize = 50,
		@SortBy  = 'UserName',
		@SortOrder  = 'DESC'
*/
CREATE
	

 PROCEDURE [dbo].[ReportMissingPunchDetail] (
	@TenantId BIGINT
	,@StartDate DATE
	,@EndDate DATE
	,@UserID BIGINT = NULL
	,@MissingType VARCHAR(20) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'UserName'
	,@SortOrder VARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF @UserID = ''
		SET @UserID = NULL;

	IF OBJECT_ID('tempdb..#Users') IS NOT NULL
		DROP TABLE #Users;

	IF OBJECT_ID('tempdb..#Attendance') IS NOT NULL
		DROP TABLE #Attendance;

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
	INNER JOIN UserTenantMapping M ON M.UserId = U.UserID
		AND M.TenantId = @TenantId
	WHERE U.IsDeleted = 0
		AND (
			@UserID IS NULL
			OR U.UserID = @UserID
			);

	CREATE TABLE #Attendance (
		UserId BIGINT
		,CreatedDate DATE
		,StartDate DATETIME
		,EndDate DATETIME
		,Type BIT
		,AttendanceId BIGINT
		);

	INSERT INTO #Attendance
	SELECT A.UserId
		,CAST(A.CreatedDate AS DATE)
		,A.StartDate
		,A.EndDate
		,A.Type
		,A.AttendanceId
	FROM Attendance A WITH (NOLOCK)
	INNER JOIN #Users U ON U.UserId = A.UserId
	WHERE CAST(A.CreatedDate AS DATE) BETWEEN @StartDate
			AND @EndDate;;

	WITH CalcPunch
	AS (
		SELECT A.UserId
			,A.CreatedDate
			,MIN(CASE 
					WHEN A.Type = 0
						THEN A.StartDate
					END) AS FirstPunchIn
			,CASE 
				WHEN SUM(CASE 
							WHEN A.Type = 0
								AND A.EndDate IS NULL
								THEN 1
							END) > 0
					THEN NULL
				ELSE MAX(CASE 
							WHEN A.Type = 0
								THEN A.EndDate
							END)
				END AS LastPunchOut
			,COUNT(CASE 
					WHEN A.Type = 0
						THEN 1
					END) AS TotalPunchCount
		FROM #Attendance A
		GROUP BY A.UserId
			,A.CreatedDate
		)
		,DateList
	AS (
		SELECT @StartDate AS D
		
		UNION ALL
		
		SELECT DATEADD(DAY, 1, D)
		FROM DateList
		WHERE D < @EndDate
		)
		,FinalData
	AS (
		SELECT U.UserId
			,U.UserName
			,DL.D AS [Date]
			,CP.FirstPunchIn
			,CP.LastPunchOut
			,CP.TotalPunchCount
			,CASE 
				WHEN CP.FirstPunchIn IS NULL
					AND CP.LastPunchOut IS NULL
					THEN 'Both'
				WHEN CP.FirstPunchIn IS NULL
					THEN 'Punch In'
				WHEN CP.LastPunchOut IS NULL
					THEN 'Punch Out'
				ELSE NULL
				END AS MissingType
			,CASE 
				WHEN CP.FirstPunchIn IS NULL
					AND CP.LastPunchOut IS NULL
					THEN NULL
				WHEN CP.FirstPunchIn IS NULL
					THEN CP.LastPunchOut
				WHEN CP.LastPunchOut IS NULL
					THEN CP.FirstPunchIn
				WHEN CP.LastPunchOut >= CP.FirstPunchIn
					THEN CP.LastPunchOut
				ELSE CP.FirstPunchIn
				END AS LastRecordedPunchTime
		FROM #Users U
		CROSS JOIN DateList DL
		LEFT JOIN CalcPunch CP ON CP.UserId = U.UserId
			AND CP.CreatedDate = DL.D
		WHERE (
				CP.FirstPunchIn IS NULL
				OR CP.LastPunchOut IS NULL
				)
			AND (
				@MissingType IS NULL
				OR (
					@MissingType = 'Punch In'
					AND CP.FirstPunchIn IS NULL
					AND CP.LastPunchOut IS NOT NULL
					)
				OR (
					@MissingType = 'Punch Out'
					AND CP.LastPunchOut IS NULL
					AND CP.FirstPunchIn IS NOT NULL
					)
				OR (
					@MissingType = 'Both'
					AND CP.FirstPunchIn IS NULL
					AND CP.LastPunchOut IS NULL
					)
				)
		)
	SELECT UserId
		,UserName
		,[Date]
		,FirstPunchIn
		,LastPunchOut
		,LastRecordedPunchTime
		,TotalPunchCount
		,MissingType
		,(
			SELECT COUNT(*)
			FROM FinalData
			) AS TotalCount
	FROM FinalData
	ORDER BY CASE 
			WHEN @SortBy = 'UserName'
				AND @SortOrder = 'ASC'
				THEN UserName
			END ASC
		,CASE 
			WHEN @SortBy = 'UserName'
				AND @SortOrder = 'DESC'
				THEN UserName
			END DESC
		,CASE 
			WHEN @SortBy = 'Date'
				AND @SortOrder = 'ASC'
				THEN [Date]
			END ASC
		,CASE 
			WHEN @SortBy = 'Date'
				AND @SortOrder = 'DESC'
				THEN [Date]
			END DESC
		,CASE 
			WHEN @SortBy = 'TotalPunchCount'
				AND @SortOrder = 'ASC'
				THEN TotalPunchCount
			END ASC
		,CASE 
			WHEN @SortBy = 'TotalPunchCount'
				AND @SortOrder = 'DESC'
				THEN TotalPunchCount
			END DESC
		,CASE 
			WHEN @SortBy = 'MissingType'
				AND @SortOrder = 'ASC'
				THEN MissingType
			END ASC
		,CASE 
			WHEN @SortBy = 'MissingType'
				AND @SortOrder = 'DESC'
				THEN MissingType
			END DESC
		,CASE 
			WHEN @SortBy = 'LastRecordedPunchTime'
				AND @SortOrder = 'ASC'
				THEN LastRecordedPunchTime
			END ASC
		,CASE 
			WHEN @SortBy = 'LastRecordedPunchTime'
				AND @SortOrder = 'DESC'
				THEN LastRecordedPunchTime
			END DESC
		,UserName DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY
	OPTION (MAXRECURSION 0);

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

