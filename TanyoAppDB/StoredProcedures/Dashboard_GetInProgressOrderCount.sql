-- =============================================
-- Author:  MagnusMinds
-- Create date: 22-Jul-2025
-- Description: Get count of Orders which are in InProgress status
-- =============================================
/*
--Admin
EXEC Dashboard_GetInProgressOrderCount
 @TenantId = 2,
 @CurrentUserId = 4328,
 @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'

--SalesRepresentative
EXEC Dashboard_GetInProgressOrderCount
 @TenantId = 2,
 @CurrentUserId = 4386,
 @RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'
*/
CREATE PROCEDURE [dbo].[Dashboard_GetInProgressOrderCount] 
	 @TenantId INT
	,@CurrentUserId INT
	,@RoleId NVARCHAR(100)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @IsAdmin BIT = 0
			,@HasSuperAccess BIT = 0
			,@IsWholesaler BIT = 0;

		-- Permission checks
		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.Approve'
						,'Permissions.General.Order.Approve'
						)
				)
			SET @IsAdmin = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.SuperAccess'
						,'Permissions.General.Order.SuperAccess'
						)
				)
			SET @HasSuperAccess = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.WholeselerPrice'
						,'Permissions.General.Order.WholeselerPrice'
						)
				)
			SET @IsWholesaler = 1;

		DECLARE @ExpectedOrderType INT = CASE 
				WHEN @IsWholesaler = 1
					THEN 2
				ELSE 1
				END;

		SELECT COUNT(*) AS StatusCount
		FROM Orders o
		WHERE o.TenantId = @TenantId
			AND o.Status = 3 -- InProgress
			AND o.IsArchive = 0
			AND (
				@IsAdmin = 1
				OR (
					@HasSuperAccess = 1
					AND o.OrderType = @ExpectedOrderType
					)
				OR (
					o.SalesmanId = @CurrentUserId
					AND o.OrderType = @ExpectedOrderType
					)
				);
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

