/*
EXEC [dbo].[HFJob_SendRawMaterialStockUpdate]
*/

CREATE   PROCEDURE [dbo].[HFJob_SendRawMaterialStockUpdate] 
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
		,rm.TenantId
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		,T.TenantName
		,T.NotificationEmail
	FROM RawMaterials rm WITH (NOLOCK)
	INNER JOIN RawMaterialInventory rmi WITH (NOLOCK) ON rm.RawMaterialId = rmi.RawMaterialId
	INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId =RM.TenantId
		AND T.IsDeleted = 0 AND T.NotificationEmail IS NOT NULL
	INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON rm.TenantId = TSD.TenantID
		AND TSD.IsDeleted = 0	
		--AND rm.TenantId = @TenantId
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

