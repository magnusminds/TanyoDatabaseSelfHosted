CREATE   PROC [dbo].[DeletePOProducts]
(
	@POProductId BIGINT
	,@TenantId BIGINT
	,@UserId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRAN
		
		-- Validate record exists
		IF EXISTS (
			SELECT 1
			FROM dbo.POProducts WITH (NOLOCK)
			WHERE POProductId = @POProductId
			AND TenantId = @TenantId
			AND IsDeleted = 0
		)
		BEGIN
			-- Soft delete PO
			UPDATE dbo.POProducts
			SET 
				IsDeleted = 1,
				UpdatedBy = @UserId,
				UpdatedDate = SYSDATETIMEOFFSET(),
				UpdatedUTCDate = GETUTCDATE()
			WHERE POProductId = @POProductId
			AND TenantId = @TenantId

			SELECT 'Purchase Order deleted successfully.' AS Message, 1 AS Status
		END
		ELSE
		BEGIN
			SELECT 'Purchase Order not found or already deleted.' AS Message, 0 AS Status
		END

		COMMIT TRAN

	END TRY
BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

