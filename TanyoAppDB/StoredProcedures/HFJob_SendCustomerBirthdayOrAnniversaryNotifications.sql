CREATE PROCEDURE [dbo].[HFJob_SendCustomerBirthdayOrAnniversaryNotifications]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
	DECLARE @Today DATE = GETDATE();

	IF OBJECT_ID('tempdb..#CustomerSubjectType') IS NOT NULL
		DROP TABLE #CustomerSubjectType

	
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;

	SELECT SubjectTypeId
		,TenantId
	INTO #CustomerSubjectType
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Customers'

	
	CREATE TABLE #OwnerPhoneNumbers (
		TenantId INT,
		OwnerPhoneNumbers NVARCHAR(MAX)
	);

	INSERT INTO #OwnerPhoneNumbers (TenantId, OwnerPhoneNumbers)
	SELECT 
		TenantId
		,STRING_AGG(PhoneNumber, ',') AS OwnerPhoneNumbers
	FROM OrganizationOwnerDetails WITH (NOLOCK)
	WHERE IsDeleted = 0
		AND PhoneNumber IS NOT NULL
		AND PhoneNumber != ''
	GROUP BY TenantId;

	SELECT C.CustomerId
		,CONCAT (
			C.FirstName
			,' '
			,ISNULL(C.LastName,'')
			) AS FullName
		,C.PhoneNumber
		,C.EmailId
		,C.TenantId
		,C.CustomerTypeId
		,CASE 
			WHEN C.Birthday IS NOT NULL
				AND DAY(C.Birthday) = DAY(@Today)
				AND MONTH(C.Birthday) = MONTH(@Today)
				THEN 1
			ELSE 0
			END AS IsBirthday
		,CASE 
			WHEN C.Anniversary IS NOT NULL
				AND DAY(C.Anniversary) = DAY(@Today)
				AND MONTH(C.Anniversary) = MONTH(@Today)
				THEN 1
			ELSE 0
			END AS IsAnniversary
		,T.TenantName
		,T.NotificationEmail
		,ISNULL(T.EmailId,'') AS TenantEmail
		,T.EnableEmailNotification
		,T.EnableSMSNotification
		,T.EnableWhatsappNotification
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		--,T.OwnerMobileNumbers
		,T.PhoneNumber AS TenantPhoneNumber
		,OPN.OwnerPhoneNumbers  
	FROM Customers C WITH (NOLOCK)
	INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId = C.TenantId
		AND T.IsDeleted = 0
	INNER JOIN #CustomerSubjectType CST ON CST.TenantId = C.TenantId
	INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON C.TenantId = TSD.TenantID
		AND TSD.IsDeleted = 0
		AND (
			T.EnableEmailNotification = 1
			OR T.EnableWhatsappNotification = 1
			)
	LEFT JOIN #OwnerPhoneNumbers OPN ON C.TenantId = OPN.TenantId  
	WHERE C.IsDeleted = 0
		AND (
			(
				C.Birthday IS NOT NULL
				AND DAY(C.Birthday) = DAY(@Today)
				AND MONTH(C.Birthday) = MONTH(@Today)
				)
			OR (
				C.Anniversary IS NOT NULL
				AND DAY(C.Anniversary) = DAY(@Today)
				AND MONTH(C.Anniversary) = MONTH(@Today)
				)
			);

	
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;

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

