/*
EXEC dbo.GetOrderNotificationData
	@TenantId = 2
	,@OrderId = 1
	,@PageIndex = 1
	,@PageSize = 25
	,@SortBy = 'CreatedDate'
	,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[GetOrderNotificationData] (
	@TenantId INT
	,@OrderId BIGINT
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @OrderSubjectTypeId BIGINT;

	SELECT @OrderSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Orders'
		AND TenantId = @TenantId;

	SELECT NM.NotificationManagementID
		,NM.NotificationType
		,NM.NotificationMethod
		,ISNULL(CO.FirstName, '') + ' ' + ISNULL(CO.LastName, '') AS ReceiverName
		,NM.ReceiverEmail
		,NM.ReceiverMobile
		,NM.MessageSubject
		,NM.MessageBody
		,NM.STATUS
		,NM.CreatedDate
		,NM.UpdatedDate
		,ORD.OrderNo AS Entity
		,ORD.OrderId
		,COUNT(*) OVER () AS TotalCount
	FROM NotificationManagement NM WITH (NOLOCK)
	INNER JOIN Orders ORD WITH (NOLOCK) ON NM.EntityID = ORD.OrderId
		AND ORD.TenantId = NM.TenantId
		AND ORD.STATUS <> 9
	INNER JOIN Customers CO WITH (NOLOCK) ON ORD.CustomerID = CO.CustomerId
		AND CO.TenantId = ORD.TenantId
	WHERE NM.TenantId = @TenantId
		AND NM.EntityTypeID = @OrderSubjectTypeId
		AND (NM.EntityID = @OrderId)
	ORDER BY CASE 
			WHEN @SortBy = 'CreatedOn'
				AND @SortOrder = 'ASC'
				THEN NM.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'CreatedOn'
				AND @SortOrder = 'DESC'
				THEN NM.CreatedDate
			END DESC
		,CASE 
			WHEN @SortBy = 'NotificationType'
				AND @SortOrder = 'ASC'
				THEN NM.NotificationType
			END ASC
		,CASE 
			WHEN @SortBy = 'NotificationType'
				AND @SortOrder = 'DESC'
				THEN NM.NotificationType
			END DESC
		,CASE 
			WHEN @SortBy = 'NotificationMethod'
				AND @SortOrder = 'ASC'
				THEN NM.NotificationMethod
			END ASC
		,CASE 
			WHEN @SortBy = 'NotificationMethod'
				AND @SortOrder = 'DESC'
				THEN NM.NotificationMethod
			END DESC
		,CASE 
			WHEN @SortBy = 'ReceiverName'
				AND @SortOrder = 'ASC'
				THEN ISNULL(CO.FirstName, '') + ' ' + ISNULL(CO.LastName, '')
			END ASC
		,CASE 
			WHEN @SortBy = 'ReceiverName'
				AND @SortOrder = 'DESC'
				THEN ISNULL(CO.FirstName, '') + ' ' + ISNULL(CO.LastName, '')
			END DESC
		,CASE 
			WHEN @SortBy = 'ReceiverEmail'
				AND @SortOrder = 'ASC'
				THEN NM.ReceiverEmail
			END ASC
		,CASE 
			WHEN @SortBy = 'ReceiverEmail'
				AND @SortOrder = 'DESC'
				THEN NM.ReceiverEmail
			END DESC
		,CASE 
			WHEN @SortBy = 'ReceiverPhone'
				AND @SortOrder = 'ASC'
				THEN NM.ReceiverMobile
			END ASC
		,CASE 
			WHEN @SortBy = 'ReceiverPhone'
				AND @SortOrder = 'DESC'
				THEN NM.ReceiverMobile
			END DESC
		,CASE 
			WHEN @SortBy = 'Status'
				AND @SortOrder = 'ASC'
				THEN NM.STATUS
			END ASC
		,CASE 
			WHEN @SortBy = 'Status'
				AND @SortOrder = 'DESC'
				THEN NM.STATUS
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

