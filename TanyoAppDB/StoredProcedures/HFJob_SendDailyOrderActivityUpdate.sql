
CREATE PROCEDURE [dbo].[HFJob_SendDailyOrderActivityUpdate]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
	DECLARE @Yesterday DATE = DATEADD(DAY, - 1, CAST(GETDATE() AS DATE));
	
	-- Create temp table for Payment Summary
	IF OBJECT_ID('tempdb..#PaymentSummary') IS NOT NULL
		DROP TABLE #PaymentSummary;
		
	CREATE TABLE #PaymentSummary (
		OrderId INT,
		TotalPaymentAmount DECIMAL(18, 2)
	);
	
	INSERT INTO #PaymentSummary (OrderId, TotalPaymentAmount)
	SELECT OrderId
		,SUM(CASE 
				WHEN PaymentStatus = 1
					THEN ISNULL(ReceivedAmount, 0)
				ELSE 0
				END) AS TotalPaymentAmount
	FROM Payments WITH (NOLOCK)
	WHERE IsDeleted = 0
	GROUP BY OrderId;
	
	-- Create temp table for Owner IDs
	IF OBJECT_ID('tempdb..#OwnerIds') IS NOT NULL
		DROP TABLE #OwnerIds;
		
	CREATE TABLE #OwnerIds (
		TenantId INT,
		OwnerIds NVARCHAR(MAX)
	);
	
	INSERT INTO #OwnerIds (TenantId, OwnerIds)
	SELECT 
		TenantId
		,STRING_AGG(CAST(OwnerId AS NVARCHAR(10)), ',') AS OwnerIds
	FROM OrganizationOwnerDetails WITH (NOLOCK)
	WHERE IsDeleted = 0
	GROUP BY TenantId;
	
	-- Create temp table for Owner Phone Numbers
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;
		
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
	
	-- Create temp table for Owner Email IDs
	IF OBJECT_ID('tempdb..#OwnerEmailIds') IS NOT NULL
		DROP TABLE #OwnerEmailIds;
		
	CREATE TABLE #OwnerEmailIds (
		TenantId INT,
		OwnerEmailIds NVARCHAR(MAX)
	);
	
	INSERT INTO #OwnerEmailIds (TenantId, OwnerEmailIds)
	SELECT 
		TenantId
		,STRING_AGG(EmailId, ',') AS OwnerEmailIds
	FROM OrganizationOwnerDetails WITH (NOLOCK)
	WHERE IsDeleted = 0
		AND EmailId IS NOT NULL 
		AND EmailId != ''
	GROUP BY TenantId;
	
	-- Main Query
	SELECT O.OrderId
		,O.STATUS
		,O.OrderNo
		,PS.TotalPaymentAmount AS TotalPaymentAmount
		,CONCAT (
			U.FirstName
			,' '
			,U.LastName
			) AS SalesmanName
		,CONCAT (
			C.FirstName
			,' '
			,ISNULL(C.LastName, '')
			) AS CustomerName
		,C.PhoneNumber
		,O.CreatedDate AS InquiryDate
		,O.AmountBeforeGST
		,O.SGSTAmount
		,O.CGSTAmount
		,U.UserId
		,O.DeliveryAmountCollectionType
		,O.DeliveryCharge
		,O.DeliveryAmount
		,ROUND(ISNULL(O.TotalAmt, 0), 0) + CASE 
			WHEN O.DeliveryAmountCollectionType = 1 -- Bill
				THEN ISNULL(O.DeliveryAmount, 0)
			ELSE 0
			END AS TotalAmount
		,ROUND(ISNULL(O.AmountBeforeGST, 0) + ISNULL(O.SGSTAmount, 0) + ISNULL(O.CGSTAmount, 0) + CASE 
				WHEN O.DeliveryAmountCollectionType = 1 -- Bill
					AND O.DeliveryCharge = 3 -- ExtraWithAmount
					THEN ISNULL(O.DeliveryAmount, 0)
				ELSE 0
				END - ISNULL(PS.TotalPaymentAmount, 0), 0) AS RemainingAmount
		,TSD.FromEmail
		,TSD.[Password]
		,TSD.SMTPPort
		,TSD.SMTPServer
		,TSD.Username
		,TSD.EnableSSL
		,TSD.TargetName
		,T.EmailId AS NotificationEmail
		,T.TenantId
		,T.TenantName
		,T.EnableWhatsappNotification
		,T.PhoneNumber As TenantPhoneNumber
		--,T.OwnerMobileNumbers
		,T.EnableEmailNotification
		,STO.SubjectTypeId AS OrderSubjectTypeId
		,OID.OwnerIds
		,OPN.OwnerPhoneNumbers
		,OEI.OwnerEmailIds
	FROM Orders O WITH (NOLOCK)
	LEFT JOIN #PaymentSummary PS ON O.OrderId = PS.OrderId
	LEFT JOIN AspNetUsers U WITH (NOLOCK) ON O.CreatedBy = U.UserId
	LEFT JOIN Customers C WITH (NOLOCK) ON O.CustomerID = C.CustomerId
		AND O.TenantId = C.TenantId
		AND C.IsDeleted = 0
	INNER JOIN Tenants T WITH (NOLOCK) ON O.TenantId = T.TenantId
		AND T.IsDeleted = 0
	INNER JOIN SubjectTypes STO ON STO.TenantId = O.TenantId
		AND STO.SubjectTypeName = 'Orders'
	INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON O.TenantId = TSD.TenantID
	LEFT JOIN #OwnerIds OID ON O.TenantId = OID.TenantId
	LEFT JOIN #OwnerPhoneNumbers OPN ON O.TenantId = OPN.TenantId
	LEFT JOIN #OwnerEmailIds OEI ON O.TenantId = OEI.TenantId
	WHERE CAST(O.CreatedDate AS DATE) = @Yesterday
		AND O.STATUS <> 9
		AND T.TenantId != 116 -- Exclude Tenant for notification;
		
	-- Clean up temp tables
	IF OBJECT_ID('tempdb..#PaymentSummary') IS NOT NULL
		DROP TABLE #PaymentSummary;
		
	IF OBJECT_ID('tempdb..#OwnerIds') IS NOT NULL
		DROP TABLE #OwnerIds;
		
	IF OBJECT_ID('tempdb..#OwnerPhoneNumbers') IS NOT NULL
		DROP TABLE #OwnerPhoneNumbers;
		
	IF OBJECT_ID('tempdb..#OwnerEmailIds') IS NOT NULL
		DROP TABLE #OwnerEmailIds;

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

