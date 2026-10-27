-- =============================================================================
-- SP Name   : OwnerDashboardSalesTrend
-- Module    : Owner Dashboard - Sales trend line chart (poster style)
-- Params    : @TenantId INT, @Month INT, @Year INT
-- Returns   : One row per day of the month:
--               Day                 1..31
--               DailyAchieved       approved order value that day (pre-GST)
--               CumulativeAchieved  running total through that day
--               DailyTarget         monthly rep target / days in month
-- Notes     : Cumulative uses a window function (SQL 2012+).
--             Chart plots target (dashed, full month) vs achieved (solid).
-- =============================================================================
CREATE PROCEDURE [dbo].[OwnerDashboardSalesTrend] 
	 @TenantId INT
	,@Month INT
	,@Year INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
		DECLARE @DaysInMonth INT = DAY(EOMONTH(@MonthStart));
		-- Fetched from AspNetUsers.SalesTarget
		DECLARE @MonthlyTarget DECIMAL(18, 2) = ISNULL((
					SELECT SUM(u.SalesTarget)
					FROM dbo.AspNetUsers u WITH (NOLOCK)
					JOIN dbo.UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = u.UserId
					WHERE utm.TenantId = @TenantId
						AND utm.IsDeleted = 0
						AND u.IsActive = 1
						AND u.IsDeleted = 0
					), 0);

		;WITH Daily
		AS (
			SELECT CAST(o.ApprovedDate AS DATE) AS ApprovedDay
				,SUM(CAST(o.AmountBeforeGST AS DECIMAL(18, 2))) AS Achieved
			FROM dbo.Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 2
				AND o.Status NOT IN (
					6
					,8
					) -- Won
				AND YEAR(o.ApprovedDate) = @Year
				AND MONTH(o.ApprovedDate) = @Month
			GROUP BY CAST(o.ApprovedDate AS DATE)
			)
			,Calendar
		AS (
			SELECT TOP (@DaysInMonth) DATEADD(DAY, ROW_NUMBER() OVER (
						ORDER BY (
								SELECT NULL
								)
						) - 1, @MonthStart) AS [Day]
			FROM sys.objects a
			CROSS JOIN sys.objects b
			)
		SELECT DAY(c.[Day]) AS [Day]
			,ISNULL(d.Achieved, 0) AS DailyAchieved
			,SUM(ISNULL(d.Achieved, 0)) OVER (
				ORDER BY c.[Day] ROWS UNBOUNDED PRECEDING
				) AS CumulativeAchieved
			,CASE 
				WHEN @DaysInMonth > 0
					THEN @MonthlyTarget / @DaysInMonth
				ELSE 0
				END AS DailyTarget
			,(
				CASE 
					WHEN @DaysInMonth > 0
						THEN @MonthlyTarget / @DaysInMonth
					ELSE 0
					END
				) * ROW_NUMBER() OVER (
				ORDER BY c.[Day]
				) AS CumulativeTarget
		FROM Calendar c
		LEFT JOIN Daily d ON d.ApprovedDay = c.[Day]
		ORDER BY c.[Day];
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

