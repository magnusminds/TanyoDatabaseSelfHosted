-- =============================================
-- Author:  MagnusMinds
-- Create date: 22-Jul-2025
-- Description: Get count of Orders which are in TotalComplain status
-- =============================================
/*
--Admin
EXEC Dashboard_GetTotalComplainCount
 @TenantId = 1206,
 @CurrentUserId = 13303,
 @RoleId = 'A30DD003-8DE8-4C9F-9517-92F039ABB420'

--SalesRepresentative
EXEC Dashboard_GetTotalComplainCount
 @TenantId = 2,
 @CurrentUserId = 2131,
 @RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'
*/
CREATE PROCEDURE [dbo].[Dashboard_GetTotalComplainCount] 
	 @TenantId INT
	,@CurrentUserId INT
	,@RoleId NVARCHAR(100)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @IsAdmin BIT = 0
			,@CanListAllOrders BIT = 0
			,@IsWholesaler BIT = 0;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoles
				WHERE Id = @RoleId
					AND [Name] = 'Administrator_' + CAST(@TenantId AS VARCHAR(5))
				)
			SET @IsAdmin = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue = 'Permissions.App.Complain.ListAllOrders'
				)
			SET @CanListAllOrders = 1;

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

		SELECT COUNT(*) AS StatusCount
		FROM Complains c
		LEFT JOIN Orders o ON c.OrderId = o.OrderId
			AND o.TenantId = @TenantId
			AND o.IsArchive = 0
		WHERE c.TenantId = @TenantId
			AND c.Status <> 4
			AND (
				(@IsAdmin = 1)
				OR (@CanListAllOrders = 1)
				OR (
					@IsAdmin = 0
					AND @CanListAllOrders = 0
					AND c.CreatedBy = @CurrentUserId
					AND ISNULL(o.OrderType, 1) = CASE 
						WHEN @IsWholesaler = 1
							THEN 2
						ELSE 1
						END
					)
				);
			--SELECT @IsAdmin ,@CanListAllOrders, @IsWholesaler
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg NVARCHAR(4000);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

