CREATE   VIEW dbo.UT_VW_UnmappedWarehouseProducts  
WITH ENCRYPTION
AS
SELECT  
    t.TenantId,  
    t.TenantName,  
    p.ProductId,  
    p.ProductTitle,  
    p.ModelNo,  
    p.Status,  
    pq.Quantity AS SaleableQuantity  
FROM dbo.Products p WITH (NOLOCK)  
INNER JOIN dbo.ProductQuantities pq WITH (NOLOCK)  
    ON pq.ProductId = p.ProductId  
INNER JOIN dbo.Tenants t WITH (NOLOCK)  
    ON t.TenantId = p.TenantId  
   AND t.IsDeleted = 0  
WHERE p.Status <> 3  
AND NOT EXISTS  
(  
    SELECT 1  
    FROM dbo.ProductQuantitiesByWarehouse pqw WITH (NOLOCK)  
    WHERE pqw.ProductId = p.ProductId  
);