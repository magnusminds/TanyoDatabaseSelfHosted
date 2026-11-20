CREATE PROCEDURE [dbo].[HFJob_SendUpcomingDeliveryNotifications]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
	DECLARE @Today DATE = CAST(GETDATE() AS DATE);

	IF OBJECT_ID('tempdb..#OrderSubjectType') IS NOT NULL
		DROP TABLE #OrderSubjectType

	
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;

	SELECT SubjectTypeId
		,TenantId
	INTO #OrderSubjectType
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Orders'

	
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

	SELECT o.OrderId
		,o.OrderNo
		,(au.FirstName + ' ' + au.LastName) AS SalesmanName
		,(c.FirstName + ' ' + ISNULL(c.LastName, '')) AS CustomerName
		,CASE 
			WHEN o.TentativeDeliveryDate < DATEADD(DAY, - 1, @Today)
				AND o.DeliveryDate IS NULL
				THEN 'Overdue'
			WHEN o.TentativeDeliveryDate BETWEEN @Today
					AND DATEADD(DAY, 6, @Today)
				THEN 'Upcoming'
			ELSE ''
			END AS StatusType
		,c.PhoneNumber
		,o.TentativeDeliveryDate
		,au.UserId AS SalesmanId
		,o.Comments AS [Message]
		,o.TenantId
		,OST.SubjectTypeId AS OrderSubjectTypeId
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		,T.TenantName
		,ISNULL(T.NotificationEmail, T.EmailId) AS NotificationEmail
		,NULLIF(AU.RegisteredFCMToken, '') AS RegisteredFCMToken
		,T.PhoneNumber AS TenantPhoneNumber
		--,T.OwnerMobileNumbers
		,OPN.OwnerPhoneNumbers 
	FROM Orders o WITH (NOLOCK)
	INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
	INNER JOIN AspNetUsers au WITH (NOLOCK) ON o.CreatedBy = au.UserId
	INNER JOIN Tenants T WITH (NOLOCK) ON O.TenantId = T.TenantId
		AND T.IsDeleted = 0
	INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON O.TenantId = TSD.TenantID
		AND TSD.IsDeleted = 0
	INNER JOIN #OrderSubjectType OST ON OST.TenantId = O.TenantId
	LEFT JOIN #OwnerPhoneNumbers OPN ON O.TenantId = OPN.TenantId  
	WHERE
		o.STATUS = 2 -- Approved
		AND (
			(
				o.TentativeDeliveryDate < DATEADD(DAY, - 1, @Today)
				AND o.DeliveryDate IS NULL
				) -- Overdue
			OR (
				o.TentativeDeliveryDate BETWEEN @Today
					AND DATEADD(DAY, 6, @Today)
				) -- Upcoming
			)
	ORDER BY o.TentativeDeliveryDate
		,CustomerName;

	
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

