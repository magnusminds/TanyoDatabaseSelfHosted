
CREATE   PROCEDURE [dbo].[zKafkaEmailSendingSP] (
	@OrderId BIGINT
	,@Subject VARCHAR(250)
	,@EmailBody VARCHAR(max)
	,@OrderPdf VARCHAR(max)
	,@CustomerEmailId VARCHAR(250)
	,@TenantId BIGINT
	,@UserId INT
	,@NotificationEmail VARCHAR(250)
	,@AttachmentFileName VARCHAR(100)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	INSERT INTO KafkaEmailSending (
		OrderId
		,[Subject]
		,EmailBody
		,TenantID
		,OrderPdf
		,CreatedBy
		,CreatedDate
		,CreatedUTCDate
		,CustomerEmailId
		,NotificationEmail
		,AttachmentFileName
		)
	VALUES (
		@OrderId
		,@Subject
		,@EmailBody
		,@TenantId
		,@OrderPdf
		,@UserId
		,GETDATE()
		,GETUTCDATE()
		,@CustomerEmailId
		,@NotificationEmail
		,@AttachmentFileName
		);

	SELECT *
	FROM KafkaEmailSending
	WHERE KafkaEmailSendingId = @@IDENTITY
END;

GO

