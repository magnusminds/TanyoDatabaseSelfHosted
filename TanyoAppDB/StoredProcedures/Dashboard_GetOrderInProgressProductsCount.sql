-- =============================================
-- Author      : MagnusMinds
-- Create date : 07-Jul-2026
-- Description : Get Pending and Ready To Deliver Order Product Counts
-- =============================================
/*
-- Admin
EXEC [dbo].[Dashboard_GetOrderInProgressProductsCount]
     @TenantId = 2,
     @CurrentUserId = 4328,
     @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'

-- Sales Representative
EXEC [dbo].[Dashboard_GetOrderInProgressProductsCount]
     @TenantId = 2,
     @CurrentUserId = 4386,
     @RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'
*/
CREATE PROCEDURE [dbo].[Dashboard_GetOrderInProgressProductsCount] (
	@TenantId INT
	,@CurrentUserId INT
	,@RoleId NVARCHAR(100)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @IsAdmin BIT = 0
			,@HasSuperAccess BIT = 0
			,@IsWholesaler BIT = 0
			,@OrderType INT;

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
		SET @OrderType = CASE 
				WHEN @IsWholesaler = 1
					THEN 2
				ELSE 1
				END;

		SELECT PendingCount = ISNULL(SUM(CASE 
						WHEN osi.ItemStatus = 4
							THEN 1
						ELSE 0
						END), 0)
			,ReadyToDeliverCount = ISNULL(SUM(CASE 
						WHEN osi.ItemStatus = 2
							THEN 1
						ELSE 0
						END), 0)
		FROM OrderSetItems osi
		INNER JOIN Orders o ON o.OrderId = osi.OrderId
			AND o.TenantId = @TenantId
		WHERE osi.ParentOrderSetItemId IS NULL
			AND o.IsArchive = 0
			AND osi.IsDeleted = 0
			AND osi.ItemStatus IN (
				2
				,-- ReadyToDelivered
				4 -- Pending
				)
			AND (
				@IsAdmin = 1
				OR (
					@HasSuperAccess = 1
					AND o.OrderType = @OrderType
					)
				OR (
					o.CreatedBy = @CurrentUserId
					AND o.OrderType = @OrderType
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

