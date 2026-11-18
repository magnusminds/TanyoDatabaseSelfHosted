/*
	EXEC [dbo].[PopulateInventoryLogs]
		@ProductId = 26916,
		@WarehouseId = NULL,
		@Description = 'Stock adjusted after inventory reconciliation',
		@OrderNo = NULL,
		@InwardNo = NULL,
		@PurchaseOrderNo = NULL,
		@Remarks = NULL,
		@UserId = 4489;
*/
CREATE PROCEDURE [dbo].[zPopulateInventoryLogs] (
	@ProductId BIGINT
	,@WarehouseId BIGINT = NULL
	,@Description VARCHAR(500)
	,@OrderNo VARCHAR(50) = NULL
	,@InwardNo VARCHAR(50) = NULL
	,@PurchaseOrderNo VARCHAR(50) = NULL
	,@Remarks NVARCHAR(1000) = NULL
	,@UserId INT
	,@CreatedDate DATETIMEOFFSET = NULL
	,@CreatedUTCDate DATETIME = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	IF @CreatedDate IS NULL
		SET @CreatedDate = SYSDATETIMEOFFSET();
	IF @CreatedUTCDate IS NULL
		SET @CreatedUTCDate = GETUTCDATE();

	BEGIN TRY
		BEGIN TRAN;

		INSERT INTO dbo.InventoryLogs (
			ProductId
			,WarehouseId
			,Description
			,OrderNo
			,InwardNo
			,PurchaseOrderNo
			,Remarks
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			)
		VALUES (
			@ProductId
			,@WarehouseId
			,@Description
			,@OrderNo
			,@InwardNo
			,@PurchaseOrderNo
			,@Remarks
			,@UserId
			,@CreatedDate
			,@CreatedUTCDate
			);

		COMMIT TRAN;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN;

		THROW;
	END CATCH;
END;

GO

