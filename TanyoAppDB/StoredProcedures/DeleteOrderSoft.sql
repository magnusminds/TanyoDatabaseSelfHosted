/*      
 EXEC [dbo].[DeleteOrderSoft] @OrderId = 84,@TenantId = 2,@DeletedBy = 1    
*/
CREATE PROCEDURE [dbo].[DeleteOrderSoft] (
	 @OrderId VARCHAR(MAX)
	,@TenantId INT
	,@DeletedBy BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Status INT
		,@Message VARCHAR(100)
		,@Error VARCHAR(MAX)
		,@IncOrderId BIGINT
		,@InventoryOrderId BIGINT
		,@OrderStatus INT;

	DROP TABLE IF EXISTS #DelOrder	

	DROP TABLE IF EXISTS #OrderList	

	DROP TABLE IF EXISTS #ResponseData	

	CREATE TABLE #ResponseData (
	Status BIT
	,Message NVARCHAR(max) 
	,JsonObject NVARCHAR(max) 
	,Error	NVARCHAR(max)
	)

	SELECT CAST(TRIM(ORD.value) AS BIGINT) AS OrderId
	INTO #DelOrder
	from STRING_SPLIT(TRIM(@OrderId),',') ORD


	BEGIN TRY
		BEGIN TRAN delOrderDependentData

		DECLARE @SubjectTypeId BIGINT
			,@OrderNo VARCHAR(20)

		SELECT @SubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE TenantId = @TenantId
			AND SubjectTypeName = 'ProductQuantity'

		SELECT ORD.OrderId
			  ,ORD.OrderNo
			  ,ORD.Status
		INTO #OrderList
		FROM Orders ORD WITH (NOLOCK)
		INNER JOIN #DelOrder DORD ON DORD.OrderId = ORD.OrderId

		-- 1. Validate Order Exists
		IF NOT EXISTS (SELECT 1 FROM #DelOrder)
			OR EXISTS (
				SELECT 1
				FROM #DelOrder DORD
				LEFT JOIN #OrderList OL
					ON OL.OrderId = DORD.OrderId
				WHERE OL.OrderId IS NULL
			)
		BEGIN
			SELECT 0 AS [Status],
				'Order not found.' AS [Message],
				NULL AS [Data],
				NULL AS [Error];
			RETURN;
		END

		-- 2. Validate Already Deleted Orders
		IF EXISTS (
			SELECT 1
			FROM #OrderList
			WHERE Status = 9
		)
		BEGIN
			SELECT 0 AS [Status],
				'This order has already been deleted.' AS [Message],
				NULL AS [Data],
				NULL AS [Error];
			RETURN;
		END

		-- Check Stock on Hold and Release if any
		DECLARE @Temp_OrderSetItems TABLE
		(
			ID INT PRIMARY KEY IDENTITY
			,OrderSetItemId BIGINT
			,OrderId BIGINT
			,OrderNo VARCHAR(20)
			,SubjectId BIGINT
			,SubjectTypeId INT
			,OrderStatus INT
		)

		INSERT INTO @Temp_OrderSetItems
		(
			OrderSetItemId
			,OrderId
			,OrderNo
			,SubjectId
			,SubjectTypeId
			,OrderStatus
		)
		SELECT OSI.OrderSetItemId
			  ,OSI.OrderId
			  ,ORDL.OrderNo
			  ,OSI.SubjectId
			  ,OSI.SubjectTypeId
			  ,ORDL.Status
		FROM OrderSetItems OSI WITH (NOLOCK)
		INNER JOIN #OrderList ORDL ON ORDL.OrderId = OSI.OrderId
		
		DECLARE @OrderSetItemId BIGINT
			,@cnt INT
			,@inc INT = 1

		SELECT @cnt = COUNT(1)
		FROM @Temp_OrderSetItems

		WHILE (@cnt >= @inc)
		BEGIN
			SELECT @OrderSetItemId = NULL
			SELECT @IncOrderId = NULL
			SELECT @OrderStatus = NULL

			SELECT @OrderSetItemId = OrderSetItemId
				,@IncOrderId = OrderId
				,@OrderStatus = OrderStatus
			FROM @Temp_OrderSetItems
			WHERE ID = @inc

			IF @OrderStatus >= 2 AND @OrderStatus NOT IN (5,8) --Delivered, Declined
			BEGIN
				INSERT INTO #ResponseData
				EXEC [dbo].[UpdateInventoryByOrderSetItem]
					@OrderSetItemId = @OrderSetItemId
					,@OrderId = @IncOrderId
					,@UserId = @DeletedBy
					,@TenantId = @TenantId

				--IF EXISTS (SELECT 1 FROM #ResponseData WHERE Status = 0)
				--BEGIN
				--	SELECT TOP 1 @Error = Error FROM #ResponseData WHERE Status = 0
				--	RAISERROR('Inventory update failed: %s', 16, 1, @Error)				
				--END
			END

			EXEC [dbo].[ReleaseStockOnHoldByOrderSetItemId]
				@OrderSetItemId = @OrderSetItemId
				,@OrderId = @IncOrderId
				,@UserId = @DeletedBy
		
			SET @inc = @inc + 1
		END

		UPDATE al
		SET AL.Description = LEFT(Description, CASE WHEN (CHARINDEX('for order', Description) - 2)>=0 
									  THEN (CHARINDEX('for order', Description) - 2) 
									  ELSE 
									  CASE WHEN (CHARINDEX('From', Description)-2) >= 0 
									  THEN (CHARINDEX('From', Description)-2)
									  ELSE 
									  CASE WHEN (CHARINDEX('For', Description)-2)>=0 
									  THEN  (CHARINDEX('For', Description)-2) 
								      ELSE (CHARINDEX(ORDL.OrderNo, Description) - 2) END END END)
		FROM InventoryLogs al
		INNER JOIN #OrderList ORDL ON Description LIKE '%' + ORDL.OrderNo + '%'
		WHERE  al.Productid IN (
				SELECT osi.SubjectId AS Productid
				FROM @Temp_OrderSetItems osi 
				INNER JOIN SubjectTypes st WITH (NOLOCK) ON st.SubjectTypeId = osi.SubjectTypeId
					AND st.SubjectTypeName = 'Products'
				--INNER JOIN ProductQuantities pq WITH (NOLOCK) ON pq.ProductId = osi.SubjectId      
				)

		--DELETE WCL
		--FROM dbo.WhatsAppComplaintLogs WCL
		--INNER JOIN #OrderList ORDL ON WCL.OrderId = ORDL.OrderId

		--DELETE al
		--FROM ActivityLogs al
		--INNER JOIN SubjectTypes st ON st.SubjectTypeId = al.SubjectTypeId
		--	AND SubjectTypeName = 'Orders'
		--INNER JOIN #OrderList ORDL ON al.Subjectid = ORDL.OrderId

		--DELETE n
		--FROM Notifications n
		--INNER JOIN SubjectTypes st ON st.SubjectTypeId = n.EntityTypeId
		--	AND SubjectTypeName = 'Orders'
		--INNER JOIN #OrderList ORDL ON n.EntityId = ORDL.OrderId

		--DELETE nm
		--FROM NotificationManagement nm
		--INNER JOIN SubjectTypes st ON st.SubjectTypeId = nm.EntityTypeId
		--	AND SubjectTypeName = 'Orders'
		--INNER JOIN #OrderList ORDL ON nm.EntityId = ORDL.OrderId

		--DELETE 
		--FROM ComplainAttachments 
		--WHERE ComplainId IN 
		--					(
		--						SELECT ComplainId 
		--						FROM Complains CS
		--						INNER JOIN #OrderList ORDL ON CS.OrderId = ORDL.OrderId
		--					)

		--DELETE 
		--FROM ComplainComments 
		--WHERE ComplainId IN 
		--					(
		--						SELECT ComplainId 
		--						FROM Complains CS
		--						INNER JOIN #OrderList ORDL ON CS.OrderId = ORDL.OrderId
		--					)

		--DELETE CS
		--FROM dbo.Complains CS
		--INNER JOIN #OrderList ORDL ON CS.OrderId = ORDL.OrderId

		--DELETE OSU
		--FROM dbo.OrderShortedURL OSU
		--INNER JOIN #OrderList ORDL ON OSU.OrderId = ORDL.OrderId

		--DELETE FBC
		--FROM dbo.FeedbackComments FBC
		--INNER JOIN #OrderList ORDL ON FBC.OrderId = ORDL.OrderId

		--DELETE FBO
		--FROM dbo.FeedbackOrders FBO
		--INNER JOIN #OrderList ORDL ON FBO.OrderId = ORDL.OrderId

		--DELETE FORD
		--FROM dbo.FollowUpOrders FORD
		--INNER JOIN #OrderList ORDL ON FORD.OrderId = ORDL.OrderId


		--DELETE KES
		--FROM dbo.KafkaEmailSending KES
		--INNER JOIN #OrderList ORDL ON KES.OrderId = ORDL.OrderId

		--DELETE OA
		--FROM dbo.OrderAddresses OA
		--INNER JOIN #OrderList ORDL ON OA.OrderId = ORDL.OrderId

		--DELETE OAV
		--FROM dbo.OrderAnonymousViews OAV
		--INNER JOIN #OrderList ORDL ON OAV.OrderId = ORDL.OrderId

		--DELETE OA
		--FROM dbo.OrderAttachments OA
		--INNER JOIN #OrderList ORDL ON OA.OrderId = ORDL.OrderId

		UPDATE OC
		SET OC.Status = 9
		FROM dbo.OrderComments OC 
		INNER JOIN #OrderList ORDL ON OC.OrderId = ORDL.OrderId
		WHERE OC.Status <> 9;

		UPDATE PTS
		SET IsDeleted = 1
			,UpdatedBy = @DeletedBy
			,UpdatedDate = GETDATE()
			,UpdatedUTCDate = GETUTCDATE()
		FROM dbo.Payments PTS
		INNER JOIN #OrderList ORDL ON PTS.OrderId = ORDL.OrderId
		WHERE PTS.IsDeleted = 0;

		--DELETE 
		--FROM OrderSetItemReceivables 
		--WHERE OrderSetItemId IN (SELECT OrderSetItemId FROM @Temp_OrderSetItems)

		--DELETE 
		--FROM OrderSetItemImages 
		--WHERE OrderSetItemId IN (SELECT OrderSetItemId FROM @Temp_OrderSetItems )

		--DELETE AORD
		--FROM dbo.Archive_Orders AORD
		--INNER JOIN #OrderList ORDL ON AORD.OrderId = ORDL.OrderId


		--DELETE AOSI
		--FROM dbo.Archive_OrderSetItems AOSI
		--INNER JOIN #OrderList ORDL ON AOSI.OrderId = ORDL.OrderId


		--DELETE AOS
		--FROM dbo.Archive_OrderSets AOS
		--INNER JOIN #OrderList ORDL ON AOS.OrderId = ORDL.OrderId

		--DELETE 
		--FROM ManufacturingActivityLogs 
		--WHERE ManufacturingWorkflowId IN 
		--								(
		--									SELECT OrderManufacturingWorkflowId 
		--									FROM OrderManufacturingWorkflows OMWFL
		--									INNER JOIN #OrderList ORDL ON OMWFL.OrderId = ORDL.OrderId											
		--								) -- OrderManufacturingWorkflowId

		--DELETE 
		--FROM OrderManufacturingWorkflowImages 
		--WHERE OrderManufacturingWorkflowId IN 
		--										(
		--											SELECT OrderManufacturingWorkflowId 
		--											FROM OrderManufacturingWorkflows OMWFL
		--											INNER JOIN #OrderList ORDL ON OMWFL.OrderId = ORDL.OrderId											
		--										) -- OrderManufacturingWorkflowId


		--DELETE OMWFL
		--FROM dbo.OrderManufacturingWorkflows OMWFL
		--INNER JOIN #OrderList ORDL ON OMWFL.OrderId = ORDL.OrderId											

		--DELETE OPC
		--FROM dbo.OrderProductCharges OPC
		--INNER JOIN #OrderList ORDL ON OPC.OrderId = ORDL.OrderId

		UPDATE OSI
		SET IsDeleted = 1
			,UpdatedBy = @DeletedBy
			,UpdatedDate = GETDATE()
			,UpdatedUTCDate = GETUTCDATE()
		FROM dbo.OrderSetItems OSI
		INNER JOIN #OrderList ORDL ON OSI.OrderId = ORDL.OrderId
		WHERE OSI.IsDeleted = 0;

		UPDATE OS
		SET IsDeleted = 1
			,UpdatedBy = @DeletedBy
			,UpdatedDate = GETDATE()
			,UpdatedUTCDate = GETUTCDATE()
		FROM dbo.OrderSets OS
		INNER JOIN #OrderList ORDL ON OS.OrderId = ORDL.OrderId		
		WHERE OS.IsDeleted = 0;

		--DELETE SOH
		--FROM dbo.StockOnHold SOH
		--INNER JOIN #OrderList ORDL ON SOH.OrderId = ORDL.OrderId	

		UPDATE ORD
		SET STATUS = 9
			,UpdatedBy = @DeletedBy
			,UpdatedDate = GETDATE()
			,UpdatedUTCDate = GETUTCDATE()
		FROM dbo.Orders ORD
		INNER JOIN #OrderList ORDL ON ORD.OrderId = ORDL.OrderId
		WHERE ORD.STATUS <> 9;

		COMMIT TRAN delOrderDependentData

		SET @Status = 1;

		SELECT @Message = 'All the order dependent data has been deleted successfully!';

		SET @Error = NULL;

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,NULL AS [Data]
			,@Error AS [Error]
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
		BEGIN
			ROLLBACK TRAN delOrderDependentData
		END

		SET @Status = 0;

		SELECT @Message = 'Order dependent data not deleted';

		SET @Error = NULL;

		DECLARE @ErrorMsg VARCHAR(MAX)

		SET @ErrorMsg = ERROR_MESSAGE()

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,NULL AS [Data]
			,@ErrorMsg AS [Error]

		RAISERROR (
				'Error in DeleteOrder : %s'
				,15
				,1
				,@ErrorMsg
				)
	END CATCH
END

GO

