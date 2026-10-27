/*
EXEC dbo.App_List_GetAllOrders_ByStatus
    @TenantId        = 2,
    @CurrentUserId   = 4279,
    @RoleId          = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F',
    @Status          = 0,                 -- Inquiry
    @StatusName      = NULL,
    @CustomerId      = NULL,
    @IsArchive       = 0,
    @PageIndex      = 1,
    @PageSize        = 500,
    @SortBy      = 'TotalAmount',
    @SortOrder   = 'DESC';
*/
CREATE PROCEDURE [dbo].[App_List_GetAllOrders_ByStatus] (
	@TenantId INT
	,@CurrentUserId BIGINT
	,@RoleId NVARCHAR(100)
	,@Status INT = NULL
	,@StatusName NVARCHAR(50) = NULL
	,@CustomerId BIGINT = NULL
	,@SalesmanName NVARCHAR(200) = NULL
	,@PriorityId INT = NULL
	,@OrderNo NVARCHAR(50) = NULL
	,@FilterBy INT = NULL
	,-- 1 = Pinned, 2 = Flagged
	@IsArchive BIT = 0
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy NVARCHAR(50) = 'OrderDate'
	,@SortOrder NVARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		/* ================= Role Flags ================= */
		DECLARE @IsAdmin BIT = 0
			,@HasSuperAccess BIT = 0
			,@IsWholesaler BIT = 0;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoles WITH (NOLOCK)
				WHERE Id = @RoleId
					AND Name LIKE 'Administrator_%'
				)
			SET @IsAdmin = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims WITH (NOLOCK)
				WHERE RoleId = @RoleId
					AND ClaimValue IN ( 
					'Permissions.App.Order.SuperAccess'
					,'Permissions.General.Order.SuperAccess'
					)
				)
			SET @HasSuperAccess = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims WITH (NOLOCK)
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

		/* ================= Main Query ================= */
		SELECT o.OrderId
			,o.OrderNo
			,o.CreatedDate AS OrderDate
			,o.ApprovedDate
			,o.Status
			,CASE 
				WHEN @IsArchive = 1
					THEN CAST(o.Status AS NVARCHAR(50))
				ELSE @StatusName
				END AS OrderStatus
			,LTRIM(RTRIM(ISNULL(c.FirstName, '') + CASE 
						WHEN c.LastName IS NULL
							OR c.LastName = ''
							THEN ''
						ELSE ' ' + c.LastName
						END)) AS CustomerName
			,u.FirstName + ' ' + u.LastName AS SalesmanName
			,ROUND(o.AmountBeforeGST + o.CGSTAmount + o.SGSTAmount + ISNULL(o.DeliveryCharges, 0) + CASE 
					WHEN o.DeliveryAmountCollectionType = 1
						THEN ISNULL(o.DeliveryAmount, 0)
					ELSE 0
					END - ISNULL(o.LumpsumDiscount, 0), 0) AS TotalAmount
			,ISNULL(l.LabelName, '') AS PriorityLabel
			,ISNULL(l.ColorCode, '') AS PriorityColorCode
			,o.IsArchive
			,o.IsFlagged
			,o.IsPinned
			,o.TentativeDeliveryDate
			,fu.FollowUpDate
			,fu.FollowUpComment AS FollowUpLastComment
			,CASE 
				WHEN o.IsArchive = 1
					THEN o.ArchiveOrderDate
				ELSE NULL
				END AS ArchiveOrderDate
			,COUNT(*) OVER () AS TotalCount
		FROM Orders o WITH (NOLOCK)
		INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			AND c.TenantId = @TenantId
		INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.SalesmanId = u.UserId
		LEFT JOIN Labels l WITH (NOLOCK) ON o.LabelId = l.LabelId
			AND l.TenantId = @TenantId
		OUTER APPLY (
			SELECT TOP 1 FollowUpDate
				,FollowUpComment
			FROM FollowUpOrders WITH (NOLOCK)
			WHERE OrderId = o.OrderId
			ORDER BY CreatedDate DESC
			) fu
		WHERE o.TenantId = @TenantId
			AND o.IsArchive = @IsArchive
			AND (
				@IsArchive = 1
				OR @Status IS NULL
				OR o.Status = @Status
				)
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
				)
			AND (
				@CustomerId IS NULL
				OR o.CustomerID = @CustomerId
				)
			AND (
				@PriorityId IS NULL
				OR o.LabelId = @PriorityId
				)
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@SalesmanName IS NULL
				OR REPLACE(LOWER(u.FirstName + u.LastName), ' ', '') LIKE '%' + REPLACE(LOWER(@SalesmanName), ' ', '') + '%'
				)
			AND (
				@FilterBy IS NULL
				OR (
					@FilterBy = 1
					AND o.IsPinned = 1
					)
				OR (
					@FilterBy = 2
					AND o.IsFlagged = 1
					)
				)
		/* ================= Sorting ================= */
		ORDER BY o.IsPinned DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN o.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN o.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN o.CreatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN o.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'ArchiveOrderDate'
					AND @SortOrder = 'ASC'
					THEN o.ArchiveOrderDate
				END ASC
			,CASE 
				WHEN @SortBy = 'ArchiveOrderDate'
					AND @SortOrder = 'DESC'
					THEN o.ArchiveOrderDate
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN c.FirstName + ISNULL(' ' + c.LastName, '')
				END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN c.FirstName + ISNULL(' ' + c.LastName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'ASC'
					THEN u.FirstName + ' ' + u.LastName
				END ASC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'DESC'
					THEN u.FirstName + ' ' + u.LastName
				END DESC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.TentativeDeliveryDate
				END ASC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.TentativeDeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'ASC'
					THEN fu.FollowUpDate
				END ASC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'DESC'
					THEN fu.FollowUpDate
				END DESC
			,CASE 
				WHEN @SortBy = 'FollowUpLastComment'
					AND @SortOrder = 'ASC'
					THEN fu.FollowUpComment
				END ASC
			,CASE 
				WHEN @SortBy = 'FollowUpLastComment'
					AND @SortOrder = 'DESC'
					THEN fu.FollowUpComment
				END DESC
			,CASE 
				WHEN @SortBy = 'PriorityLabel'
					AND @SortOrder = 'ASC'
					THEN l.LabelName
				END ASC
			,CASE 
				WHEN @SortBy = 'PriorityLabel'
					AND @SortOrder = 'DESC'
					THEN l.LabelName
				END DESC
			,CASE 
				WHEN @SortBy = 'TotalAmount'
					AND @SortOrder = 'ASC'
					THEN TotalAmount
				END ASC
			,CASE 
				WHEN @SortBy = 'TotalAmount'
					AND @SortOrder = 'DESC'
					THEN TotalAmount
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
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

