/*
EXEC [dbo].[GetClientStatstics]
    @last_X_days  = 7
*/
CREATE PROCEDURE [dbo].[GetClientStatstics]
    @last_X_days INT = 1
WITH ENCRYPTION
AS
BEGIN

BEGIN TRY
    SET NOCOUNT ON;

    DECLARE @HTML         NVARCHAR(MAX);
    DECLARE @TableRows    NVARCHAR(MAX);
    DECLARE @ReportDate   NVARCHAR(30) = CONVERT(NVARCHAR(30), GETDATE(), 106);
    DECLARE @Subject      NVARCHAR(255);

    ----------------------------------------------------------------------
    -- 1. Capture the report into a temp table
    ----------------------------------------------------------------------
    IF OBJECT_ID('tempdb..#TenantUsage') IS NOT NULL
        DROP TABLE #TenantUsage;

    SELECT
        ROW_NUMBER() OVER (ORDER BY o.CountOfQuotations DESC, p.CountOfProducts DESC, t.TenantID) AS RecordNumber,
        t.TenantID, 
        t.TenantName, 
        t.City,
        o.CountOfQuotations         AS NoOfQuotations,
        p.CountOfProducts           AS NoOfProducts,
        l.CountOfLeads              AS NoOfLeads,
        c.CountOfCustomers          AS NoOfCustomers,
        pimg.CountOfProductImages   AS NoOfProductImages,
        u.CountOfUsers              AS NoOfUsers,
        po.CountOfPOs               AS NoOfPurchaseOrders,
        i.CountOfInwards            AS NoOfInwards,
        v.CountOfVendors            AS NoOfVendors,
        d.CountOfDealers            AS NoOfDealers,
        comp.CountOfComplains       AS NoOfComplaints,
        cat.CountOfCatalogues       AS NoOfCatalogues,
        CASE
            WHEN nwlt.CountOfNotificationsWALifeTime > 0
                THEN CONCAT(nw.CountOfNotificationsWA, ' (LifeTime - ', nwlt.CountOfNotificationsWALifeTime, ')')
            ELSE CAST(nw.CountOfNotificationsWA AS VARCHAR)
        END                         AS NoOfNotifications_WA,
        ne.CountOfNotificationsEmail AS NoOfNotifications_Email,
        ns.CountOfNotificationsSMS   AS NoOfNotifications_SMS,
        na.CountOfNotificationsInApp AS NoOfNotifications_InApp
    INTO #TenantUsage
    FROM [dbo].Tenants t
    CROSS APPLY ( -- Leads
        SELECT COUNT(1) CountOfLeads FROM dbo.Leads l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) l
    CROSS APPLY ( -- Customers
        SELECT COUNT(1) CountOfCustomers FROM dbo.Customers l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) c
    CROSS APPLY ( -- Products
        SELECT COUNT(1) CountOfProducts FROM dbo.Products l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) p
    CROSS APPLY ( -- ProductImages
        SELECT COUNT(1) CountOfProductImages FROM dbo.ProductImages l
        JOIN dbo.Products b ON l.ProductId = b.ProductId
        WHERE b.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) pimg
    CROSS APPLY ( -- Quotations
        SELECT COUNT(1) CountOfQuotations FROM dbo.Orders l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) o
    CROSS APPLY ( -- Users
        SELECT COUNT(1) CountOfUsers FROM dbo.UserTenantMapping l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) u
    CROSS APPLY ( -- Purchase Orders
        SELECT COUNT(1) CountOfPOs FROM dbo.POProducts l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) po
    CROSS APPLY ( -- Inwards
        SELECT COUNT(1) CountOfInwards FROM dbo.InwardEntry l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) i
    CROSS APPLY ( -- Vendors
        SELECT COUNT(1) CountOfVendors FROM dbo.Vendors l
        WHERE l.TenantId = t.TenantId AND l.IsDealer = 0 AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) v
    CROSS APPLY ( -- Dealers
        SELECT COUNT(1) CountOfDealers FROM dbo.Vendors l
        WHERE l.TenantId = t.TenantId AND l.IsDealer = 1 AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) d
    CROSS APPLY ( -- Complaints
        SELECT COUNT(1) CountOfComplains FROM dbo.Complains l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) comp
    CROSS APPLY ( -- Catalogue
        SELECT COUNT(1) CountOfCatalogues FROM dbo.Catalogue l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) cat
    CROSS APPLY ( -- Notifications WhatsApp LifeTime
        SELECT COUNT(1) CountOfNotificationsWALifeTime FROM dbo.NotificationManagement l
        WHERE l.TenantId = t.TenantId AND l.NotificationMethod = 'WhatsApp'
    ) nwlt
    CROSS APPLY ( -- Notifications WhatsApp
        SELECT COUNT(1) CountOfNotificationsWA FROM dbo.NotificationManagement l
        WHERE l.TenantId = t.TenantId AND l.NotificationMethod = 'WhatsApp' AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) nw
    CROSS APPLY ( -- Notifications Email
        SELECT COUNT(1) CountOfNotificationsEmail FROM dbo.NotificationManagement l
        WHERE l.TenantId = t.TenantId AND l.NotificationMethod = 'Email' AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) ne
    CROSS APPLY ( -- Notifications SMS
        SELECT COUNT(1) CountOfNotificationsSMS FROM dbo.NotificationManagement l
        WHERE l.TenantId = t.TenantId AND l.NotificationMethod = 'SMS' AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) ns
    CROSS APPLY ( -- In-App Notifications
        SELECT COUNT(1) CountOfNotificationsInApp FROM dbo.Notifications l
        WHERE l.TenantId = t.TenantId AND DATEDIFF(d, l.CreatedDate, GETDATE()) <= @last_X_days
    ) na
    WHERE NOT (
        CountOfLeads = 0 AND CountOfCustomers = 0 AND CountOfQuotations = 0 AND 
        CountOfProducts = 0 AND CountOfProductImages = 0 AND CountOfUsers = 0 AND 
        CountOfInwards = 0 AND CountOfComplains = 0 AND CountOfCatalogues = 0 AND 
        CountOfNotificationsWA = 0 AND CountOfNotificationsEmail = 0 AND 
        CountOfNotificationsSMS = 0 AND CountOfNotificationsInApp = 0
    )
    AND TenantId NOT IN (2, 14, 20, 28, 43, 76) -- internal tenants
    ORDER BY CountOfQuotations DESC, CountOfProducts DESC, TenantId;

    ----------------------------------------------------------------------
    -- 2. Exit if no activity found
    ----------------------------------------------------------------------
    IF NOT EXISTS (SELECT 1 FROM #TenantUsage)
    BEGIN
        PRINT 'No tenant activity found for the selected period - no email sent.';
        RETURN;
    END

    ----------------------------------------------------------------------
    -- 3. Build the HTML email body
    ----------------------------------------------------------------------
    IF @Subject IS NULL
    BEGIN
        IF @last_X_days = 0 OR @last_X_days = 1
        BEGIN
            SET @Subject = N'Client Statistics for Today (' + CONVERT(NVARCHAR(10), GETDATE(), 101) + N')';
        END
        ELSE
        BEGIN
            SET @Subject = N'Client Statistics for Last ' + CAST(@last_X_days AS NVARCHAR(10)) + N' Days (' 
                           + CONVERT(NVARCHAR(10), DATEADD(day, -(@last_X_days - 1), GETDATE()), 101) 
                           + N' to ' 
                           + CONVERT(NVARCHAR(10), GETDATE(), 101) + N')';
        END
    END

       SELECT
             RecordNumber
            ,TenantID
            ,TenantName
            ,ISNULL(NULLIF(City, ''), '') AS City
            ,NoOfQuotations
            ,NoOfProducts
            ,NoOfLeads
            ,NoOfCustomers
            ,NoOfProductImages
            ,NoOfUsers
            ,NoOfPurchaseOrders
            ,NoOfInwards
            ,NoOfVendors
            ,NoOfDealers
            ,NoOfComplaints
            ,NoOfCatalogues
            ,NoOfNotifications_WA
            ,NoOfNotifications_Email
            ,NoOfNotifications_SMS
            ,NoOfNotifications_InApp
        FROM #TenantUsage
        ORDER BY NoOfQuotations DESC, NoOfProducts DESC, TenantId
       
    DROP TABLE #TenantUsage;
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

