/*  
 EXEC [dbo].[RPT_ProductSoldBySalesman]   
  @TenantId = 1206  
  ,@FromDate = '2026-09-01'  
  ,@ToDate = '2026-09-08'  
  ,@SalesmanId = -1  
*/  
CREATE PROCEDURE [dbo].[RPT_ProductSoldBySalesman] (  
 @TenantId INT  
 ,@FromDate DATE  
 ,@ToDate DATE  
 ,@SalesmanId BIGINT = - 1  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 50  
 ,@SortBy VARCHAR(50) = 'NoofOrders'  
 ,@SortOrder VARCHAR(50) = 'DESC'  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @ApproveFromDateTime DATETIMEOFFSET(7) = CAST(@FromDate AS VARCHAR(10)) + ' 00:00:00.0000000 +05:30'  
   ,@ApproveToDateTime DATETIMEOFFSET(7) = CAST(@ToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +05:30';  
  
  WITH OrderSummary  
  AS (  
   SELECT o.SalesmanId  
    ,COUNT(DISTINCT o.OrderId) AS NoofOrders  
    ,SUM(CASE   
      WHEN o.GSTType = 1  
       THEN o.AmountBeforeGST + o.SpecialDiscount  
      ELSE o.TotalAmount + o.SpecialDiscount  
      END) AS ValueofOrders  
   FROM Orders o WITH (NOLOCK)  
   WHERE o.TenantId = @TenantId  
    AND O.ApprovedDate >= @ApproveFromDateTime  
    AND O.ApprovedDate <= @ApproveToDateTime  
   GROUP BY o.SalesmanId  
   )  
  SELECT CONVERT(VARCHAR(10), O.ApprovedDate, 103) AS [Date]  
   ,aus.FirstName + ' ' + aus.LastName + CASE   
    WHEN aus.IsDeleted = 1  
     THEN ' (Inactive)'  
    ELSE ''  
    END AS SalesmanName  
   ,O.OrderNo AS [Order Number]  
   ,CASE   
    WHEN OD.ItemStatus = 3  
     THEN 'Delivered'  
    ELSE 'Not Delivered'  
    END AS [DELIVERY Status]  
   ,C.CategoryName AS [Category Name]  
   ,P.ProductTitle AS [Product Title]  
   ,CAST((OD.UnitSalePrice * OD.Quantity) AS NUMERIC(18, 2)) AS [Item Amount]  
   ,SUM(CAST(OD.UnitSalePrice * OD.Quantity AS NUMERIC(18,2))) OVER () AS [GrandValueOfItemAmount]  
   ,COUNT(1) OVER () AS TotalCount  
  FROM Orders O WITH (NOLOCK)  
  INNER JOIN AspNetUsers aus WITH (NOLOCK) ON O.SalesmanId = aus.UserId  
  INNER JOIN OrderSetItems OD WITH (NOLOCK) ON O.OrderId = OD.OrderId  
  INNER JOIN Products P WITH (NOLOCK) ON OD.SubjectId = P.ProductId  
  INNER JOIN OrderSummary os ON os.SalesmanId = aus.UserId  
  INNER JOIN Categories C WITH (NOLOCK) ON P.CategoryId = C.CategoryId  
  WHERE O.TenantId = @TenantId  
   AND O.ApprovedDate >= @ApproveFromDateTime  
   AND O.ApprovedDate <= @ApproveToDateTime  
   AND P.ProductTitle IS NOT NULL  
   AND (  
    @SalesmanId = - 1  
    OR aus.UserId = @SalesmanId  
    )  
  ORDER BY CASE   
    WHEN @SortBy = 'Salesman'  
     AND @SortOrder = 'ASC'  
     THEN aus.FirstName + ' ' + aus.LastName  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'Salesman'  
     AND @SortOrder = 'DESC'  
     THEN aus.FirstName + ' ' + aus.LastName  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'ApprovedDate'  
     AND @SortOrder = 'ASC'  
     THEN O.ApprovedDate  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'ApprovedDate'  
     AND @SortOrder = 'DESC'  
     THEN O.ApprovedDate  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'NoofOrders'  
     AND @SortOrder = 'ASC'  
     THEN os.NoofOrders  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'NoofOrders'  
     AND @SortOrder = 'DESC'  
     THEN os.NoofOrders  
    END DESC  
   ,O.OrderId ASC OFFSET(@PageIndex - 1) * @PageSize ROWS  
  
  FETCH NEXT @PageSize ROWS ONLY;  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ObjectName VARCHAR(500) = OBJECT_NAME(@@PROCID)  
   ,@ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
 END CATCH  
END
