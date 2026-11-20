/*
	EXEC dbo.GetSupervisorUsers
		@TenantId = 2
*/
CREATE   PROC [dbo].[GetSupervisorUsers]
(
	@TenantId BIGINT
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;


	BEGIN TRY
	SELECT au.UserId AS SupervisorId
		,au.FirstName + ' ' + au.LastName AS SupervisorName
		,mw.ManufacturingWorkflowId AS WorkflowId
		,mw.WorkflowName AS WorkflowName
	FROM AspNetUsers au WITH (NOLOCK)
	INNER JOIN AspNetUserRoles aur WITH (NOLOCK) ON aur.UserId = au.Id
	INNER JOIN AspNetRoles ar WITH (NOLOCK) ON ar.Id = aur.RoleId
	INNER JOIN UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = au.UserId
		AND utm.IsDeleted = 0
		AND utm.TenantId = @TenantId
	INNER JOIN ManufacturingWorkflowMapping mwm WITH (NOLOCK) ON mwm.ManufacturingUserId = au.UserId
		AND mwm.IsDeleted = 0
	INNER JOIN ManufacturingWorkflows mw WITH (NOLOCK) ON mw.ManufacturingWorkflowId = mwm.ManufacturingWorkflowId
		AND mw.IsDeleted = 0
	WHERE ar.TenantId = @TenantId
	AND ar.NormalizedName = 'SUPERVISOR_' + CAST(@TenantId AS VARCHAR(5))
	AND au.IsActive = 1
	ORDER BY 2

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

