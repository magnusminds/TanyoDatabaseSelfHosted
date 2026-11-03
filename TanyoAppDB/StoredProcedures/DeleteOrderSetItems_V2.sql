/*    
	EXEC [dbo].[DeleteOrderSetItems_V2]
		@OrderSetItemId = 757
		,@DeletedBy = 4279
		,@TenantId = 2
		,@ResultMessage = '' OUTPUT
*/
CREATE PROCEDURE [dbo].[DeleteOrderSetItems_V2] (
	@OrderSetItemId BIGINT
	,@DeletedBy BIGINT
	,@TenantId INT
	,@ResultMessage VARCHAR(500) = '' OUTPUT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Status BIT
		,@Message VARCHAR(200)
		,@OrderId BIGINT
		,@SubjectTypeId INT
		,@ItemType VARCHAR(50)
		,@ProductName VARCHAR(150)
		,@OrderStatus INT
		,@IsQuantityOnHold BIT
		,@cnt INT
		,@ID INT = 1
		,@AddOnOrdersetItemId BIGINT
		,@dtoffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtutc DATETIME = GETUTCDATE()
		,@ActivityDescription NVARCHAR(MAX)
		,@ProductId BIGINT
		,@Quantity NUMERIC(18, 2)
		,@orderNo VARCHAR(50);

	BEGIN TRY
		SELECT @OrderId = OrderId
		FROM OrderSetItems WITH (NOLOCK)
		WHERE OrderSetItemId = @OrderSetItemId

		IF EXISTS (
				SELECT 1
				FROM OrderSetItems osi
				INNER JOIN Orders o ON o.OrderId = osi.OrderId
				WHERE o.OrderId = @OrderId
					AND osi.OrderSetItemId = @orderSetItemId
					AND osi.IsDeleted = 0
					AND osi.ItemSTATUS = 3 --Delivered
				)
		BEGIN
			SET @Status = - 1
			SET @ResultMessage = 'You cannot delete the item from Delivered order.'

			RETURN
		END

		BEGIN TRANSACTION DeleteOrderSetItemsV2

		SELECT @ProductName = p.ProductTitle
			,@OrderId = osi.OrderId
			,@IsQuantityOnHold = IsQuantityOnHold
			,@ProductId = p.ProductId
			,@Quantity = osi.Quantity
			,@orderNo = o.OrderNo
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
		INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
			AND p.TenantId = @TenantId
		WHERE osi.OrderSetItemId = @OrderSetItemId

		DECLARE @AddOnSetItems TABLE
		(
			RowNum INT
			,OrderSetItemId BIGINT
		)

		INSERT INTO @AddOnSetItems
		(
			RowNum
			,OrderSetItemId
		)
		SELECT ROW_NUMBER() OVER (ORDER BY OrderSetItemId) AS RowNum
			,OrderSetItemId
		FROM OrderSetItems WITH (NOLOCK)
		WHERE ParentOrderSetItemId = @OrderSetItemId

		SELECT @OrderStatus = o.STATUS
		FROM Orders o WITH (NOLOCK)
		WHERE o.OrderId = @OrderId

		--First delete Add on Items
		IF EXISTS (
				SELECT 1
				FROM @AddOnSetItems
				)
		BEGIN
			SET @ID = 1

			SELECT @cnt = count(OrderSetItemId)
			FROM @AddOnSetItems

			WHILE @ID <= @cnt
			BEGIN
				SELECT @AddOnOrdersetItemId = 0

				SELECT @AddOnOrdersetItemId = OrderSetItemId
				FROM @AddOnSetItems
				WHERE RowNum = @ID

				EXEC [dbo].[DeleteOrderSetItems_V2] @OrderSetItemId = @AddOnOrdersetItemId
					,@DeletedBy = @DeletedBy
					,@TenantId = @TenantId
					,@ResultMessage = @ResultMessage OUTPUT

				IF @ResultMessage <> ''
				BEGIN
					RAISERROR ('%s',16,1,@ResultMessage)
					RETURN
				END

				SET @ID = @ID + 1
			END
		END

		-- 2. Get SubjectTypeId for 'Orders'  
		SELECT @SubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Orders'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		--Release Stock, if ON HOLD
		IF EXISTS (
				SELECT 1
				FROM OrderSetItems osi WITH (NOLOCK)
				INNER JOIN StockOnHold soh WITH (NOLOCK) ON soh.OrderSetItemId = osi.OrderSetItemId
					AND soh.IsStockOnHold = 1
				WHERE osi.OrderSetItemId = @OrderSetItemId
					AND osi.OrderId = @OrderId
				)
		BEGIN
			EXEC [dbo].[ReleaseStockOnHoldByOrderSetItemId] @OrderSetItemId = @OrderSetItemId
				,@OrderId = @OrderId
				,@UserId = @DeletedBy
		END

		--Increase Quantity if removing product is already Delivered/Declined
		IF @OrderStatus >= 2
			AND @OrderStatus NOT IN (
				5
				,8
				,9
				) --Delivered, Declined, deleted
		BEGIN
			DECLARE @LogDescription VARCHAR(MAX)
			DECLARE @oldQuantity NUMERIC(18, 2);

			SELECT @oldQuantity = pq.Quantity
			FROM ProductQuantities pq
			WHERE pq.ProductID = @ProductId;

			SET @LogDescription = 'Inventory has been updated from ' + CAST(@oldQuantity AS NVARCHAR(100)) + ' to ' + CAST((@oldQuantity + @Quantity) AS NVARCHAR(100)) + ' (+' + CAST(@Quantity AS NVARCHAR(100)) + ') for order ' + CAST(@OrderNo AS NVARCHAR(50))

			-- Add back to ProductQuantities + its own InventoryLogs entry
			EXEC dbo.AddProductSaleableQuantity @TenantId = @TenantId
				,@UserId = @deletedBy
				,@ProductId = @ProductId
				,@Quantity = @Quantity
				,@Description = @LogDescription
		END

		-- 3. Delete Charges  
		DELETE
		FROM OrderProductCharges
		WHERE OrderSetItemId = @OrderSetItemId
			AND OrderId = @OrderId

		DELETE OMWF
		FROM OrderManufacturingWorkflows OMWF
		WHERE OMWF.OrderSetItemId = @OrderSetItemId
			AND OMWF.OrderId = @OrderId

		DELETE ODD
		FROM OrderDeliveryDetails ODD
		WHERE ODD.OrderSetItemId = @OrderSetItemId
			AND ODD.OrderId = @OrderId

		DELETE OSIM
		FROM OrderSetItemImages OSIM
		WHERE OSIM.OrderSetItemId = @OrderSetItemId

		-- 7. Log Activity  
		SELECT @ActivityDescription = ISNULL(@ItemType, '') + ' ' + ISNULL(@ProductName, '') + ' has been deleted.';

		EXEC dbo.SaveActivityLog @SubjectTypeId = @SubjectTypeId
			,@SubjectId = @OrderId
			,@Description = @ActivityDescription
			,@Action = 'DELETE'
			,@CreatedBy = @DeletedBy
			,@CreatedDate = @dtoffset
			,@CreatedUTCDate = @dtutc;

		DELETE OSI
		FROM OrderSetItems OSI
		WHERE OSI.OrderSetItemId = @OrderSetItemId
			OR OSI.ParentOrderSetItemId = @OrderSetItemId
			AND OSI.IsDeleted = 0
			
		IF EXISTS (
				SELECT 1
				FROM OrderSetItems
				WHERE OrderId = @OrderId
				)
			AND NOT EXISTS (
				SELECT 1
				FROM OrderSetItems
				WHERE OrderId = @OrderId
					AND ItemStatus <> 3
				)
		BEGIN
			UPDATE Orders
			SET STATUS = 5
				,UpdatedBy = @DeletedBy
				,UpdatedDate = GETDATE()
				,UpdatedUTCDate = GETUTCDATE()
			WHERE OrderId = @OrderId
				AND STATUS <> 5;

			IF @@ROWCOUNT > 0
			BEGIN
				EXEC dbo.SaveActivityLog @SubjectTypeId = @SubjectTypeId
					,@SubjectId = @OrderId
					,@Description = 'Inquiry status has been changed to Delivered.'
					,@Action = 'UPDATE'
					,@CreatedBy = @DeletedBy
					,@CreatedDate = @dtoffset
					,@CreatedUTCDate = @dtutc;
			END
		END

		COMMIT TRANSACTION DeleteOrderSetItemsV2

		-- Success response  
		SET @ResultMessage = ''

		-- Recalculate Order Amount after delete order set item
		EXEC dbo.UpdateOrderRefreshInquiry @OrderId = @OrderId
			,@TenantId = @TenantId
			,@UserId = @DeletedBy
	END TRY

	BEGIN CATCH
		IF XACT_State() > 0
			ROLLBACK TRANSACTION

		IF @ResultMessage IS NULL
			OR @ResultMessage = ''
		BEGIN
			DECLARE @ErrorMessage VARCHAR(MAX);

			SET @ErrorMessage = ERROR_MESSAGE();
			SET @ResultMessage = 'Error in DeleteOrderSetItems_V2: ' + @ErrorMessage;
		END
	END CATCH
END

GO

