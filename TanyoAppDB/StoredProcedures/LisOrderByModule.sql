/*  
====================================================================  
IMPORTANT: If any changes in Parameters or in WHERE clause, please do update [dbo].[GetOrderCountByModule] SP.  
====================================================================  
  
	EXEC [dbo].[LisOrderByModule]
		@Status = 0
		,@IsArchiveOrders = 0
		,@TenantId = 2
		,@UserId = 4279
		,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
		,@SalesmanId = NULL
		,@PriorityId = NULL
		,@ModuleName = 'Remaining'
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
CREATE PROC [dbo].[LisOrderByModule] (
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
				END

		IF OBJECT_ID('tempdb..#Temp_Orders') IS NOT NULL
			DROP TABLE #Temp_Orders;

		CREATE TABLE #Temp_Orders (
			Id INT PRIMARY KEY IDENTITY
			,OrderId BIGINT
			,OrderNo VARCHAR(20)
			,OrderDate DATETIMEOFFSET
			,ApprovedDate DATETIMEOFFSET
			,TotalAmount NUMERIC(18, 2)
			,AmountBeforeGST NUMERIC(18, 2)
			,CGSTAmount NUMERIC(18, 2)
			,SGSTAmount NUMERIC(18, 2)
			,DeliveryCharges NUMERIC(18, 2)
			,DeliveryAmount NUMERIC(18, 2)
			,DeliveryAmountCollectionType INT
			,LumpsumDiscount NUMERIC(18, 2)
			,SalesmanId INT
			,IsFlagged BIT
			,IsPinned BIT
			,TentativeDeliveryDate DATE
			,DeliveryDate DATE
			,IsArchive BIT
			,Status INT
			,CustomerId BIGINT
			,CustomerName VARCHAR(100)
			,SalesmanName NVARCHAR(MAX)
			,PriorityColorCode VARCHAR(10)
			,PriorityLabel VARCHAR(100)
			,PriorityId BIGINT
			,FollowUpDate DATETIME
			,FollowUpLastComment NVARCHAR(MAX)
			,CustomerVisitCount INT
			,ModuleGroup VARCHAR(20)
			,OrderSetItemId BIGINT
			,OrderSetItem VARCHAR(100)
			)

		INSERT INTO #Temp_Orders
		SELECT o.OrderId
			,o.OrderNo
			,o.CreatedDate AS OrderDate
			,o.ApprovedDate
			,ROUND(o.AmountBeforeGST + o.CGSTAmount + o.SGSTAmount + ISNULL(o.DeliveryCharges, 0) + CASE 
					WHEN o.DeliveryAmountCollectionType = 1
						THEN ISNULL(o.DeliveryAmount, 0)
					ELSE 0
					END - ISNULL(o.LumpsumDiscount, 0), 2) AS TotalAmount
			,o.AmountBeforeGST
			,o.CGSTAmount
			,o.SGSTAmount
			,o.DeliveryCharges
			,o.DeliveryAmount
			,o.DeliveryAmountCollectionType
			,o.LumpsumDiscount
			,o.SalesmanId
			,ISNULL(o.IsFlagged, 0) AS IsFlagged
			,o.IsPinned
			,o.TentativeDeliveryDate
			,o.DeliveryDate
			,o.IsArchive
			,o.Status
			,c.CustomerId
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,u.FirstName + ' ' + u.LastName + CASE 
				WHEN u.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS SalesmanName
			,ISNULL(l.ColorCode, '') AS PriorityColorCode
			,ISNULL(l.LabelName, '') AS PriorityLabel
			,l.LabelId AS PriorityId
			,f.FollowUpDate
			,f.FollowUpComment AS FollowUpLastComment
			,ISNULL(v.CustomerVisitCount, 0) AS CustomerVisitCount
			,CASE -- Determine ModuleName grouping  
				WHEN o.IsPinned = 1
					THEN 'Pinned'
				WHEN o.IsFlagged = 1
					AND o.IsPinned = 0
					THEN 'Flagged'
				WHEN f.FollowUpDate IS NOT NULL
					AND CAST(f.FollowUpDate AS DATE) = @dt
					AND o.IsPinned = 0
					AND ISNULL(o.IsFlagged, 0) = 0
					THEN 'Today'
				WHEN f.FollowUpDate IS NOT NULL
					AND f.FollowUpDate < @dt
					AND o.IsPinned = 0
					AND ISNULL(o.IsFlagged, 0) = 0
					THEN 'Overdue'
				WHEN f.FollowUpDate IS NOT NULL
					AND f.FollowUpDate > @dt
					AND o.IsPinned = 0
					AND ISNULL(o.IsFlagged, 0) = 0
					THEN 'Upcoming'
				ELSE 'Remaining'
				END AS ModuleGroup
			,0 AS OrderSetItemId
			,'' AS OrderSetItem
		FROM Orders o WITH (NOLOCK)
		INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			AND c.TenantId = o.TenantId
		--AND c.IsDeleted = 0
		LEFT JOIN AspNetUsers u WITH (NOLOCK) ON o.SalesmanId = u.UserId
		LEFT JOIN Labels l WITH (NOLOCK) ON o.LabelId = l.LabelId
			AND l.TenantId = @TenantId
			AND l.IsDeleted = 0
		OUTER APPLY (
			SELECT TOP 1 FollowUpDate
				,FollowUpComment
			FROM FollowUpOrders f
			WHERE f.OrderId = o.OrderId
			ORDER BY f.FollowUpDate DESC
			) f
		LEFT JOIN (
			SELECT OrderId
				,COUNT(*) AS CustomerVisitCount
			FROM OrderAnonymousViews WITH (NOLOCK)
			GROUP BY OrderId
			) v ON v.OrderId = o.OrderId
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

		SELECT o.Id
			,o.OrderId
			,o.OrderNo
			,o.OrderDate
			,o.ApprovedDate
			,o.TotalAmount
			,o.AmountBeforeGST
			,o.CGSTAmount
			,o.SGSTAmount
			,o.DeliveryCharges
			,o.DeliveryAmount
			,o.DeliveryAmountCollectionType
			,o.LumpsumDiscount
			,o.SalesmanId
			,o.IsFlagged
			,o.IsPinned
			,o.TentativeDeliveryDate
			,o.DeliveryDate
			,o.IsArchive
			,o.Status
			,o.CustomerId
			,o.CustomerName
			,o.SalesmanName
			,o.PriorityColorCode
			,o.PriorityLabel
			,o.PriorityId
			,o.FollowUpDate
			,o.FollowUpLastComment
			,o.CustomerVisitCount
			,o.ModuleGroup
			,o.OrderSetItemId
			,o.OrderSetItem
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM #Temp_Orders o
		WHERE (
				@ModuleName = 'All'
				OR o.ModuleGroup = @ModuleName
				)
		ORDER BY o.IsPinned DESC
			,CASE 
				WHEN @SortBy = 'PriorityLabel'
					AND @SortOrder = 'asc'
					THEN ISNULL(o.PriorityLabel, '')
				END ASC
			,CASE 
				WHEN @SortBy = 'PriorityLabel'
					AND @SortOrder = 'desc'
					THEN ISNULL(o.PriorityLabel, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'asc'
					THEN o.OrderDate
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'desc'
					THEN o.OrderDate
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'asc'
					THEN o.CustomerName
				END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'desc'
					THEN o.CustomerName
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'asc'
					THEN o.SalesmanName
				END ASC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'desc'
					THEN o.SalesmanName
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'asc'
					THEN o.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'desc'
					THEN o.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'asc'
					THEN o.FollowUpDate
				END ASC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'desc'
					THEN o.FollowUpDate
				END DESC
			,CASE 
				WHEN @SortBy = 'FollowUpLastComment'
					AND @SortOrder = 'asc'
					THEN o.FollowUpLastComment
				END ASC
			,CASE 
				WHEN @SortBy = 'FollowUpLastComment'
					AND @SortOrder = 'desc'
					THEN o.FollowUpLastComment
				END DESC
			,CASE 
				WHEN @SortBy = 'TotalAmount'
					AND @SortOrder = 'asc'
					THEN o.TotalAmount
				END ASC
			,CASE 
				WHEN @SortBy = 'TotalAmount'
					AND @SortOrder = 'desc'
					THEN o.TotalAmount
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY
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

