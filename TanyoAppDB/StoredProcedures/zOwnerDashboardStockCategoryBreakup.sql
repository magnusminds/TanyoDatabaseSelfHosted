-- =============================================================================
-- SP Name   : OwnerDashboardStockCategoryBreakup
-- Module    : Owner Dashboard - Stock (Category Breakup Donut)
-- Params    : @TenantId INT
-- Returns   : Current stock value grouped by product category.
-- =============================================================================

CREATE   PROCEDURE [dbo].[zOwnerDashboardStockCategoryBreakup]
    @TenantId INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        c.CategoryName AS CategoryName
        ,SUM(CAST(pq.Quantity AS DECIMAL(18, 2)) * CAST(p.CostPrice AS DECIMAL(18, 2))) AS StockValue
    FROM dbo.ProductQuantities pq WITH (NOLOCK)
    INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = pq.ProductId
        AND p.Status <> 3
    INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
    WHERE p.TenantId = @TenantId
    AND pq.Quantity > 0
    GROUP BY c.CategoryName
    ORDER BY StockValue DESC;
END;

GO

