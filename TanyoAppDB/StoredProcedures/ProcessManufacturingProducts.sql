CREATE   PROCEDURE [dbo].[ProcessManufacturingProducts] (
	@OrderId BIGINT
	,@TenantId INT
	,@UserId INT
	,@AutoProcess BIT
	,@RequestProcessOrder NVARCHAR(MAX) = NULL
	--,@Status BIT = 0  OUTPUT
	--,@Message NVARCHAR(MAX) = NULL OUTPUT
	--,@Error NVARCHAR(MAX) = NULL OUTPUT
	)
WITH ENCRYPTION
AS
BEGIN
	IF OBJECT_ID('tempdb..#OrderSetItemsData') IS NOT NULL
		DROP TABLE #OrderSetItemsData

	IF OBJECT_ID('tempdb..#OrderManufacturingWorkflows') IS NOT NULL
		DROP TABLE #OrderManufacturingWorkflows

	BEGIN TRY

	DECLARE @OrderSubjectTypeId INT
		,@OrderNo VARCHAR(50)
		,@productSubjectTypeId INT
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
		,@JsonObject NVARCHAR(MAX)
		,@Dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@DtUTC DATETIME = GETUTCDATE()
		,@IsEnableProductProcessingWorkflow BIT;

		SELECT
			@IsEnableProductProcessingWorkflow = ISNULL(EnableProductProcessingWorkflow, 0)
		FROM TenantConfigurations WITH (NOLOCK)
		WHERE TenantId = @TenantId;

	DECLARE @ProcessOrder TABLE (
		RowId INT IDENTITY(1, 1)
		,OrderSetItemID BIGINT
		,ProductID BIGINT
		,StockQty DECIMAL(18, 2)
		,ManufacturingWorkflowID BIGINT
		,ContractorUserID BIGINT
		,SupervisorUserID BIGINT
		,Position INT
		)

	CREATE TABLE #OrderSetItemsData (
		Id INT IDENTITY
		,OrderSetItemId BIGINT
		,ParentOrderSetItemId BIGINT
		,DeliveryNo VARCHAR(Max)
		,SubjectId INT
		,SubjectTypeId INT
		,ItemStatus INT
		,StockQty DECIMAL(18, 2)
		);;

	INSERT INTO #OrderSetItemsData (
		OrderSetItemId
		,ParentOrderSetItemId
		,DeliveryNo
		,SubjectId
		,SubjectTypeId
		,ItemStatus
		,StockQty
		)
	SELECT OrderSetItemId
		,ParentOrderSetItemId
		,DeliveryNo
		,SubjectId
		,SubjectTypeId
		,ItemStatus
		,StockQty
	FROM OrderSetItems osi
	INNER JOIN Products p ON p.ProductId = OSI.SubjectId
	INNER JOIN Categories c ON c.CategoryId = p.CategoryId
	WHERE OrderId = @OrderId
		-- TAN-4714: only in-house manufacturing enters the manufacturing workflow path
		AND c.IsManufacturing = 1
		AND c.IsInHouseManufacturing = 1
		AND osi.IsDeleted = 0
		AND NOT EXISTS (SELECT 1 
						FROM OrderManufacturingWorkflows OMWF WITH (NOLOCK)
						WHERE OMWF.OrderSetItemId = OSI.OrderSetItemId
						);

	IF (@RequestProcessOrder IS NOT NULL)
	BEGIN
		INSERT INTO @ProcessOrder (
			OrderSetItemID
			,ProductID
			,StockQty
			,ManufacturingWorkflowID
			,ContractorUserID
			,SupervisorUserID
			,Position
			)
		SELECT j.orderSetItemID
			,j.productID
			,j.stockQty
			,mwf.manufacturingWorkflowID
			,mwf.contractorUserID
			,mwf.supervisorUserID
			,ROW_NUMBER() OVER (
				PARTITION BY j.orderSetItemID ORDER BY j.orderSetItemID ASC
				)
		FROM OPENJSON(@RequestProcessOrder) WITH (
				OrderSetItemID INT
				,ProductID INT
				,StockQty DECIMAL(18, 2)
				,ManufacturingWorkflowData NVARCHAR(MAX) AS JSON
				) AS j
		CROSS APPLY OPENJSON(j.manufacturingWorkflowData) WITH (
				ManufacturingWorkflowID INT
				,ContractorUserID INT
				,SupervisorUserID INT
				) AS mwf;

		IF (
				(
					SELECT COUNT(1)
					FROM @ProcessOrder
					) = 0
				)
		BEGIN
			INSERT INTO @ProcessOrder (
				OrderSetItemID
				,ProductID
				,StockQty
				,ManufacturingWorkflowID
				,ContractorUserID
				,SupervisorUserID
				,Position
				)
			SELECT j.orderSetItemID
				,j.productID
				,j.stockQty
				,NULL
				,NULL
				,NULL
				,ROW_NUMBER() OVER (
					PARTITION BY j.orderSetItemID ORDER BY j.orderSetItemID ASC
					)
			FROM OPENJSON(@RequestProcessOrder) WITH (
					OrderSetItemID INT
					,ProductID INT
					,StockQty DECIMAL(18, 2)
					,ManufacturingWorkflowData NVARCHAR(MAX) AS JSON
					) AS j
		END
	END
	ELSE
	BEGIN
		INSERT INTO @ProcessOrder (
			OrderSetItemID
			,ProductID
			,StockQty
			,ManufacturingWorkflowID
			,ContractorUserID
			,SupervisorUserID
			,Position
			)
		SELECT osi.orderSetItemID
			,p.productID
			,osi.StockQty
			,p.ManufacturingWorkflowId
			,p.ContractorUserID
			,p.SupervisorUserID
			,p.Position
		FROM ProductWorkflows p
		INNER JOIN #OrderSetItemsData osi ON osi.SubjectId = p.ProductID
	END

	-- Create OrderManufacturingWorkflows temp table.
	CREATE TABLE #OrderManufacturingWorkflows (
		Id INT IDENTITY
		,OrderManufacturingWorkflowId BIGINT
		,TentativeDays INT
		);

	DECLARE @Index INT = 1
		,@Count INT = (
			SELECT MAX(Id)
			FROM #OrderSetItemsData
			);

	WHILE @Index <= @Count
	BEGIN
		SELECT @OrderSetItemId = OrderSetItemId
			,@ParentOrderSetItemId = ParentOrderSetItemId
			,@SubjectId = SubjectId
			,@SubjectTypeId = SubjectTypeId
		FROM #OrderSetItemsData
		WHERE Id = @Index

		IF (@AutoProcess = 1)
		BEGIN
			-- Update Order
			UPDATE OrderSetItems
			SET ItemStatus = 1
			WHERE OrderSetItemId = @OrderSetItemId
		END

		-- Create OrderManufacturingWorkflows.
		INSERT INTO OrderManufacturingWorkflows (
			OrderId
			,OrderSetItemId
			,ManufacturingWorkflowId
			,ContractorUserID
			,SupervisorUserID
			,Position
			,ManufacturingStatus
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			,LabourCharge
			)
		SELECT osi.OrderId
			,osi.OrderSetItemId
			,p.ManufacturingWorkflowId
			,p.ContractorUserID
			,p.SupervisorUserID
			,p.Position
			,0 AS ManufacturingStatus
			,@UserId
			,SYSDATETIMEOFFSET()
			,GETUTCDATE()
			,PWF.LabourCharge
		FROM OrderSetItems osi
		INNER JOIN @ProcessOrder p ON osi.SubjectId = p.ProductID
			AND osi.OrderSetItemId = P.OrderSetItemID
		INNER JOIN ManufacturingWorkflows mwf ON p.ManufacturingWorkflowId = mwf.ManufacturingWorkflowId
		INNER JOIN ProductWorkflows PWF ON PWF.ProductID = osi.SubjectId
			AND PWF.ManufacturingWorkflowId = mwf.ManufacturingWorkflowId
		INNER JOIN AspNetUsers u1 ON p.ContractorUserID = u1.UserId
		INNER JOIN AspNetUsers u2 ON p.SupervisorUserID = u2.UserId
		WHERE osi.OrderSetItemId = @OrderSetItemId
			AND osi.IsDeleted = 0
		ORDER BY p.ProductID
			,p.Position;

		--MFG product without Workflow
		IF @@ROWCOUNT = 0
		BEGIN
			UPDATE OrderSetItems
			SET ItemStatus = CASE
								WHEN @IsEnableProductProcessingWorkflow = 1
									THEN 4 -- Pending
								ELSE 2     -- ReadyToDelivered
							 END
			WHERE OrderSetItemId = @OrderSetItemId;

			-- Update related PO Items as Material Ready only when item moves to ReadyToDelivered
			IF @IsEnableProductProcessingWorkflow = 0
			BEGIN
				UPDATE POProductItems
				SET Status = 5,
					POItemMaterialReadyDate = GETDATE()
				WHERE VendorOrderSetItemId = @OrderSetItemId;

				-- Update PO status if all items are Material Ready & completed
				UPDATE PO
				SET PO.Status = 5,
					POMaterialReadyDate = GETDATE()
				FROM POProducts PO
				WHERE PO.VendorOrderId = @OrderId
				  AND NOT EXISTS
				  (
					  SELECT 1
					  FROM POProductItems POI
					  WHERE POI.POProductId = PO.POProductId
						AND ISNULL(POI.Status, 0) NOT IN (4,5)
				  );
			END

		END
		ELSE
		BEGIN
			-- Truncate the temporary table
			TRUNCATE TABLE #OrderManufacturingWorkflows;

			-- Update ManufacturingDeliveryDate
			INSERT INTO #OrderManufacturingWorkflows (
				OrderManufacturingWorkflowId
				,TentativeDays
				)
			SELECT omw.OrderManufacturingWorkflowId
				,pwf.TentativeDays
			FROM ProductWorkflows pwf
			INNER JOIN OrderSetItems osi ON pwf.ProductID = osi.SubjectId
			INNER JOIN OrderManufacturingWorkflows omw ON osi.OrderSetItemId = omw.OrderSetItemId
				AND pwf.ManufacturingWorkflowId = omw.ManufacturingWorkflowId
			WHERE osi.OrderSetItemId = @OrderSetItemId
				AND osi.IsDeleted = 0
			ORDER BY omw.Position

			SELECT @ManufacturingIndex = 1;

			SELECT @ManufacturingCount = (
					SELECT MAX(Id)
					FROM #OrderManufacturingWorkflows
					);

			SELECT @ManufacturingDeliveryDate = NULL

			WHILE @ManufacturingIndex <= @ManufacturingCount
			BEGIN
				SELECT @OrderManufacturingWorkflowId = OrderManufacturingWorkflowId
					,@ManufacturingDeliveryDays = TentativeDays
				FROM #OrderManufacturingWorkflows
				WHERE Id = @ManufacturingIndex

				SELECT @ManufacturingDeliveryDate = CASE 
						WHEN @ManufacturingDeliveryDate IS NULL
							THEN DATEADD(day, @ManufacturingDeliveryDays, SYSDATETIMEOFFSET())
						ELSE DATEADD(day, @ManufacturingDeliveryDays, @ManufacturingDeliveryDate)
						END;

				UPDATE OrderManufacturingWorkflows
				SET ManufacturingDeliveryDate = @ManufacturingDeliveryDate
				WHERE OrderManufacturingWorkflowId = @OrderManufacturingWorkflowId

				SET @ManufacturingIndex = @ManufacturingIndex + 1
			END
		END

		SET @Index = @Index + 1
	END

	UPDATE OSI
	SET StockQty = PRO.StockQty
	,UpdatedBy = @UserId
	,UpdatedDate = @Dt
	,UpdatedUTCDate = @DtUTC
	FROM OrderSetItems OSI
	INNER JOIN @ProcessOrder PRO ON PRO.OrderSetItemID = OSI.OrderSetItemId

	--SET @Status = 1

	END TRY

	BEGIN CATCH


		--SET @Status = 0

		--SET @Message = 'Your order could not be Processed.';


		--IF @Error IS NULL
		--BEGIN
		--	SET @Error = ERROR_MESSAGE();
		--END

		THROW;
		
	END CATCH;

END;

GO

