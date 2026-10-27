CREATE PROCEDURE [dbo].[SaveSplitOrders] (
	@OrderId BIGINT
	,@JsonObject NVARCHAR(MAX)
	,@ReturnOrderId VARCHAR(512) = 0 OUTPUT
	,@Status BIT = 0 OUTPUT
	,@Message VARCHAR(128) = '' OUTPUT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	--SET XACT_ABORT ON;
	BEGIN TRY
		BEGIN TRAN SaveSplitOrders;

		DECLARE @NewOrderID BIGINT
			,@TentativeDeliveryDate DATE
			,@SplitCustomerID BIGINT
			,@OrderCustomerId BIGINT
			,@Date DATETIME = GETDATE()
			,@DateUtc DATETIME = GETUTCDATE()
			,@DateOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@UserID INT
			,@TenantID INT
			,@OrderType VARCHAR(1)
			,@LocationID BIGINT
			,@isFromBackOrder BIT
			,@PaymentAmount NUMERIC(18, 2)
			,@OrderPayment NUMERIC(18, 2)
			,@CustomerId BIGINT
			,@CustFamilyId BIGINT
			,@OrderSetItemId BIGINT
			,@Id INT = 1
			,@Count INT
			,@Comment VARCHAR(MAX)
			,@Remarks VARCHAR(MAX)

		DROP TABLE IF EXISTS #Families

		DROP TABLE IF EXISTS #OrderDetails

		DROP TABLE IF EXISTS #OrderSetItemDetails

		DROP TABLE IF EXISTS #OrderComments

		DROP TABLE IF EXISTS #OrderPayments

		DROP TABLE IF EXISTS #NewOrderIds

		DROP TABLE IF EXISTS #OnHoldOrderSetItems
		
			SELECT ROW_NUMBER() OVER (
					ORDER BY (
							SELECT 1
							)
					) AS OrderSplit
				,JSON_QUERY(value, '$.OrderData') AS OrdersJson
			INTO #Families
			FROM OPENJSON(@JsonObject, '$.SplitOrders');

		CREATE TABLE #NewOrderIds (OrderId BIGINT)

		SELECT *
		INTO #OrderDetails
		FROM Orders WITH (NOLOCK)
		WHERE OrderId = @OrderId

		SELECT *
		INTO #OrderSetItemDetails
		FROM OrderSetItems WITH (NOLOCK)
		WHERE OrderId = @OrderId

		SELECT @UserID = CreatedBy
			,@TenantID = TenantId
			,@OrderType = CASE 
				WHEN OrderType = 1
					THEN 'R'
				ELSE 'W'
				END
			,@LocationID = LocationID
			,@isFromBackOrder = IsBackOrder
			,@TentativeDeliveryDate = TentativeDeliveryDate
			,@CustomerId = CustomerID
		FROM #OrderDetails

		SELECT *
		INTO #OrderComments
		FROM OrderComments WITH (NOLOCK)
		WHERE OrderId = @OrderId

		DECLARE @Cnt INT
			,@Inc INT = 1
			,@FinalJsonObject NVARCHAR(MAX)

		SELECT @Cnt = COUNT(*)
		FROM #Families

		SELECT *
		INTO #OrderPayments
		FROM Payments WITH (NOLOCK)
		WHERE OrderId = @OrderId
			AND IsDeleted = 0

		SELECT @PaymentAmount = SUM(ReceivedAmount)
		FROM #OrderPayments
		GROUP BY OrderId

		SELECT @OrderPayment = @PaymentAmount / @Cnt

		SET @Inc = 1

		INSERT INTO CustomerFamily (
			FamilyName
			,CreatedBy
			,CreatedDate
			,CreatedDateUTC
			)
		SELECT CONCAT (
				FirstName
				,' '
				,ISNULL(LastName, '')
				)
			,@UserID
			,@DateOffset
			,@DateUtc
		FROM Customers
		WHERE CustomerId = @CustomerId

		SELECT @CustFamilyId = SCOPE_IDENTITY()

		WHILE @Inc <= @Cnt
		BEGIN
			SET @FinalJsonObject = NULL
			SET @TentativeDeliveryDate = NULL

			SELECT @FinalJsonObject = OrdersJson
			FROM #Families
			WHERE OrderSplit = @Inc

			EXEC [SplitSaveOrder] @OrderID = 0
				,@OrderType = @OrderType
				,@TenantID = @TenantID
				,@UserID = @UserID
				,@RefreshInquiry = 0
				,@JsonObject = @FinalJsonObject
				,@LocationID = @LocationID
				,@isFromBackOrder = 0
				,@ReturnOrderID = @NewOrderID OUTPUT

			INSERT INTO #NewOrderIds (OrderId)
			SELECT @NewOrderID

			IF ISNULL(@OrderPayment, 0) > 0
				AND ISNULL(@NewOrderID, 0) > 0
			BEGIN
				INSERT INTO Payments (
					OrderId
					,TenantId
					,PaymentType
					,BankName
					,AccountHolderName
					,ChequeNo
					,ReceivedAmount
					,PaymentReceivedBy
					,PaymentApprovedBy
					,PaymentStatus
					,ApprovedDate
					,IsDeleted
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,ReceivedDate
					,Comments
					,TransactionId
					)
				SELECT @NewOrderID
					,@TenantID
					,PaymentType
					,BankName
					,AccountHolderName
					,ChequeNo
					,@OrderPayment
					,PaymentReceivedBy
					,PaymentApprovedBy
					,PaymentStatus
					,ApprovedDate
					,0
					,CreatedBy
					,@DateOffset
					,@DateUtc
					,ReceivedDate
					,Comments
					,TransactionId
				FROM #OrderPayments
			END

			EXEC SplitSaveApprovedOrder_V2 @OrderId = @NewOrderID
				,@TenantId = @TenantID
				,@UserId = @UserId
				,@Comment = NULL
				,@Remarks = NULL
				,@TentativeDeliveryDate = @TentativeDeliveryDate

			SET @Inc = @Inc + 1
		END

		INSERT INTO OrderFamily (
			CustFamilyId
			,OrderId
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			)
		SELECT @CustFamilyId
			,OrderId
			,@UserID
			,@DateOffset
			,@DateUtc
		FROM #NewOrderIds

		IF EXISTS (
				SELECT 1
				FROM #OrderComments
				)
		BEGIN
			SET @Inc = 1;

			SELECT @Cnt = COUNT(1) FROM #OrderComments;

			WHILE @Cnt >= @Inc
			BEGIN
				SELECT @Comment = Comments
					,@Remarks = Remarks
					,@UserID = CreatedBy
				FROM #OrderComments
				WHERE RowId = @Inc;

				EXEC dbo.SaveOrderComment @OrderId = @NewOrderID
					,@Status = 0
					,@Comment = @Comment
					,@Remarks = @Remarks
					,@CreatedBy = @UserID
					,@CreatedDate = @DateOffset
					,@CreatedUTCDate = @DateUtc;

				SET @Inc = @Inc + 1;
			END
		END

		IF EXISTS (
				SELECT 1
				FROM #NewOrderIds
				)
		BEGIN
			UPDATE ORD
			SET ORD.ParentOrderId = @CustFamilyId
			FROM Orders ORD
			INNER JOIN #NewOrderIds NORD ON NORD.OrderId = ORD.OrderId
		END

		SELECT osi.OrderSetItemId
			,osi.OrderId
			,ROW_NUMBER() OVER (
				ORDER BY osi.OrderSetItemId
				) AS Id
		INTO #OnHoldOrderSetItems
		FROM #OrderSetItemDetails OSI
		INNER JOIN StockOnHold SOH ON SOH.OrderSetItemId = OSI.OrderSetItemId
		WHERE IsDeleted = 0
			AND OSI.IsQuantityOnHold = 1
			AND SOH.IsStockOnHold = 1
			AND HoldUptoDate > @DateOffset

		IF EXISTS (
				SELECT 1
				FROM #OnHoldOrderSetItems
				)
		BEGIN
			SELECT @Count = COUNT(OrderSetItemId)
			FROM #OnHoldOrderSetItems

			WHILE @Id <= @Count
			BEGIN
				SET @OrderSetItemId = 0

				SELECT @OrderSetItemId = OrderSetItemId
				FROM #OnHoldOrderSetItems
				WHERE Id = @Id

				EXEC [dbo].[ReleaseStockOnHoldByOrderSetItemId] @OrderSetItemId = @OrderSetItemId
					,@OrderId = @OrderId
					,@UserId = @UserId

				SET @Id = @Id + 1
			END
		END

		DELETE OPC
		FROM OrderProductCharges OPC
		INNER JOIN #OrderSetItemDetails OSI ON OPC.OrderSetItemId = OSI.OrderSetItemId

		DELETE OSI
		FROM OrderSetItems OSI
		INNER JOIN #OrderSetItemDetails OSID ON OSID.OrderSetItemId = OSI.OrderSetItemId

		DELETE OS
		FROM OrderSets OS
		WHERE OrderId = @OrderId

		DELETE ORD
		FROM Orders ORD
		WHERE OrderId = @OrderId

		IF @NewOrderID > 0
		BEGIN
			SELECT @ReturnOrderId = STRING_AGG(OrderId, ',')
			FROM #NewOrderIds

			SET @Status = 1
			SET @Message = 'Order Split Successfully'
		END
		ELSE
		BEGIN
			SET @ReturnOrderId = NULL
			SET @Status = 0
			SET @Message = 'Order Split Failed'
		END

		COMMIT TRAN SaveSplitOrders;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN SaveSplitOrders;
       
	    DECLARE @ObjectName VARCHAR(500)
		,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
		,@ErrorMsg = @ErrorMsg;

		SET @Status = 0;
		SET @ReturnOrderId = NULL;
		SET @Message = ERROR_MESSAGE();
	END CATCH
END

GO

