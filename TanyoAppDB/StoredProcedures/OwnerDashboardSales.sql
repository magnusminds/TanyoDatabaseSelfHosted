CREATE PROCEDURE [dbo].[OwnerDashboardSales] 
	 @TenantId INT
	,@Month INT
	,@Year INT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);
		DECLARE @MonthEnd DATE = EOMONTH(@MonthStart);

		;WITH SalesData
		AS (
			SELECT SUM(CAST(o.AmountBeforeGST AS DECIMAL(18, 2))) AS AchievedAmount
				,COUNT(o.OrderId) AS OrderCount
			FROM dbo.Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
				AND o.IsArchive = 0
				AND o.Status >= 2
				AND o.Status NOT IN (
					6
					,8
					) -- Won (Approved, InProgress, Completed, Delivered, MaterialReceive)
				AND o.ApprovedDate BETWEEN @MonthStart
					AND @MonthEnd
			)
			,LeadData
		AS (
			SELECT COUNT(l.LeadId) AS NewLeadsCount
			FROM dbo.Leads l WITH (NOLOCK)
			WHERE l.TenantId = @TenantId
				AND l.Status <> 6 -- exclude Delete
				AND l.CreatedDate BETWEEN @MonthStart
					AND @MonthEnd
			)
			,TargetData
		AS (
			SELECT ISNULL(SUM(u.SalesTarget), 0) AS MonthlyTarget
			FROM dbo.AspNetUsers u WITH (NOLOCK)
			JOIN dbo.UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = u.UserId
			WHERE utm.TenantId = @TenantId
				AND utm.IsDeleted = 0
				AND u.IsActive = 1
				AND u.IsDeleted = 0
			)
		SELECT t.MonthlyTarget
			,ISNULL(s.AchievedAmount, 0) AS AchievedAmount
			,t.MonthlyTarget - ISNULL(s.AchievedAmount, 0) AS TargetGap
			,CASE 
				WHEN t.MonthlyTarget > 0
					THEN (ISNULL(s.AchievedAmount, 0) * 100.0) / t.MonthlyTarget
				ELSE 0
				END AS AchievementPct
			,ISNULL(s.OrderCount, 0) AS OrderCount
			,CASE 
				WHEN ISNULL(s.OrderCount, 0) > 0
					THEN ISNULL(s.AchievedAmount, 0) / s.OrderCount
				ELSE 0
				END AS AverageOrderValue
			,ISNULL(ld.NewLeadsCount, 0) AS NewLeadsCount
			,CASE 
				WHEN ISNULL(ld.NewLeadsCount, 0) > 0
					THEN (ISNULL(s.OrderCount, 0) * 100.0) / ld.NewLeadsCount
				ELSE 0
				END AS LeadConversionPct
		FROM TargetData t
		CROSS JOIN SalesData s
		CROSS JOIN LeadData ld;
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

