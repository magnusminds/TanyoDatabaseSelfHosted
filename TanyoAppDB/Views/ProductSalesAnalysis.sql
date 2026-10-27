
Create view [dbo].[ProductSalesAnalysis] as with cte as(
SELECT 
osi.CreatedDate as dt,
p.ProductID,
CAST(osi.CreatedDate AS date) AS Date,
p.ProductTitle AS Product,
'Sales' AS Type,
NULL AS CostPrice,
osi.Quantity,
osi.UnitPrice*(CASE WHEN osi.DiscountPrice > 0 THEN (osi.DiscountPrice/100) ELSE 1 END) AS SalesPrice,
p.TenantId
FROM OrderSetItems osi 
INNER JOIN SubjectTypes st ON st.SubjectTypeId=osi.SubjectTypeId
INNER JOIN Products p ON p.ProductId=osi.SubjectId
WHERE st.SubjectTypeName='Products'
UNION ALL
SELECT 
ide.CreatedDate as dt,
p.ProductID,
CAST(ide.CreatedDate AS date) AS Date,
p.ProductTitle AS Product,
'Inward'AS Type,
ide.Amount AS CostPrice,
ide.Quantity,
NULL AS SalesPrice,
p.TenantId
FROM InwardDetailsEntry ide 
INNER JOIN Products p ON p.ProductId=ide.ProductId
)
select  ProductID, Date, Product, Type,CostPrice,Quantity,SalesPrice,TenantId
from cte

GO

