CREATE   PROC [dbo].[ReportOrderDueAmount] (  
 @TenantId INT  
 ,@FromDate DATE  
 ,@ToDate DATE  
 ,@SalesmanId BIGINT = NULL  
 ,@CustomerName VARCHAR(50) = NULL  
 ,@Status INT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 50  
 ,@SortBy VARCHAR(50) = 'SalesmanName'  
 ,@SortOrder VARCHAR(50) = 'DESC'  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  WITH cte  
  AS (  
   SELECT p.OrderId  
    ,SUM(p.ReceivedAmount) AS ReceivedAmount  
   FROM dbo.Payments p WITH (NOLOCK)  
   WHERE p.TenantId = @TenantId  
    AND p.PaymentStatus = 1  
    AND p.IsDeleted = 0  
   GROUP BY p.OrderId  
   ) 
   ,cte2
   AS 
   (
  SELECT CAST(o.ApprovedDate AS DATE) AS OrderDate  
   ,o.OrderId  
   ,o.OrderNo  
   ,o.CreatedBy AS SalesmanId  
   ,(au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END) AS SalesmanName  
   ,o.CustomerID  
   ,(IsNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'')) AS CustomerName  
   ,c.PhoneNumber  
   ,CASE   
    WHEN o.STATUS = 5  
     THEN o.DeliveryDate  
    ELSE o.TentativeDeliveryDate  
    END AS DeliveryDate  
   ,o.STATUS  
   ,ROUND(o.TotalAmt + IIF(o.DeliveryAmountCollectionType = 1, ISNULL(o.DeliveryAmount, 0), 0) - (ISNULL(o.LumpsumDiscount, 0)),0) AS TotalAmt  
   ,ISNULL(ROUND(p.ReceivedAmount, 0), 0) AS AdvanceAmount  
   --,ROUND((o.TotalAmt - ISNULL(p.ReceivedAmount, 0)), 0) AS DuesAmount  
   ,ROUND((o.TotalAmt + IIF(o.DeliveryAmountCollectionType = 1, ISNULL(o.DeliveryAmount, 0), 0) - ((ISNULL(o.LumpsumDiscount, 0)) + ISNULL(p.ReceivedAmount, 0))), 0) AS DuesAmount  
   ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
   ,SUM(ROUND(o.TotalAmt + IIF(o.DeliveryAmountCollectionType = 1, ISNULL(o.DeliveryAmount, 0), 0) - (ISNULL(o.LumpsumDiscount, 0)),0)) OVER () AS GrandTotalTotalAmt  
   ,SUM(ISNULL(ROUND(p.ReceivedAmount, 0), 0))  OVER () AS GrandTotalAdvanceAmount  
   ,SUM(ROUND((o.TotalAmt + IIF(o.DeliveryAmountCollectionType = 1, ISNULL(o.DeliveryAmount, 0), 0) - ((ISNULL(o.LumpsumDiscount, 0)) + ISNULL(p.ReceivedAmount, 0))), 0))  OVER () AS GrandTotalDuesAmount  
  FROM dbo.Orders o WITH (NOLOCK)  
  INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId  
  INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID  
   AND c.TenantId = o.TenantId  
  LEFT JOIN cte p ON p.OrderId = o.OrderId  
  WHERE o.TenantId = @TenantId  
   AND o.STATUS IN (  
    2  
    ,3  
    ,4  
    ,5  
    )  
   AND CONVERT(DATE, o.ApprovedDate) BETWEEN @FromDate  
    AND @ToDate  
   AND (  
    @SalesmanId IS NULL  
    OR o.SalesmanId = @SalesmanId  
    )  
   AND (  
    @CustomerName IS NULL  
    OR (c.FirstName + ' ' + c.LastName) LIKE '%' + @CustomerName + '%'  
    )  
   AND (  
    @Status IS NULL  
    OR o.STATUS = @Status  
    ) --Approved, In Progress, Completed, Delivered  
  ORDER BY CASE   
    WHEN @SortBy = 'OrderDate'  
     AND @SortOrder = 'ASC'  
     THEN CAST(o.ApprovedDate AS DATE)  
    END  
   ,CASE   
    WHEN @SortBy = 'OrderDate'  
     AND @SortOrder = 'DESC'  
     THEN CAST(o.ApprovedDate AS DATE)  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'OrderNo'  
     AND @SortOrder = 'ASC'  
     THEN o.OrderNo  
    END  
   ,CASE   
    WHEN @SortBy = 'OrderNo'  
     AND @SortOrder = 'DESC'  
     THEN o.OrderNo  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'SalesmanName'  
     AND @SortOrder = 'ASC'  
     THEN (au.FirstName + ' ' + au.LastName)  
    END  
   ,CASE   
    WHEN @SortBy = 'SalesmanName'  
     AND @SortOrder = 'DESC'  
     THEN (au.FirstName + ' ' + au.LastName)  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'CustomerName'  
     AND @SortOrder = 'ASC'  
     THEN (c.FirstName + ' ' + c.LastName)  
    END  
   ,CASE   
    WHEN @SortBy = 'CustomerName'  
     AND @SortOrder = 'DESC'  
     THEN (c.FirstName + ' ' + c.LastName)  
    END DESC  
 ,CASE   
    WHEN @SortBy = 'PhoneNumber'  
     AND @SortOrder = 'ASC'  
     THEN c.PhoneNumber  
    END  
   ,CASE   
    WHEN @SortBy = 'PhoneNumber'  
     AND @SortOrder = 'DESC'  
     THEN c.PhoneNumber  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'DeliveryDate'  
     AND @SortOrder = 'ASC'  
     THEN CASE   
       WHEN o.STATUS = 5  
        THEN o.DeliveryDate  
       ELSE o.TentativeDeliveryDate  
       END  
    END  
   ,CASE   
    WHEN @SortBy = 'DeliveryDate'  
     AND @SortOrder = 'DESC'  
     THEN CASE   
       WHEN o.STATUS = 5  
        THEN o.DeliveryDate  
       ELSE o.TentativeDeliveryDate  
       END  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'OrderStatus'  
     AND @SortOrder = 'ASC'  
     THEN o.STATUS  
    END  
   ,CASE   
    WHEN @SortBy = 'OrderStatus'  
     AND @SortOrder = 'DESC'  
     THEN o.STATUS  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'TotalAmt'  
     AND @SortOrder = 'ASC'  
     THEN o.TotalAmt  
    END  
   ,CASE   
    WHEN @SortBy = 'TotalAmt'  
     AND @SortOrder = 'DESC'  
     THEN o.TotalAmt  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'AdvanceAmount'  
     AND @SortOrder = 'ASC'  
     THEN ISNULL(p.ReceivedAmount, 0)  
    END  
   ,CASE   
    WHEN @SortBy = 'AdvanceAmount'  
     AND @SortOrder = 'DESC'  
     THEN ISNULL(p.ReceivedAmount, 0)  
    END DESC  
   ,CASE   
    WHEN @SortBy = 'DuesAmount'  
     AND @SortOrder = 'ASC'  
     THEN (o.TotalAmt - ISNULL(p.ReceivedAmount, 0))  
    END  
   ,CASE   
    WHEN @SortBy = 'DuesAmount'  
     AND @SortOrder = 'DESC'  
     THEN (o.TotalAmt - ISNULL(p.ReceivedAmount, 0))  
    END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS  
  
  FETCH NEXT @PageSize ROWS ONLY 
  )
  SELECT *
        ,SUM(TotalAmt) OVER () AS TotalAmtTotal
        ,SUM(AdvanceAmount) OVER () AS AdvanceAmountTotal  
        ,SUM(DuesAmount) OVER () AS DuesAmountTotal 
  FROM cte2

 END TRY  
  
BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH  
END

GO

