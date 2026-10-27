CREATE   VIEW dbo.UT_VW_OrderSetItems_StuckManufacturing
WITH ENCRYPTION
AS
SELECT
    t.TenantId,
    t.TenantName,
    ISNULL(tc.EnableProductProcessingWorkflow, 0)
        AS EnableProductProcessingWorkflow,

    o.OrderId,
    o.OrderNo,
    o.Status AS OrderStatus,
    o.TotalAmt,

    osi.OrderSetItemId,
    osi.SubjectId AS ProductId,
    osi.Quantity,
    osi.DeliveryDate,

    (
        SELECT COUNT(*)
        FROM dbo.OrderManufacturingWorkflows omw
        WHERE omw.OrderSetItemId = osi.OrderSetItemId
    ) AS WorkflowRows,

    (
        SELECT MAX(omw.ManufacturingStatus)
        FROM dbo.OrderManufacturingWorkflows omw
        WHERE omw.OrderSetItemId = osi.OrderSetItemId
    ) AS MaxWorkflowStatus,

    CASE
        WHEN NOT EXISTS (
            SELECT 1
            FROM dbo.OrderManufacturingWorkflows omw
            WHERE omw.OrderSetItemId = osi.OrderSetItemId
        )
        THEN 'No manufacturing workflow (orphan)'
        ELSE 'All workflows Completed, never advanced'
    END AS StuckReason,

    (
        SELECT COUNT(*)
        FROM dbo.OrderSetItems a
        WHERE a.OrderId = o.OrderId
          AND a.IsDeleted = 0
    ) AS TotalItems,

    (
        SELECT COUNT(*)
        FROM dbo.OrderSetItems a
        WHERE a.OrderId = o.OrderId
          AND a.ItemStatus = 3
          AND a.IsDeleted = 0
    ) AS DeliveredItems

FROM dbo.OrderSetItems osi
INNER JOIN dbo.Orders o
    ON o.OrderId = osi.OrderId
INNER JOIN dbo.Tenants t
    ON t.TenantId = o.TenantId
LEFT JOIN dbo.TenantConfigurations tc
    ON tc.TenantId = o.TenantId

WHERE osi.ParentOrderSetItemId IS NULL
  AND osi.ItemStatus = 1
  AND osi.IsDeleted = 0
  AND o.Status NOT IN (5, 6, 8, 9)

  -- No open manufacturing workflow exists
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.OrderManufacturingWorkflows omw
      WHERE omw.OrderSetItemId = osi.OrderSetItemId
        AND omw.ManufacturingStatus <> 2
  )

  -- At least one item in the order is already delivered
  AND EXISTS (
      SELECT 1
      FROM dbo.OrderSetItems d
      WHERE d.OrderId = o.OrderId
        AND d.ItemStatus = 3
        AND d.IsDeleted = 0
  );

GO

