CREATE PROCEDURE [dbo].[zApp_List_GetStockOnHoldOrders] (
	@TenantId INT
	,@SalesmanName NVARCHAR(200) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy NVARCHAR(50) = 'LastUpdate'
	,-- OrderDate | LastUpdate | CustomerName | SalesmanName
	@SortOrder NVARCHAR(4) = 'DESC' -- ASC | DESC
	,@UserId INT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM AspNetUsers AU WITH (NOLOCK)
			INNER JOIN AspNetUserRoles AUR WITH (NOLOCK) ON AU.Id = AUR.UserId
			INNER JOIN AspNetRoles AR WITH (NOLOCK) ON AR.ID = AUR.RoleId
			WHERE AU.UserId = @UserId
				AND AR.Name LIKE 'Administrator%'
			)
	BEGIN
		SET @UserId = NULL
	END

	SELECT z.FirstName
		,z.LastName
		,x.OrderId
		,hold.OrderNo
		,x.CreatedDate AS OrderDate
		,z.FirstName + ' ' + z.LastName AS SalesmanName
		,LTRIM(RTRIM(ISNULL(y.FirstName, '') + ' ' + ISNULL(y.LastName, ''))) AS CustomerName
		,ROUND(hold.AmountBeforeGST + hold.CGSTAmount + hold.SGSTAmount + ISNULL(hold.DeliveryCharges, 0) + CASE 
				WHEN hold.DeliveryAmountCollectionType = 1
					THEN ISNULL(hold.DeliveryAmount, 0)
				ELSE 0
				END - ISNULL(hold.LumpsumDiscount, 0), 0) AS TotalAmount
		,fu.FollowUpDate
		,COALESCE(x.UpdatedDate, x.CreatedDate) AS LastUpdate
		,ISNULL(l.ColorCode, '') AS PriorityColorCode
		,ISNULL(l.LabelName, '') AS PriorityLabel
		,ISNULL(v.VisitCount, 0) AS CustomerVisitCount
		,hold.IsArchive
	FROM StockOnHold x WITH (NOLOCK)
	INNER JOIN Orders hold WITH (NOLOCK) ON x.OrderId = hold.OrderId
	INNER JOIN OrderSetItems osi WITH (NOLOCK) ON x.OrderSetItemId = osi.OrderSetItemId
	INNER JOIN Customers y WITH (NOLOCK) ON hold.CustomerID = y.CustomerId
		AND y.TenantId = @TenantId
	INNER JOIN AspNetUsers z WITH (NOLOCK) ON x.CreatedBy = z.UserId
	LEFT JOIN Labels l WITH (NOLOCK) ON hold.LabelId = l.LabelId
		AND l.TenantId = @TenantId
	OUTER APPLY (
		SELECT TOP 1 FollowUpDate
		FROM FollowUpOrders WITH (NOLOCK)
		WHERE OrderId = x.OrderId
		ORDER BY FollowUpDate DESC
		) fu
	OUTER APPLY (
		SELECT COUNT(*) AS VisitCount
		FROM OrderAnonymousViews WITH (NOLOCK)
		WHERE OrderId = x.OrderId
			AND CustomerId = y.CustomerId
		) v
	WHERE x.IsStockOnHold = 1
		AND hold.STATUS = 0
		AND hold.IsArchive = 0
		AND DATEADD(DAY, ISNULL(TRY_CONVERT(INT, x.TimePeriod), 0), x.CreatedDate) > SYSDATETIMEOFFSET()
		AND (
			@SalesmanName IS NULL
			OR REPLACE(LOWER(z.FirstName + z.LastName), ' ', '') LIKE '%' + REPLACE(LOWER(@SalesmanName), ' ', '') + '%'
			)
		AND (
			@UserId IS NULL
			OR x.CreatedBy = @UserId
			)
	ORDER BY CASE 
			WHEN @SortBy = 'OrderDate'
				AND @SortOrder = 'ASC'
				THEN x.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'OrderDate'
				AND @SortOrder = 'DESC'
				THEN x.CreatedDate
			END DESC
		,CASE 
			WHEN @SortBy = 'LastUpdate'
				AND @SortOrder = 'ASC'
				THEN COALESCE(x.UpdatedDate, x.CreatedDate)
			END ASC
		,CASE 
			WHEN @SortBy = 'LastUpdate'
				AND @SortOrder = 'DESC'
				THEN COALESCE(x.UpdatedDate, x.CreatedDate)
			END DESC
		,CASE 
			WHEN @SortBy = 'CustomerName'
				AND @SortOrder = 'ASC'
				THEN LTRIM(RTRIM(ISNULL(y.FirstName, '') + ' ' + ISNULL(y.LastName, '')))
			END ASC
		,CASE 
			WHEN @SortBy = 'CustomerName'
				AND @SortOrder = 'DESC'
				THEN LTRIM(RTRIM(ISNULL(y.FirstName, '') + ' ' + ISNULL(y.LastName, '')))
			END DESC
		,CASE 
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'ASC'
				THEN z.FirstName + ' ' + z.LastName
			END ASC
		,CASE 
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'DESC'
				THEN z.FirstName + ' ' + z.LastName
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY;
END

GO

