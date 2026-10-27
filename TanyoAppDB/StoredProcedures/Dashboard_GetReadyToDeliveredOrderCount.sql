-- =============================================
-- Author:  MagnusMinds
-- Create date: 22-Jul-2025
-- Description: Get count of ReadyToDelivered Orders
-- =============================================
/*
--Admin
EXEC Dashboard_GetReadyToDeliveredOrderCount
 @TenantId = 2,
 @CurrentUserId = 4328,
 @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'

--SalesRepresentative
EXEC Dashboard_GetReadyToDeliveredOrderCount
 @TenantId = 2,
 @CurrentUserId = 4386,
 @RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'
*/
CREATE PROCEDURE [dbo].[Dashboard_GetReadyToDeliveredOrderCount] 
	 @TenantId INT
	,@CurrentUserId INT
	,@RoleId VARCHAR(100)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @ProductSubjectTypeId INT
			,@PolishSubjectTypeId INT
			,@FabricSubjectTypeId INT
			,@IsAdmin BIT = 0
			,@HasSuperAccess BIT = 0
			,@IsWholesaler BIT = 0

		--SELECT @ProductSubjectTypeId = SubjectTypeId 
		--FROM SubjectTypes
		--WHERE TenantId = @TenantId
		-- AND IsDeleted = 0
		-- AND SubjectTypeName = 'Products'
		--SELECT @PolishSubjectTypeId = SubjectTypeId 
		--FROM SubjectTypes
		--WHERE TenantId = @TenantId
		-- AND IsDeleted = 0
		-- AND SubjectTypeName = 'Polish'
		--SELECT @FabricSubjectTypeId = SubjectTypeId 
		--FROM SubjectTypes
		--WHERE TenantId = @TenantId
		-- AND IsDeleted = 0
		-- AND SubjectTypeName = 'Fabrics'
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
						'Permissions.App.Order.SuperAccess'
						,'Permissions.General.Order.SuperAccess'
						)
				)
			SET @HasSuperAccess = 1;

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

		SELECT COUNT(1) AS ReadyToDeliverCount
		FROM OrderSetItems osi(NOLOCK)
		INNER JOIN Orders o(NOLOCK) ON osi.OrderId = o.OrderId
			AND o.TenantId = @TenantId
		--LEFT JOIN Products p ON osi.SubjectId = p.ProductId AND osi.SubjectTypeId = @ProductSubjectTypeId
		--LEFT JOIN Fabrics f ON osi.SubjectId = f.FabricId AND osi.SubjectTypeId = @FabricSubjectTypeId
		--LEFT JOIN Polish po ON osi.SubjectId = po.PolishId AND osi.SubjectTypeId = @PolishSubjectTypeId
		WHERE osi.ItemStatus = 2 -- ReadyToDelivered
			AND osi.ParentOrderSetItemId IS NULL
			AND o.IsArchive = 0
			AND (
				@IsAdmin = 1
				OR (
					@HasSuperAccess = 1
					AND o.OrderType = CASE 
						WHEN @IsWholesaler = 1
							THEN 2
						ELSE 1
						END
					)
				OR (
					o.CreatedBy = @CurrentUserId
					AND o.OrderType = CASE 
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

