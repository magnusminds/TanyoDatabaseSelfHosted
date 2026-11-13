CREATE PROCEDURE [dbo].[ReportProductSalesDetailsDrill] (  
 @TenantId INT  
 ,@FromDate DATE = NULL  
 ,@ToDate DATE = NULL  
 ,@SalesmanId VARCHAR(20) = NULL  
 ,@CategoryId BIGINT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 50  
 ,@SortBy VARCHAR(50) = 'CountOfCategory'  
 ,@SortOrder VARCHAR(50) = 'ASC'  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @SubjectTypeId INT;  
  
  SELECT @SubjectTypeId = st.SubjectTypeId  
  FROM SubjectTypes st WITH (NOLOCK)  
  WHERE st.TenantId = @TenantId  
  AND st.SubjectTypeName = 'Products'  
  
  SELECT  
   c.CategoryId  
   ,c.CategoryName AS CategoryName  
   ,o.SalesmanId  
   ,au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName  
   ,o.OrderNo AS OrderNo  
   ,p.ProductTitle  
   ,p.ModelNo  
   ,ISNULL(osi.ProductImage, '') AS ProductImage  
   ,osi.Quantity AS ProductQantity  
   ,osi.AmountBeforeGST AS ProductSalePrice  
   ,osi.ItemStatus as OrderSetItemStatus  
   ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
  FROM Products p WITH (NOLOCK)  
  INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId  
  INNER JOIN OrderSetItems osi WITH (NOLOCK) ON osi.SubjectId = p.ProductId  
   AND osi.SubjectTypeId = @SubjectTypeId  
   AND osi.IsDeleted = 0  
  INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId  
  INNER JOIN AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId  
  WHERE (@CategoryId IS NULL OR p.CategoryId = @CategoryId)  
  AND (@SalesmanId IS NULL OR o.SalesmanId = @SalesmanId)  
  AND o.STATUS IN (2,3,4,5)  
  AND o.ApprovedDate >= @FromDate  
  AND o.ApprovedDate <= @ToDate  
  ORDER BY CASE   
    WHEN @SortBy = 'OrderNo'  
     AND @SortOrder = 'ASC'  
     THEN o.OrderNo  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'OrderNo'  
     AND @SortOrder = 'DESC'  
     THEN o.OrderNo  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'ModelNo'  
     AND @SortOrder = 'ASC'  
     THEN p.ModelNo  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'ModelNo'  
     AND @SortOrder = 'DESC'  
     THEN p.ModelNo  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'ProductTitle'  
     AND @SortOrder = 'ASC'  
     THEN p.ProductTitle  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'ProductTitle'  
     AND @SortOrder = 'DESC'  
     THEN p.ProductTitle  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'CategoryName'  
     AND @SortOrder = 'ASC'  
     THEN c.CategoryName  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'CategoryName'  
     AND @SortOrder = 'DESC'  
     THEN c.CategoryName  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'Price'  
     AND @SortOrder = 'ASC'  
     THEN osi.AmountBeforeGST  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'Price'  
     AND @SortOrder = 'DESC'  
     THEN osi.AmountBeforeGST  
    END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS  
  
  FETCH NEXT @PageSize ROWS ONLY  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ErrorMessage NVARCHAR(4000)  
  DECLARE @ErrorSeverity INT  
 END CATCH  
END

GO

