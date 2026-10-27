CREATE   VIEW view_Products_With_Stock AS
SELECT 
    P.ProductId AS Product_ID,
    P.ProductTitle AS Product_Name,
    P.ModelNo AS Product_Model_Number,
    PQ.Quantity AS Current_Inventory_Stock,
    P.RetailerPrice AS Unit_Cost_Price,
    P.RetailerPrice AS Retail_Price,
    P.WholesalerPrice AS Wholesale_Price
FROM dbo.Products P
INNER JOIN dbo.ProductQuantities PQ ON P.ProductId = PQ.ProductId
WHERE P.TenantId = 1;

GO

