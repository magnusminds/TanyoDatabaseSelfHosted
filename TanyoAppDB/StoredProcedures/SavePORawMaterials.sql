CREATE OR ALTER   PROC [dbo].[SavePORawMaterials]
(
	@PORawMaterialId BIGINT
	,@TenantId BIGINT
	,@VendorId BIGINT
	,@OrderDate DATE
	,@Status INT
	,@UserId BIGINT
	,@PORawMaterialItems NVARCHAR(MAX)
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		IF @PORawMaterialId > 0
			AND NOT EXISTS (
				SELECT 1
				FROM dbo.PORawMaterials WITH (NOLOCK)
				WHERE PORawMaterialId = @PORawMaterialId
					AND [Status] = 1
				)
		BEGIN
			SELECT CAST(0 AS BIGINT) AS NewPORawMaterialId
				,'Only Pending purchase orders can be updated.' AS [Message];

			RETURN
		END

		BEGIN TRAN SavePORawMaterials

		DECLARE @NewPORawMaterialId BIGINT

		-- =========================================
		-- INSERT CASE (New PO)
		-- =========================================
		IF @PORawMaterialId = 0
		BEGIN
			DECLARE @PONumber VARCHAR(20)
			SELECT @PONumber = [dbo].[GetPORawMaterialNumber](@TenantId)

			INSERT INTO [dbo].[PORawMaterials]
			(
				[TenantId]
				,[VendorId]
				,[PONumber]
				,[OrderDate]
				,[Status]
				,[CreatedBy]
			)
			VALUES
			(
				@TenantId
				,@VendorId
				,@PONumber
				,@OrderDate
				,@Status
				,@UserId
			)

			SET @NewPORawMaterialId = SCOPE_IDENTITY()
		END
		-- =========================================
		-- UPDATE CASE (Existing PO)
		-- =========================================
		ELSE
		BEGIN
			UPDATE dbo.PORawMaterials
			SET
				OrderDate = @OrderDate
				,Status = @Status
				,UpdatedBy = @UserId
				,UpdatedDate = SYSDATETIMEOFFSET()
				,UpdatedUTCDate = GETUTCDATE()
			WHERE PORawMaterialId = @PORawMaterialId

			SET @NewPORawMaterialId = @PORawMaterialId

			-- Optionally delete old items before re-inserting
			DELETE FROM dbo.PORawMaterialItems WHERE PORawMaterialId = @NewPORawMaterialId
		END

		-- =========================================
		-- INSERT ITEMS
		-- =========================================
		;WITH POItems AS (
			SELECT
				RawMaterialId
				,Quantity
				,VendorRawMaterialPrice
				,ExpectedDeliveryDate
				,Status
				,Remarks
			FROM OPENJSON(@PORawMaterialItems)
			WITH (
				RawMaterialId BIGINT
				,Quantity DECIMAL(18,2)
				,VendorRawMaterialPrice DECIMAL(18,2)
				,ExpectedDeliveryDate DATE
				,Status INT
				,Remarks NVARCHAR(500)
			)
		)
		INSERT INTO dbo.PORawMaterialItems
		(
			PORawMaterialId
			,RawMaterialId
			,Quantity
			,UnitPrice
			,ExpectedDeliveryDate
			,Status
			,Remarks
			,CreatedBy
		)
		SELECT
			@NewPORawMaterialId
			,RawMaterialId
			,Quantity
			,VendorRawMaterialPrice
			,ExpectedDeliveryDate
			,Status
			,Remarks
			,@UserId
		FROM POItems

		DECLARE @TotalAmount DECIMAL(18, 2)

		SELECT @TotalAmount = SUM(TotalPrice)
		FROM dbo.PORawMaterialItems poi
		WHERE poi.PORawMaterialId = @NewPORawMaterialId

		UPDATE dbo.PORawMaterials
		SET TotalAmount = @TotalAmount
		WHERE PORawMaterialId = @NewPORawMaterialId

		COMMIT TRAN SavePORawMaterials

		SELECT @NewPORawMaterialId AS NewPORawMaterialId
			,'' AS [Message]
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 
		ROLLBACK TRAN SavePORawMaterials

		DECLARE @ObjectName VARCHAR(500)
		,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

