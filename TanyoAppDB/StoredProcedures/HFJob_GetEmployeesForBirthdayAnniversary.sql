CREATE PROCEDURE [dbo].[HFJob_GetEmployeesForBirthdayAnniversary]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF OBJECT_ID('tempdb..#AllTenantEmails') IS NOT NULL
		DROP TABLE #AllTenantEmails

	
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;

	DECLARE @Date DATETIME = GETDATE()

	SELECT UT.TenantId
		,STRING_AGG(CAST(AU.Email AS NVARCHAR(MAX)), ',') AS AllTenantEmails
	INTO #AllTenantEmails
	FROM Tenants T
	INNER JOIN UserTenantMapping UT ON UT.TenantId = T.TenantId
	INNER JOIN AspNetUsers AU ON AU.UserId = UT.UserId
	WHERE ISNULL(TRIM(T.EveryoneEmail), '') = ''
		AND AU.Email IS NOT NULL
	GROUP BY UT.TenantId

	
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

	SELECT ed.EmployeeDetailID
		,ed.UserID
		,CONCAT (
			anu.FirstName
			,' '
			,anu.LastName
			) AS FullName
		,anu.Email
		,anu.PhoneNumber
		,ed.ProfilePic
		,ed.DateOfJoining
		,t.TenantId
		,t.TenantName
		,t.Greetinglogo
		,t.LogoPath
		,t.EveryoneEmail
		,ATE.AllTenantEmails AS AllTenantUserEmails
		,t.IsSendGreeting
		,ts.FromEmail
		,ts.Password
		,ts.SMTPPort
		,ts.SMTPServer
		,ts.Username
		,ts.EnableSSL
		,ts.TargetName
		--,t.OwnerMobileNumbers
		,OPN.OwnerPhoneNumbers  
		,CASE 
			WHEN (
					ed.DateofBirth IS NOT NULL
					AND MONTH(ed.DateofBirth) = MONTH(@Date)
					AND DAY(ed.DateofBirth) = DAY(@Date)
					)
				THEN 1
			ELSE 0
			END AS IsBirthDay
		,CASE 
			WHEN (
					ed.DateOfAnniversary IS NOT NULL
					AND MONTH(ed.DateOfAnniversary) = MONTH(@Date)
					AND DAY(ed.DateOfAnniversary) = DAY(@Date)
					)
				THEN 1
			ELSE 0
			END AS IsAnniversary
		,CASE 
			WHEN (
					ed.DateOfJoining IS NOT NULL
					AND MONTH(ed.DateOfJoining) = MONTH(@Date)
					AND DAY(ed.DateOfJoining) = DAY(@Date)
					)
				THEN 1
			ELSE 0
			END AS IsWorkAnniversaryDate
		,t.NotificationEmail
		,CASE 
			WHEN (
					ed.DateofBirth IS NOT NULL
					AND MONTH(ed.DateofBirth) = MONTH(@Date)
					AND DAY(ed.DateofBirth) = DAY(@Date)
					)
				THEN ECDB.EmailBody
			END AS BirthdayEmailBody
		,CASE 
			WHEN (
					ed.DateOfAnniversary IS NOT NULL
					AND MONTH(ed.DateOfAnniversary) = MONTH(@Date)
					AND DAY(ed.DateOfAnniversary) = DAY(@Date)
					)
				THEN ECDA.EmailBody
			END AS AnniversaryEmailBody
		,CASE 
			WHEN (
					ed.DateOfJoining IS NOT NULL
					AND MONTH(ed.DateOfJoining) = MONTH(@Date)
					AND DAY(ed.DateOfJoining) = DAY(@Date)
					)
				THEN ECDW.EmailBody
			END AS DateOfJoiningEmailBody
	FROM EmployeeDetails ed
	INNER JOIN AspNetUsers anu ON anu.UserId = ed.UserID
	INNER JOIN UserTenantMapping utm ON utm.UserId = anu.UserId
	INNER JOIN Tenants t ON t.TenantId = utm.TenantId
	INNER JOIN TenantSMTPDetails ts ON ts.TenantID = t.TenantId
	LEFT JOIN #AllTenantEmails ATE ON utm.TenantId = ATE.TenantId
	LEFT JOIN #OwnerPhoneNumbers OPN ON utm.TenantId = OPN.TenantId  
	LEFT JOIN EmailCMSDetails ECDB WITH (NOLOCK) ON ECDB.TenantID = UTM.TenantId AND ECDB.Subject = 'Birthday Email Template'
	LEFT JOIN EmailCMSDetails ECDA WITH (NOLOCK) ON ECDA.TenantID = UTM.TenantId AND ECDA.Subject = 'Anniversary Email Template'
	LEFT JOIN EmailCMSDetails ECDW WITH (NOLOCK) ON ECDW.TenantID = UTM.TenantId AND ECDW.Subject = 'Work Anniversary Email Template'
	WHERE anu.IsDeleted = 0
		AND t.EnableEmailNotification = 1
		AND t.NotificationEmail IS NOT NULL
		AND (
			CASE 
				WHEN (
						ed.DateofBirth IS NOT NULL
						AND MONTH(ed.DateofBirth) = MONTH(@Date)
						AND DAY(ed.DateofBirth) = DAY(@Date)
						)
					THEN 1
				ELSE 0
				END = 1
			OR CASE 
				WHEN (
						ed.DateOfAnniversary IS NOT NULL
						AND MONTH(ed.DateOfAnniversary) = MONTH(@Date)
						AND DAY(ed.DateOfAnniversary) = DAY(@Date)
						)
					THEN 1
				ELSE 0
				END = 1
			OR CASE 
				WHEN (
						ed.DateOfJoining IS NOT NULL
						AND MONTH(ed.DateOfJoining) = MONTH(@Date)
						AND DAY(ed.DateOfJoining) = DAY(@Date)
						)
					THEN 1
				ELSE 0
				END = 1
			)
	ORDER BY ed.EmployeeDetailID ASC

	
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

