-- ============================================================================  
-- SP Name : HFJob_GetWarrantyNotificationRecipients  
-- Purpose : Hangfire job support SP for the "Warranty WhatsApp Notification"  
--           recurring job. The job passes the production tenant (8 - SDF) and  
--           each testing tenant from AppSettings:TestingTenantIds; this SP  
--           processes whichever @TenantId it receives.  
--           Returns one row per (delivered product, due notification type):  
--             1. WarrantyPostDelivery    - 3 days after delivery  
--             2. WarrantyYearlyReminder  - on completion of each warranty year  
--                                          (12, 24, 36 ... months, while the  
--                                          year is strictly before the  
--                                          warranty end)  
--             3. WarrantyPreCompletion   - 1 month before warranty completion (skipped when the warranty is under 1 month)  
--             4. WarrantyCompletion      - on warranty completion  
--           Warranty (in months) is read from the Product Custom Field whose  
--           LookupValues.LookupValueName = 'Warranty'.  
--           Fractional months (e.g. 0.25) are honoured: whole months plus the  
--           remaining fraction of a month approximated as 30 days.  
--           Duplicate prevention: a notification is returned only when no  
--           NotificationManagement row exists yet for the same product line  
--           (OrderSetItemId), notification type and WhatsApp method  
--           (any status - Pending/Completed/Failed - blocks a resend).  
-- Notes   : - The caller passes @TenantId (8 = SDF production, plus testing tenants  
--             from AppSettings:TestingTenantIds).  
--           - Optionally add the index below if the job becomes slow:  
--               CREATE INDEX IX_NotificationManagement_Dedup  
--               ON dbo.NotificationManagement (TenantId, EntityTypeID, EntityID, NotificationType, NotificationMethod);  
-- ============================================================================  
  
CREATE PROCEDURE [dbo].[HFJob_GetWarrantyNotificationRecipients]  
    @TenantId INT  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
        DECLARE @Today DATE = CAST(GETDATE() AS DATE);  
  
        DECLARE @ProductSubjectTypeId INT =  
        (  
            SELECT TOP 1 ST.SubjectTypeId  
            FROM dbo.SubjectTypes ST WITH (NOLOCK) 
            WHERE ST.SubjectTypeName = 'Products'  
              AND ST.TenantId = @TenantId  
        );  
  
        ;WITH DeliveredWarrantyItems AS  
        (  
            SELECT  
                OSI.OrderSetItemId,  
                OSI.OrderId,  
                O.OrderNo,  
                P.ProductId,  
                P.ProductTitle,  
                O.CustomerID AS CustomerId,  
                C.FirstName + CASE WHEN C.LastName IS NULL OR LTRIM(RTRIM(C.LastName)) = '' THEN '' ELSE ' ' + C.LastName END AS CustomerName,  
                C.PhoneNumber AS CustomerMobile,  
                O.TenantId,  
                T.TenantName,  
                W.WarrantyMonths,  
                M.WholeMonths,  
                M.FractionDays,  
                CAST(OSI.DeliveryDate AS DATE) AS DeliveryDate,  
                DATEADD(DAY, M.FractionDays, DATEADD(MONTH, M.WholeMonths, CAST(OSI.DeliveryDate AS DATE))) AS WarrantyEndDate,  
                @ProductSubjectTypeId AS EntityTypeId  
            FROM dbo.OrderSetItems OSI WITH (NOLOCK)  
            INNER JOIN dbo.Orders O  WITH (NOLOCK) 
                ON O.OrderId = OSI.OrderId  
               AND O.TenantId = @TenantId  
            INNER JOIN dbo.Products P  WITH (NOLOCK) 
                ON P.ProductId = OSI.SubjectId  
               AND P.TenantId = @TenantId  
            INNER JOIN dbo.Categories Cat WITH (NOLOCK)  
                ON p.CategoryId = Cat.CategoryId  
                and Cat.IsManufacturing = 1  
            INNER JOIN dbo.SubjectTypes ST WITH (NOLOCK)  
                ON ST.SubjectTypeId = OSI.SubjectTypeId  
               AND ST.SubjectTypeName = 'Products'  
               AND ST.TenantId = @TenantId  
            INNER JOIN dbo.Customers C WITH (NOLOCK)   
                ON C.CustomerId = O.CustomerID  
               AND C.IsDeleted = 0  
            INNER JOIN dbo.Tenants T WITH (NOLOCK)  
                ON T.TenantId = @TenantId  
               AND T.EnableWhatsappNotification = 1  
            OUTER APPLY  
            (  
                -- Latest non-deleted 'Warranty' custom field (value = months)  
                SELECT TOP 1 TRY_CONVERT(float, PCF.CustomValue) AS WarrantyMonths  
                FROM dbo.ProductCustomFields PCF WITH (NOLOCK)  
                INNER JOIN dbo.LookupValues LV WITH (NOLOCK)  
                    ON LV.LookupValueId = PCF.LookupValueId  
                   AND LOWER(LTRIM(RTRIM(LV.LookupValueName))) = 'warranty'  
                WHERE PCF.ProductId = P.ProductId  
                  AND PCF.TenantId = @TenantId  
                  AND PCF.IsDeleted = 0  
                  AND TRY_CONVERT(float, PCF.CustomValue) > 0  
                ORDER BY PCF.Id DESC  
            ) W  
            CROSS APPLY  
            (  
                -- Fractional months are honoured: whole months plus the remaining  
                -- fraction of a month approximated as 30 days (e.g. 0.25 -> 8 days).  
                SELECT  
                    CAST(FLOOR(W.WarrantyMonths) AS INT) AS WholeMonths,  
                    CAST(ROUND((W.WarrantyMonths - FLOOR(W.WarrantyMonths)) * 30, 0) AS INT) AS FractionDays  
            ) M  
            WHERE OSI.ItemStatus = 3                 -- OrderSetItemsStatus.Delivered  
              AND OSI.IsDeleted = 0  
              AND OSI.DeliveryDate IS NOT NULL  
              AND W.WarrantyMonths > 0  
              AND C.PhoneNumber IS NOT NULL  
              AND LTRIM(RTRIM(C.PhoneNumber)) <> ''  
        )  
        -- 1. Post-Delivery: 3 days after delivery  
        SELECT  
            DWI.OrderSetItemId,  
            DWI.OrderId,  
            DWI.OrderNo,  
            DWI.ProductId,  
            DWI.ProductTitle,  
            DWI.CustomerId,  
            DWI.CustomerName,  
            DWI.CustomerMobile,  
            DWI.TenantId,  
            DWI.TenantName,  
            DWI.WarrantyMonths,  
            DWI.DeliveryDate,  
            DWI.WarrantyEndDate,  
            DWI.EntityTypeId,  
            'WarrantyPostDelivery' AS NotificationType,  
            CAST(NULL AS INT) AS YearNumber,  
            DATEADD(DAY, 3, DWI.DeliveryDate) AS DueDate  
        FROM DeliveredWarrantyItems DWI  
        WHERE DATEADD(DAY, 3, DWI.DeliveryDate) <= @Today  
          AND NOT EXISTS  
          (  
              SELECT 1  
              FROM dbo.NotificationManagement NM WITH (NOLOCK)  
              WHERE NM.TenantId = DWI.TenantId  
                AND NM.EntityTypeID = DWI.EntityTypeId  
                AND NM.EntityID = DWI.OrderSetItemId  
                AND NM.NotificationType = 'WarrantyPostDelivery'  
                AND NM.NotificationMethod = 'WhatsApp'  
          )  
  
        UNION ALL  
  
        -- 2. Yearly Reminder: on completion of each warranty year (12, 24, 36 ... months)  
        --    Only for years strictly before the warranty end (e.g. 60 months -> years 1..4).  
        SELECT  
            DWI.OrderSetItemId,  
            DWI.OrderId,  
            DWI.OrderNo,  
            DWI.ProductId,  
            DWI.ProductTitle,  
            DWI.CustomerId,  
            DWI.CustomerName,  
            DWI.CustomerMobile,  
            DWI.TenantId,  
            DWI.TenantName,  
            DWI.WarrantyMonths,  
            DWI.DeliveryDate,  
            DWI.WarrantyEndDate,  
            DWI.EntityTypeId,  
            'WarrantyYearlyReminder' AS NotificationType,  
            CAST(Y.YearNumber as int) As YearNumber,  
            DATEADD(MONTH, 12 * Y.YearNumber, DWI.DeliveryDate) AS DueDate  
        FROM DeliveredWarrantyItems DWI  
        CROSS APPLY  
        (  
            -- Years completed so far: 1 .. (CEILING(WarrantyMonths / 12) - 1)  
            -- (correct for fractional months too, e.g. 60.5 -> years 1..5)  
            SELECT TOP (CAST(CEILING(DWI.WarrantyMonths / 12.0) - 1 AS INT))  
                   ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS YearNumber  
            FROM sys.all_objects  
        ) Y  
        WHERE DATEADD(MONTH, 12 * Y.YearNumber, DWI.DeliveryDate) <= @Today  
          AND NOT EXISTS  
          (  
              SELECT 1  
              FROM dbo.NotificationManagement NM WITH (NOLOCK)  
              WHERE NM.TenantId = DWI.TenantId  
                AND NM.EntityTypeID = DWI.EntityTypeId  
                AND NM.EntityID = DWI.OrderSetItemId  
                AND NM.NotificationType = 'WarrantyYearlyReminder'  
                AND NM.NotificationMethod = 'WhatsApp'  
          )  
  
        UNION ALL  
  
        -- 3. 1 Month Before Completion  
        SELECT  
            DWI.OrderSetItemId,  
            DWI.OrderId,  
            DWI.OrderNo,  
            DWI.ProductId,  
            DWI.ProductTitle,  
            DWI.CustomerId,  
            DWI.CustomerName,  
            DWI.CustomerMobile,  
            DWI.TenantId,  
            DWI.TenantName,  
            DWI.WarrantyMonths,  
            DWI.DeliveryDate,  
            DWI.WarrantyEndDate,  
            DWI.EntityTypeId,  
            'WarrantyPreCompletion' AS NotificationType,  
            CAST(NULL AS INT) AS YearNumber,  
            DATEADD(DAY, DWI.FractionDays, DATEADD(MONTH, DWI.WholeMonths - 1, DWI.DeliveryDate)) AS DueDate  
        FROM DeliveredWarrantyItems DWI  
        WHERE DWI.WarrantyMonths >= 1
          AND DATEADD(DAY, DWI.FractionDays, DATEADD(MONTH, DWI.WholeMonths - 1, DWI.DeliveryDate)) <= @Today  
          AND NOT EXISTS  
          (  
              SELECT 1  
              FROM dbo.NotificationManagement NM WITH (NOLOCK)  
              WHERE NM.TenantId = DWI.TenantId  
                AND NM.EntityTypeID = DWI.EntityTypeId  
                AND NM.EntityID = DWI.OrderSetItemId  
                AND NM.NotificationType = 'WarrantyPreCompletion'  
                AND NM.NotificationMethod = 'WhatsApp'  
          )  
  
        UNION ALL  
  
        -- 4. Warranty Completion  
        SELECT  
            DWI.OrderSetItemId,  
            DWI.OrderId,  
            DWI.OrderNo,  
            DWI.ProductId,  
            DWI.ProductTitle,  
            DWI.CustomerId,  
            DWI.CustomerName,  
            DWI.CustomerMobile,  
            DWI.TenantId,  
            DWI.TenantName,  
            DWI.WarrantyMonths,  
            DWI.DeliveryDate,  
            DWI.WarrantyEndDate,  
            DWI.EntityTypeId,  
            'WarrantyCompletion' AS NotificationType,  
            CAST(NULL AS INT) AS YearNumber,  
            DATEADD(DAY, DWI.FractionDays, DATEADD(MONTH, DWI.WholeMonths, DWI.DeliveryDate)) AS DueDate  
        FROM DeliveredWarrantyItems DWI  
        WHERE DATEADD(DAY, DWI.FractionDays, DATEADD(MONTH, DWI.WholeMonths, DWI.DeliveryDate)) <= @Today  
          AND NOT EXISTS  
          (  
              SELECT 1  
              FROM dbo.NotificationManagement NM WITH (NOLOCK)  
              WHERE NM.TenantId = DWI.TenantId  
                AND NM.EntityTypeID = DWI.EntityTypeId  
                AND NM.EntityID = DWI.OrderSetItemId  
                AND NM.NotificationType = 'WarrantyCompletion'  
                AND NM.NotificationMethod = 'WhatsApp'  
          );  
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

