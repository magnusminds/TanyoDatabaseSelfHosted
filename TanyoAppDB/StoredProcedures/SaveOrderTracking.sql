CREATE PROCEDURE [dbo].[SaveOrderTracking] (
     @TenantId BIGINT
	,@ProductId BIGINT
	,@CustomerId BIGINT
	,@OrderId BIGINT
	,@OrderNo VARCHAR(20)
	,@CustomerName VARCHAR(255)
	,@Quantity NUMERIC(18, 2) = 0
	,@UserId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Date DATETIMEOFFSET = SYSDATETIMEOFFSET()
	DECLARE @DateUtc DATETIME = GETUTCDATE()

	BEGIN TRY
		BEGIN TRANSACTION SaveOrderTrack

		-- If product already exists in OrderTrack for this order, UPDATE quantity
		IF EXISTS (
			SELECT 1 
			FROM dbo.OrderTrack WITH (NOLOCK)
			WHERE OrderId = @OrderId
				AND ProductId = @ProductId
				AND TenantId = @TenantId
				AND IsDeleted = 0
		)
		BEGIN
			UPDATE dbo.OrderTrack
			SET Quantity = @Quantity
				,LastModifiedDate = @Date
				,LastModifiedUtcDate = @DateUtc
				,LastModifiedBy = @UserId
			WHERE OrderId = @OrderId
				AND ProductId = @ProductId
				AND TenantId = @TenantId
				AND IsDeleted = 0
				AND ISNULL(Quantity, 0) <> ISNULL(@Quantity, 0);
		END
		ELSE
		BEGIN
			-- If new product, INSERT into OrderTrack
			INSERT INTO dbo.OrderTrack (
				 TenantId
				,ProductId
				,CustomerId
				,OrderId
				,OrderNo
				,CustomerName
				,Quantity
				,LastModifiedDate
				,LastModifiedUtcDate
				,LastModifiedBy
				)
			VALUES (
				 @TenantId
				,@ProductId
				,@CustomerId
				,@OrderId
				,@OrderNo
				,@CustomerName
				,@Quantity
				,@Date
				,@DateUtc
				,@UserId
				);
		END

		COMMIT TRANSACTION SaveOrderTrack
	END TRY

	BEGIN CATCH
		IF @@ROWCOUNT > 0
			ROLLBACK TRANSACTION SaveOrderTrack

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END;

GO

