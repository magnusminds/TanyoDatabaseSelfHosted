-- =============================================
-- Author:  MagnusMinds
-- Create date: 22-Jul-2025
-- Description: Get count of Complains by status
-- =============================================
/*
--Admin
EXEC Dashboard_GetComplainByStatusCount
 @TenantId = 2,
 @CurrentUserId = 4328,
 @Status = 3,
 @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'

--SalesRepresentative
EXEC Dashboard_GetComplainByStatusCount
 @TenantId = 2,
 @CurrentUserId = 4386,
 @Status = 3,
 @RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'
*/
CREATE PROCEDURE [dbo].[Dashboard_GetComplainByStatusCount] 
	 @TenantId INT
	,@CurrentUserId BIGINT
	,@RoleId NVARCHAR(100)
	,@Status INT
	,@LocationID INT = NULL
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @IsAdmin BIT = 0
			,@IsWholesaler BIT = 0;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND [ClaimValue] IN (
						'Permissions.App.Order.Approve'
						,'Permissions.General.Order.Approve'
						)
				)
			SET @IsAdmin = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND [ClaimValue] IN (
						'Permissions.App.Order.WholeselerPrice'
						,'Permissions.General.Order.WholeselerPrice'
						)
				)
			SET @IsWholesaler = 1;

		SELECT COUNT(*)
		FROM Complains c
		INNER JOIN Customers cust ON c.CustomerId = cust.CustomerId
			AND cust.TenantId = @TenantId
		LEFT JOIN Orders o ON c.OrderId = o.OrderId
			AND o.IsArchive = 0
			AND o.TenantId = @TenantId
		WHERE c.Status = @Status
			AND c.TenantId = @TenantId
			AND (
				@LocationID IS NULL
				OR @LocationID = - 1
				OR cust.LocationID = @LocationID
				)
			AND (
				@IsAdmin = 1
				OR (
					c.CreatedBy = @CurrentUserId
					AND ISNULL(o.OrderType, 1) = CASE 
						WHEN @IsWholesaler = 1
							THEN 2
						ELSE 1
						END
					)
				)
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

