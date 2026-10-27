/*
	DECLARE @Result INT
	
	EXEC dbo.DeductProductSaleableQuantity
		@TenantId = 0
		,@UserId = 0
		,@ProductId = 0
		,@OrderNo = ''
		,@Quantity = 0
		,@Description = ''
		,@Result = @Result OUTPUT
		,@InwardNo = NULL
		,@StockTransferNo = NULL
		,@PurchaseOrderNo  = NULL
	
	SELECT @Result
*/
CREATE PROC [dbo].[DeductProductSaleableQuantity] (
	@TenantId INT
	,@UserId BIGINT
	,@ProductId BIGINT
	,@OrderNo VARCHAR(50)
	,@Quantity NUMERIC(18, 2)
	,@Description VARCHAR(500)
	,@Result INT OUTPUT
	,@InwardNo VARCHAR(50) = NULL
	,@StockTransferNo VARCHAR(50) = NULL
	,@PurchaseOrderNo VARCHAR(50) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		-- Start a transaction
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
			FROM ProductQuantities pq WITH (NOLOCK)
			WHERE ProductId = @ProductId
				AND (Quantity - @Quantity >= 0)

			IF @StockAvailable = 0
			BEGIN
				SET @Result = - 1 --'Product quantity cannot be negative.'

				RETURN
			END
		END

		BEGIN TRANSACTION DeductProductSaleableQuantity

		UPDATE pq
		SET pq.Quantity = pq.Quantity - @Quantity
			,pq.LastModifiedBy = @UserId
			,pq.LastModifiedDate = @DtNowOffset
			,pq.LastModifiedUTCDate = @DtNowUTC
		FROM ProductQuantities pq
		WHERE pq.ProductId = @ProductId

		INSERT INTO dbo.InventoryLogs (
			ProductId
			,Description
			,OrderNo
			,InwardNo
			,StockTransferNo
			,PurchaseOrderNo
			,CreatedBy
			)
		SELECT @ProductId
			,@Description
			,@OrderNo
			,@InwardNo
			,@StockTransferNo
			,@PurchaseOrderNo
			,@UserId

		SET @Result = 1 -- Success

		-- Commit a transaction
		COMMIT TRAN DeductProductSaleableQuantity
	END TRY

	BEGIN CATCH
		-- Rollback the transaction
		IF XACT_State() > 0
			ROLLBACK TRANSACTION

		DECLARE @ErrorSeverity INT

		SELECT @ErrorSeverity = ERROR_SEVERITY()

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX)

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ErrorMsg = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg

		SET @Result = - 2 -- Unexpected database error
	END CATCH
END

GO

