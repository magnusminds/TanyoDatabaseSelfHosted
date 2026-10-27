
/*
EXEC [dbo].[SaveCancelledOrder]
 @OrderId = 260552
,@TenantId = 1207
,@UserId = 13309
*/
CREATE PROCEDURE [dbo].[SaveCancelledOrder] (
	@OrderId BIGINT
	,@TenantId INT
	,@UserId INT
	,@Comment NVARCHAR(MAX) = NULL
	,@ReturnMessage NVARCHAR(500) = '' OUTPUT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @OrderNo VARCHAR(50)
			,@productSubjectTypeId INT
			,@productQuantitiesSubjectTypeId INT
			,@rawMaterialSubjectTypeId INT
			,@OrderSubjectTypeId INT
			,@Status BIT
			,@Message NVARCHAR(MAX)
			,@JsonObject NVARCHAR(MAX)
			,@Error NVARCHAR(MAX)
			,@DT DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@DTUTC DATETIME = GETUTCDATE()
			,@ProductId BIGINT
			,@Date DATETIME = GETDATE()
			,@UserName VARCHAR(200)
			,@SystemComment VARCHAR(MAX)
			,@LogDescription VARCHAR(500)
			,@KasarAmount DECIMAL(18, 2) = 0

		-- Check if any OrderSetItems Delivered
		IF NOT EXISTS (
				SELECT 1
				FROM OrderSetItems WITH (NOLOCK)
				WHERE OrderId = @OrderId
					AND ItemStatus != 3
				)
		BEGIN
			SET @ReturnMessage = 'Your one of the item was delivered already.';
			SET @Message = 'Your one of the item was delivered already.';
			SET @JsonObject = NULL
			SET @Status = 0
			SET @Error = NULL

			--SELECT @ReturnMessage AS [ReturnMessage];
			SELECT @Status AS [Status]
			,@Message AS [Message]
			,@JsonObject AS [Data]
			,@Error AS [Error]

			RETURN;
		END

		-- Start a transaction
		BEGIN TRANSACTION SaveCancelledOrder;

		DECLARE @CurrentOrderStatus INT;

		SELECT @CurrentOrderStatus = Status
		FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK)
		WHERE OrderId = @OrderId
		
		IF @CurrentOrderStatus IS NULL
		BEGIN
			SET @Message = 'Order not found.'
		    ;THROW 50001, @Message, 1;
		END
		
		IF @CurrentOrderStatus = 6
		BEGIN
			SET @Message = 'This order has already been cancelled.'
		    ;THROW 50002, @Message, 1;
		END
		
		-- Check if the order exists and the condition is met
		SELECT @OrderNo = OrderNo, @KasarAmount = KasarAmount
		FROM Orders WITH (NOLOCK)
		WHERE OrderId = @OrderId;

		-- Get User Name for system generated cancel comment
		SELECT @UserName = CONCAT (
				ISNULL(FirstName, '')
				,' '
				,ISNULL(LastName, '')
				)
		FROM AspNetUsers WITH (NOLOCK)
		WHERE UserId = @UserId;

		-- Prepare system generated cancel comment
		SET @SystemComment = 'This inquiry has been canceled by ' + @UserName + ' on ' + FORMAT(@Date, 'dd-MM-yyyy hh:mm tt') + '.';

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
			AND IsDeleted = 0;

		--SELECT DISTINCT SubjectId
		--INTO #subjectIds
		--FROM #orderSetItemByOrderId;
		--SELECT *
		--INTO #allProductQty
		--FROM ProductQuantities;

		DROP TABLE IF EXISTS #OrderProductQuantity

			-- Temporary table to hold the result
			CREATE TABLE #OrderProductQuantity (
				Id INT IDENTITY
				,OrderId INT
				,ProductQuantityId BIGINT
				,ProductId INT
				,ProductQuantity NUMERIC(18, 2)
				,Quantity NUMERIC(18, 2)
				,Status BIT
				);

		-- Calculate and insert data into the temporary table
		INSERT INTO #OrderProductQuantity (
			OrderId
			,ProductQuantityId
			,ProductId
			,ProductQuantity
			,Quantity
			,Status
			)
		SELECT @OrderId AS OrderId
			,p.ProductQuantityId
			,o.SubjectId AS ProductId
			,ISNULL(p.Quantity, 0) AS ProductQuantity
			,SUM(o.Quantity) AS Quantity
			,1 -- Set Status Based on Tenants Flag
		FROM #orderSetItemByOrderId o
		LEFT JOIN ProductQuantities p WITH (NOLOCK) ON o.SubjectId = p.ProductId
		WHERE o.OrderId = @OrderId
			AND o.SubjectTypeId = @productSubjectTypeId
		GROUP BY p.ProductQuantityId
			,o.SubjectId
			,p.Quantity;

		-- Declare variables
		DECLARE @ProductQuantityId BIGINT;
		DECLARE @Quantity NUMERIC(18, 2);
		DECLARE @Index INT = 1
		DECLARE @Count INT = (
				SELECT MAX(Id)
				FROM #OrderProductQuantity
				)

		WHILE @Index <= @Count
		BEGIN
			SET @ProductId = 0

			SELECT @ProductQuantityId = ProductQuantityId
				,@Quantity = Quantity
				,@ProductId = ProductId
			FROM #OrderProductQuantity
			WHERE Id = @Index

			-- Get oldQuantity for log description, then add back via centralized proc
			DECLARE @oldQuantity NUMERIC(18, 2);

			SELECT @oldQuantity = pq.Quantity
			FROM ProductQuantities pq WITH (NOLOCK)
			WHERE pq.ProductQuantityId = @ProductQuantityId;

			SET @LogDescription = 'Inventory has been updated from ' + CAST(@oldQuantity AS NVARCHAR(50)) + ' to ' + CAST((@oldQuantity + @Quantity) AS NVARCHAR(50)) + ' (+' + CAST(@Quantity AS NVARCHAR(50)) + ') for order ' + CAST(@OrderNo AS NVARCHAR(50))

			-- Add back to ProductQuantities + its own InventoryLogs entry
			EXEC dbo.AddProductSaleableQuantity @TenantId = @TenantId
				,@UserId = @UserId
				,@ProductId = @ProductId
				,@Quantity = @Quantity
				,@Description = @LogDescription

			SET @Index = @Index + 1
		END

		-- Update ItemStatus in OrderSetItems to 0 for all records associated with this order
		UPDATE OrderSetItems
		SET ItemStatus = 0
		WHERE OrderId = @OrderId;

		-- Update the Orders table
		UPDATE Orders
		SET Status = 0
			,KasarAmount = 0
			,Comments = ISNULL(@Comment, '')
			,UpdatedBy = @UserId
			,UpdatedDate = SYSDATETIMEOFFSET()
			,UpdatedUTCDate = GETUTCDATE()
			,ApprovedDate = NULL
		WHERE OrderId = @OrderId;

		-- Add Order Comment
		-- Add System Generated Cancel Comment
		EXEC dbo.SaveOrderComment @OrderId = @OrderId
			,@Status = 0
			,@Comment = @SystemComment
			,@Remarks = NULL
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC;

		-- Declare a flag variable to track whether the comment has been added
		DECLARE @CommentAdded BIT = 0;

		IF ISNULL(@Comment, '') <> ''
			AND @CommentAdded = 0
		BEGIN
			EXEC dbo.SaveOrderComment @OrderId = @OrderId
				,@Status = 0
				,@Comment = @Comment
				,@Remarks = NULL
				,@CreatedBy = @UserId
				,@CreatedDate = @DT
				,@CreatedUTCDate = @DTUTC;

			-- Set the flag to indicate that the comment has been added
			SET @CommentAdded = 1;
		END;

		SELECT @OrderSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Orders'
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		-- Order Activity Log for cancelled order
		EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = @SystemComment
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC;

		-- Order Activity Log for back to inquiry order
		EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = 'Inquiry status has been changed to Inquiry.'
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC;

		-- Kasar removal Activity Log for cancelled order
		IF ISNULL(@KasarAmount, 0) > 0
		BEGIN
			SET @LogDescription = 'Kasar amount ' + CAST(@KasarAmount AS NVARCHAR(50)) + ' has been removed for Inquiry ' + @OrderNo + ' because order has been cancelled.';

			EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
				,@SubjectId = @OrderId
				,@Description = @LogDescription
				,@Action = 'DELETE'
				,@CreatedBy = @UserId
				,@CreatedDate = @DT
				,@CreatedUTCDate = @DTUTC;
		END

		-- DeleteOrderManufacturingWorkflows	
		DELETE
		FROM OrderManufacturingWorkflows
		WHERE OrderId = @OrderId

		-- Soft delete for OrderTrack
		UPDATE dbo.OrderTrack
		SET IsDeleted = 1
		   ,LastModifiedBy = @UserId
		   ,LastModifiedDate = @DT
		   ,LastModifiedUtcDate = @DTUTC
		WHERE OrderId = @OrderId
		AND TenantId = @TenantId

		-- Commit the transaction if everything is successful
		COMMIT TRAN SaveCancelledOrder;

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

			SELECT @Message = 'Your order has been successfully canceled.';

			SET @Error = NULL;

			SELECT @Status AS [Status]
				,@Message AS [Message]
				,@JsonObject AS [Data]
				,@Error AS [Error]
		END
	END TRY

	BEGIN CATCH
		-- Rollback the transaction in case of an error
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION SaveCancelledOrder;

		SET @Status = 0;

		DECLARE @ObjectName VARCHAR(500)       
			,@ErrorMsg NVARCHAR(4000);

		SET @ObjectName = OBJECT_NAME(@@PROCID);

		IF (@ErrorMsg IS NULL)
		BEGIN
			SET @ErrorMsg = ERROR_MESSAGE();
		END

		-- Append TenantId and OrderId to the description saved in DBErrorLog
		SET @ErrorMsg = @ErrorMsg + N' | TenantId: ' + ISNULL(CAST(@TenantId AS NVARCHAR(20)), N'NULL')
			+ N' | OrderId: ' + ISNULL(CAST(@OrderId AS NVARCHAR(20)), N'NULL');

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
			SELECT @Message = 'Your order could not be canceled.';
		END

		IF @Error IS NULL
		BEGIN
			SELECT @Error = ERROR_MESSAGE();
		END

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,@JsonObject AS [Data]
			,@Error AS [Error]
	END CATCH;
END;

GO

