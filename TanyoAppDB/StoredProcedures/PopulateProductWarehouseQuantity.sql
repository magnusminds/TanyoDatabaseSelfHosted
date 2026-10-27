/*  
	EXEC dbo.PopulateProductWarehouseQuantity
		@TenantId = 0
		,@UserId = 0
		,@ProductId = 0
		,@WarehouseId = 0
		,@Quantity = 0
		,@Description = '' 
*/
CREATE PROC [dbo].[PopulateProductWarehouseQuantity] (
	@TenantId INT
	,@UserId BIGINT
	,@ProductId BIGINT
	,@WarehouseId INT
	,@Quantity NUMERIC(18, 2)
	,@Description VARCHAR(500)
	,@Remarks VARCHAR(1000) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		-- Start a transaction  
		BEGIN TRANSACTION PopulateProductWarehouseQuantity

		DECLARE @DtNow DATETIME = CAST(GETDATE() AS DATE)

		IF NOT EXISTS (
				SELECT TOP 1 1
				FROM ProductQuantitiesByWarehouse pqw WITH (NOLOCK)
				WHERE pqw.ProductId = @ProductId
					AND pqw.WarehouseId = @WarehouseId
				)
		BEGIN
			INSERT INTO ProductQuantitiesByWarehouse (
				ProductId
				,WarehouseId
				,Quantity
				,QuantityDate
				,LastModifiedBy
				)
			SELECT @ProductId
				,@WarehouseId
				,@Quantity
				,@DtNow
				,@UserId

			INSERT INTO dbo.InventoryLogs (
				ProductId
				,WarehouseId
				,Description
				,CreatedBy
				,Remarks
				)
			SELECT @ProductId
				,@WarehouseId
				,@Description
				,@UserId
				,@Remarks
		END

		-- Commit a transaction  
		COMMIT TRAN PopulateProductWarehouseQuantity
	END TRY

	BEGIN CATCH
		-- Rollback the transaction  
		IF XACT_State() <> 0
			ROLLBACK TRANSACTION

		DECLARE @ErrorSeverity INT

		SELECT @ErrorSeverity = ERROR_SEVERITY()

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX)

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ErrorMsg = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog 
			 @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg

	END CATCH
END

GO

