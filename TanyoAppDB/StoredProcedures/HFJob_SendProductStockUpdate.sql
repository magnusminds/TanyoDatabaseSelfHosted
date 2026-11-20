/*
	EXEC [dbo].[HFJob_SendProductStockUpdate]		
*/
CREATE   PROCEDURE [dbo].[HFJob_SendProductStockUpdate]
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SELECT PT.ProductTitle AS Title
		,QT.Quantity
		,QT.MinimumLimit
		,'Product' AS EntityType
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		,T.TenantName
		,T.NotificationEmail
	FROM Products AS PT WITH (NOLOCK)
	INNER JOIN ProductQuantities AS QT WITH (NOLOCK) ON PT.ProductId = QT.ProductId
	INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId = PT.TenantId
		AND T.IsDeleted = 0
		AND T.NotificationEmail IS NOT NULL
		AND T.CheckProductStock = 1
	INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON PT.TenantId = TSD.TenantID
		AND TSD.IsDeleted = 0
	WHERE QT.Quantity < QT.MinimumLimit
		AND PT.STATUS = 1
	
	
	UNION ALL
	
	SELECT RM.Title AS Title
		,CAST(RMI.Inventory AS NUMERIC(18,2)) AS Quantity
		,RMI.MinimumLimit
		,'RawMaterial' AS EntityType
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		,T.TenantName
		,T.NotificationEmail
	FROM RawMaterials AS RM WITH (NOLOCK)
	INNER JOIN RawMaterialInventory AS RMI WITH (NOLOCK) ON RM.RawMaterialId = RMI.RawMaterialId
	INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId = RM.TenantId
		AND T.IsDeleted = 0
		AND T.NotificationEmail IS NOT NULL
		AND T.CheckRawMaterialStock = 1
	INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON RM.TenantId = TSD.TenantID
		AND TSD.IsDeleted = 0
	WHERE RMI.Inventory < RMI.MinimumLimit
		AND RM.IsDeleted = 0
		

	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END;

GO

