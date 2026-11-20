CREATE   PROCEDURE [dbo].[ImportUpdateFabricStock] (
	@WrkProductID BIGINT
	,@UserId INT
	,@TotalRecords INT
	,@ProcessStartDate DATETIMEOFFSET = NULL
	,@ProcessEndDate DATETIMEOFFSET = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRAN;

		DECLARE @TenantId BIGINT
			,@WrkImportFileID BIGINT
			,@CategoryName VARCHAR(MAX)
			,@ProductTitle VARCHAR(MAX)
			,@ModelNo VARCHAR(MAX)
			,@WarehouseName VARCHAR(MAX)
			,@StockQty VARCHAR(MAX)
			,@CategoryId INT
			,@ProductId BIGINT
			,@WarehouseId BIGINT
			,@OtherWarehouseId BIGINT
			,@TenantLogo VARCHAR(800)
			,@ErrorMessage VARCHAR(MAX) = ''
			,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@dtUTC DATETIME = GETUTCDATE()
			,@StockQtyNumeric NUMERIC(18,2)
			,@CategoryTypeId BIGINT;

			DECLARE @OldQty NUMERIC(18,2) = 0
			,@ProductQty NUMERIC(18,2) = 0
			,@OldProductQty NUMERIC(18,2);

			DECLARE @TotalQty NUMERIC(18,2);

		SELECT @TenantId = WIF.TenantId
			,@WrkImportFileID = WP.WrkImportFileID
			,@CategoryName = WP.CategoryName
			,@ProductTitle = WP.ProductTitle
			,@ModelNo = WP.ModelNo
			,@WarehouseName = WP.WarehouseName
			,@StockQty = WP.StockQty
		FROM WrkProducts WP WITH (NOLOCK)
		INNER JOIN WrkImportFiles WIF ON WP.WrkImportFileID = WIF.WrkImportFileID
		WHERE WP.WrkProductID = @WrkProductID;

		SELECT @TenantLogo = LogoPath
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId


		SELECT @CategoryId = CategoryId
			,@CategoryTypeId = CategoryTypeId
		FROM Categories WITH (NOLOCK)
		WHERE LOWER(CategoryName) = LOWER(@CategoryName)
			AND TenantId = @TenantId
			AND IsDeleted = 0;

		IF @CategoryName IS NULL
			OR @CategoryName = ''
			SET @ErrorMessage += 'Category is required. ';
		ELSE IF @CategoryId IS NULL
			SET @ErrorMessage += 'Category does not exist. ';


		IF ISNULL(@WarehouseName, '') <> ''
		BEGIN
			SELECT @WarehouseId = Id
			FROM Warehouse WITH (NOLOCK)
			WHERE LOWER(Name) = LOWER(@WarehouseName)
			AND TenantId = @TenantId;

			IF @WarehouseId IS NULL
				SET @ErrorMessage += 'Requested warehouse record does not exist. ';
		END
		ELSE
			SET @WarehouseId = 0;

		IF ISNULL(@ProductTitle, '') = ''
			SET @ErrorMessage += 'Product Title is required. ';


		IF ISNULL(@ModelNo, '') = ''
			SET @ErrorMessage += 'ModelNo is required. ';
		ELSE
		BEGIN
			IF CHARINDEX(' ', @ModelNo) > 0
				SET @ErrorMessage += 'ModelNo does not allow white space. ';

			IF LEN(@ModelNo) > 100
				SET @ErrorMessage += 'Maximum length of ModelNo is 100 characters. ';

			IF PATINDEX('%[^a-zA-Z0-9/_-]%', @ModelNo) > 0
				SET @ErrorMessage += 'ModelNo does not allow special characters. ';
			
			IF LEN(@ModelNo) > 100
				SET @ErrorMessage += 'Maximum length of ModelNo is 100 characters';
		
		END


		SET @StockQtyNumeric = TRY_CAST(@StockQty AS NUMERIC(18,2));

		IF @StockQty IS NULL
			OR @StockQty = ''
			OR @StockQtyNumeric IS NULL
			OR @StockQtyNumeric < 0
			SET @ErrorMessage += 'Current Stock must be a valid non-negative number. ';

		SELECT @ProductId = ProductId
		FROM Products WITH (NOLOCK)
		WHERE CategoryId = @CategoryId
			AND LOWER(ProductTitle) = LOWER(@ProductTitle)
			AND LOWER(ModelNo) = LOWER(@ModelNo)
			AND TenantId = @TenantId
			AND STATUS <> 3;

		IF @ProductId IS NULL
			SET @ErrorMessage += 'Product not found with given details. ';

		IF ISNULL(@CategoryTypeId,0) <> 2
		BEGIN
		     SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Product items cannot be imported through the Fabric Import module. Please use the Product Import module instead. '
		END		

		IF EXISTS (
			SELECT TOP 1 1
			FROM OrderSetItems osi WITH (NOLOCK)
			INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
			WHERE osi.SubjectId = @ProductId
			AND o.TenantId = @TenantId
			AND osi.IsDeleted = 0
			AND o.Status IN (2,3,4) -- Approved, In Progress, Completed
			AND osi.ItemStatus IN (0,1,2,4) -- Ready To Manufacturing, Manufacturing, ReadyToDelivered, Pending
		) AND @TenantId NOT IN (185,145)
		BEGIN
			SET @ErrorMessage = ISNULL(@ErrorMessage, '') + 'Stock quantity cannot be updated because this product is allocated to an active order in the Approved, In Progress, or Ready to Deliver stage.'
		END

		IF @ErrorMessage = ''
		BEGIN
			SELECT @OtherWarehouseId = Id
			FROM Warehouse WITH (NOLOCK)
			WHERE Name = 'Other'
			AND TenantId = @TenantId;

			IF @WarehouseId = 0
			BEGIN
				SET @WarehouseId = @OtherWarehouseId;
				SET @WarehouseName = 'Other';
			END

			SELECT @OldProductQty = Quantity
			from ProductQuantities WITH (NOLOCK)
			where ProductId = @ProductId

			SELECT @OldQty = Quantity
			FROM ProductQuantitiesByWarehouse WITH (NOLOCK)
			WHERE ProductId = @ProductId
				AND WarehouseId = @WarehouseId;

			IF EXISTS (
					SELECT 1
					FROM ProductQuantitiesByWarehouse WITH (NOLOCK)
					WHERE ProductId = @ProductId
						AND WarehouseId = @WarehouseId
					)
			BEGIN
				UPDATE PQBW
				SET Quantity = @StockQtyNumeric
					,QuantityDate = CAST(@dt AS DATE)
					,LastModifiedBy = @UserId
					,LastModifiedDate = @dt
					,LastModifiedUTCDate = @dtUTC
					FROM ProductQuantitiesByWarehouse PQBW
				WHERE ProductId = @ProductId
					AND WarehouseId = @WarehouseId;
			END
			ELSE
			BEGIN
				INSERT INTO ProductQuantitiesByWarehouse (
					ProductId
					,WarehouseId
					,Quantity
					,QuantityDate
					,LastModifiedBy
					,LastModifiedDate
					,LastModifiedUTCDate
					)
				VALUES (
					@ProductId
					,@WarehouseId
					,@StockQtyNumeric
					,CAST(@dt AS DATE)
					,@UserId
					,@dt
					,@dtUTC
					);
			END

			SELECT @TotalQty = SUM(Quantity)
			FROM ProductQuantitiesByWarehouse WITH (NOLOCK)
			WHERE ProductId = @ProductId;

			DECLARE @SellableQty INT
			DECLARE @ReservedQty INT

			SELECT @ReservedQty = SUM(osi.Quantity)
			FROM OrderSetItems osi WITH (NOLOCK)
			INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
			WHERE osi.SubjectId = @ProductId
			AND o.TenantId = @TenantId
			AND osi.IsDeleted = 0
			AND o.Status IN (2,3,4) -- Approved, In Progress, Completed
			AND osi.ItemStatus IN (0,1,2,4) -- Ready To Manufacturing, Manufacturing, ReadyToDelivered, Pending
		
			SELECT @SellableQty = @TotalQty - ISNULL(@ReservedQty, 0)

			UPDATE PQ
			SET Quantity = @SellableQty
				,QuantityDate =@dt
				,LastModifiedBy = @UserId
				,LastModifiedDate = @dt
				,LastModifiedUTCDate = @dtUTC
			FROM ProductQuantities PQ
			WHERE ProductId = @ProductId;

			INSERT INTO InventoryLogs
			(
				ProductId
				,Description
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
			)
			SELECT @ProductId
				,'Inventory has been replaced with ' + CAST(@SellableQty AS VARCHAR(10)) + ' based on the importing Stock file.'
				,@UserId
				,@DT
				,@DTUTC

			INSERT INTO InventoryLogs
			(
				ProductId
				,WarehouseId
				,Description
				,CreatedBy
			)
			SELECT @ProductId
				,@WarehouseId
				,'Inventory has been replaced with ' + CAST(@StockQtyNumeric AS NVARCHAR(10)) + ' in ' + @WarehouseName + ' warehouse based on the importing Stock file.'
				,@UserId

			UPDATE WrkProducts
			SET STATUS = 2
				,ErrorMessage = NULL
			WHERE WrkProductID = @WrkProductID;


			INSERT INTO InwardDetailsEntry (
				ProductId
				,Amount
				,Quantity
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,WarehouseId
				,IsDeleted
				,InwardId
				)
			SELECT P.ProductId
				,P.CostPrice
				,@StockQtyNumeric
				,@UserId
				,@dt
				,@dtUTC
				,CASE 
					WHEN @WarehouseId > 0
						THEN @WarehouseId
					ELSE NULL
					END
				,0
				,0
			FROM Products P
			WHERE P.ProductId = @ProductId;

		END
		ELSE
		BEGIN
			UPDATE WrkProducts
			SET STATUS = 3
				,ErrorMessage = @ErrorMessage
			WHERE WrkProductID = @WrkProductID;
		END

		UPDATE WrkImportFiles
		SET Success = CASE 
				WHEN @ErrorMessage = ''
					THEN ISNULL(Success, 0) + 1
				ELSE ISNULL(Success,0)
				END
			,Failed = CASE 
				WHEN @ErrorMessage <> ''
					THEN ISNULL(Failed, 0) + 1
				ELSE ISNULL(Failed,0)
				END
			,STATUS = 2
			,TotalRecords = @TotalRecords
			,ProcessStartDate = CASE WHEN @ProcessStartDate IS NULL THEN ProcessStartDate ELSE @ProcessStartDate END
			,ProcessEndDate = CASE WHEN @ProcessEndDate IS NULL THEN ProcessEndDate ELSE @ProcessEndDate END
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @dtUTC
		WHERE WrkImportFileID = @WrkImportFileID;


		SELECT CASE WHEN @ErrorMessage = '' THEN @ProductId ELSE NULL END AS ProductId
			,@TenantId AS TenantId
			,CASE WHEN @ErrorMessage = '' THEN @TenantLogo ELSE NULL END AS TenantLogo
			,@ErrorMessage AS ErrorMessage

		COMMIT;
	END TRY

BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		SELECT NULL AS ProductId
			,@TenantId AS TenantId
			,NULL AS TenantLogo
			,@ErrorMessage AS ErrorMessage

	END CATCH
END

GO

