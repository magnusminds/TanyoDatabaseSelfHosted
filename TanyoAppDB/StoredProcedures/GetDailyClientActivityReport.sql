/*
EXEC [dbo].[GetDailyClientActivityReport] @last_X_days = 7
*/
CREATE PROCEDURE [dbo].[GetDailyClientActivityReport]
    @last_X_days INT = 7
WITH ENCRYPTION
AS
BEGIN

BEGIN TRY
    SET NOCOUNT ON;

    DECLARE @StartDate DATE = DATEADD(DAY, -(@last_X_days - 1), CAST(GETDATE() AS DATE));
    DECLARE @EndDate   DATE = CAST(GETDATE() AS DATE);
    DECLARE @EndExclusive DATETIME = DATEADD(DAY, 1, @EndDate);

    ------------------------------------------------------------------
    -- Calendar days
    ------------------------------------------------------------------
    DECLARE @Days TABLE (ActivityDate DATE PRIMARY KEY);
    DECLARE @Current DATE = @StartDate;
    WHILE @Current <= @EndDate
    BEGIN
        INSERT INTO @Days (ActivityDate) VALUES (@Current);
        SET @Current = DATEADD(DAY, 1, @Current);
    END

    ------------------------------------------------------------------
    -- Active tenant IDs (any activity in the period, non-internal)
    ------------------------------------------------------------------
    DECLARE @ActiveTenantIds TABLE (TenantId INT PRIMARY KEY);

    INSERT INTO @ActiveTenantIds (TenantId)
    SELECT DISTINCT TenantId FROM dbo.Orders         WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Leads     WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Products  WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Customers WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.UserTenantMapping WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.POProducts       WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.InwardEntry      WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Vendors          WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Complains        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Catalogue        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.NotificationManagement WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT DISTINCT TenantId FROM dbo.Notifications    WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
    UNION SELECT TenantId FROM (
        SELECT DISTINCT pr.TenantId
        FROM dbo.ProductImages pi
        INNER JOIN dbo.Products pr ON pi.ProductId = pr.ProductId
        WHERE pi.CreatedDate >= @StartDate AND pi.CreatedDate < @EndExclusive
    ) pimg;

    ------------------------------------------------------------------
    -- Active tenants with names (exclude internal tenants)
    ------------------------------------------------------------------
    DECLARE @ActiveTenants TABLE (TenantId INT PRIMARY KEY, TenantName VARCHAR(200));
    INSERT INTO @ActiveTenants (TenantId, TenantName)
    SELECT a.TenantId, t.TenantName
    FROM @ActiveTenantIds a
    INNER JOIN dbo.Tenants t ON t.TenantId = a.TenantId
    WHERE a.TenantId NOT IN (2, 14, 20, 28, 43, 76);

    ------------------------------------------------------------------
    -- Main result: calendar days x active tenants x all 16 metrics
    ------------------------------------------------------------------
    SELECT
        d.ActivityDate,
        at.TenantId,
        at.TenantName,
        ISNULL(oq.Cnt, 0)  AS NoOfQuotations,
        ISNULL(prd.Cnt, 0) AS NoOfProducts,
        ISNULL(led.Cnt, 0) AS NoOfLeads,
        ISNULL(cus.Cnt, 0) AS NoOfCustomers,
        ISNULL(pim.Cnt, 0) AS NoOfProductImages,
        ISNULL(usr.Cnt, 0) AS NoOfUsers,
        ISNULL(pop.Cnt, 0) AS NoOfPurchaseOrders,
        ISNULL(iwd.Cnt, 0) AS NoOfInwards,
        ISNULL(ven.Cnt, 0) AS NoOfVendors,
        ISNULL(dlr.Cnt, 0) AS NoOfDealers,
        ISNULL(cmp.Cnt, 0) AS NoOfComplaints,
        ISNULL(cat.Cnt, 0) AS NoOfCatalogues,
        ISNULL(nwa.Cnt, 0) AS NoOfNotifications_WA,
        ISNULL(nem.Cnt, 0) AS NoOfNotifications_Email,
        ISNULL(nsm.Cnt, 0) AS NoOfNotifications_SMS,
        ISNULL(nip.Cnt, 0) AS NoOfNotifications_InApp
    FROM @Days d
    CROSS JOIN @ActiveTenants at
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Orders
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) oq ON oq.TenantId = at.TenantId AND oq.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Products
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) prd ON prd.TenantId = at.TenantId AND prd.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Leads
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) led ON led.TenantId = at.TenantId AND led.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Customers
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) cus ON cus.TenantId = at.TenantId AND cus.D = d.ActivityDate
    LEFT JOIN (
        SELECT pr.TenantId, CAST(pi.CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.ProductImages pi
        INNER JOIN dbo.Products pr ON pi.ProductId = pr.ProductId
        WHERE pi.CreatedDate >= @StartDate AND pi.CreatedDate < @EndExclusive
        GROUP BY pr.TenantId, CAST(pi.CreatedDate AS DATE)
    ) pim ON pim.TenantId = at.TenantId AND pim.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.UserTenantMapping
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) usr ON usr.TenantId = at.TenantId AND usr.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.POProducts
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) pop ON pop.TenantId = at.TenantId AND pop.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.InwardEntry
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) iwd ON iwd.TenantId = at.TenantId AND iwd.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Vendors
        WHERE IsDealer = 0 AND CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) ven ON ven.TenantId = at.TenantId AND ven.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Vendors
        WHERE IsDealer = 1 AND CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) dlr ON dlr.TenantId = at.TenantId AND dlr.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Complains
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) cmp ON cmp.TenantId = at.TenantId AND cmp.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Catalogue
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) cat ON cat.TenantId = at.TenantId AND cat.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.NotificationManagement
        WHERE NotificationMethod = 'WhatsApp'
          AND CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) nwa ON nwa.TenantId = at.TenantId AND nwa.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.NotificationManagement
        WHERE NotificationMethod = 'Email'
          AND CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) nem ON nem.TenantId = at.TenantId AND nem.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.NotificationManagement
        WHERE NotificationMethod = 'SMS'
          AND CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) nsm ON nsm.TenantId = at.TenantId AND nsm.D = d.ActivityDate
    LEFT JOIN (
        SELECT TenantId, CAST(CreatedDate AS DATE) AS D, COUNT(1) AS Cnt
        FROM dbo.Notifications
        WHERE CreatedDate >= @StartDate AND CreatedDate < @EndExclusive
        GROUP BY TenantId, CAST(CreatedDate AS DATE)
    ) nip ON nip.TenantId = at.TenantId AND nip.D = d.ActivityDate
    ORDER BY d.ActivityDate, at.TenantId;

END TRY

BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK;
    DECLARE @ObjectName VARCHAR(500), @ErrorMsg VARCHAR(4000);
    SET @ObjectName = OBJECT_NAME(@@PROCID);
    SET @ErrorMsg = ERROR_MESSAGE();
    EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName, @ErrorMsg = @ErrorMsg;
END CATCH
END

GO

