CREATE   PROCEDURE [dbo].[GetUserDetailsByTenantAndRole]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT DISTINCT U.UserId
		,REPLACE(R.Name, '_' + CAST(T.TenantId AS VARCHAR(20)), '') AS UserRole
		,R.Id AS RoleId
		,T.TenantId
		,T.TenantName
		,U.FirstName
		,U.LastName
		,U.Email
		,U.PhoneNumber
	FROM AspNetUsers U WITH (NOLOCK)
	INNER JOIN UserTenantMapping UTM WITH (NOLOCK) ON UTM.UserId = U.UserId
		AND UTM.IsDeleted = 0
	INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId = UTM.TenantId
		AND T.IsDeleted = 0
	INNER JOIN AspNetUserRoles UR WITH (NOLOCK) ON UR.UserId = U.Id
	INNER JOIN AspNetRoles R WITH (NOLOCK) ON R.Id = UR.RoleId
		AND R.TenantId = T.TenantId
		AND R.Name LIKE '%Administrator%'
		AND R.IsDeleted = 0
		AND R.TenantId != 116 -- Exclude Tenant for notification
	WHERE U.IsActive = 1;

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

