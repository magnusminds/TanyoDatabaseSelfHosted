-- =============================================
-- Author:		<Author,,Name>
-- Create date: <Create Date,,>
-- Description:	<Description,,>
/*
EXEC [dbo].[GetSystemUser]
@TenantId = 1
*/
-- =============================================
CREATE PROCEDURE [dbo].[zGetSystemUser]
(
    @TenantId INT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
        SELECT TOP 1 u.FirstName
	        ,u.LastName
            ,u.UserName
	        ,u.Email
	        ,REPLACE(r.Name, '_' + CAST(@TenantId AS VARCHAR), '') [UserRole]
	        ,u.PhoneNumber
	        ,u.UserId
	        ,u.IsActive
	        ,ur.RoleId
        FROM AspNetUsers u
        INNER JOIN UserTenantMapping utm ON u.UserId = utm.UserId
	        AND utm.TenantId = @TenantId
        INNER JOIN AspNetUserRoles ur ON u.Id = ur.UserId
        INNER JOIN AspNetRoles r ON ur.RoleId = r.Id
        WHERE r.Name = 'SystemUser_' + CAST(@TenantId AS VARCHAR)
        ORDER BY u.UserId DESC
END

GO

