/*
	DECLARE @Result INT

	EXEC dbo.DeductProductWarehouseQuantity
		@TenantId = 0
		,@UserId = 0
		,@ProductId = 0
		,@WarehouseId = 0
		,@OrderNo = ''
		,@Quantity = 0
		,@Description = ''
		,@Result = @Result OUTPUT

	SELECT @Result
*/
CREATE   PROC [dbo].[DeductProductWarehouseQuantity]
(
	@TenantId INT
	,@UserId BIGINT
	,@ProductId BIGINT
	,@WarehouseId INT
	,@OrderNo VARCHAR(50)
	,@Quantity NUMERIC(18, 2)
	,@Description VARCHAR(500)
	,@Result INT OUTPUT
	,@InwardNo VARCHAR(50) = NULL
	,@StockTransferNo VARCHAR(50) = NULL
	,@PurchaseOrderNo VARCHAR(50)  = NULL
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	BEGIN TRY

			DECLARE @DtNowOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
					,@DtNowUTC DATETIME = GETUTCDATE()
					,@CheckProductStock BIT
					,@StockAvailable BIT
					,@Message VARCHAR(MAX)

			--Check Tenant maintain only positive quantity
			SELECT @CheckProductStock = CheckProductStock
			FROM Tenants t WITH (NOLOCK)
			WHERE t.TenantId = @TenantId

			IF @CheckProductStock = 1 --Check product quantity should be stay in positive, after deducting
			BEGIN
				SELECT @StockAvailable = COUNT(1)
				FROM ProductQuantitiesByWarehouse pqw WITH (NOLOCK)
				WHERE ProductId = @ProductId
				AND WarehouseId = @WarehouseId
				AND (Quantity - @Quantity >= 0)

				IF @StockAvailable = 0
				BEGIN
					SET @Result = -1 --'Product quantity cannot be negative.'
					RETURN
				END
			END

			BEGIN TRANSACTION DeductProductWarehouseQuantity

			UPDATE pqw
			SET pqw.Quantity = pqw.Quantity - @Quantity
				,pqw.LastModifiedBy = @UserId
				,pqw.LastModifiedDate = @DtNowOffset
				,pqw.LastModifiedUTCDate = @DtNowUTC
			FROM ProductQuantitiesByWarehouse pqw
			WHERE pqw.ProductId = @ProductId
			AND pqw.WarehouseId = @WarehouseId

			INSERT INTO dbo.InventoryLogs
			(
				ProductId
				,WarehouseId
				,Description
				,OrderNo
				,InwardNo
				,StockTransferNo
				,PurchaseOrderNo
				,CreatedBy
			)
			SELECT @ProductId
				,@WarehouseId
				,@Description
				,@OrderNo
				,@InwardNo
				,@StockTransferNo
				,@PurchaseOrderNo
				,@UserId
		
		SET @Result = 1 -- Success

		-- Commit a transaction
		COMMIT TRAN 
	END TRY
	BEGIN CATCH
		-- Rollback the transaction
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN DeductProductWarehouseQuantity

		DECLARE @ErrorSeverity INT
		SELECT @ErrorSeverity = ERROR_SEVERITY()

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX)

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ErrorMsg = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog
			@ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg
		
		SET @Result = -2 -- Unexpected database error
	
	END CATCH
END

GO

