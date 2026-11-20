
-- =============================================
-- Author:		<Author,,MAGNUSMINDS>
-- Create date: <Create Date,2024-11-05,>
-- Description:	<Description,,>
/*
EXEC [dbo].[GetRawMaterialThresholdLessThanZero] 
	@TenantId = 1
*/

-- =============================================
CREATE   PROCEDURE [dbo].[GetRawMaterialThresholdLessThanZero] (@TenantId BIGINT = 1)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SELECT rm.RawMaterialId
		,rm.Title
		,rm.ImagePath
		,rm.UnitPrice
		,rmi.Inventory [StockonHand]
		,rmi.MinimumLimit
		,rmi.InventoryDate [InventoryDate]
		,(au.FirstName + ' ' + au.LastName) [LastModifiedBy]
	FROM RawMaterials rm WITH (NOLOCK)
	INNER JOIN RawMaterialInventory rmi WITH (NOLOCK) ON rm.RawMaterialId = rmi.RawMaterialId
		AND rm.TenantId = @TenantId
		AND rm.IsDeleted = 0
		AND rmi.Inventory <= rmi.MinimumLimit
	INNER JOIN AspNetUsers au WITH (NOLOCK) ON rmi.LastModifiedBy = au.UserId
	ORDER BY rm.Title

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

