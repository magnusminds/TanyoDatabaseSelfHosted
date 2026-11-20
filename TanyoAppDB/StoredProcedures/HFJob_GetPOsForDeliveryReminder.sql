CREATE PROCEDURE [dbo].[HFJob_GetPOsForDeliveryReminder]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @TargetDate DATE = DATEADD(DAY, 5, CAST(GETDATE() AS DATE));

	SELECT POP.POProductId
		,POP.PONumber
		,POP.ExpectedDeliveryDate AS DeliveryDate
		,V.VendorName
		,V.VendorEmailId
		,V.VendorPhone
		,T.TenantId
		,T.TenantName
		,T.PhoneNumber AS TenantPhone
		,T.EnableEmailNotification
		,T.EnableWhatsappNotification
		,CASE 
			WHEN T.Greetinglogo IS NOT NULL
				AND T.Greetinglogo <> ''
				THEN T.Greetinglogo
			WHEN T.LogoPath IS NOT NULL
				AND T.LogoPath <> ''
				THEN T.LogoPath
			ELSE ''
			END AS TenantLogo
		,SMTP.FromEmail
		,SMTP.Password AS SMTPPassword
		,SMTP.SMTPPort
		,SMTP.SMTPServer
		,SMTP.Username AS SMTPUsername
		,SMTP.EnableSSL
		,SMTP.TargetName
	FROM POProducts POP
	INNER JOIN POProductItems POPI ON POP.POProductId = POPI.POProductId
	INNER JOIN Vendors V ON POP.VendorId = V.VendorId
	INNER JOIN Tenants T ON POP.TenantId = T.TenantId
		AND T.EnableEmailNotification = 1
		AND T.EnableWhatsappNotification = 1
		AND T.NotificationEmail IS NOT NULL
	LEFT JOIN TenantSMTPDetails SMTP ON T.TenantId = SMTP.TenantID
	WHERE
		-- Filter by Delivery Date (Target Date matches Expected Date)
		POP.ExpectedDeliveryDate = @TargetDate
		AND POP.STATUS IN (
			1
			,2
			) -- 1: Pending, 2: InProgress
		AND POPI.STATUS IN (
			1
			,2
			)
		AND POP.IsDeleted = 0
	GROUP BY POP.POProductId
		,POP.PONumber
		,POP.ExpectedDeliveryDate
		,V.VendorName
		,V.VendorEmailId
		,V.VendorPhone
		,T.TenantId
		,T.TenantName
		,T.PhoneNumber
		,T.EnableEmailNotification
		,T.EnableWhatsappNotification
		,T.Greetinglogo
		,T.LogoPath
		,SMTP.FromEmail
		,SMTP.Password
		,SMTP.SMTPPort
		,SMTP.SMTPServer
		,SMTP.Username
		,SMTP.EnableSSL
		,SMTP.TargetName

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

