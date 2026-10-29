
/*  
EXEC [dbo].[DeliverOrderSetItem]  
    @TenantId = 1207,  
    @ProductId = 402789,  
    @OrderSetItemId = 446052,  
    @OrderId = 260537,  
    @UserId = 13305,  
    @WarehouseDetails = '[  
        {  
            "WarehouseId": 10259,  
            "DeliverQuantity": 10.00  
        }  
    ]',  
    @Comment = NULL;  
*/
CREATE PROCEDURE [dbo].[DeliverOrderSetItem] (
	@TenantId INT
	,@ProductId BIGINT
	,@OrderSetItemId BIGINT
	,@OrderId BIGINT
	,@UserId INT
	,@WarehouseDetails VARCHAR(MAX)
	,@Comment VARCHAR(MAX) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	DECLARE @IsRestrictDeliveryWithoutFullPayment BIT
		,@ReturnStatus BIT = 0
		,@ReturnMessage VARCHAR(512) = ''
		,@ReturnOrderId BIGINT = @OrderId
		,@ReceivedAmount NUMERIC(18, 2) = 0
		,@TotalAmt NUMERIC(18, 2)
		,@CheckProductStock BIT
		,@CheckRawMaterialStock BIT
		,@ProductSubjectTypeId INT
		,@ProductQuantitiesSubjectTypeId INT
		,@FabricSubjectTypeId INT
		,@RawMaterialSubjectTypeId INT
		,@RawMaterialInventorySubjectTypeId INT
		,@StockAvailable INT
		,@OrderNo VARCHAR(20)
		,@DT DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@DTUTC DATETIME = GETUTCDATE()
		,@OrderSetItemSubjectTypeId INT
		,@WarehouseName VARCHAR(200)
		,@OrderSubjectTypeId INT
		,@ProductTitle VARCHAR(150)
		,@CategoryTypeId INT
		,@WarehouseId BIGINT
		,@Description VARCHAR(500)
		,@ProvidedQuantity NUMERIC(18, 2)
		,@PQResult INT
		,@ActivityDescription VARCHAR(MAX);

	DROP TABLE IF EXISTS #orderSetItemByOrderId;

	DROP TABLE IF EXISTS #OrderProductQuantity;

	DROP TABLE IF EXISTS #WarehouseDeliverDetails;

	DROP TABLE IF EXISTS #ProductStockByWarehouse;

	DROP TABLE IF EXISTS #RawMaterials;

	DROP TABLE IF EXISTS #RawMaterialQuantityDeduction;

	DROP TABLE IF EXISTS #RawMaterialInventory;

		SELECT @IsRestrictDeliveryWithoutFullPayment = IsRestrictDeliveryWithoutFullPayment
			,@CheckProductStock = CheckProductStock
			,@CheckRawMaterialStock = CheckRawMaterialStock
		--,@IsAutoManufacture = IsAutoManufacture  
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId

	SELECT @ReceivedAmount = Round(SUM(ReceivedAmount), 0)
	FROM Payments WITH (NOLOCK)
	WHERE OrderId = @OrderId
		AND PaymentStatus = 1
		AND IsDeleted = 0

	SELECT @TotalAmt = Round(TotalAmt, 0)
		,@OrderNo = OrderNo
	FROM Orders WITH (NOLOCK)
	WHERE OrderId = @OrderId

	SELECT @ProductTitle = ProductTitle
		,@CategoryTypeId = CategoryTypeId
	FROM Products PT WITH (NOLOCK)
	INNER JOIN Categories CT WITH (NOLOCK) ON PT.CategoryId = CT.CategoryId
	WHERE ProductId = @ProductId;

	IF NOT EXISTS (
			SELECT 1
			FROM OrderSetItems WITH (NOLOCK)
			WHERE OrderSetItemId = @OrderSetItemId
				AND OrderId = @OrderId
				AND IsDeleted = 0
			)
	BEGIN
		SET @ReturnStatus = 0
		SET @ReturnMessage = 'Order set item details not found.'

		SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]
			,@ReturnMessage AS [ReturnMessage]
			,@ReturnOrderId AS [ReturnOrderId]

		RETURN
	END

	IF @IsRestrictDeliveryWithoutFullPayment = 1
		AND ISNULL(@ReceivedAmount, 0) < ISNULL(@TotalAmt, 0)
	BEGIN
		SET @ReturnStatus = 0
		SET @ReturnMessage = 'Delivery cannot be processed until the full payment is received.'

		SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]
			,@ReturnMessage AS [ReturnMessage]
			,@ReturnOrderId AS [ReturnOrderId]

		RETURN
	END

	SELECT CAST(j.WarehouseId AS INT) AS WarehouseId
		,CAST(j.Quantity AS NUMERIC(18, 2)) AS Quantity
	INTO #WarehouseDeliverDetails
	FROM OPENJSON(@WarehouseDetails) WITH (
			WarehouseId INT '$.WarehouseId'
			,Quantity NUMERIC(18, 2) '$.DeliverQuantity'
			) j;

	IF NOT EXISTS (
			SELECT 1
			FROM #WarehouseDeliverDetails
			)
	BEGIN
		SET @ReturnStatus = 0
		SET @ReturnMessage = 'No delivery details provided.'

		SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]
			,@ReturnMessage AS [ReturnMessage]
			,@ReturnOrderId AS [ReturnOrderId]

		RETURN;
	END

	-- Manage Product Quantity    
	SELECT @productSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT @productQuantitiesSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'ProductQuantity'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT @FabricSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Fabrics'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT @RawMaterialSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'RawMaterials'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT @RawMaterialInventorySubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'RawMaterialInventory'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT @OrderSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Orders'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT *
	INTO #orderSetItemByOrderId
	FROM OrderSetItems OSI WITH (NOLOCK)
	WHERE OrderId = @OrderId
		AND IsDeleted = 0
		AND OrderSetItemId = @OrderSetItemId;

	SELECT @OrderSetItemSubjectTypeId = SubjectTypeId
	FROM #orderSetItemByOrderId
	WHERE OrderSetItemId = @OrderSetItemId

	CREATE TABLE #UnmappedWarehouses (
		Id INT IDENTITY(1, 1)
		,WarehouseId INT
		,WareHouseName VARCHAR(50)
		);

	-- Identify warehouses selected in delivery that are NOT mapped in ProductQuantitiesByWarehouse  
	INSERT INTO #UnmappedWarehouses (
		WarehouseId
		,WareHouseName
		)
	SELECT WD.WarehouseId
		,W.Name
	FROM #WarehouseDeliverDetails WD
	INNER JOIN Warehouse w ON WD.WarehouseId = w.Id
	WHERE NOT EXISTS (
			SELECT 1
			FROM ProductQuantitiesByWarehouse PQW WITH (NOLOCK)
			WHERE PQW.ProductId = @ProductId
				AND PQW.WarehouseId = WD.WarehouseId
			);

	DECLARE @Inc INT = 1
	DECLARE @Cnt INT = 0
	DECLARE @MWarehouseId BIGINT;
	DECLARE @MWarehouseName VARCHAR(50);

	SELECT @Cnt = COUNT(1)
	FROM #UnmappedWarehouses;

	WHILE @Cnt >= @Inc
	BEGIN
		SELECT @MWarehouseId = WarehouseId
			,@MWarehouseName = WareHouseName
		FROM #UnmappedWarehouses
		WHERE Id = @Inc;

		SET @Description = 'Inventory record created with as initial quantity of 0.00 in the' + @MWarehouseName + 'warehouse during delivery.'

		EXEC dbo.PopulateProductWarehouseQuantity @TenantId = @TenantId
			,@UserId = @UserId
			,@ProductId = @ProductId
			,@WarehouseId = @MWarehouseId
			,@Quantity = 0
			,@Description = @Description;

		SET @Inc = @Inc + 1;
	END;

	DROP TABLE IF EXISTS #UnmappedWarehouses;

		SELECT PQW.ProductQuantityByWarehouseId
			,PQW.WarehouseId
			,PQW.Quantity AS WarehouseQuantity
			,WD.Quantity AS ProvidedQuantity
			,ROW_NUMBER() OVER (
				ORDER BY ProductQuantityByWarehouseId
				) AS Rn
		INTO #ProductStockByWarehouse
		FROM ProductQuantitiesByWarehouse PQW WITH (NOLOCK)
		INNER JOIN #WarehouseDeliverDetails WD ON PQW.WarehouseId = WD.WarehouseId
		INNER JOIN #orderSetItemByOrderId OSI ON OSI.SubjectId = PQW.ProductId
		WHERE OSI.OrderSetItemId = @OrderSetItemId

	CREATE TABLE #RawMaterials (
		Seq INT IDENTITY
		,RawMaterialId INT
		)

	INSERT INTO #RawMaterials (RawMaterialId)
	SELECT DISTINCT pm.SubjectId AS RawMaterialId
	FROM ProductMaterials PM WITH (NOLOCK)
	INNER JOIN #orderSetItemByOrderId OSI ON OSI.SubjectId = PM.ProductId
	WHERE OSI.OrderSetItemId = @OrderSetItemId
		AND PM.SubjectTypeId = @RawMaterialSubjectTypeId

	SELECT PM.SubjectId AS RawMaterialId
		,SUM(OSI.Quantity * PM.Qty) AS ProvidedQuantity
	INTO #RawMaterialQuantityDeduction
	FROM ProductMaterials PM WITH (NOLOCK)
	INNER JOIN #orderSetItemByOrderId OSI ON OSI.SubjectId = PM.ProductId
	WHERE OSI.OrderSetItemId = @OrderSetItemId
		AND PM.SubjectTypeId = @RawMaterialSubjectTypeId
	GROUP BY PM.SubjectId

	SET @Cnt = 0
	SET @Inc = 1

	SELECT @Cnt = COUNT(RawMaterialId)
	FROM #RawMaterials

	CREATE TABLE #RawMaterialInventory (
		RawMaterialInventoryByWarehouseId BIGINT
		,RawMaterialId BIGINT
		,WarehouseId BIGINT
		,Quantity NUMERIC(18, 2)
		)

	WHILE @Inc <= @Cnt
	BEGIN
		INSERT INTO #RawMaterialInventory (
			RawMaterialInventoryByWarehouseId
			,RawMaterialId
			,WarehouseId
			)
		SELECT TOP 1 RM.RawMaterialInventoryByWarehouseId
			,RM.RawMaterialId
			,RM.WarehouseId
		FROM RawMaterialInventoryByWarehouse RM WITH (NOLOCK)
		INNER JOIN #RawMaterials RMI ON RMI.RawMaterialId = RM.RawMaterialId
		WHERE RMI.Seq = @Inc
		ORDER BY RawMaterialInventoryByWarehouseId ASC

		SET @Inc = @Inc + 1
	END

	BEGIN TRY
		DECLARE @CurrentItemStatus INT;

		SELECT @CurrentItemStatus = ItemStatus
		FROM dbo.OrderSetItems WITH (
				UPDLOCK
				,HOLDLOCK
				)
		WHERE OrderSetItemId = @OrderSetItemId
			AND OrderId = @OrderId
			AND IsDeleted = 0;

		IF @CurrentItemStatus IS NULL
		BEGIN
			;THROW 50001
				,'Order item not found.'
				,1;
		END

		IF @CurrentItemStatus = 3
		BEGIN
			;THROW 50002
				,'This order item has already been delivered.'
				,1;
		END

		BEGIN TRAN DeliverOrderSetItem

		IF @OrderSetItemSubjectTypeId = @ProductSubjectTypeId
		BEGIN
			-- IF @CheckProductStock = 1  
			--  OR @CheckRawMaterialStock = 1  
			-- BEGIN  
			--  IF EXISTS (  
			--    SELECT 1  
			--    FROM #ProductStockByWarehouse  
			--    WHERE (WarehouseQuantity - ProvidedQuantity) < 0  
			--    )  
			--  BEGIN  
			--   SELECT TOP 1 @WarehouseName = W.Name  
			--   FROM #ProductStockByWarehouse PSW  
			--   INNER JOIN Warehouse W ON W.Id = PSW.WarehouseId  
			--   WHERE (WarehouseQuantity - ProvidedQuantity) < 0  
			--   ROLLBACK TRAN  
			--   SET @ReturnMessage = 'You have Maintain Positive Product Inventory enabled — ' + @WarehouseName + ' has no stock'  
			--   SET @ReturnStatus = 0;  
			--   SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]  
			--    ,@ReturnMessage AS [ReturnMessage]  
			--    ,@ReturnOrderId AS [ReturnOrderId];  
			--   RETURN;  
			--  END  
			-- END  
			--UPDATE pqw  
			--SET pqw.Quantity = pqw.Quantity - PSW.ProvidedQuantity  
			-- ,pqw.LastModifiedBy = @UserId  
			-- ,pqw.LastModifiedDate = @DT  
			-- ,pqw.LastModifiedUTCDate = @DTUTC  
			--FROM ProductQuantitiesByWarehouse pqw  
			--INNER JOIN #ProductStockByWarehouse PSW ON PQW.ProductQuantityByWarehouseId = PSW.ProductQuantityByWarehouseId  
			DECLARE @Count INT = 0
			DECLARE @Id INT = 1

			SELECT @Count = COUNT(ProductQuantityByWarehouseId)
			FROM #ProductStockByWarehouse

			WHILE @Id <= @Count
			BEGIN
				SELECT @WarehouseId = NULL;

				SELECT @Description = NULL

				SELECT @WarehouseName = NULL

				SELECT @WarehouseId = PSW.WarehouseId
					,@Description = 'Delivered ' + CAST((PSW.ProvidedQuantity) AS NVARCHAR(100)) + ' quantity from the ' + WH.Name + ' warehouse for order ' + CAST(@OrderNo AS NVARCHAR(50))
					,@ProvidedQuantity = PSW.ProvidedQuantity
					,@WarehouseName = WH.Name
				FROM ProductQuantitiesByWarehouse pqw
				INNER JOIN #ProductStockByWarehouse PSW ON PQW.ProductQuantityByWarehouseId = PSW.ProductQuantityByWarehouseId
				INNER JOIN Warehouse WH ON WH.Id = pqw.WarehouseId
				WHERE PSW.Rn = @Id

				EXEC dbo.DeductProductWarehouseQuantity @TenantId = @TenantId
					,@UserId = @UserId
					,@ProductId = @ProductId
					,@WarehouseId = @WarehouseId
					,@OrderNo = @OrderNo
					,@Quantity = @ProvidedQuantity
					,@Description = @Description
					,@Result = @PQResult OUTPUT

				IF @PQResult = - 1
				BEGIN
					IF XACT_State() <> 0
						ROLLBACK TRANSACTION

					SET @ReturnMessage = 'You have Maintain Positive Product Inventory enabled — ' + @WarehouseName + ' has no stock'
					SET @ReturnStatus = 0;

					SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]
						,@ReturnMessage AS [ReturnMessage]
						,@ReturnOrderId AS [ReturnOrderId];

					RETURN;
				END
				ELSE IF @PQResult <> 1
				BEGIN
					IF XACT_State() <> 0
						ROLLBACK TRANSACTION

					SET @ReturnMessage = 'Unable to deduct product quantity for warehouse ' + @WarehouseName + '.'
					SET @ReturnStatus = 0;

					SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]
						,@ReturnMessage AS [ReturnMessage]
						,@ReturnOrderId AS [ReturnOrderId];

					RETURN;
				END

				--EXEC PopulateInventoryLogs  
				--@ProductId = @ProductId  
				--,@WarehouseId = @WarehouseId      
				--,@Description = @Description  
				--,@OrderNo = @OrderNo  
				--,@InwardNo = NULL  
				--,@PurchaseOrderNo = NULL  
				--,@Remarks = NULL  
				--,@UserId = @UserId  
				--,@CreatedDate = @DT  
				--,@CreatedUTCDate = @DTUTC  
				SET @Id = @Id + 1
			END

			UPDATE RMIW
			SET Quantity = RMIW.Quantity - RMQ.ProvidedQuantity
				,LastModifiedBy = @UserId
				,LastModifiedDate = @DT
				,LastModifiedUTCDate = @DTUTC
			FROM RawMaterialInventoryByWarehouse rmiw
			INNER JOIN #RawMaterialInventory RMI ON RMI.RawMaterialInventoryByWarehouseId = RMIW.RawMaterialInventoryByWarehouseId
			INNER JOIN #RawMaterialQuantityDeduction RMQ ON RMQ.RawMaterialId = RMI.RawMaterialId

			SET @Inc = 1;
			SET @Cnt = 0;

			DECLARE @SubjectId BIGINT;

			CREATE TABLE #ActivityLog (
				RowId INT IDENTITY(1, 1)
				,SubjectId BIGINT
				,Description VARCHAR(MAX)
				);

			INSERT INTO #ActivityLog (
				SubjectId
				,Description
				)
			SELECT RMIW.RawMaterialInventoryByWarehouseId
				,'RawMaterial Inventory has been updated from ' + CAST(RMIW.Quantity + RMQ.ProvidedQuantity AS NVARCHAR(100)) + ' to ' + CAST((RMIW.Quantity) AS NVARCHAR(100)) + ' (-' + CAST((RMQ.ProvidedQuantity) AS NVARCHAR(100)) + ') for order ' + CAST(@OrderNo AS NVARCHAR(500))
			FROM RawMaterialInventoryByWarehouse rmiw
			INNER JOIN #RawMaterialInventory RMI ON RMI.RawMaterialInventoryByWarehouseId = RMIW.RawMaterialInventoryByWarehouseId
			INNER JOIN #RawMaterialQuantityDeduction RMQ ON RMQ.RawMaterialId = RMI.RawMaterialId;

			SELECT @Cnt = COUNT(1)
			FROM #ActivityLog;

			WHILE @Cnt >= @Inc
			BEGIN
				SELECT @SubjectId = SubjectId
					,@ActivityDescription = Description
				FROM #ActivityLog
				WHERE RowId = @Inc;

				EXEC dbo.SaveActivityLog @SubjectTypeId = @RawMaterialInventorySubjectTypeId
					,@SubjectId = @SubjectId
					,@Description = @ActivityDescription
					,@Action = 'UPDATE'
					,@CreatedBy = @UserId
					,@CreatedDate = @DT
					,@CreatedUTCDate = @DTUTC;

				SET @Inc = @Inc + 1;
			END;

			DROP TABLE #ActivityLog;

			INSERT INTO OrderDeliveryDetails (
				ProductId
				,OrderId
				,OrderSetItemId
				,WarehouseId
				,DeliverQuantity
				,LastModifiedBy
				,LastModifiedDate
				,LastModifiedUTCDate
				)
			SELECT @ProductId
				,@OrderId
				,@OrderSetItemId
				,w.WarehouseId
				,w.Quantity
				,@UserId
				,@DT
				,@DTUTC
			FROM #WarehouseDeliverDetails w;
		END

		UPDATE OrderSetItems
		SET ItemStatus = 3 -- OrderSetItemsStatus.Delivered  
			,DeliveryComment = @Comment
			,UpdatedBy = @UserId
			,UpdatedDate = @DT
			,UpdatedUTCDate = @DTUTC
			,DeliveryDate = @DT
		WHERE OrderSetItemId = @OrderSetItemId;

		UPDATE OrderSetItems
		SET ItemStatus = 3 -- OrderSetItemsStatus.Delivered  
			,DeliveryComment = @Comment
			,UpdatedBy = @UserId
			,UpdatedDate = @DT
			,UpdatedUTCDate = @DTUTC
			,DeliveryDate = @DT
		WHERE ParentOrderSetItemId = @OrderSetItemId;

		/*  
  IF EXISTS (SELECT 1 FROM POProductItems WHERE VendorOrderSetItemId = @OrderSetItemId)  
  BEGIN  
  
   UPDATE POProductItems  
   set Status = 5  -- MaterialReady  
   where VendorOrderSetItemId = @OrderSetItemId  
  END  
  IF NOT EXISTS (  
    SELECT 1  
    FROM POProductItems POI WITH (NOLOCK)  
    INNER JOIN POProducts PO WITH (NOLOCK) ON POI.POProductId = PO.POProductId   
    WHERE VendorOrderId = @OrderId  
     AND POI.Status <> 5  
    )  
  BEGIN  
  
   UPDATE POProducts  
   SET Status = 5  
   WHERE VendorOrderId = @OrderId  
  
  END  
  */
		SET @ActivityDescription = ''
		SET @ActivityDescription = CASE 
				WHEN @CategoryTypeId = 2
					THEN 'Fabric'
				ELSE 'Product'
				END + ' ' + @ProductTitle + ' has been Delivered.';

		EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = @ActivityDescription
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC;

		IF NOT EXISTS (
				SELECT 1
				FROM OrderSetItems WITH (NOLOCK)
				WHERE OrderId = @OrderId
					AND ItemStatus <> 3
					AND IsDeleted = 0
				)
		BEGIN
			UPDATE Orders
			SET Status = 5 -- OrderStatusEnum.Delivered  
				,UpdatedBy = @UserId
				,UpdatedDate = @DT
				,UpdatedUTCDate = @DTUTC
				,DeliveryDate = @DT
			WHERE OrderId = @OrderId;

			EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
				,@SubjectId = @OrderId
				,@Description = 'Inquiry status has been changed to Delivered.'
				,@Action = 'UPDATE'
				,@CreatedBy = @UserId
				,@CreatedDate = @DT
				,@CreatedUTCDate = @DTUTC;
		END

		UPDATE OrderManufacturingWorkflows
		SET ManufacturingStatus = 2 -- OrderManufacturingWorkFlowEnum.Completed  
			,UpdatedBy = @UserId
			,UpdatedDate = @DT
			,UpdatedUTCDate = @DTUTC
		WHERE OrderSetItemId = @OrderSetItemId
			AND OrderId = @OrderId;

		INSERT INTO ManufacturingActivityLogs (
			OrderManufacturingWorkflowId
			,Description
			,Action
			,ManufacturingWorkflowId
			,ProductId
			,CreatedBy
			)
		SELECT OMW.OrderManufacturingWorkflowId
			,'Manufacturing Order has been Delivered.'
			,'UPDATE'
			,OMW.ManufacturingWorkflowId
			,@ProductId
			,@UserId
		FROM OrderManufacturingWorkflows OMW
		WHERE OMW.OrderSetItemId = @OrderSetItemId
			AND OMW.OrderId = @OrderId;

		SET @ReturnStatus = 1
		SET @ReturnMessage = 'Selected items have been delivered successfully.'

		SELECT CAST(@ReturnStatus AS BIT) AS [ReturnCode]
			,@ReturnMessage AS [ReturnMessage]
			,@ReturnOrderId AS [ReturnOrderId]

		COMMIT TRAN DeliverOrderSetItem
	END TRY

	BEGIN CATCH
		IF XACT_State() <> 0
			ROLLBACK TRANSACTION

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		-- Append TenantId and OrderId to the description saved in DBErrorLog
		SET @ErrorMsg = @ErrorMsg + ' | TenantId: ' + ISNULL(CAST(@TenantId AS VARCHAR(20)), 'NULL')
			+ ' | OrderId: ' + ISNULL(CAST(@OrderId AS VARCHAR(20)), 'NULL');

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		SELECT CAST(0 AS BIT) AS [ReturnCode]
			,ERROR_MESSAGE() AS [ReturnMessage]
			,@ReturnOrderId AS [ReturnOrderId]
	END CATCH
END

GO

