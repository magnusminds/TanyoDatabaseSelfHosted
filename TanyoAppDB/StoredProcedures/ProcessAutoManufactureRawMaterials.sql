CREATE PROCEDURE [dbo].[ProcessAutoManufactureRawMaterials] (
	@OrderId BIGINT
	,@TenantId INT
	,@UserId INT
	,@DT DATETIMEOFFSET
	,@DTUTC DATETIME
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @rawMaterialSubjectTypeId INT
		,@RawMaterialInventoryId INT
		,@QuantityNeeded NUMERIC(18, 2)
		,@oldQuantity NUMERIC(18, 2)
		,@StockAvailable BIT
		,@CheckRawMaterialStock BIT
		,@LogDescription NVARCHAR(MAX)
		,@Message NVARCHAR(MAX)
		,@OrderNo VARCHAR(50);

	SELECT @OrderNo = OrderNo
	FROM Orders WITH (NOLOCK)
	WHERE OrderId = @OrderId

	-- Moved in from SaveApprovedOrder: only needed here, so compute locally
	SELECT @CheckRawMaterialStock = (
			SELECT CheckRawMaterialStock
			FROM Tenants WITH (NOLOCK)
			WHERE TenantId = @TenantId
			);

	SELECT @rawMaterialSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'RawMaterialInventory'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	DROP TABLE IF EXISTS #TempProductMaterial;

		CREATE TABLE #TempProductMaterial (
			Id INT IDENTITY
			,ProductId BIGINT
			,QuantityNeeded NUMERIC(18, 2)
			);

	INSERT INTO #TempProductMaterial (
		ProductId
		,QuantityNeeded
		)
	SELECT rm.RawMaterialInventoryId AS ProductId
		,SUM(pm.Qty * osi.Quantity) AS QuantityNeeded
	FROM ProductMaterials pm WITH (NOLOCK)
	INNER JOIN OrderSetItems osi WITH (NOLOCK) ON pm.ProductId = osi.SubjectId
	INNER JOIN RawMaterialInventory rm WITH (NOLOCK) ON pm.SubjectId = rm.RawMaterialId
	WHERE osi.OrderId = @OrderId
		AND osi.IsDeleted = 0
	GROUP BY rm.RawMaterialInventoryId;

	DECLARE @RawIndex INT = 1
	DECLARE @RawCount INT = (
			SELECT MAX(Id)
			FROM #TempProductMaterial
			)

	WHILE @RawIndex <= @RawCount
	BEGIN
		SELECT @RawMaterialInventoryId = ProductId
			,@QuantityNeeded = QuantityNeeded
		FROM #TempProductMaterial
		WHERE Id = @RawIndex

		SELECT @oldQuantity = pq.Inventory
		FROM RawMaterialInventory pq WITH (NOLOCK)
		WHERE pq.RawMaterialInventoryId = @RawMaterialInventoryId;

		IF @CheckRawMaterialStock = 1
		BEGIN
			SELECT @StockAvailable = (
					SELECT COUNT(*)
					FROM RawMaterialInventory WITH (NOLOCK)
					WHERE RawMaterialInventoryId = @RawMaterialInventoryId
						AND (Inventory - @QuantityNeeded >= 0)
					);

			IF @StockAvailable = 0
			BEGIN
				SELECT 'RawMaterials quantities cannot go negative for some records.' AS Message;

				RETURN;
			END
		END

		-- Update RawMaterialInventory for each product
		UPDATE RawMaterialInventory
		SET Inventory = Inventory - @QuantityNeeded
			,LastModifiedBy = @UserId
			,LastModifiedDate = @DT
			,LastModifiedUTCDate = @DTUTC
		WHERE RawMaterialInventoryId = @RawMaterialInventoryId;

		-- Build the description into a variable first (avoids inline
		-- string-concatenation-in-EXEC syntax issues), then log via
		-- shared SaveActivityLog SP instead of direct INSERT
		SET @LogDescription = 'RawMaterial Inventory has been updated from ' + CAST(@oldQuantity AS NVARCHAR(50)) + ' to ' + CAST((@oldQuantity - @QuantityNeeded) AS NVARCHAR(50)) + ' (-' + CAST(@QuantityNeeded AS NVARCHAR(50)) + ') for order ' + CAST(@OrderNo AS NVARCHAR(50));

		EXEC [dbo].[SaveActivityLog] @SubjectTypeId = @rawMaterialSubjectTypeId
			,@SubjectId = @RawMaterialInventoryId
			,@Description = @LogDescription
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DT
			,@CreatedUTCDate = @DTUTC

		SET @RawIndex = @RawIndex + 1
	END

	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

