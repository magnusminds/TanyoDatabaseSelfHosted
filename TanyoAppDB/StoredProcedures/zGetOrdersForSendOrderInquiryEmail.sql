-- =============================================
/*
EXEC [GetOrdersForSendOrderInquiryEmail]
@TenantId = 1

*/
-- =============================================
CREATE   PROCEDURE [dbo].[zGetOrdersForSendOrderInquiryEmail] (
	@TenantId INT	
	)
WITH ENCRYPTION
AS
BEGIN
	DECLARE @Reminder1 INT
    	,@Reminder2 INT
    	,@Reminder3 INT
		,@dt DATETIME

	SELECT @dt = GETDATE()
	
	DROP TABLE IF EXISTS ##TenantSMTPDetailstmp
	
	CREATE TABLE ##TenantSMTPDetailstmp
	(
		ReminderDays INT
		,Position INT
	)

	INSERT INTO ##TenantSMTPDetailstmp (
		ReminderDays
		,Position
		)
	SELECT ReminderDays
		,Position
	FROM TenantReminderSettings
	WHERE TenantId = @TenantId
		AND ReminderDays > 0
		AND ReminderType = 'Customer Order Inquiry'

	SELECT @Reminder1 = ReminderDays
	FROM ##TenantSMTPDetailstmp
	WHERE Position = 1

	SELECT @Reminder2 = ReminderDays
	FROM ##TenantSMTPDetailstmp
	WHERE Position = 2

	SELECT @Reminder3 = ReminderDays
	FROM ##TenantSMTPDetailstmp
	WHERE Position = 3

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
		,o.GrossTotal - o.Discount + o.GSTTaxAmount - o.AdvanceAmount [PayableAmount]
		,u.FirstName + ' ' + u.LastName [SalesmanName]
		,u.PhoneNumber [SalesmanPhoneNumber]
		,o.TenantId
		,o.CreatedBy
		,DATEDIFF(day, o.CreatedDate, @dt) [Reminder Days]
	FROM Orders o WITH (NOLOCK)
	INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
		AND c.IsDeleted = 0
	INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.CreatedBy = u.UserId
		AND u.IsActive = 1
		AND u.IsDeleted = 0
	WHERE o.STATUS = 0
		AND o.TenantId = @TenantId
		AND (
			DATEDIFF(day, o.CreatedDate, @dt) = @Reminder1
			OR DATEDIFF(day, o.CreatedDate, @dt) = @Reminder2
			OR DATEDIFF(day, o.CreatedDate, @dt) = @Reminder3
			)
	ORDER BY DATEDIFF(day, o.CreatedDate, @dt)
	SET NOCOUNT ON;
END

GO

