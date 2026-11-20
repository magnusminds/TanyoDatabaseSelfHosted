CREATE PROCEDURE [dbo].[Job_GetOrdersForSendOrderInquiryEmail]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @dt DATETIME = GETDATE();

	DROP TABLE IF EXISTS #TenantSMTPDetailstmp
	
	DROP TABLE IF EXISTS #OrderDetails

		CREATE TABLE #TenantSMTPDetailstmp 
		(
			TenantId INT
			,ReminderDays INT
			,Position INT
		)

	INSERT INTO #TenantSMTPDetailstmp (
		TenantId
		,ReminderDays
		,Position
		)
	SELECT TenantId
		,ReminderDays
		,Position
	FROM TenantReminderSettings
	WHERE ReminderDays > 0
		AND ReminderType = 'Customer Order Inquiry'

	SELECT o.OrderId
		,O.CustomerID
		,O.OrderNo
		,o.CreatedDate
		,o.DeliveryDate [DeliveryDate]
		,o.GrossTotal [GrossTotal]
		,o.Discount [Discount]
		,o.TotalAmount [TotalAmount]
		,o.GSTTaxAmount [GSTTaxAmount]
		,o.AdvanceAmount [AdvanceAmount]
		,o.GrossTotal - o.Discount + o.GSTTaxAmount - o.AdvanceAmount [PayableAmount]
		,o.TenantId
		,o.CreatedBy
	INTO #OrderDetails
	FROM Orders o WITH (NOLOCK)
	WHERE DATEDIFF(day, o.CreatedDate, @dt) < 14
		AND o.STATUS = 0
	


	SELECT o.OrderId [OrderId]
		
		,c.CustomerId [CustomerId]
		,c.FirstName + ' ' + ISNULL(c.LastName, '') [FullName]
		,c.EmailId [EmailId]
		,c.PhoneNumber [PhoneNumber]
		,o.OrderNo [OrderNo]
		,o.CreatedDate [OrderDate]
		,o.DeliveryDate [DeliveryDate]
		,o.GrossTotal [GrossTotal]
		,o.Discount [Discount]
		,o.TotalAmount [TotalAmount]
		,o.GSTTaxAmount [GSTTaxAmount]
		,o.AdvanceAmount [AdvanceAmount]
		,o.PayableAmount
		,u.FirstName + ' ' + u.LastName [SalesmanName]
		,u.PhoneNumber [SalesmanPhoneNumber]
		,o.TenantId
		,o.CreatedBy
		,T.TenantName
		,T.EnableWhatsappNotification
		,T.EnableEmailNotification
		,ECD.EmailBody
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		,DATEDIFF(day, o.CreatedDate, @dt) [Reminder Days]
		,ECD.Subject
		,T.LogoPath
	FROM #OrderDetails o
	INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
		AND c.IsDeleted = 0
	INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.CreatedBy = u.UserId
		AND u.IsActive = 1
		AND u.IsDeleted = 0
	INNER JOIN Tenants T WITH (NOLOCK) ON t.TenantId = o.TenantId
		AND T.IsDeleted = 0
	 INNER JOIN EmailCMS EC WITH (NOLOCK) ON EC.TenantID = T.TenantId AND KeyName = 'Order Inquiry Reminder - 1'
	 INNER JOIN EmailCMSDetails ECD WITH (NOLOCK) ON EC.EmailCMSID = ECD.EmailCMSID AND EC.TenantID = ECD.TenantID	
	 INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON o.TenantId = TSD.TenantID
	LEFT JOIN #TenantSMTPDetailstmp TSDP1 ON TSDP1.TenantId = O.TenantId
		AND TSDP1.Position = 1
	LEFT JOIN #TenantSMTPDetailstmp TSDP2 ON TSDP2.TenantId = O.TenantId
		AND TSDP2.Position = 2
	LEFT JOIN #TenantSMTPDetailstmp TSDP3 ON TSDP3.TenantId = O.TenantId
		AND TSDP3.Position = 3
	WHERE 
			(
			(
				TSDP1.ReminderDays IS NOT NULL
				AND DATEDIFF(day, o.CreatedDate, @dt) = TSDP1.ReminderDays
				)
			OR (
				TSDP2.ReminderDays IS NOT NULL
				AND DATEDIFF(day, o.CreatedDate, @dt) = TSDP2.ReminderDays
				)
			OR (
				TSDP3.ReminderDays IS NOT NULL
				AND DATEDIFF(day, o.CreatedDate, @dt) = TSDP3.ReminderDays
				)
			)
	ORDER BY DATEDIFF(day, o.CreatedDate, @dt)

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

