
CREATE VIEW [dbo].[vw_DuplicateDeliveryRowCounts]
WITH ENCRYPTION
AS
WITH d AS (
    SELECT O.TenantId,
           ROW_NUMBER() OVER (
               PARTITION BY ODD.OrderId, ODD.OrderSetItemId, ODD.ProductId, ODD.WarehouseId, ODD.DeliverQuantity
               ORDER BY ODD.LastModifiedDate, ODD.%%physloc%%) AS rn
    FROM dbo.OrderDeliveryDetails ODD
    INNER JOIN dbo.Orders O ON O.OrderId = ODD.OrderId
),
m AS (
    SELECT O.TenantId,
           ROW_NUMBER() OVER (
               PARTITION BY L.OrderManufacturingWorkflowId, L.Description, L.Action, L.ProductId
               ORDER BY L.%%physloc%%) AS rn
    FROM dbo.ManufacturingActivityLogs L
    INNER JOIN dbo.OrderManufacturingWorkflows OMW
        ON OMW.OrderManufacturingWorkflowId = L.OrderManufacturingWorkflowId
    INNER JOIN dbo.Orders O ON O.OrderId = OMW.OrderId
    WHERE L.Description = 'Manufacturing Order has been Delivered.'
),
a AS (
    SELECT O.TenantId,
           ROW_NUMBER() OVER (
               PARTITION BY AL.SubjectTypeId, AL.SubjectId, AL.Description, AL.Action
               ORDER BY AL.CreatedDate, AL.%%physloc%%) AS rn
    FROM dbo.ActivityLogs AL
    INNER JOIN dbo.Orders O ON O.OrderId = AL.SubjectId
    INNER JOIN dbo.SubjectTypes ST
        ON ST.SubjectTypeId = AL.SubjectTypeId
       AND ST.SubjectTypeName = 'Orders'
       AND ST.TenantId = O.TenantId
       AND ST.IsDeleted = 0
    WHERE AL.Description LIKE '% has been Delivered.'
       OR AL.Description = 'Inquiry status has been changed to Delivered.'
)
SELECT TenantId, 'OrderDeliveryDetails' AS TableName, COUNT(*) AS DuplicateRows FROM d WHERE rn > 1 GROUP BY TenantId
UNION ALL
SELECT TenantId, 'ManufacturingActivityLogs', COUNT(*) FROM m WHERE rn > 1 GROUP BY TenantId
UNION ALL
SELECT TenantId, 'ActivityLogs', COUNT(*) FROM a WHERE rn > 1 GROUP BY TenantId;
/* To resolve the duplicate delivery count this commented code will be used
/*
Tenant-wise cleanup of duplicate rows written by DeliverOrderSetItem when it ran twice for the same order.
Keeps the FIRST row of each duplicate group and removes the rest.

ASSUMPTIONS (verify before running):
  - dbo.Orders has a TenantId column
  - SaveActivityLog writes to dbo.ActivityLogs with columns
    SubjectTypeId, SubjectId, Description, Action, CreatedDate

Usage: set @TenantId, run once with @DoDelete = 0 to preview, then set @DoDelete = 1.
Optionally set @OrderId to limit to a single order inside that tenant.
*/

DECLARE @TenantId INT = 156;       -- REQUIRED: tenant to clean
DECLARE @OrderId BIGINT = NULL;     -- NULL = all orders of the tenant
DECLARE @DoDelete BIT = 1;          -- 0 = preview only, 1 = delete

DROP TABLE IF EXISTS #TenantOrders;

SELECT OrderId
INTO #TenantOrders
FROM dbo.Orders
WHERE TenantId = @TenantId
  AND (@OrderId IS NULL OR OrderId = @OrderId);

CREATE UNIQUE CLUSTERED INDEX IX_TenantOrders ON #TenantOrders (OrderId);

DECLARE @OrderSubjectTypeId INT;
SELECT @OrderSubjectTypeId = SubjectTypeId
FROM dbo.SubjectTypes
WHERE SubjectTypeName = 'Orders'
  AND TenantId = @TenantId
  AND IsDeleted = 0;

------------------------------------------------------------
-- PREVIEW: duplicate counts for this tenant
------------------------------------------------------------
;WITH d AS (
    SELECT ROW_NUMBER() OVER (
               PARTITION BY ODD.OrderId, ODD.OrderSetItemId, ODD.ProductId, ODD.WarehouseId, ODD.DeliverQuantity
               ORDER BY ODD.LastModifiedDate, ODD.%%physloc%%) AS rn
    FROM dbo.OrderDeliveryDetails ODD
    INNER JOIN #TenantOrders T ON T.OrderId = ODD.OrderId
)
SELECT 'OrderDeliveryDetails' AS TableName, COUNT(*) AS DuplicateRows FROM d WHERE rn > 1;

;WITH m AS (
    SELECT ROW_NUMBER() OVER (
               PARTITION BY L.OrderManufacturingWorkflowId, L.Description, L.Action, L.ProductId
               ORDER BY L.%%physloc%%) AS rn
    FROM dbo.ManufacturingActivityLogs L
    INNER JOIN dbo.OrderManufacturingWorkflows OMW
        ON OMW.OrderManufacturingWorkflowId = L.OrderManufacturingWorkflowId
    INNER JOIN #TenantOrders T ON T.OrderId = OMW.OrderId
    WHERE L.Description = 'Manufacturing Order has been Delivered.'
)
SELECT 'ManufacturingActivityLogs' AS TableName, COUNT(*) AS DuplicateRows FROM m WHERE rn > 1;

;WITH a AS (
    SELECT ROW_NUMBER() OVER (
               PARTITION BY AL.SubjectTypeId, AL.SubjectId, AL.Description, AL.Action
               ORDER BY AL.CreatedDate, AL.%%physloc%%) AS rn
               ,AL.*
    FROM dbo.ActivityLogs AL
    INNER JOIN #TenantOrders T ON T.OrderId = AL.SubjectId
    WHERE AL.SubjectTypeId = @OrderSubjectTypeId
      AND (AL.Description LIKE '% has been Delivered.'
           OR AL.Description = 'Inquiry status has been changed to Delivered.')
)
SELECT 'ActivityLogs' AS TableName, * FROM a WHERE rn > 1;

------------------------------------------------------------
-- DELETE (only when @DoDelete = 1)
-- Each CTE reads ONE table (required to delete through a CTE);
-- tenant filtering is done with IN (SELECT ... #TenantOrders).
------------------------------------------------------------
IF @DoDelete = 1
BEGIN
    BEGIN TRY
        BEGIN TRAN;

        ;WITH d AS (
            SELECT ROW_NUMBER() OVER (
                       PARTITION BY OrderId, OrderSetItemId, ProductId, WarehouseId, DeliverQuantity
                       ORDER BY LastModifiedDate, %%physloc%%) AS rn
            FROM dbo.OrderDeliveryDetails
            WHERE OrderId IN (SELECT OrderId FROM #TenantOrders)
        )
        DELETE FROM d WHERE rn > 1;
        PRINT 'OrderDeliveryDetails deleted: ' + CAST(@@ROWCOUNT AS VARCHAR(20));

        ;WITH m AS (
            SELECT ROW_NUMBER() OVER (
                       PARTITION BY OrderManufacturingWorkflowId, Description, Action, ProductId
                       ORDER BY %%physloc%%) AS rn
            FROM dbo.ManufacturingActivityLogs
            WHERE Description = 'Manufacturing Order has been Delivered.'
              AND OrderManufacturingWorkflowId IN (
                    SELECT OMW.OrderManufacturingWorkflowId
                    FROM dbo.OrderManufacturingWorkflows OMW
                    INNER JOIN #TenantOrders T ON T.OrderId = OMW.OrderId)
        )
        DELETE FROM m WHERE rn > 1;
        PRINT 'ManufacturingActivityLogs deleted: ' + CAST(@@ROWCOUNT AS VARCHAR(20));

        ;WITH a AS (
            SELECT ROW_NUMBER() OVER (
                       PARTITION BY SubjectTypeId, SubjectId, Description, Action
                       ORDER BY CreatedDate, %%physloc%%) AS rn
            FROM dbo.ActivityLogs
            WHERE SubjectTypeId = @OrderSubjectTypeId
              AND SubjectId IN (SELECT OrderId FROM #TenantOrders)
              AND (Description LIKE '% has been Delivered.'
                   OR Description = 'Inquiry status has been changed to Delivered.')
        )
        DELETE FROM a WHERE rn > 1;
        PRINT 'ActivityLogs deleted: ' + CAST(@@ROWCOUNT AS VARCHAR(20));

        COMMIT TRAN;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0 ROLLBACK TRAN;
        THROW;
    END CATCH
END

DROP TABLE IF EXISTS #TenantOrders;
*/

GO

