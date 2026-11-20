CREATE PROCEDURE [dbo].[HFJob_DailyProductQuantitySales]
WITH ENCRYPTION
AS
BEGIN
	

	BEGIN TRY
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;

	DECLARE @YesterdayDate DATE = DATEADD(DAY,-1,GETDATE())
	DECLARE @YesterdayDateStart DATETIMEOFFSET = CAST(@YesterdayDate AS VARCHAR(10))+' 00:00:00.0000001 +05:30'
		,@YesterdayDateEnd DATETIMEOFFSET = CAST(@YesterdayDate AS VARCHAR(10))+' 23:59:59.9999999 +05:30'

	
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

	SELECT t.TenantId
		,ts.FromEmail
		,ts.Password
		,ts.SMTPPort
		,ts.SMTPServer
		,ts.Username
		,ts.EnableSSL
		,ts.TargetName
		,t.NotificationEmail
		,t.PhoneNumber
		,t.TenantName
		,p.ProductId
		,p.ProductTitle
		,p.ModelNo
		,SUM(osi.Quantity) AS Quantity
		,STO.SubjectTypeId AS OrderSubjectTypeId
		--,t.OwnerMobileNumbers
		,OPN.OwnerPhoneNumbers  
	FROM OrderSetItems osi
	INNER JOIN Orders o ON o.OrderId = osi.OrderId
	INNER JOIN SubjectTypes st ON st.SubjectTypeId = osi.SubjectTypeId
		AND st.SubjectTypeName = 'Products'
	INNER JOIN SubjectTypes STO ON STO.TenantId = o.TenantId
		AND STO.SubjectTypeName = 'Orders'
	INNER JOIN Products p ON p.ProductId = osi.SubjectId
	INNER JOIN Tenants t ON t.TenantId = p.TenantId
		AND t.EnableEmailNotification = 1
		AND t.NotificationEmail IS NOT NULL
	INNER JOIN TenantSMTPDetails ts ON ts.TenantID = t.TenantId
	LEFT JOIN #OwnerPhoneNumbers OPN ON t.TenantId = OPN.TenantId  
	WHERE p.ModelNo != 'PROCUST'
		AND o.Status = 2 -- Approved
		AND o.ApprovedDate BETWEEN @YesterdayDateStart AND @YesterdayDateEnd
	GROUP BY t.TenantId
		,ts.FromEmail
		,ts.Password
		,ts.SMTPPort
		,ts.SMTPServer
		,ts.Username
		,ts.EnableSSL
		,ts.TargetName
		,t.NotificationEmail
		,t.PhoneNumber
		,t.TenantName
		,p.ProductId
		,p.ProductTitle
		,p.ModelNo
		,STO.SubjectTypeId
		--,t.OwnerMobileNumbers
		,OPN.OwnerPhoneNumbers  

	
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

