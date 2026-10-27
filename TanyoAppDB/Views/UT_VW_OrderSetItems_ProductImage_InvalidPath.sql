CREATE   VIEW dbo.UT_VW_OrderSetItems_ProductImage_InvalidPath
WITH ENCRYPTION
AS
SELECT
    OSI.*,
    P.CoverImage AS ExpectedProductImage,
    'Invalid ProductImage: /Product/null?' AS IssueDescription
FROM dbo.OrderSetItems OSI
LEFT JOIN dbo.Products P
    ON OSI.SubjectId = P.ProductId
WHERE OSI.ProductImage LIKE '%/Product/null?%';

GO

