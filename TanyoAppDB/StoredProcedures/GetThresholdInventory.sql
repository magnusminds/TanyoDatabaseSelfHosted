-- =============================================
-- Author		: MagnusMinds - JenilV
-- Ref			: TAN-963, TAN-1008, TAN-1009
-- Create date	: 2023-Sep-12
-- Description	: Get Threshold Inventory (Minimum Limit of Products and RawMaterials Reached)
-- =============================================
/*
	EXEC [dbo].[GetThresholdInventory]
		@TenantID = 1
*/
CREATE PROCEDURE [dbo].[GetThresholdInventory] (
	@TenantId INT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		-- Start a transaction
		DECLARE @ProductInventoryJsonObject NVARCHAR(MAX)
			,@RawMaterialInventoryJsonObject NVARCHAR(MAX)
			,@Status BIT
			,@Message NVARCHAR(MAX)
			,@Error NVARCHAR(MAX);

		SELECT @ProductInventoryJsonObject = (
				SELECT Product.ProductTitle AS ProductTitle	
					,Quantities.Quantity
					,Quantities.MinimumLimit
				FROM Products AS Product
				INNER JOIN ProductQuantities AS Quantities ON Product.ProductId = Quantities.ProductId
				WHERE Quantities.Quantity < Quantities.MinimumLimit
					AND Product.STATUS = 1
					AND Product.TenantId = @TenantId
				FOR JSON AUTO
				);

		SELECT @RawMaterialInventoryJsonObject = (
				SELECT RawMaterial.Title AS RawMaterialTitle
					,Quantities.Inventory
					,Quantities.MinimumLimit
				FROM RawMaterials AS RawMaterial
				JOIN RawMaterialInventory AS Quantities ON RawMaterial.RawMaterialId = Quantities.RawMaterialId
				WHERE Quantities.Inventory < Quantities.MinimumLimit
					AND RawMaterial.IsDeleted = 0
					AND RawMaterial.TenantId = @TenantId
				FOR JSON AUTO
				);

		SET @Status = 1;

		SELECT @Message = 'Data Retrived Successfully.';

		SET @Error = NULL;

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,CASE WHEN @ProductInventoryJsonObject IS NULL
					AND @RawMaterialInventoryJsonObject IS NULL THEN NULL ELSE JSON_QUERY('{"ProductInventory": ' + ISNULL(@ProductInventoryJsonObject, 'null') + ', "RawMaterialInventory": ' + ISNULL(@RawMaterialInventoryJsonObject, 'null') + '}') END AS [Data]
			,@Error AS [Error]
	END TRY

BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		SET @Status = 0;

		IF @Message IS NULL
		BEGIN
			SELECT @Message = 'Data retrieval was not successful.';
		END

		IF @Error IS NULL
		BEGIN
			SELECT @Error = @ErrorMsg;
		END

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,CASE WHEN @ProductInventoryJsonObject IS NULL
					AND @RawMaterialInventoryJsonObject IS NULL THEN NULL ELSE JSON_QUERY('{"ProductInventory": ' + ISNULL(@ProductInventoryJsonObject, 'null') + ', "RawMaterialInventory": ' + ISNULL(@RawMaterialInventoryJsonObject, 'null') + '}') END AS [Data]
			,@Error AS [Error]
	END CATCH;
END;

GO

