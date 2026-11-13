CREATE PROCEDURE [dbo].[ReportSalesmanSaleByCategory] (  
 @TenantId INT  
 ,@FromDate DATE = NULL  
 ,@ToDate DATE = NULL  
 ,@SalesmanId VARCHAR(20) = NULL  
 ,@CategoryId BIGINT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 50  
 ,@SortBy VARCHAR(50) = 'TotalProductQuantities'  
 ,@SortOrder VARCHAR(50) = 'ASC'  
 ,@OrderType INT = NULL
 ,@GroupBy INT = 1 -- 1: Salesman, 2: Category
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

  ;WITH RawData AS (
  SELECT c.CategoryId  
   ,c.CategoryName AS CategoryName  
   ,o.SalesmanId  
   ,au.FirstName + ' ' + au.LastName  + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName  
   ,osi.AmountBeforeGST
   ,osi.Quantity
  FROM Orders o WITH (NOLOCK)  
  INNER JOIN AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId  
  INNER JOIN OrderSetItems osi WITH (NOLOCK) ON osi.OrderId = o.OrderId  
   AND osi.SubjectTypeId = @SubjectTypeId  
   AND osi.IsDeleted = 0  
  INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId  
  INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId  
  WHERE o.TenantId = @TenantId  
  AND o.STATUS IN (2,3,4,5)  
  AND (  
   @FromDate IS NULL  
   OR o.ApprovedDate >= @FromDate  
   )  
  AND (  
   @ToDate IS NULL  
   OR o.ApprovedDate <= @ToDate  
   )  
  AND (  
   @SalesmanId IS NULL  
   OR o.SalesmanId = @SalesmanId  
   )  
  AND (  
   @CategoryId IS NULL  
   OR p.CategoryId = @CategoryId  
   )  
  AND (
   @OrderType IS NULL
   OR o.OrderType = @OrderType
  )
  ),
    MainData AS (
    SELECT 
        CASE WHEN @GroupBy = 1 AND @CategoryId IS NULL THEN 0 ELSE CategoryId END AS CategoryId,
        CASE WHEN @GroupBy = 1 AND @CategoryId IS NULL THEN 'All Categories' ELSE CategoryName END AS CategoryName,
        CASE WHEN @GroupBy = 2 AND @SalesmanId IS NULL THEN 0 ELSE SalesmanId END AS SalesmanId,
        CASE WHEN @GroupBy = 2 AND @SalesmanId IS NULL THEN 'All Salesmen' ELSE SalesmanName END AS SalesmanName,
        SUM(AmountBeforeGST) AS TotalSales,
        SUM(Quantity) AS TotalProductQuantities
    FROM RawData
    GROUP BY 
        CASE WHEN @GroupBy = 1 AND @CategoryId IS NULL THEN 0 ELSE CategoryId END,
        CASE WHEN @GroupBy = 1 AND @CategoryId IS NULL THEN 'All Categories' ELSE CategoryName END,
        CASE WHEN @GroupBy = 2 AND @SalesmanId IS NULL THEN 0 ELSE SalesmanId END,
        CASE WHEN @GroupBy = 2 AND @SalesmanId IS NULL THEN 'All Salesmen' ELSE SalesmanName END
  ),
  GrandTotals AS (
    SELECT SUM(AmountBeforeGST) AS GrandTotalSales, SUM(Quantity) AS GrandTotalProductQuantities
    FROM RawData
  )
  SELECT 
    m.*,
    gt.GrandTotalSales,
    gt.GrandTotalProductQuantities,
    COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
  FROM MainData m, GrandTotals gt
  ORDER BY CASE   
    WHEN @SortBy = 'SalesmanName'  
     AND @SortOrder = 'ASC'  
     THEN SalesmanName  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'SalesmanName'  
     AND @SortOrder = 'DESC'  
     THEN SalesmanName  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'CategoryName'  
     AND @SortOrder = 'ASC'  
     THEN CategoryName  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'CategoryName'  
     AND @SortOrder = 'DESC'  
     THEN CategoryName  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'TotalSales'  
     AND @SortOrder = 'ASC'  
     THEN TotalSales  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'TotalSales'  
     AND @SortOrder = 'DESC'  
     THEN TotalSales  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'TotalProductQuantities'  
     AND @SortOrder = 'ASC'  
     THEN TotalProductQuantities  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'TotalProductQuantities'  
     AND @SortOrder = 'DESC'  
     THEN TotalProductQuantities  
    END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS  
  
  FETCH NEXT @PageSize ROWS ONLY  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ErrorMessage NVARCHAR(4000)  
  DECLARE @ErrorSeverity INT  
 END CATCH  
END;

GO

