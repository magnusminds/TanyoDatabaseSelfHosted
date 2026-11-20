/*
    EXEC [dbo].[DeleteOrderSet_V2]
        @OrderSetId = 35,
        @DeletedBy = 1,
        @TenantId = 2,
		@ResultMessage = '' OUTPUT
*/
CREATE PROCEDURE [dbo].[DeleteOrderSet_V2] (
	@OrderSetId BIGINT
	,@DeletedBy BIGINT
	,@TenantId INT
	,@ResultMessage VARCHAR(MAX) = '' OUTPUT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Status BIT = 0
		,@Message VARCHAR(200)
		,@ErrorMsg VARCHAR(MAX)
		,@OrderId BIGINT
		,@OrderSetItemId BIGINT
		,@ID INT = 1
		,@Count INT
		,@dtoffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtutc DATETIME = GETUTCDATE()

	BEGIN TRY
		/*
            Get all active items for this OrderSet.

            We keep the list before calling the delete SP because
            DeleteOrderSetItems_New will physically delete the item.
        */
		DECLARE @OrderSetItems TABLE (
			ID INT IDENTITY(1, 1) PRIMARY KEY
			,OrderSetItemId BIGINT
			);

		INSERT INTO @OrderSetItems (OrderSetItemId)
		SELECT OrderSetItemId
		FROM OrderSetItems
		WHERE OrderSetId = @OrderSetId
			AND IsDeleted = 0

		SELECT @Count = COUNT(1)
		FROM @OrderSetItems;

		BEGIN TRANSACTION DeleteOrderSetV2

		/*
            Delete each OrderSetItem using the common
            DeleteOrderSetItems_New procedure.
        */
		WHILE @ID <= @Count
		BEGIN
			SET @ResultMessage = '';

			SELECT @OrderSetItemId = OrderSetItemId
			FROM @OrderSetItems
			WHERE ID = @ID;

			EXEC dbo.DeleteOrderSetItems_V2 @OrderSetItemId = @OrderSetItemId
				,@DeletedBy = @DeletedBy
				,@TenantId = @TenantId
				,@resultMessage = @ResultMessage OUTPUT;

			IF @ResultMessage <> ''
			BEGIN
				RAISERROR (
						'%s'
						,16
						,1
						,@ResultMessage
						)

				RETURN
			END

			SET @ID = @ID + 1;
		END;

		UPDATE OrderSets
		SET IsDeleted = 1
			,UpdatedDate = @dtoffset
			,UpdatedUTCDate = @dtutc
		WHERE OrderSetId = @OrderSetId
			AND IsDeleted = 0

		SET @Message = '';

		COMMIT TRANSACTION DeleteOrderSetV2
	END TRY

BEGIN CATCH
		IF XACT_State() > 0
			ROLLBACK TRANSACTION;

		DECLARE @ObjectName VARCHAR(500);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		IF @ResultMessage IS NULL
			OR @ResultMessage = ''
		BEGIN
			SET @ResultMessage = 'Error in DeleteOrderSet_V2: ' + @ErrorMsg;
		END
	END CATCH
END

GO

