CREATE Procedure DeleteDeletedOrders
WITH ENCRYPTION
AS
BEGIN


	BEGIN TRY
/* Take Backup of the data which will going to be be deleted
	SELECT OrderId
	INTO #Orders
	FROM [TanyoApp].dbo.Orders
	WHERE Status= 9

	SELECT OC.* INTO [TanyoTempTable].dbo.[TanyoTempTable].dbo.OrderComments_Deleted_20260831
	FROM [TanyoApp].dbo.OrderComments OC
	INNER JOIN #Orders ORD ON OC.OrderId = ORD.OrderId

	-- Set Item Level

	SELECT OMFWI.* INTO [TanyoTempTable].dbo.OrderManufacturingWorkflowImages_Deleted_20260831
	FROM [TanyoApp].dbo.OrderManufacturingWorkflowImages OMFWI
	INNER JOIN [TanyoApp].dbo.OrderManufacturingWorkflows OMFW ON OMFW.OrderManufacturingWorkflowId = OMFWI.OrderManufacturingWorkflowId
	INNER JOIN #Orders ORD ON OMFW.OrderId = ORD.OrderId


	SELECT  MFWAL.* INTO [TanyoTempTable].dbo.ManufacturingActivityLogs_Deleted_20260831
	FROM [TanyoApp].dbo.ManufacturingActivityLogs MFWAL
	INNER JOIN [TanyoApp].dbo.OrderManufacturingWorkflows OMFW ON OMFW.OrderManufacturingWorkflowId = MFWAL.OrderManufacturingWorkflowId
	INNER JOIN #Orders ORD ON OMFW.OrderId = ORD.OrderId

	SELECT  OMFW.* INTO [TanyoTempTable].dbo.OrderManufacturingWorkflows_Deleted_20260831
	FROM [TanyoApp].dbo.OrderManufacturingWorkflows OMFW
	INNER JOIN #Orders ORD ON OMFW.OrderId = ORD.OrderId

	SELECT  PT.* INTO [TanyoTempTable].dbo.Payments_Deleted_20260831
	FROM [TanyoApp].dbo.Payments PT
	INNER JOIN #Orders ORD ON PT.OrderId = ORD.OrderId

	SELECT  AO.* INTO [TanyoTempTable].dbo.Archive_Orders_Deleted_20260831
	FROM [TanyoApp].dbo.Archive_Orders AO
	INNER JOIN #Orders ORD ON AO.OrderId = ORD.OrderId

	SELECT  OAD.* INTO [TanyoTempTable].dbo.OrderArchiveDetails_Deleted_20260831
	FROM [TanyoApp].dbo.OrderArchiveDetails OAD
	INNER JOIN #Orders ORD ON OAD.OrderId = ORD.OrderId

	SELECT  FO.* INTO [TanyoTempTable].dbo.FollowUpOrders_Deleted_20260831
	FROM [TanyoApp].dbo.FollowUpOrders FO
	INNER JOIN #Orders ORD ON FO.OrderId = ORD.OrderId

	SELECT  FO.* INTO [TanyoTempTable].dbo.FeedbackOrders_Deleted_20260831
	FROM [TanyoApp].dbo.FeedbackOrders FO
	INNER JOIN #Orders ORD ON FO.OrderId = ORD.OrderId

	SELECT  OAV.* INTO [TanyoTempTable].dbo.OrderAnonymousViews_Deleted_20260831
	FROM [TanyoApp].dbo.OrderAnonymousViews OAV
	INNER JOIN #Orders ORD ON OAV.OrderId = ORD.OrderId

	SELECT  OSU.* INTO [TanyoTempTable].dbo.OrderShortedURL_Deleted_20260831
	FROM [TanyoApp].dbo.OrderShortedURL OSU
	INNER JOIN #Orders ORD ON OSU.OrderId = ORD.OrderId

	SELECT  OA.* INTO [TanyoTempTable].dbo.OrderAttachments_Deleted_20260831
	FROM [TanyoApp].dbo.OrderAttachments OA
	INNER JOIN #Orders ORD ON OA.OrderId = ORD.OrderId

	SELECT  AL.* INTO [TanyoTempTable].dbo.ActivityLogs_Deleted_20260831
	FROM [TanyoApp].dbo.ActivityLogs AL
	INNER JOIN #Orders ORD ON AL.OrderId = ORD.OrderId
		AND (
			Description LIKE '%order price%'
			OR Description LIKE '%Inquiry has been created%'
			OR Description LIKE '%order payment%'
			OR Description LIKE '%Order status has been changed to%'
			OR Description LIKE '%Order has been updated%'
			OR Description LIKE '%added a lumpsum discount of%to the entire order%'
			)

	SELECT  OSIM.* INTO [TanyoTempTable].dbo.OrderSetItemImages_Deleted_20260831
	FROM [TanyoApp].dbo.OrderSetItemImages OSIM
	INNER JOIN [TanyoApp].dbo.OrderSetItems OSI ON OSIM.OrderSetItemId = OSI.OrderSetItemId
	INNER JOIN #Orders ORD ON OSI.OrderId = ORD.OrderId

	SELECT  OS.* INTO [TanyoTempTable].dbo.OrderAddresses_Deleted_20260831
	FROM [TanyoApp].dbo.OrderAddresses OS
	INNER JOIN #Orders ORD ON OS.OrderId = ORD.OrderId

	SELECT  OS.* INTO [TanyoTempTable].dbo.OrderSets_Deleted_20260831
	FROM [TanyoApp].dbo.OrderSets OS
	INNER JOIN #Orders ORD ON OS.OrderId = ORD.OrderId

	SELECT  OSI.* INTO [TanyoTempTable].dbo.OrderSetItems_Deleted_20260831
	FROM [TanyoApp].dbo.OrderSetItems OSI
	INNER JOIN #Orders ORD ON OSI.OrderId = ORD.OrderId

	SELECT  OD.* INTO [TanyoTempTable].dbo.Orders_Deleted_20260831
	FROM [TanyoApp].dbo.Orders OD
	INNER JOIN #Orders ORD ON OD.OrderId = ORD.OrderId
*/
	DROP TABLE IF EXISTS #Orders

	SELECT OrderId
	INTO #Orders
	FROM Orders
	WHERE Status= 9

	DELETE OC
	FROM OrderComments OC
	INNER JOIN #Orders ORD ON OC.OrderId = ORD.OrderId

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

