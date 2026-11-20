CREATE PROCEDURE [dbo].[DeleteOrderDetailsByTenant] (@TenantId INT)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	DROP TABLE IF EXISTS #Orders

	SELECT OrderId
	INTO #Orders
	FROM Orders
	WHERE TenantId = @TenantId

	DELETE OC
	FROM OrderComments OC
	INNER JOIN #Orders ORD ON OC.OrderId = ORD.OrderId

	DELETE FL
	FROM FollowUpLeads FL
	INNER JOIN Leads L on L.LeadId = FL.LeadId AND L.TenantId = @TenantId

	DELETE L
	FROM Leads L
	WHERE L.TenantId = @TenantId

	-- Set Item Level

	DELETE OMFWI
	FROM OrderManufacturingWorkflowImages OMFWI
	INNER JOIN OrderManufacturingWorkflows OMFW ON OMFW.OrderManufacturingWorkflowId = OMFWI.OrderManufacturingWorkflowId
	INNER JOIN #Orders ORD ON OMFW.OrderId = ORD.OrderId


	DELETE MFWAL
	FROM ManufacturingActivityLogs MFWAL
	INNER JOIN OrderManufacturingWorkflows OMFW ON OMFW.OrderManufacturingWorkflowId = MFWAL.OrderManufacturingWorkflowId
	INNER JOIN #Orders ORD ON OMFW.OrderId = ORD.OrderId

	DELETE OMFW
	FROM OrderManufacturingWorkflows OMFW
	INNER JOIN #Orders ORD ON OMFW.OrderId = ORD.OrderId

	DELETE PT
	FROM Payments PT
	INNER JOIN #Orders ORD ON PT.OrderId = ORD.OrderId

	DELETE AO
	FROM Archive_Orders AO
	INNER JOIN #Orders ORD ON AO.OrderId = ORD.OrderId

	DELETE OAD
	FROM OrderArchiveDetails OAD
	INNER JOIN #Orders ORD ON OAD.OrderId = ORD.OrderId

	DELETE FO
	FROM FollowUpOrders FO
	INNER JOIN #Orders ORD ON FO.OrderId = ORD.OrderId

	DELETE FO
	FROM FeedbackOrders FO
	INNER JOIN #Orders ORD ON FO.OrderId = ORD.OrderId

	DELETE OAV
	FROM OrderAnonymousViews OAV
	INNER JOIN #Orders ORD ON OAV.OrderId = ORD.OrderId

	DELETE OSU
	FROM OrderShortedURL OSU
	INNER JOIN #Orders ORD ON OSU.OrderId = ORD.OrderId

	DELETE OA
	FROM OrderAttachments OA
	INNER JOIN #Orders ORD ON OA.OrderId = ORD.OrderId

	DELETE AL
	FROM ActivityLogs AL
	INNER JOIN #Orders ORD ON AL.OrderId = ORD.OrderId
		AND (
			Description LIKE '%order price%'
			OR Description LIKE '%Inquiry has been created%'
			OR Description LIKE '%order payment%'
			OR Description LIKE '%Order status has been changed to%'
			OR Description LIKE '%Order has been updated%'
			OR Description LIKE '%added a lumpsum discount of%to the entire order%'
			)

	DELETE OSIM
	FROM OrderSetItemImages OSIM
	INNER JOIN OrderSetItems OSI ON OSIM.OrderSetItemId = OSI.OrderSetItemId
	INNER JOIN #Orders ORD ON OSI.OrderId = ORD.OrderId

	DELETE OS
	FROM OrderAddresses OS
	INNER JOIN #Orders ORD ON OS.OrderId = ORD.OrderId

	DELETE OS
	FROM OrderSets OS
	INNER JOIN #Orders ORD ON OS.OrderId = ORD.OrderId

	DELETE OSI
	FROM OrderSetItems OSI
	INNER JOIN #Orders ORD ON OSI.OrderId = ORD.OrderId

	DELETE OD
	FROM Orders OD
	INNER JOIN #Orders ORD ON OD.OrderId = ORD.OrderId


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

