/*  
====================================================================  
IMPORTANT: If any changes in Parameters or in WHERE clause, please do update [dbo].[LisOrderByModule] SP.  
====================================================================  
  
	EXEC [dbo].[GetOrderCountByModule]
		@Status = 0
		,@IsArchiveOrders = 0
		,@TenantId = 2
		,@UserId = 4279
		,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
		,@SalesmanId = NULL
		,@PriorityId = NULL
		,@ModuleName = 'Pinned'
		,@PageIndex = 1
		,@PageSize = 50
		,@SortBy = ''
		,@SortOrder = ''
		,@OrderNo = NULL
		,@CustomerName = NULL
		,@OrderFromDate = NULL
		,@OrderToDate = NULL
		,@TentativeDeliveryFromDate = NULL
		,@TentativeDeliveryToDate = NULL
  
*/
CREATE PROC [dbo].[GetOrderCountByModule] (
	@Status INT
	,@IsArchiveOrders BIT
	,@TenantId INT
	,@UserId INT
	,@RoleId NVARCHAR(MAX)
	,@SalesmanId INT = NULL
	,@PriorityId BIGINT = NULL
	,@ModuleName VARCHAR(50) = 'Today'
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(100) = 'OrderDate'
	,@SortOrder VARCHAR(100) = 'DESC'
	,@OrderNo VARCHAR(20) = NULL
	,@CustomerName VARCHAR(100) = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@TentativeDeliveryFromDate DATE = NULL
	,@TentativeDeliveryToDate DATE = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @dt DATE = GETDATE()
		DECLARE @HasWholesalerPrice BIT = 0
			,@IsAdmin BIT = 0
			,@SupperAccess BIT = 0
			,@OrderFromDateTime DATETIMEOFFSET = NULL
			,@OrderToDateTime DATETIMEOFFSET = NULL
			,@DeliveryFromDateTime DATETIMEOFFSET = NULL
			,@DeliveryToDateTime DATETIMEOFFSET = NULL

		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'
			,@DeliveryFromDateTime = CAST(@TentativeDeliveryFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@DeliveryToDateTime = CAST(@TentativeDeliveryToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30';

		SELECT @HasWholesalerPrice = CASE 
				WHEN EXISTS (
						SELECT 1
						FROM AspNetRoleClaims WITH (NOLOCK)
						WHERE RoleId = @RoleId
							AND ClaimValue IN (
								'Permissions.App.Order.WholeselerPrice'
								,'Permissions.General.Order.WholeselerPrice'
								)
						)
					THEN 1
				ELSE 0
				END

		SELECT @IsAdmin = CASE 
				WHEN EXISTS (
						SELECT 1
						FROM AspNetRoleClaims WITH (NOLOCK)
						WHERE RoleId = @RoleId
							AND ClaimValue IN (
								'Permissions.App.Order.Approve'
								,'Permissions.General.Order.Approve'
								)
						)
					THEN 1
				ELSE 0
				END

		SELECT @SupperAccess = CASE 
				WHEN EXISTS (
						SELECT 1
						FROM AspNetRoleClaims WITH (NOLOCK)
						WHERE RoleId = @RoleId
							AND ClaimValue IN (
								'Permissions.App.Order.SuperAccess'
								,'Permissions.General.Order.SuperAccess'
								)
						)
					THEN 1
				ELSE 0
				END

		DECLARE @OrderType INT = CASE 
				WHEN @HasWholesalerPrice = 1
					THEN 2
				ELSE 1
				END;

		WITH OrderWithFollowUp
		AS (
			SELECT o.OrderId
				,o.IsPinned
				,o.IsFlagged
				,f.FollowUpDate
			FROM Orders o WITH (NOLOCK)
			INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
				AND c.TenantId = o.TenantId
			INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.CreatedBy = u.UserId
			LEFT JOIN Labels l WITH (NOLOCK) ON o.LabelId = l.LabelId
				AND l.TenantId = @TenantId
				AND l.IsDeleted = 0
			OUTER APPLY (
				SELECT TOP 1 FollowUpDate
				FROM FollowUpOrders f
				WHERE f.OrderId = o.OrderId
				ORDER BY f.FollowUpDate DESC
				) f
			WHERE o.TenantId = @TenantId
				AND o.Status = @Status
				AND o.IsArchive = @IsArchiveOrders
				AND (
					@PriorityId IS NULL
					OR l.LabelId = @PriorityId
					)
				AND (
					@IsAdmin = 1
					OR (
						@IsAdmin = 0
						AND @SupperAccess = 1
						AND o.OrderType = @OrderType
						)
					OR (
						@IsAdmin = 0
						AND @SupperAccess = 0
						AND o.CreatedBy = @UserId
						AND o.OrderType = @OrderType
						)
					)
				AND (
					@SalesmanId IS NULL
					OR o.SalesmanId = @SalesmanId
					)
				AND (
					ISNULL(@CustomerName, '') = ''
					OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @CustomerName + '%'
					)
				AND (
					@OrderFromDate IS NULL
					OR o.ApprovedDate >= @OrderFromDateTime
					)
				AND (
					@OrderToDate IS NULL
					OR o.ApprovedDate <= @OrderToDateTime
					)
				AND (
					@TentativeDeliveryFromDate IS NULL
					OR o.TentativeDeliveryDate >= @DeliveryFromDateTime
					)
				AND (
					@TentativeDeliveryToDate IS NULL
					OR o.TentativeDeliveryDate <= @DeliveryToDateTime
					)
				AND (
					@OrderNo IS NULL
					OR o.OrderNo LIKE '%' + @OrderNo + '%'
					)
			)
		SELECT ISNULL(SUM(CASE 
						WHEN Module = 'Pinned'
							THEN 1
						ELSE 0
						END), 0) AS PinnedCount
			,ISNULL(SUM(CASE 
						WHEN Module = 'Flagged'
							THEN 1
						ELSE 0
						END), 0) AS FlaggedCount
			,ISNULL(SUM(CASE 
						WHEN Module = 'Today'
							THEN 1
						ELSE 0
						END), 0) AS TodayCount
			,ISNULL(SUM(CASE 
						WHEN Module = 'Overdue'
							THEN 1
						ELSE 0
						END), 0) AS OverdueCount
			,ISNULL(SUM(CASE 
						WHEN Module = 'Upcoming'
							THEN 1
						ELSE 0
						END), 0) AS UpcomingCount
			,ISNULL(SUM(CASE 
						WHEN Module = 'Remaining'
							THEN 1
						ELSE 0
						END), 0) AS RemainingCount
		FROM (
			SELECT CASE 
					WHEN IsPinned = 1
						THEN 'Pinned'
					WHEN IsFlagged = 1
						THEN 'Flagged'
					WHEN FollowUpDate IS NOT NULL
						AND CAST(FollowUpDate AS DATE) = @dt
						THEN 'Today'
					WHEN FollowUpDate IS NOT NULL
						AND FollowUpDate < @dt
						THEN 'Overdue'
					WHEN FollowUpDate IS NOT NULL
						AND FollowUpDate > @dt
						THEN 'Upcoming'
					ELSE 'Remaining'
					END AS Module
			FROM OrderWithFollowUp
			) X
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

