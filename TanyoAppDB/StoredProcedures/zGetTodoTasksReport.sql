/*
	EXEC dbo.GetTodoTasksReport
*/
CREATE   PROC [dbo].[zGetTodoTasksReport]
(
	@UserID BIGINT = NULL
	,@TenantID BIGINT = NULL
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;

	DECLARE @dt DATE = GETDATE()

	SELECT te.TenantId
		,te.TenantName
		,ISNULL(asu.FirstName, '') + ' ' + ISNULL(asu.LastName, '') AS ReportingToName
		,ISNULL(asu.Email, '') AS ReportingToEmail
		,ISNULL(asu.PhoneNumber, '') AS ReportingToPhoneNumber
		,tau.FirstName + ' ' + tau.LastName AS TaskAssignedTo
		,t.TaskId AS TaskNo
		,t.Title AS TaskName
		,c.FirstName + ' ' + ISNULL(c.LastName, '') AS ClientName
		,os.StatusLabel AS TaskStatus
		,t.StartDate
		,t.DueDate
	FROM Tasks t WITH (NOLOCK)
	INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = t.CustomerId
	INNER JOIN OrderStatus os WITH (NOLOCK) ON os.OrderStatusId = t.StatusId
		--AND os.Type = 'Task'
	INNER JOIN AspNetUsers tau WITH (NOLOCK) ON tau.UserId = t.AssignTo
	INNER JOIN EmployeeDetails ed WITH (NOLOCK) ON ed.UserID = tau.UserId
	LEFT JOIN AspNetUsers asu WITH (NOLOCK) ON asu.UserId = ed.ReportingTo
	INNER JOIN Tenants te WITH (NOLOCK) ON te.TenantId = t.TenantId
	WHERE t.StartDate = @dt
	AND os.StatusLabel IN ('Pending','In Progress','Inquiry')
	AND (@UserID IS NULL OR t.AssignTo = @UserID)
	AND (@TenantID IS NULL OR t.TenantId = @TenantID)
	ORDER BY TaskAssignedTo, t.StartDate ASC
END

GO

