-- =============================================
-- Author		: MagnusMinds
-- Create date	: 06-09-2023
-- Description	: Report - Notifications Management
-- =============================================
/*
	EXEC [dbo].[ReportNotificationManagement]
		@TenantId = 125
		,@FromDate = '2026-02-01'
		,@ToDate = '2026-02-18'
		,@Notificationtype  = NULL
		,@EntityName = NULL
		,@NotificationMethod  = 'BusinessInsights'
		,@ReceiverName  = NULL
		,@ReceiverEmail  = NULL
		,@ReceiverMobile  = NULL
		,@Status = NULL
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'NotificationType'
		,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[ReportNotificationManagement] (
	@TenantId INT
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@Notificationtype VARCHAR(50) = NULL
	,@EntityName VARCHAR(50) = NULL
	,@NotificationMethod VARCHAR(50) = NULL
	,@ReceiverName VARCHAR(50) = NULL
	,@ReceiverEmail VARCHAR(50) = NULL
	,@ReceiverMobile VARCHAR(50) = NULL
	,@Status INT = - 1
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'NotificationType'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		Declare
			 @CustomersSubjectTypeId BIGINT
			,@OrdersSubjectTypeId BIGINT
			,@VendorSubjectTypeId BIGINT
			,@EmployeeSubjectTypeId BIGINT
		
		SELECT @CustomersSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantId
		AND st.SubjectTypeName = 'Customers'

		SELECT @OrdersSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantId
		AND st.SubjectTypeName = 'Orders'

		SELECT @VendorSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantId
		AND st.SubjectTypeName = 'Vendor'

		SELECT @EmployeeSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantId
		AND st.SubjectTypeName = 'Employee'
		
		SELECT nm.NotificationManagementID
			,nm.NotificationType
			,nm.NotificationMethod
			,CASE 
				WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = ood.OwnerId THEN COALESCE(ood.OwnerFullName, '')
				WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = T.TenantId THEN CONCAT(ISNULL(T.FirstName, ''), ' ', ISNULL(T.LastName, ''))
				ELSE CONCAT(' ', COALESCE(c.FirstName + ' ' + c.LastName, ''))
			END AS ReceiverName
			,nm.ReceiverEmail
			,nm.ReceiverMobile
			,nm.MessageSubject
			,nm.MessageBody
			,nm.Status
			,nm.CreatedBy
			,nm.CreatedDate
			,nm.UpdatedBy
			,nm.UpdatedDate
			,nm.EntityTypeID
			,nm.CreatedDate AS CreatedUTCDate
			,nm.UpdatedDate AS UpdatedUTCDate
			,'MagnusMinds' AS OrderIdEncrypt
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			,CASE 
			    WHEN nm.NotificationType = 'BusinessInsights' THEN ''
				WHEN nm.EntityTypeID = @OrdersSubjectTypeId THEN COALESCE(allOrders.OrderNo, '') 
				WHEN nm.EntityTypeID = @VendorSubjectTypeId THEN CONCAT (' ', Vendors.VendorName) 
				WHEN nm.EntityTypeID = @EmployeeSubjectTypeId THEN CONCAT (' ', anu.FirstName + ' ' + anu.LastName) 
				ELSE CONCAT (' ', allCustomers.FirstName, ' ', COALESCE(allCustomers.LastName, '')) 
			 END AS Entity
			,CASE WHEN nm.EntityTypeID = 0 THEN allOrders.OrderId ELSE 0 END AS OrderId
			,CASE WHEN nm.EntityTypeID = @CustomersSubjectTypeId AND allCustomers.CustomerTypeId = 1 THEN nm.EntityID ELSE 0 END AS CustomerId
			,CASE WHEN nm.EntityTypeID = @CustomersSubjectTypeId AND allCustomers.CustomerTypeId = 2 THEN nm.EntityID ELSE 0 END AS InteriorId
		FROM [dbo].[NotificationManagement] AS nm WITH (NOLOCK)
		INNER JOIN [dbo].[Tenants] AS T WITH (NOLOCK) ON nm.TenantId = T.TenantId
		AND T.IsDeleted = 0
		LEFT JOIN [dbo].[OrganizationOwnerDetails] AS ood WITH (NOLOCK) 
			ON nm.EntityID = ood.OwnerId 
			AND nm.NotificationType = 'BusinessInsights'
			AND ood.IsDeleted = 0
		LEFT JOIN [dbo].[Customers] AS allCustomers WITH (NOLOCK) ON nm.EntityID = allCustomers.CustomerId
			AND nm.EntityTypeID = @CustomersSubjectTypeId
		LEFT JOIN [dbo].[Vendors] AS Vendors WITH (NOLOCK) ON nm.EntityID = Vendors.VendorId
			AND nm.EntityTypeID = @VendorSubjectTypeId
		LEFT JOIN [dbo].[Orders] AS allOrders WITH (NOLOCK) ON nm.EntityID = allOrders.OrderId
			AND nm.EntityTypeID = @OrdersSubjectTypeId
		LEFT JOIN [dbo].[Customers] AS c WITH (NOLOCK) ON allOrders.CustomerID = c.CustomerId
		LEFT JOIN [dbo].[EmployeeDetails] AS e WITH (NOLOCK) ON nm.EntityID = e.EmployeeDetailID 
		AND nm.EntityTypeID = @EmployeeSubjectTypeId 
		LEFT JOIN [dbo].[AspNetUsers] AS anu WITH (NOLOCK) ON anu.UserId = e.UserID
		AND nm.EntityTypeID = @EmployeeSubjectTypeId 
		WHERE (
				@FromDate IS NULL
				OR nm.CreatedDate >= @FromDate
				)
			AND (
				@ToDate IS NULL
				OR nm.CreatedDate < DATEADD(DAY, 1, @ToDate)
				)
			AND (nm.TenantId = @TenantId)
			AND (
				ISNULL(@Notificationtype, '') = '-1'
				OR nm.NotificationType = @Notificationtype
				)
			AND (
				ISNULL(@EntityName, '') = ''
				OR (
					CASE WHEN nm.EntityTypeID = @OrdersSubjectTypeId THEN COALESCE(allOrders.OrderNo, '') 
					ELSE CONCAT (' ', allCustomers.FirstName, ' ', COALESCE(allCustomers.LastName, '')) END
					) LIKE '%' + @EntityName + '%'
				)
			AND (
				ISNULL(@NotificationMethod, '') = '-1'
				OR nm.NotificationMethod = @NotificationMethod
				)
			AND (
				ISNULL(@ReceiverName, '') = ''
				OR (
					CASE 
						WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = ood.OwnerId THEN COALESCE(ood.OwnerFullName, '')
						WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = T.TenantId THEN CONCAT(ISNULL(T.FirstName, ''), ' ', ISNULL(T.LastName, ''))
						ELSE CONCAT_WS(' ', COALESCE(c.FirstName, allCustomers.FirstName), COALESCE(c.LastName, allCustomers.LastName))
					END
				) LIKE '%' + @ReceiverName + '%'
				)
			AND (
				ISNULL(@ReceiverEmail, '') = ''
				OR nm.ReceiverEmail LIKE '%' + @ReceiverEmail + '%'
				)
			AND (
				ISNULL(@ReceiverMobile, '') = ''
				OR nm.ReceiverMobile LIKE '%' + @ReceiverMobile + '%'
				)
			AND (
				ISNULL(@Status, - 1) = - 1
				OR nm.STATUS = @Status
				)
		ORDER BY CASE WHEN @SortBy = 'NotificationType' AND @SortOrder = 'ASC' THEN nm.NotificationType END ASC
			,CASE WHEN @SortBy = 'NotificationType' AND @SortOrder = 'DESC' THEN nm.NotificationType END DESC
			,CASE WHEN @SortBy = 'NotificationMethod' AND @SortOrder = 'ASC' THEN nm.NotificationMethod END ASC
			,CASE WHEN @SortBy = 'NotificationMethod' AND @SortOrder = 'DESC' THEN nm.NotificationMethod END DESC
			,CASE WHEN @SortBy = 'EntityName' AND @SortOrder = 'ASC' THEN CONCAT_WS(' ', allCustomers.FirstName, allCustomers.LastName) END ASC
			,CASE WHEN @SortBy = 'EntityName' AND @SortOrder = 'DESC' THEN CONCAT_WS(' ', allCustomers.FirstName, allCustomers.LastName) END DESC
			,CASE WHEN @SortBy = 'ReceiverName' AND @SortOrder = 'ASC' THEN 
				CASE 
					WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = ood.OwnerId THEN ood.OwnerFullName
					WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = T.TenantId THEN CONCAT(ISNULL(T.FirstName, ''), ' ', ISNULL(T.LastName, ''))
					ELSE c.FirstName
				END END ASC
			,CASE WHEN @SortBy = 'ReceiverName' AND @SortOrder = 'DESC' THEN 
				CASE 
					WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = ood.OwnerId THEN ood.OwnerFullName
					WHEN nm.NotificationType = 'BusinessInsights' AND nm.EntityID = T.TenantId THEN CONCAT(ISNULL(T.FirstName, ''), ' ', ISNULL(T.LastName, ''))
					ELSE c.FirstName
				END END DESC
			,CASE WHEN @SortBy = 'ReceiverEmail' AND @SortOrder = 'ASC' THEN ReceiverEmail END ASC
			,CASE WHEN @SortBy = 'ReceiverEmail' AND @SortOrder = 'DESC' THEN ReceiverEmail END DESC
			,CASE WHEN @SortBy = 'ReceiverPhone' AND @SortOrder = 'ASC' THEN ReceiverMobile END ASC
			,CASE WHEN @SortBy = 'ReceiverPhone' AND @SortOrder = 'DESC' THEN ReceiverMobile END DESC
			,CASE WHEN @SortBy = 'Status' AND @SortOrder = 'ASC' THEN nm.STATUS END ASC
			,CASE WHEN @SortBy = 'Status' AND @SortOrder = 'DESC' THEN nm.STATUS END DESC
			,CASE WHEN @SortBy = 'CreatedOn' AND @SortOrder = 'ASC' THEN nm.CreatedDate END ASC
			,CASE WHEN @SortBy = 'CreatedOn' AND @SortOrder = 'DESC' THEN nm.CreatedDate END DESC 
			OFFSET(@PageIndex - 1) * @PageSize ROWS

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

