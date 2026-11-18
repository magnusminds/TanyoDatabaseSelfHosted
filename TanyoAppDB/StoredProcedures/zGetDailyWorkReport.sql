/*
	EXEC dbo.GetDailyWorkReport
		@StartDate = '2025-06-25'
*/
CREATE   PROC zGetDailyWorkReport
(
	@StartDate DATE
	,@UserID BIGINT = NULL
	,@TenantID BIGINT = NULL
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @EndDate DATE = DATEADD(DAY, 1, @StartDate)

	SELECT te.TenantId
		,te.TenantName
		,ISNULL(asu.FirstName, '') + ' ' + ISNULL(asu.LastName, '') AS ReportingToName
		,ISNULL(asu.Email, '') AS ReportingToEmail
		,ISNULL(asu.PhoneNumber, '') AS ReportingToPhoneNumber
		,tcau.FirstName + ' ' + tcau.LastName AS TaskCommenterName
		,tau.FirstName + ' ' + tau.LastName AS TaskAssignedTo
		,t.TaskId AS TaskNo
		,t.Title AS TaskName
		,c.FirstName + ' ' + ISNULL(c.LastName, '') AS ClientName
		,os.StatusLabel AS TaskStatus
		,tc.Description AS Comments
		,tc.Hours AS SpentHours
	FROM TaskComments tc WITH (NOLOCK)
	INNER JOIN Tasks t WITH (NOLOCK) ON t.TaskId = tc.TaskId
	INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = t.CustomerId
	INNER JOIN OrderStatus os WITH (NOLOCK) ON os.OrderStatusId = t.StatusId
		--AND os.Type = 'Task'
	INNER JOIN AspNetUsers tcau WITH (NOLOCK) ON tcau.UserId = tc.CreatedBy
	INNER JOIN AspNetUsers tau WITH (NOLOCK) ON tau.UserId = t.AssignTo
	INNER JOIN EmployeeDetails ed WITH (NOLOCK) ON ed.UserID = tcau.UserId
	LEFT JOIN AspNetUsers asu WITH (NOLOCK) ON asu.UserId = ed.ReportingTo
	INNER JOIN Tenants te WITH (NOLOCK) ON te.TenantId = t.TenantId
	WHERE tc.CreatedDate BETWEEN @StartDate AND @EndDate
	AND (@UserID IS NULL OR tc.CreatedBy = @UserID)
	AND (@TenantID IS NULL OR t.TenantId = @TenantID)
	ORDER BY TaskAssignedTo DESC
END

GO

