/*
DECLARE @OrderId BIGINT = 10763;         -- Replace with an OrderId currently in "Approved" status
DECLARE @TenantId INT = 2;          
DECLARE @UserId INT = 4279;            
DECLARE @AutoProcess BIT = 1;      
DECLARE @JsonPayload NVARCHAR(MAX);
SET @JsonPayload = N'{
    "Remarks": "Initiating backend processing",
    "EstimatedDeliveryDays": 7,
    "Items": [
        {
            "OrderSetItemId": 11426,
            "QuantityToProcess": 5
        }
    ]
}';
EXEC [dbo].[SaveProcessOrder_V2] 
    @OrderId = @OrderId,
    @TenantId = @TenantId,
    @UserId = @UserId,
    @AutoProcess = @AutoProcess,
    @RequestProcessOrder = @JsonPayload;
GO
*/
CREATE PROCEDURE [dbo].[SaveProcessOrder_V2] (
	@OrderId BIGINT
	,@TenantId INT
	,@UserId INT
	,@AutoProcess BIT
	,@RequestProcessOrder NVARCHAR(MAX) = NULL -- JSON Input
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF OBJECT_ID('tempdb..#OrderSetItemsPOCreation') IS NOT NULL
		DROP TABLE #OrderSetItemsPOCreation

	BEGIN TRY
		-- Start a transaction
		BEGIN TRANSACTION SaveProcessOrder_V2;

		DECLARE @OrderSubjectTypeId INT
			,@OrderNo VARCHAR(50)
			,@productSubjectTypeId INT
			,@FabricSubjectTypeId INT
			,@IsManufacturing BIT
			,@OrderSetItemId INT
			,@ManufactureOrderSetItemId INT
			,@ParentOrderSetItemId INT
			,@SubjectId INT
			,@SubjectTypeId INT
			,@CategoryId INT
			,@OrderManufacturingWorkflowId BIGINT
			,@ManufacturingIndex INT
			,@ManufacturingCount INT
			,@ManufacturingDeliveryDate DATETIMEOFFSET
			,@ManufacturingDeliveryDays INT
			,@Status BIT
			,@OutputStatus BIT
			,@Message NVARCHAR(MAX)
			,@JsonObject NVARCHAR(MAX)
			,@Error NVARCHAR(MAX)
			,@IsEnableProductProcessingWorkflow BIT
			,@IsAutoManufacture BIT
			,@DT DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@DTUTC DATETIME = GETUTCDATE()
			,@InnerMessage NVARCHAR(MAX) = '';
		DECLARE @OutputTable TABLE (ResultMessage NVARCHAR(MAX));

		SELECT @IsManufacturing = tc.IsManufacturing
			,@IsEnableProductProcessingWorkflow = tc.EnableProductProcessingWorkflow
		FROM TenantConfigurations tc WITH (NOLOCK)
		WHERE tc.TenantId = @TenantId

		-- Get the AutoManufacture
		SELECT @IsAutoManufacture = IsAutoManufacture
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId;

		SELECT @OrderSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Orders'
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		SELECT @OrderNo = OrderNo
		FROM Orders WITH (NOLOCK)
		WHERE OrderId = @OrderId;

		SELECT @productSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		SELECT @FabricSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Fabrics'
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		IF (@IsAutoManufacture = 1)
		BEGIN
			INSERT INTO @OutputTable (ResultMessage)
			EXEC [dbo].[ProcessAutoManufactureRawMaterials] @OrderId = @OrderId
				,@TenantId = @TenantId
				,@UserId = @UserId
				,@DT = @DT
				,@DTUTC = @DTUTC;

			SELECT TOP 1 @InnerMessage = ResultMessage
			FROM @OutputTable;

			-- Insufficient raw material / non-negative stock validation failure:
			-- roll back and return Status/Message so API/Portal can display the message.
			IF ISNULL(LTRIM(RTRIM(@InnerMessage)), '') <> ''
			BEGIN
				IF @@TRANCOUNT > 0
					ROLLBACK TRANSACTION;

				SET @Status = 0;
				SET @Message = @InnerMessage;
				SET @Error = NULL;
				SET @JsonObject = '';

				SELECT @Status AS [Status]
					,@Message AS [Message]
					,@JsonObject AS [Data]
					,@Error AS [Error];

				RETURN;
			END
		END

		-- Update Order
		UPDATE Orders
		SET [Status] = 3
			,UpdatedBy = @UserId
			,UpdatedDate = SYSDATETIMEOFFSET()
			,UpdatedUTCDate = GETUTCDATE()
		WHERE OrderId = @OrderId

		-- Insert data into Activity Logs for Chnage status Approve to InProgress.
		EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = 'Inquiry status has been changed to In Progress.'
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC;

		-- Create a temporary table to hold OrderSetItems data
		IF OBJECT_ID('tempdb..#OrderSetItemStatus') IS NOT NULL
			DROP TABLE #OrderSetItemStatus

		SELECT OrderSetItemID
			,DeliveryNo = CONCAT (
				@OrderNo
				,'_'
				,ROW_NUMBER() OVER (
					ORDER BY OrderId
					)
				)
			,ItemStatus = CASE 
				-- TAN-4714: in-house manufacturing only (outsourced treated like imported)
				WHEN @IsManufacturing = 1
					AND ISNULL(c.IsManufacturing, 0) = 1
					AND c.IsInHouseManufacturing = 1
					THEN 0 -- ReadyToManufacturing
						-- Imported OR outsourced manufacturing
				WHEN ISNULL(c.IsManufacturing, 0) = 0
					OR (ISNULL(c.IsManufacturing, 0) = 1 AND c.IsInHouseManufacturing = 0)
					THEN CASE 
							WHEN @IsEnableProductProcessingWorkflow = 1
								THEN 4 -- Pending
							ELSE 2 -- ReadyToDelivered
							END
						-- Fallback
				ELSE 2 -- ReadyToDelivered
				END
		INTO #OrderSetItemStatus
		FROM OrderSetItems osi WITH (NOLOCK)
		LEFT JOIN Products p WITH (NOLOCK) ON p.ProductId = OSI.SubjectId
			AND OSI.SubjectTypeId = @productSubjectTypeId
		LEFT JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
		LEFT JOIN Fabrics FB WITH (NOLOCK) ON FB.FabricId = OSI.SubjectId
			AND OSI.SubjectTypeId = @FabricSubjectTypeId
		WHERE OrderId = @OrderId
			AND osi.IsDeleted = 0;

		UPDATE osi
		SET DeliveryNo = c.DeliveryNo
			,ItemStatus = c.ItemStatus
		FROM OrderSetItems osi
		INNER JOIN #OrderSetItemStatus c ON c.OrderSetItemID = osi.OrderSetItemId;

		IF @IsEnableProductProcessingWorkflow = 0
		BEGIN
			-- Update related PO Items as Material Ready
			UPDATE POI
			SET POI.Status = 5
				,POI.POItemMaterialReadyDate = GETDATE()
			FROM POProductItems POI
			INNER JOIN #OrderSetItemStatus c ON c.OrderSetItemID = POI.VendorOrderSetItemId
			WHERE c.ItemStatus = 2;

			-- Update PO status if all items are Material Ready & completed
			UPDATE PO
			SET PO.Status = 5
				,POMaterialReadyDate = GETDATE()
			FROM POProducts PO
			WHERE PO.VendorOrderId = @OrderId
				AND NOT EXISTS (
					SELECT 1
					FROM POProductItems POI
					WHERE POI.POProductId = PO.POProductId
						AND ISNULL(POI.Status, 0) NOT IN (
							4
							,5
							)
					);
		END

		IF @IsManufacturing = 1
		BEGIN
			EXEC ProcessManufacturingProducts @OrderId = @OrderId
				,@TenantId = @TenantId
				,@UserId = @UserId
				,@AutoProcess = @AutoProcess
				,@RequestProcessOrder = @RequestProcessOrder

			--,@Status = @OutputStatus OUTPUT
			--,@Message = @Message OUTPUT
			--,@Error = @Error OUTPUT
			IF @AutoProcess = 0
			BEGIN
				EXEC CreateManufacturingWorkOrders @OrderId = @OrderId
					,@TenantId = @TenantId
					,@UserId = @UserId;
			END
		END

		--IF @OutputStatus = 0
		--BEGIN
		--	IF @@TRANCOUNT > 0
		--	ROLLBACK TRAN
		--	RETURN;			
		--END
		--For Auto PO generation
		--CREATE TABLE #OrderSetItemsPOCreation (
		--	Id INT IDENTITY
		--	,OrderSetItemId BIGINT
		--	--,VendorId BIGINT
		--	)
		--INSERT INTO #OrderSetItemsPOCreation (
		--	OrderSetItemId
		--	--,VendorId
		--	)
		--SELECT DISTINCT osi.OrderSetItemId
		--	--,PVM.VendorId
		--FROM OrderSetItems osi WITH (NOLOCK)
		--INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = OSI.SubjectId
		--	AND P.TenantId = @TenantId
		--	AND P.Status <> 3 -- Deleted 
		--INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
		--	AND c.IsManufacturing = 0
		--	AND c.IsDeleted = 0
		--INNER JOIN ProductVendorMapping PVM WITH (NOLOCK) ON PVM.ProductId = P.ProductId
		--	--AND PVM.IsDefault = 1
		--	AND PVM.IsDeleted = 0
		--INNER JOIN Vendors V WITH (NOLOCK) ON V.VendorId = PVM.VendorId
		--	AND V.TenantId = @TenantId
		--WHERE OrderId = @OrderId
		--	AND osi.IsDeleted = 0
		--	AND osi.SubjectTypeId = @productSubjectTypeId -- Only Products
		--	AND V.IsAutoPoByOrder = 1
		--DECLARE @Inc INT = 1
		--	,@Counter INT = 0
		--	,@POOrderSetItemId BIGINT
		--	,@POVendorId BIGINT
		--SELECT @Counter = COUNT(Id)
		--FROM #OrderSetItemsPOCreation
		--WHILE @Inc <= @Counter
		--BEGIN
		--	SET @POOrderSetItemId = 0
		--	SET @POVendorId = 0
		--	SELECT @POOrderSetItemId = OrderSetItemId
		--		,@POVendorId = VendorId
		--	FROM #OrderSetItemsPOCreation
		--	WHERE Id = @Inc
		--	EXEC [SaveProcessOrderAutoPOProducts] @TenantId = @TenantId
		--		,@VendorId = @POVendorId
		--		,@UserId = @UserId
		--		,@OrderId = @OrderId
		--		,@OrderSetItemId = @POOrderSetItemId
		--	SET @Inc = @Inc + 1
		--END
		--END
		COMMIT TRAN SaveProcessOrder_V2;

		SET @Status = 1;

		SELECT @JsonObject = (
				SELECT *
				FROM Orders
				WHERE OrderId = @OrderId
				FOR JSON AUTO
				);

		SELECT @Message = 'Your order has been successfully Processed.';

		SET @Error = NULL;

		--DECLARE @MappedSetItem VARCHAR (MAX)
		--SELECT @MappedSetItem = STRING_AGG(OrderSetItemId,',')
		--FROM #OrderSetItemsPOCreation
		SELECT @Status AS [Status]
			,@Message AS [Message]
			,@JsonObject AS [Data]
			,@Error AS [Error]
			--,@MappedSetItem AS OrderSetItemId
	END TRY

	BEGIN CATCH
		-- Rollback the transaction in case of an error
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN SaveProcessOrder_V2;

		SET @Status = 0;

		DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
		DECLARE @ObjectName VARCHAR(500);

		SET @ObjectName = OBJECT_NAME(@@PROCID);

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
			SELECT @Message = 'Your order could not be Processed.';
		END

		IF @Error IS NULL
		BEGIN
			SELECT @Error = ERROR_MESSAGE();
		END

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,@JsonObject AS [Data]
			,@Error AS [Error]
			--,@MappedSetItem AS OrderSetItemId
	END CATCH
END

GO

