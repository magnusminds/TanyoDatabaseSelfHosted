/*  
 EXEC [dbo].[SaveApprovedOrder_V2]  
  @OrderID = 261183  
  ,@TenantID = 1207  
  ,@UserID = 13368  
  ,@Comment = ''  
*/
CREATE PROCEDURE [dbo].[SaveApprovedOrder_V2] (
	@OrderId BIGINT
	,@TenantId INT
	,@UserId INT
	,@Comment NVARCHAR(MAX) = NULL
	,@Remarks NVARCHAR(MAX) = NULL
	,@TentativeDeliveryDate DATE = NULL
	,@Status BIT = 0 OUTPUT
	,@Message NVARCHAR(MAX) = '' OUTPUT
	,@JsonObject NVARCHAR(MAX) = NULL OUTPUT
	,@Error VARCHAR(MAX) = NULL OUTPUT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @DT DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@DTUTC DATETIME = GETUTCDATE()
		DECLARE @OrderNo VARCHAR(50)
			,@productSubjectTypeId INT
			,@productQuantitiesSubjectTypeId INT
			,@rawMaterialSubjectTypeId INT
			,@OrderSubjectTypeId INT
			,@CheckProductStock BIT
			,@StockAvailable BIT
			,@IsAutoManufacture BIT
			,@Description VARCHAR(500);

		--Check Order Status  
		IF NOT EXISTS (
				SELECT 1
				FROM Orders WITH (NOLOCK)
				WHERE OrderId = @OrderId
					AND Status = 1
				) --Pending for Approval  
		BEGIN
			SET @Status = 0;
			SET @Message = 'Order Status must be in "Pending For Approal" to mark as Approved.'
			SET @JsonObject = NULL
			SET @Error = NULL

			RETURN
		END

		-- Check TentativeDeliveryDate  
		IF NOT EXISTS (
				SELECT 1
				FROM Orders WITH (NOLOCK)
				WHERE OrderId = @OrderId
					AND CONVERT(DATE, @DT) <= CONVERT(DATE, TentativeDeliveryDate)
				)
		BEGIN
			SET @Status = 0
			SET @Message = 'Order Delivery Date must be a valid current/future date.'
			SET @JsonObject = NULL
			SET @Error = NULL

			RETURN
		END

		--If there is any item with price 0  
		IF EXISTS (
				SELECT 1
				FROM OrderSetItems osi(NOLOCK)
				WHERE OrderId = @OrderId
					AND osi.TotalAmount <= 0
				)
			AND @TenantId NOT IN (
				185
				,193
				,130
				,177
				) --Zula n more and NOvelty and G n C and Lifestyle 360  allows  
		BEGIN
			SET @Status = 0
			SET @Message = 'Orderset Item Price 0, which is not allowed.'
			SET @JsonObject = NULL
			SET @Error = NULL

			RETURN
		END

		DECLARE @CurrentOrderStatus INT;

		SELECT @CurrentOrderStatus = Status
		FROM dbo.Orders WITH (NOLOCK)
		WHERE OrderId = @OrderId;

		IF @CurrentOrderStatus IS NULL
		BEGIN
			SET @Message = 'Order not found.';;

			THROW 50001
				,@Message
				,1;
		END

		IF @CurrentOrderStatus = 2
		BEGIN
			SET @Message = 'This order has already been approved.';;

			THROW 50002
				,@Message
				,1;
		END

		-- Start a transaction  
		BEGIN TRANSACTION SaveApprovedOrder_V2;

		UPDATE os
		SET InteriorCommission = x.InteriorCommission
		FROM OrderSetItems os WITH (NOLOCK)
		CROSS APPLY dbo.fn_CalculateInteriorCommission(@OrderID) x
		WHERE os.OrderSetItemId = x.OrderSetItemId

		UPDATE os
		SET SalesmanCommission = x.SalesmanCommission
		FROM OrderSetItems os WITH (NOLOCK)
		CROSS APPLY dbo.fn_CalculateSalesmanCommission(@OrderID) x
		WHERE os.OrderSetItemId = x.OrderSetItemId

		-- Check if the order exists and the condition is met  
		SELECT @OrderNo = OrderNo
		FROM Orders WITH (NOLOCK)
		WHERE OrderId = @OrderId;

		SELECT @CheckProductStock = (
				SELECT CheckProductStock
				FROM Tenants WITH (NOLOCK)
				WHERE TenantId = @TenantId
				);

		SELECT @IsAutoManufacture = IsAutoManufacture
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId;

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

		SELECT *
		INTO #orderSetItemByOrderId
		FROM OrderSetItems WITH (NOLOCK)
		WHERE OrderId = @OrderId
			AND SubjectTypeId = @productSubjectTypeId
			AND IsDeleted = 0
		ORDER BY OrderSetItemId;

		DROP TABLE IF EXISTS #OrderProductQuantity

			CREATE TABLE #OrderProductQuantity (
				Id INT IDENTITY
				,OrderId INT
				,ProductQuantityId BIGINT
				,ProductId INT
				,ProductQuantity NUMERIC(18, 2)
				,Quantity NUMERIC(18, 2)
				,Status BIT
				,OrderSetItemId BIGINT
				,IsAddOn BIT DEFAULT 0
				);

		-- Calculate and insert data into the temporary table  
		INSERT INTO #OrderProductQuantity (
			OrderId
			,ProductQuantityId
			,ProductId
			,ProductQuantity
			,Quantity
			,Status
			,OrderSetItemId
			,IsAddOn
			)
		SELECT @OrderId AS OrderId
			,p.ProductQuantityId
			,o.SubjectId AS ProductId
			,ISNULL(p.Quantity, 0) AS ProductQuantity
			,SUM(o.Quantity) AS Quantity
			,1 -- Set Status Based on Tenants Flag  
			,o.OrderSetItemId
			,CASE 
				WHEN O.ParentOrderSetItemId IS NOT NULL
					THEN 1
				ELSE 0
				END
		FROM #orderSetItemByOrderId o
		LEFT JOIN ProductQuantities p WITH (NOLOCK) ON o.SubjectId = p.ProductId
		WHERE o.OrderId = @OrderId
			AND o.SubjectTypeId = @productSubjectTypeId
		GROUP BY p.ProductQuantityId
			,o.SubjectId
			,p.Quantity
			,o.OrderSetItemId
			,O.ParentOrderSetItemId
		ORDER BY OrderSetItemId;

		-- Declare variables  
		DECLARE @ProductQuantityId BIGINT;
		DECLARE @Quantity NUMERIC(18, 2);
		DECLARE @Index INT = 1
		DECLARE @ProductId BIGINT
		DECLARE @OrderSetItemId BIGINT
		DECLARE @IsAddon BIT = 0
		DECLARE @Count INT = (
				SELECT MAX(Id)
				FROM #OrderProductQuantity
				)
		DECLARE @DeductResult INT

		WHILE @Index <= @Count
		BEGIN
			SET @ProductId = 0
			SET @OrderSetItemId = NULL
			SET @IsAddon = 0
			SET @Description = NULL

			SELECT @ProductQuantityId = ProductQuantityId
				,@Quantity = Quantity
				,@ProductId = ProductId
				,@OrderSetItemId = OrderSetItemId
				,@IsAddon = IsAddon
			FROM #OrderProductQuantity
			WHERE Id = @Index

			-- Check Stock on Hold and Release if any  
			EXEC [dbo].[ReleaseStockOnHoldByOrderSetItemId] @OrderSetItemId = @OrderSetItemId
				,@OrderId = @OrderId
				,@UserId = @UserId

			DECLARE @oldQuantity NUMERIC(18, 2);

			SELECT @oldQuantity = pq.Quantity
			FROM ProductQuantities pq WITH (NOLOCK)
			WHERE pq.ProductQuantityId = @ProductQuantityId;

			SELECT @Description = CASE 
					WHEN @IsAddon = 0
						THEN 'Inventory has been updated from ' + CAST(@oldQuantity AS NVARCHAR(50)) + ' to ' + CAST((@oldQuantity - @Quantity) AS NVARCHAR(50)) + ' (-' + CAST(@Quantity AS NVARCHAR(50)) + ') for order ' + CAST(@OrderNo AS NVARCHAR(50))
					ELSE 'Inventory has been updated from ' + CAST(@oldQuantity AS NVARCHAR(50)) + ' to ' + CAST((@oldQuantity - @Quantity) AS NVARCHAR(50)) + ' (-' + CAST(@Quantity AS NVARCHAR(50)) + ') — addon item for order ' + CAST(@OrderNo AS NVARCHAR(50))
					END

			EXEC dbo.DeductProductSaleableQuantity @TenantId = @TenantId
				,@UserId = @UserId
				,@ProductId = @ProductId
				,@OrderNo = @OrderNo
				,@Quantity = @Quantity
				,@Description = @Description
				,@Result = @DeductResult OUTPUT

			IF @DeductResult = - 1
			BEGIN
				SET @Status = 0
				SET @Message = 'Product quantities cannot go negative for some records.';
				SET @JsonObject = NULL
				SET @Error = NULL;

				THROW 50003, @Message, 1;
			END

			SET @Index = @Index + 1
		END

		--IF (@IsAutoManufacture = 1)  
		--BEGIN  
		--    -- Manage RawMaterial Quantity via dedicated SP  
		--    EXEC [dbo].[ProcessAutoManufactureRawMaterials]  
		--        @OrderId = @OrderId  
		--        ,@TenantId = @TenantId  
		--        ,@UserId = @UserId  
		--        ,@DT = @DT  
		--        ,@DTUTC = @DTUTC  
		--END  
		DECLARE @SalesmanCommissionPer NUMERIC(5, 2) = NULL

		SELECT @SalesmanCommissionPer = asp.CommissionPer
		FROM dbo.AspNetUsers AS asp WITH (NOLOCK)
		WHERE UserId = @UserID

		-- Update the Orders table  
		UPDATE Orders
		SET Status = 2
			,Comments = ISNULL(@Comment, '')
			,UpdatedBy = @UserId
			--,TentativeDeliveryDate = @TentativeDeliveryDate  
			,UpdatedDate = @DT
			,UpdatedUTCDate = @DTUTC
			,ApprovedDate = @DT
			,SalesmanCommissionPer = @SalesmanCommissionPer
			,IsPinned = CASE 
				WHEN IsPinned = 1
					THEN 0
				ELSE 0
				END
		WHERE OrderId = @OrderId;

		SELECT @OrderSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Orders'
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		-- Log order approval via shared SaveActivityLog SP  
		EXEC [dbo].[SaveActivityLog] @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = 'Inquiry status has been changed to Approved.'
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC

		-- Save Comment / Remarks via shared SaveOrderComment SP  
		EXEC [dbo].[SaveOrderComment] @OrderId = @OrderId
			,@Status = 2
			,@Comment = @Comment
			,@Remarks = @Remarks
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC

		COMMIT TRANSACTION SaveApprovedOrder_V2;

		-- Commit the transaction if everything is successful  
		IF @Status IS NULL
			OR @Status = 1
		BEGIN
			SET @Status = 1;

			SELECT @JsonObject = (
					SELECT *
					FROM Orders WITH (NOLOCK)
					WHERE OrderId = @OrderId
					FOR JSON AUTO
					);

			SET @Status = 1
			SET @Message = 'Your order has been successfully Approved.';
			SET @Error = NULL;

			SELECT @Status AS [Status]
				,@Message AS [Message]
				,@JsonObject AS [Data]
				,@Error AS [Error]

			RETURN
		END
	END TRY

	BEGIN CATCH
		-- Rollback the transaction in case of an error  
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION SaveApprovedOrder_V2;

		SET @Status = 0;

		DECLARE @ObjectName VARCHAR(500) = OBJECT_NAME(@@PROCID);

		-- Append TenantId and OrderId to the description saved in DBErrorLog 
		DECLARE @ErrorMsg NVARCHAR(4000) = @Message + ' | TenantId: ' + ISNULL(CAST(@TenantId AS VARCHAR(20)), 'NULL') 
		+ ' | OrderId: ' + ISNULL(CAST(@OrderId AS VARCHAR(20)), 'NULL');

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		SELECT @JsonObject = (
				SELECT *
				FROM Orders WITH (NOLOCK)
				WHERE OrderId = @OrderId
				FOR JSON AUTO
				);

		IF @Message IS NULL
		BEGIN
			SET @Message = 'Your order could not be Approved.';
		END

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,@JsonObject AS [Data]
			,@Error AS [Error]
	END CATCH;
END;

GO

