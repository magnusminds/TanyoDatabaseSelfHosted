/*
	EXEC [dbo].[Job_GetApprovedOrdersWithManufacturingNotifications]
*/
CREATE PROCEDURE [dbo].[Job_GetApprovedOrdersWithManufacturingNotifications]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @CurrentDate DATETIMEOFFSET
		,@FutureDate DATETIMEOFFSET;

	SET @CurrentDate = CAST(CAST(SYSDATETIMEOFFSET() AS VARCHAR(10)) + ' 00:00:00.0000001 +05:30' AS DATETIMEOFFSET);
	SET @FutureDate = CAST(CAST(DATEADD(DAY, 6, SYSDATETIMEOFFSET()) AS VARCHAR(10)) + ' 23:59:59.9999999 +05:30' AS DATETIMEOFFSET);

	SELECT o.OrderId
		,o.OrderNo
		,aut.FirstName + ' ' + aut.LastName AS SalesmanName
		,cust.FirstName + ' ' + ISNULL(cust.LastName, '') AS CustomerName
		,cust.PhoneNumber
		,o.TentativeDeliveryDate
		,aut.UserId AS SalesmanId
		,o.Comments AS Message
		,o.TenantId
		,t.TenantName
		,aut.RegisteredFCMToken
		,omw.OrderManufacturingWorkflowId AS EntityId
		,st.SubjectTypeId AS EntityTypeId
		,omw.ManufacturingDeliveryDate
		,omw.SupervisorUserID
		,omw.ContractorUserID
		,ISNULL(osi.DeliveryNo, '') AS DeliveryNo
	FROM dbo.Orders o WITH (NOLOCK)
	INNER JOIN dbo.Customers cust WITH (NOLOCK) ON o.CustomerID = cust.CustomerId
		AND cust.IsDeleted = 0
	INNER JOIN dbo.AspNetUsers aut WITH (NOLOCK) ON o.CreatedBy = aut.UserId
		AND aut.IsActive = 1
		AND aut.IsDeleted = 0
	INNER JOIN dbo.Tenants t WITH (NOLOCK) ON t.TenantId = o.TenantId
		AND t.IsDeleted = 0
	INNER JOIN dbo.OrderManufacturingWorkflows omw WITH (NOLOCK) ON omw.OrderId = o.OrderId
		AND omw.ManufacturingDeliveryDate >= @CurrentDate
		AND omw.ManufacturingDeliveryDate <= @FutureDate
	INNER JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderSetItemId = omw.OrderSetItemId
		AND osi.IsDeleted = 0
	INNER JOIN dbo.SubjectTypes st WITH (NOLOCK) ON st.SubjectTypeName = 'ManufacturingOrders'
		AND st.TenantId = t.TenantId
		AND st.IsDeleted = 0
	WHERE o.STATUS IN (
			2
			,3
			)
		AND ISNULL(aut.RegisteredFCMToken, '') <> ''
	ORDER BY o.TentativeDeliveryDate
		,cust.FirstName + ' ' + cust.LastName;

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

