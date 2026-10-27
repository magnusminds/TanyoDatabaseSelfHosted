CREATE PROCEDURE [dbo].[HFJob_GetPOsForEDDReminder]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @TargetDate DATE = DATEADD(DAY, 3, CAST(GETDATE() AS DATE));

	BEGIN TRY
		-- POs whose EDD is exactly 3 days away and are still Approved/Material Ready,
		-- with the PO Creator (AspNetUsers) and tenant SMTP settings for the alert email.
		SELECT POP.POProductId
			,POP.PONumber
			,POP.ExpectedDeliveryDate
			,POP.Status
			,ISNULL(RTRIM(LTRIM(CONCAT (
							U.FirstName
							,' '
							,U.LastName
							))), '') AS CreatorName
			,U.Email AS CreatorEmail
			,T.TenantId
			,T.TenantName
			,SMTP.FromEmail
			,SMTP.Username AS SMTPUsername
			,SMTP.Password AS SMTPPassword
			,ISNULL(SMTP.SMTPServer, '') AS SmtpServer
			,ISNULL(SMTP.SMTPPort, 0) AS SMTPPort
			,ISNULL(SMTP.EnableSSL, 0) AS EnableSSL
			,SMTP.TargetName
		FROM POProducts POP WITH (NOLOCK)
		INNER JOIN Tenants T WITH (NOLOCK) ON POP.TenantId = T.TenantId
			AND T.IsDeleted = 0
			AND T.EnableEmailNotification = 1
		INNER JOIN AspNetUsers U WITH (NOLOCK) ON POP.CreatedBy = U.UserId
			AND U.IsDeleted = 0
			AND U.IsActive = 1
			AND U.Email IS NOT NULL
			AND U.Email <> ''
		LEFT JOIN TenantSMTPDetails SMTP WITH (NOLOCK) ON T.TenantId = SMTP.TenantID
			AND SMTP.IsDeleted = 0
		WHERE CAST(POP.ExpectedDeliveryDate AS DATE) = @TargetDate
			AND POP.Status IN (
				2
				,5
				) -- 2: Approved, 5: Material Ready
			AND POP.IsDeleted = 0
		GROUP BY POP.POProductId
			,POP.PONumber
			,POP.ExpectedDeliveryDate
			,POP.Status
			,U.FirstName
			,U.LastName
			,U.Email
			,T.TenantId
			,T.TenantName
			,SMTP.FromEmail
			,SMTP.Username
			,SMTP.Password
			,SMTP.SMTPServer
			,SMTP.SMTPPort
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

