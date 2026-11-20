/*

EXEC GetOrderManufacturingNotificationData
    @OrderId = 10776
    ,@TenantId = 2

*/
CREATE   PROCEDURE [dbo].[GetOrderManufacturingNotificationData] (
	@OrderId BIGINT
	,@TenantId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SET NOCOUNT ON;;

	WITH WorkflowCTE
	AS (
		SELECT OSI.OrderSetItemId
			,AU.RegisteredFCMToken
			,T.TenantName
			,ORD.OrderNo
			,P.ProductTitle
			,OMWF.OrderManufacturingWorkflowId
			,OMWF.ManufacturingStatus
			,PWF.Position
			,ROW_NUMBER() OVER (
				PARTITION BY OSI.OrderSetItemId ORDER BY PWF.Position ASC
				) AS rn
		FROM OrderSetItems OSI WITH (NOLOCK)
		INNER JOIN Orders ORD WITH (NOLOCK) ON ORD.OrderId = OSI.OrderId
		INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId = ORD.TenantId
		INNER JOIN ProductWorkflows PWF WITH (NOLOCK) ON PWF.ProductID = OSI.SubjectId
		INNER JOIN ManufacturingWorkflows MWF WITH (NOLOCK) ON PWF.ManufacturingWorkflowId = MWF.ManufacturingWorkflowId
			AND MWF.TenantId = @TenantId
			AND MWF.SendPushNotification = 1
		INNER JOIN OrderManufacturingWorkflows OMWF WITH (NOLOCK) ON OSI.OrderSetItemId = OMWF.OrderSetItemId
			AND OSI.OrderId = OMWF.OrderId
			AND PWF.ManufacturingWorkflowId = OMWF.ManufacturingWorkflowId
		INNER JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = PWF.ContractorUserID
		INNER JOIN Products P WITH (NOLOCK) ON OSI.SubjectId = P.ProductId
		WHERE ORD.OrderId = @OrderId
			AND ORD.TenantId = @TenantId
		)
	SELECT TenantName
		,RegisteredFCMToken
		,CONCAT (
			'You have new order for '
			,OrderNo
			,'_'
			,OrderSetItemId
			) AS Body
		,OrderManufacturingWorkflowId
		,OrderNo
		,ProductTitle
		,CASE ManufacturingStatus
			WHEN 0
				THEN 'Pending'
			WHEN 1
				THEN 'InProgress'
			WHEN 2
				THEN 'Completed'
			WHEN 3
				THEN 'Rejected'
			WHEN 4
				THEN 'Submit'
			WHEN 5
				THEN 'Approve'
			WHEN 6
				THEN 'Declined'
			END AS STATUS
	FROM WorkflowCTE
	WHERE rn = 1
	AND RegisteredFCMToken IS NOT NULL
	ORDER BY Position ASC;

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

