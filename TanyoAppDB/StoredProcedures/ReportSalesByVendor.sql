CREATE PROCEDURE [dbo].[ReportSalesByVendor] (  
 @TenantId INT  
 ,@FromDate DATE = NULL  
 ,@ToDate DATE = NULL  
 ,@VendorName VARCHAR(2048) = NULL  
 ,@ProductCategory INT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 50  
 ,@SortBy VARCHAR(50) = 'VendorName'  
 ,@SortOrder VARCHAR(4) = 'ASC'  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @Vendor TABLE (Value VARCHAR(100));  
  DECLARE @Category TABLE (Value VARCHAR(100));  
  
  IF (  
    @VendorName IS NOT NULL  
    AND @VendorName <> ''  
    )  
   INSERT INTO @Vendor  
   SELECT TRIM(value)  
   FROM STRING_SPLIT(@VendorName, ',');  
  
  WITH CTE_VendorSales  
  AS (  
   SELECT V.VendorId  
    ,V.VendorName  
    ,SUM(OSI.TotalAmount) AS TotalSales  
    ,COUNT(DISTINCT O.OrderId) AS OrderCount  
   FROM Orders O WITH (NOLOCK)  
   INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderId = O.OrderId  
   INNER JOIN Products P WITH (NOLOCK) ON P.ProductId = OSI.SubjectId  
   INNER JOIN ProductVendorMapping PVM WITH (NOLOCK) ON P.ProductId = PVM.ProductId  
   INNER JOIN Vendors V WITH (NOLOCK) ON V.VendorId = PVM.VendorId  
   LEFT JOIN Categories PC WITH (NOLOCK) ON PC.CategoryId = P.CategoryId  
   WHERE O.TenantId = @TenantId  
    AND O.Status IN (2 ,3 ,4, 5) -- Approved, Ready to Deliver, Delivered  
    AND OSI.IsDeleted = 0  
    AND (  
     @FromDate IS NULL  
     OR CONVERT(DATE, O.ApprovedDate) >= @FromDate  
     )  
    AND (  
     @ToDate IS NULL  
     OR CONVERT(DATE, O.ApprovedDate) <= @ToDate  
     )  
    AND (  
     NOT EXISTS (  
      SELECT 1  
      FROM @Vendor  
      )  
     OR V.VendorName IN (  
      SELECT Value  
      FROM @Vendor  
      )  
     )  
    AND (  
     @ProductCategory IS NULL  
     OR P.CategoryId = @ProductCategory  
     )  
   GROUP BY V.VendorName  
    ,V.VendorId  
   )  
  SELECT VendorId  
   ,VendorName  
   ,TotalSales  
   ,OrderCount  
   ,SUM(TotalSales) OVER (PARTITION BY 1) AS GrandTotalSales  
   ,SUM(OrderCount) OVER (PARTITION BY 1) AS OrderGrandCount  
   ,(  
    SELECT COUNT(*)  
    FROM CTE_VendorSales  
    ) AS TotalCount  
  FROM CTE_VendorSales  
  ORDER BY CASE   
    WHEN @SortBy = 'VendorName'  
     AND @SortOrder = 'ASC'  
     THEN VendorName  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'VendorName'  
     AND @SortOrder = 'DESC'  
     THEN VendorName  
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
    WHEN @SortBy = 'OrderCount'  
     AND @SortOrder = 'ASC'  
     THEN OrderCount  
    END ASC  
   ,CASE   
    WHEN @SortBy = 'OrderCount'  
     AND @SortOrder = 'DESC'  
     THEN OrderCount  
    END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS  
  
  FETCH NEXT @PageSize ROWS ONLY;  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg VARCHAR(MAX);  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID);  
  SET @ErrorMsg = ERROR_MESSAGE();  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
 END CATCH  
END;  