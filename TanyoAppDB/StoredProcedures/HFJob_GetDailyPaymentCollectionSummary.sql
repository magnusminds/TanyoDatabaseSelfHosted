/*
==============================================================
EXEC [dbo].[HFJob_GetDailyPaymentCollectionSummary]
==============================================================
Purpose:
Daily payment collection summary (Tenant-wise)

Schedule:
To be called by job at 09:00 PM IST

Logic:
- Only Approved Payments (PaymentStatus = 1, IsDeleted = 0)
- Uses ApprovedDate (today)
- Group by Tenant
- PaymentType mapping (0–12 as per enum)
- Owner Mobile:
    1. OrganizationOwnerDetails (IsDeleted = 0)
    2. Fallback → Tenants.PhoneNumber

Output:
- TenantId
- TotalCollection
- Mode-wise breakup
- OwnerMobileNumbers (comma separated)
==============================================================
*/

CREATE   PROCEDURE [dbo].[HFJob_GetDailyPaymentCollectionSummary]
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE @Today DATE = CAST(GETDATE() AS DATE);

        SELECT 
            o.TenantId

            ----------------------------------------
            -- OWNER NAMES (MULTIPLE)
            ----------------------------------------
            ,ISNULL(
                STUFF((
                    SELECT ',' + od.OwnerFullName
                    FROM OrganizationOwnerDetails od WITH (NOLOCK)
                    WHERE od.TenantId = o.TenantId
                        AND od.IsDeleted = 0
                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
                ,1,1,''),
                'Owner'
            ) AS OwnerNames

            ----------------------------------------
            -- OWNER PHONE NUMBERS (MULTIPLE)
            ----------------------------------------
            ,ISNULL(
                STUFF((
                    SELECT ',' + CAST(od.PhoneNumber AS VARCHAR(20))
                    FROM OrganizationOwnerDetails od WITH (NOLOCK)
                    WHERE od.TenantId = o.TenantId
                        AND od.IsDeleted = 0
                    FOR XML PATH(''), TYPE).value('.', 'NVARCHAR(MAX)')
                ,1,1,''),
                t.PhoneNumber
            ) AS OwnerPhoneNumbers

            ----------------------------------------
            -- DATE (STRING FORMAT)
            ----------------------------------------
            ,FORMAT(@Today, 'dd/MM/yyyy') AS SummaryDate

            ----------------------------------------
            -- TOTAL COLLECTION (INDIAN FORMAT)
            ----------------------------------------
            ,ISNULL(FORMAT(SUM(p.ReceivedAmount), 'N0', 'en-IN'), '0') AS TotalCollection

            ----------------------------------------
            -- PAYMENT MODE WISE (INDIAN FORMAT)
            ----------------------------------------
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 0 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Cash
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 1 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Cheque
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 2 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS GPay
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 3 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS PhonePe
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 4 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Paytm
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 5 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS RTGS
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 6 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Scanner
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 7 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Finance
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 8 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Card
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 9 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Netbanking
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 10 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Wallet
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 11 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Upi
            ,ISNULL(FORMAT(SUM(CASE WHEN p.PaymentType = 12 THEN p.ReceivedAmount END), 'N0', 'en-IN'), '0') AS Kasar

        FROM Payments p WITH (NOLOCK)

        INNER JOIN Orders o WITH (NOLOCK)
            ON p.OrderId = o.OrderId
            AND o.Status <> 9

        LEFT JOIN Tenants t WITH (NOLOCK)
            ON t.TenantId = o.TenantId
            AND t.IsDeleted = 0

        WHERE 
            p.PaymentStatus = 1
            AND p.IsDeleted = 0
            AND CAST(p.ApprovedDate AS DATE) = @Today

        GROUP BY 
            o.TenantId,
            t.PhoneNumber

        HAVING 
            SUM(p.ReceivedAmount) > 0   -- only send if data exists

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

