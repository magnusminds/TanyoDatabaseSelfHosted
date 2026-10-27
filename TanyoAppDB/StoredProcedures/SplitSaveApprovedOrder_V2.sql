/*  
 EXEC [dbo].[SplitSaveApprovedOrder_V2]  
  @OrderID = 1  
  ,@TenantID = 1  
  ,@UserID = 1  
  ,@Comment = ''  
*/
CREATE PROCEDURE [dbo].[SplitSaveApprovedOrder_V2] (
	@OrderId BIGINT
	,@TenantId INT
	,@UserId INT
	,@Comment NVARCHAR(MAX) = NULL
	,@Remarks NVARCHAR(MAX) = NULL
	,@TentativeDeliveryDate DATE = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		-- Start a transaction  
		DECLARE @OrderNo VARCHAR(50)
			,@productSubjectTypeId INT
			,@productQuantitiesSubjectTypeId INT
			,@rawMaterialSubjectTypeId INT
			,@OrderSubjectTypeId INT
			,@CheckProductStock BIT
			,@CheckRawMaterialStock BIT
			,@StockAvailable BIT
			,@DT DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@DTUTC DATETIME = GETUTCDATE()
			,@IsAutoManufacture BIT
			,@DeductResult INT
			,@LogDescription VARCHAR(500)
			,@Status BIT = 0 
			,@Message VARCHAR(MAX) 
			,@JsonObject NVARCHAR(MAX) 
			,@Error VARCHAR(MAX)

		-- Check TentativeDeliveryDate  
		IF NOT EXISTS (
				SELECT 1
				FROM Orders WITH (NOLOCK)
				WHERE OrderId = @OrderId
					AND CONVERT(DATE, SYSDATETIMEOFFSET()) <= CONVERT(DATE, TentativeDeliveryDate)
				)
		BEGIN
		    SET @Status = 0
			SET @Message = 'Order Delivery Date must be a valid current/future date.'
			SET @JsonObject = NULL
			SET @Error = NULL

			SELECT @Status AS [Status]
				,@Message AS [Message]
				,@JsonObject AS [Data]
				,@Error AS [Error]

			RETURN
		END

		UPDATE os
		SET InteriorCommission = x.InteriorCommission
		FROM OrderSetItems os
		CROSS APPLY dbo.fn_CalculateInteriorCommission(@OrderID) x
		WHERE os.OrderSetItemId = x.OrderSetItemId

		UPDATE os
		SET SalesmanCommission = x.SalesmanCommission
		FROM OrderSetItems os
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

		SELECT @CheckRawMaterialStock = (
				SELECT CheckRawMaterialStock
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
			AND IsDeleted = 0;

		--SELECT DISTINCT SubjectId  
		--INTO #subjectIds  
		--FROM #orderSetItemByOrderId;  
		--SELECT *  
		--INTO #allProductQty  
		--FROM ProductQuantities;  
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
		DECLARE @ProductId BIGINT
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

			DECLARE @oldQuantity NUMERIC(18, 2);

			SELECT @oldQuantity = pq.Quantity
			FROM ProductQuantities pq WITH (NOLOCK)
			WHERE pq.ProductQuantityId = @ProductQuantityId;

			SET @LogDescription = 'Inventory has been updated from ' + CAST(@oldQuantity AS NVARCHAR(50)) + ' to ' + CAST((@oldQuantity - @Quantity) AS NVARCHAR(50)) + ' (-' + CAST(@Quantity AS NVARCHAR(50)) + ') for order ' + CAST(@OrderNo AS NVARCHAR(50))

			-- Deduct from ProductQuantities (includes its own stock check + InventoryLogs entry)
			EXEC dbo.DeductProductSaleableQuantity @TenantId = @TenantId
				,@UserId = @UserId
				,@ProductId = @ProductId
				,@OrderNo = @OrderNo
				,@Quantity = @Quantity
				,@Description = @LogDescription
				,@Result = @DeductResult OUTPUT

			IF @DeductResult = - 1
			BEGIN
			    SET @Status = 0
				SET @Message = 'Product quantities cannot go negative for some records.'
				SET @JsonObject = NULL
				SET @Error = NULL

				SELECT @Status AS [Status]
				,@Message AS [Message]
				,@JsonObject AS [Data]
				,@Error AS [Error]

				RETURN
			END

			SET @Index = @Index + 1
		END

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
			,UpdatedDate = SYSDATETIMEOFFSET()
			,UpdatedUTCDate = GETUTCDATE()
			,ApprovedDate = SYSDATETIMEOFFSET()
			,SalesmanCommissionPer = @SalesmanCommissionPer
		WHERE OrderId = @OrderId;

		SELECT @OrderSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Orders'
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		-- Insert data into Activity Logs with the desired format and additional information  
		EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = 'Inquiry status has been changed to Approved.'
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC;

		-- Add Order Comment  
		-- Declare a flag variable to track whether the comment has been added  
		DECLARE @CommentAdded BIT = 0;

		IF ISNULL(@Comment, '') <> ''
			AND @CommentAdded = 0
		BEGIN
			EXEC dbo.SaveOrderComment @OrderId = @OrderId
				,@Status = 2
				,@Comment = @Comment
				,@Remarks = NULL
				,@CreatedBy = @UserId
				,@CreatedDate = @DT
				,@CreatedUTCDate = @DTUTC;

			-- Set the flag to indicate that the comment has been added  
			SET @CommentAdded = 1;
		END;

		DECLARE @RemarkAdded BIT = 0;

		IF ISNULL(@Remarks, '') <> ''
			AND @RemarkAdded = 0
		BEGIN
			EXEC dbo.SaveOrderComment @OrderId = @OrderId
				,@Status = 2
				,@Comment = NULL
				,@Remarks = @Remarks
				,@CreatedBy = @UserId
				,@CreatedDate = @DT
				,@CreatedUTCDate = @DTUTC;

			-- Set the flag to indicate that the comment has been added  
			SET @RemarkAdded = 1;
		END;

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
		SET @Status = 0;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

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
			SELECT @Message = 'Your order could not be Approved.';
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

