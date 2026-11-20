/*   
 EXEC [dbo].[Report_RPT_ProfitsByProducts] @TenantId = 1207   
 ,@FromDate = NULL   
 ,@ToDate = NULL   
 ,@OrderNo = NULL   
 ,@ReferredBy = NULL   
 ,@SalesmanId = NULL   
 ,@PageIndex = 1   
 ,@PageSize = 50   
 ,@SortBy = 'OrderNo'   
 ,@SortOrder = 'ASC'   
 ,@OrderStatus = NULL   
 ,@OrderType = NULL   
 ,@DeliveryFromDate = NULL   
 ,@DeliveryToDate = NULL   
 ,@CustomerId = NULL   
 ,@ModelNo = NULL   
 ,@OrderId = 271690   
 */  
CREATE OR ALTER PROCEDURE [dbo].[Report_RPT_ProfitsByProducts] (  
 @TenantId INT  
 ,@FromDate DATE = NULL  
 ,@ToDate DATE = NULL  
 ,@OrderNo VARCHAR(20) = NULL  
 ,@ReferredBy INT = NULL  
 ,@SalesmanId INT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 50  
 ,@SortBy VARCHAR(50) = 'OrderNo'  
 ,@SortOrder VARCHAR(50) = 'ASC'  
 ,@OrderStatus INT = NULL  
 ,@OrderType SMALLINT = NULL  
 ,@DeliveryFromDate DATE = NULL  
 ,@DeliveryToDate DATE = NULL  
 ,@CustomerId BIGINT = NULL  
 ,@ModelNo VARCHAR(100) = NULL  
 ,@OrderId BIGINT = NULL  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @IsBeforeGSTFlag BIT = 0
   ,@ProductSubjectTypeId INT = NULL
   ,@DeliveryFromDateTime DATETIMEOFFSET = NULL  
   ,@DeliveryToDateTime DATETIMEOFFSET = NULL  
   ,@ApprovedFromDateTime DATETIMEOFFSET = NULL  
   ,@ApprovedToDateTime DATETIMEOFFSET = NULL;  
  
  SELECT @DeliveryFromDateTime = CAST(@DeliveryFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'  
   ,@DeliveryToDateTime = CAST(@DeliveryToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'  
   ,@ApprovedFromDateTime = CAST(@FromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'  
   ,@ApprovedToDateTime = CAST(@ToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'  
  
  SELECT @IsBeforeGSTFlag = IsBeforeGST  
  FROM Tenants  
  WHERE TenantId = @TenantId

  SELECT @ProductSubjectTypeId = SubjectTypeId
  FROM [dbo].[SubjectTypes] WITH (NOLOCK)
  WHERE TenantId = @TenantId
   AND SubjectTypeName = 'Products'

  IF (@IsBeforeGSTFlag = 1)
  BEGIN  
    ;  
  
   WITH ProductLineProfits  
   AS (  
    SELECT o.OrderId  
     ,o.OrderNo AS OrderNo  
     ,o.CustomerID  
     ,ISNULL(ci.FirstName + ' ' + ISNULL(ci.LastName, ''), '') AS CustomerName  
     ,o.SalesmanId AS SalesmanId  
     ,(  
      aus.FirstName + ' ' + aus.LastName + CASE   
       WHEN aus.IsDeleted = 1  
        THEN ' (Inactive)'  
       ELSE ''  
       END  
      ) AS SalesmanName  
     ,ISNULL(r.FirstName + ' ' + ISNULL(r.LastName, ''), NULL) AS ReferredName  
     ,p.ProductId AS ProductId  
     ,ISNULL(p.ProductTitle, '') AS ProductTitle  
     ,ISNULL(p.ModelNo, '') AS ModelNo  
     ,ISNULL(CAST(SUM(osi.AmountBeforeGST) AS INT), 0) AS InvoiceAmt  
     ,ISNULL(CAST(SUM(osi.CGSTAmount + osi.SGSTAmount) AS INT), 0) AS GSTAmount  
     ,ISNULL((- 1) * CAST(SUM(ROUND(osi.SalesmanCommission, 0)) AS INT), 0) AS SalesmanCommission  
     ,ISNULL((- 1) * CAST(SUM(ROUND(osi.InteriorCommission, 0)) AS INT), 0) AS InteriorCommission  
     ,o.STATUS AS OrderStatus  
     ,FORMAT(o.ApprovedDate, 'dd/MM/yyyy') AS ApprovedDate  
     ,FORMAT(o.DeliveryDate, 'dd/MM/yyyy') AS DeliveryDate
     ,o.ApprovedDate AS ApprovedDateSort
     ,o.DeliveryDate AS DeliveryDateSort
     ,ISNULL(CAST(SUM(osi.InstantCostPrice * osi.Quantity) AS INT), 0) AS TotalCostPriceByOrder
     ,CAST(ROUND(SUM(ISNULL(osi.AmountBeforeGST, 0) - ISNULL(osi.InteriorCommission, 0) - ISNULL(osi.SalesmanCommission, 0) - ISNULL(osi.InstantCostPrice * osi.Quantity, 0)), 0) AS INT) AS TotalProfit
     ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
    FROM [dbo].[Orders] AS o WITH (NOLOCK)  
    INNER JOIN [dbo].[OrderSetItems] AS osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
     AND osi.IsDeleted = 0
    LEFT JOIN [dbo].[OrderSetItems] AS posi WITH (NOLOCK) ON posi.OrderSetItemId = osi.ParentOrderSetItemId
     AND ISNULL(osi.ParentOrderSetItemId, 0) > 0
    INNER JOIN [dbo].[Products] AS p WITH (NOLOCK) ON p.ProductId = ISNULL(posi.SubjectId, osi.SubjectId)
     AND ISNULL(posi.SubjectTypeId, osi.SubjectTypeId) = @ProductSubjectTypeId
    INNER JOIN [dbo].[Customers] AS ci WITH (NOLOCK) ON o.CustomerID = ci.CustomerId  
    LEFT JOIN [dbo].[Customers] AS r WITH (NOLOCK) ON o.RefferedBy = r.CustomerId  
    LEFT JOIN [dbo].[AspNetUsers] AS aus WITH (NOLOCK) ON aus.UserId = o.SalesmanId  
    WHERE o.TenantId = @TenantId  
     AND (  
      (  
       (  
        @OrderStatus IS NULL  
        AND o.STATUS IN (  
         2  
         ,3  
         ,4  
         ,5  
         )  
        )  
       OR @OrderStatus = o.STATUS  
       )  
      AND (  
       @FromDate IS NULL  
       OR o.ApprovedDate >= @ApprovedFromDateTime  
       )  
      AND (  
       @ToDate IS NULL  
       OR o.ApprovedDate <= @ApprovedToDateTime
       )  
      )  
     AND (  
      @OrderNo IS NULL  
      OR o.OrderNo LIKE '%' + @OrderNo + '%'  
      )  
     AND (  
      @ReferredBy IS NULL  
      OR @ReferredBy = r.CustomerId  
      )  
     AND (  
      @CustomerId IS NULL  
      OR o.CustomerID = @CustomerId  
      )  
     AND (  
      @SalesmanId IS NULL  
      OR @SalesmanId = o.SalesmanId  
      )  
     AND (  
      @OrderType IS NULL  
      OR o.OrderType = @OrderType  
      )  
     AND (  
      @DeliveryFromDate IS NULL  
      OR o.DeliveryDate >= @DeliveryFromDateTime  
      )  
     AND (  
      @DeliveryToDate IS NULL  
      OR o.DeliveryDate <= @DeliveryToDateTime  
      )  
     AND (  
      @OrderId IS NULL  
      OR @OrderId = o.OrderId  
      )  
     AND (  
      @ModelNo IS NULL  
      OR p.ModelNo LIKE '%' + @ModelNo + '%'  
      )  
    GROUP BY o.OrderId  
     ,o.OrderNo  
     ,o.CustomerID  
     ,ci.FirstName  
     ,ci.LastName  
     ,o.STATUS  
     ,r.FirstName  
     ,r.LastName  
     ,o.ApprovedDate  
     ,O.DeliveryDate  
     ,o.SalesmanId  
     ,aus.FirstName + ' ' + aus.LastName  
     ,aus.IsDeleted  
     ,p.ProductId  
     ,p.ProductTitle  
     ,p.ModelNo  
    )  
   SELECT OrderId  
    ,OrderNo  
    ,CustomerID  
    ,CustomerName  
    ,SalesmanId  
    ,SalesmanName  
    ,ReferredName  
    ,ProductId  
    ,ProductTitle  
    ,ModelNo  
    ,InvoiceAmt  
    ,GSTAmount  
    ,SalesmanCommission  
    ,InteriorCommission  
    ,OrderStatus  
    ,TotalProfit  
    ,ApprovedDate  
    ,DeliveryDate  
    ,TotalCostPriceByOrder  
    ,TotalCount  
    ,SUM(InvoiceAmt) OVER () AS TotalInvoiceAmt  
    ,SUM(GSTAmount) OVER () AS TotalGSTAmount  
    ,SUM(TotalCostPriceByOrder) OVER () AS TotalCostPrice  
    ,SUM(SalesmanCommission) OVER () AS TotalSalesmanCommission  
    ,SUM(InteriorCommission) OVER () AS TotalInteriorCommission  
    ,SUM(TotalProfit) OVER () AS TotalProfitAllOrders  
   FROM ProductLineProfits  
   ORDER BY CASE   
     WHEN @SortBy = 'OrderNo'  
      AND @SortOrder = 'ASC'  
      THEN OrderNo  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'OrderNo'  
      AND @SortOrder = 'DESC'  
      THEN OrderNo  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'CustomerName'  
      AND @SortOrder = 'DESC'  
      THEN CustomerName  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'CustomerName'  
      AND @SortOrder = 'ASC'  
      THEN CustomerName  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'SalesmanName'  
      AND @SortOrder = 'DESC'  
      THEN SalesmanName  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'SalesmanName'  
      AND @SortOrder = 'ASC'  
      THEN SalesmanName  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ReferredName'  
      AND @SortOrder = 'DESC'  
      THEN ReferredName  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ReferredName'  
      AND @SortOrder = 'ASC'  
      THEN ReferredName  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'CostPrice'  
      AND @SortOrder = 'ASC'  
      THEN TotalCostPriceByOrder  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'CostPrice'  
      AND @SortOrder = 'DESC'  
      THEN TotalCostPriceByOrder  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'InvoiceAmt'  
      AND @SortOrder = 'ASC'  
      THEN InvoiceAmt  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'InvoiceAmt'  
      AND @SortOrder = 'DESC'  
      THEN InvoiceAmt  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'GSTAmount'  
      AND @SortOrder = 'ASC'  
      THEN GSTAmount  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'GSTAmount'  
      AND @SortOrder = 'DESC'  
      THEN GSTAmount  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'SalesmanCommission'  
      AND @SortOrder = 'ASC'  
      THEN SalesmanCommission  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'SalesmanCommission'  
      AND @SortOrder = 'DESC'  
      THEN SalesmanCommission  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'InteriorCommission'  
      AND @SortOrder = 'ASC'  
      THEN InteriorCommission  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'InteriorCommission'  
      AND @SortOrder = 'DESC'  
      THEN InteriorCommission  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'TotalProfit'  
      AND @SortOrder = 'ASC'  
      THEN TotalProfit  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'TotalProfit'  
      AND @SortOrder = 'DESC'  
      THEN TotalProfit  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ProductTitle'  
      AND @SortOrder = 'ASC'  
      THEN ProductTitle  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ProductTitle'  
      AND @SortOrder = 'DESC'  
      THEN ProductTitle  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ProductId'  
      AND @SortOrder = 'ASC'  
      THEN ProductId  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ProductId'  
      AND @SortOrder = 'DESC'  
      THEN ProductId  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ModelNo'  
      AND @SortOrder = 'ASC'  
      THEN ModelNo  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ModelNo'  
      AND @SortOrder = 'DESC'  
      THEN ModelNo  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ApproveDate'  
      AND @SortOrder = 'ASC'  
      THEN ApprovedDateSort
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ApproveDate'  
      AND @SortOrder = 'DESC'  
      THEN ApprovedDateSort
     END DESC  
    ,CASE   
     WHEN @SortBy = 'DeliveryDate'  
      AND @SortOrder = 'ASC'  
      THEN DeliveryDateSort
     END ASC  
    ,CASE   
     WHEN @SortBy = 'DeliveryDate'  
      AND @SortOrder = 'DESC'  
      THEN DeliveryDateSort
     END DESC
    ,OrderId ASC
    ,ProductId ASC
    OFFSET(@PageIndex - 1) * @PageSize ROWS
  
   FETCH NEXT @PageSize ROWS ONLY  
  END  
  ELSE  
  BEGIN  
    ;  
  
   WITH ProductLineProfits  
   AS (  
    SELECT o.OrderId  
     ,o.OrderNo AS OrderNo  
     ,o.CustomerID  
     ,ISNULL(ci.FirstName + ' ' + ISNULL(ci.LastName, ''), '') AS CustomerName  
     ,o.SalesmanId AS SalesmanId  
     ,(  
      aus.FirstName + ' ' + aus.LastName + CASE   
       WHEN aus.IsDeleted = 1  
        THEN ' (Inactive)'  
       ELSE ''  
       END  
      ) AS SalesmanName  
     ,ISNULL(r.FirstName + ' ' + ISNULL(r.LastName, ''), NULL) AS ReferredName  
     ,p.ProductId AS ProductId  
     ,ISNULL(p.ProductTitle, '') AS ProductTitle  
     ,ISNULL(p.ModelNo, '') AS ModelNo  
     ,ISNULL(CAST(SUM(osi.TotalAmount) AS INT), 0) AS InvoiceAmt  
     ,ISNULL(CAST(SUM(osi.CGSTAmount + osi.SGSTAmount) AS INT), 0) AS GSTAmount  
     ,ISNULL((- 1) * CAST(SUM(osi.SalesmanCommission) AS INT), 0) AS SalesmanCommission  
     ,ISNULL((- 1) * CAST(SUM(osi.InteriorCommission) AS INT), 0) AS InteriorCommission  
     ,o.STATUS AS OrderStatus  
     ,FORMAT(o.ApprovedDate, 'dd/MM/yyyy') AS ApprovedDate  
     ,FORMAT(o.DeliveryDate, 'dd/MM/yyyy') AS DeliveryDate
     ,o.ApprovedDate AS ApprovedDateSort
     ,o.DeliveryDate AS DeliveryDateSort
     ,ISNULL(CAST(SUM(osi.InstantCostPrice * osi.Quantity) AS INT), 0) AS TotalCostPriceByOrder
     ,CAST(ROUND(SUM(ISNULL(osi.AmountBeforeGST, 0) - ISNULL(osi.InteriorCommission, 0) - ISNULL(osi.SalesmanCommission, 0) - ISNULL(osi.InstantCostPrice * osi.Quantity, 0)), 0) AS INT) AS TotalProfit
     ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
    FROM [dbo].[Orders] AS o WITH (NOLOCK)  
    INNER JOIN [dbo].[OrderSetItems] AS osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
     AND osi.IsDeleted = 0
    LEFT JOIN [dbo].[OrderSetItems] AS posi WITH (NOLOCK) ON posi.OrderSetItemId = osi.ParentOrderSetItemId
     AND ISNULL(osi.ParentOrderSetItemId, 0) > 0
    INNER JOIN [dbo].[Products] AS p WITH (NOLOCK) ON p.ProductId = ISNULL(posi.SubjectId, osi.SubjectId)
     AND ISNULL(posi.SubjectTypeId, osi.SubjectTypeId) = @ProductSubjectTypeId
    INNER JOIN [dbo].[Customers] AS ci WITH (NOLOCK) ON o.CustomerID = ci.CustomerId  
    LEFT JOIN [dbo].[Customers] AS r WITH (NOLOCK) ON o.RefferedBy = r.CustomerId  
    LEFT JOIN [dbo].[AspNetUsers] AS aus WITH (NOLOCK) ON aus.UserId = o.SalesmanId  
    WHERE o.TenantId = @TenantId  
     AND (  
      (  
       (  
        @OrderStatus IS NULL  
        AND o.STATUS IN (  
         2  
         ,3  
         ,4  
         ,5  
         )  
        )  
       OR @OrderStatus = o.STATUS  
       )  
      AND (  
       @FromDate IS NULL  
       OR o.ApprovedDate >= @ApprovedFromDateTime  
       )  
      AND (  
       @ToDate IS NULL  
       OR o.ApprovedDate <= @ApprovedToDateTime -- TAN-4732: was DATEADD(DAY, 1, end-of-day) = one extra day
       )  
      )  
     AND (  
      @OrderNo IS NULL  
      OR o.OrderNo LIKE '%' + @OrderNo + '%'  
      )  
     AND (  
      @ReferredBy IS NULL  
      OR @ReferredBy = r.CustomerId  
      )  
     AND (  
      @CustomerId IS NULL  
      OR o.CustomerID = @CustomerId  
      )  
     AND (  
      @SalesmanId IS NULL  
      OR @SalesmanId = o.SalesmanId  
      )  
     AND (  
      @OrderType IS NULL  
      OR o.OrderType = @OrderType  
      )  
     AND (  
      @DeliveryFromDate IS NULL  
      OR o.DeliveryDate >= @DeliveryFromDateTime  
      )  
     AND (  
      @DeliveryToDate IS NULL  
      OR o.DeliveryDate <= @DeliveryToDateTime  
      )  
     AND (  
      @OrderId IS NULL  
      OR @OrderId = o.OrderId  
      )  
     AND (  
      @ModelNo IS NULL  
      OR p.ModelNo LIKE '%' + @ModelNo + '%'  
      )  
    GROUP BY o.OrderId  
     ,o.OrderNo  
     ,o.CustomerID  
     ,ci.FirstName  
     ,ci.LastName  
     ,o.STATUS  
     ,r.FirstName  
     ,r.LastName  
     ,o.ApprovedDate  
     ,o.DeliveryDate  
     ,o.SalesmanId  
     ,aus.FirstName + ' ' + aus.LastName  
     ,aus.IsDeleted  
     ,p.ProductId  
     ,p.ProductTitle  
     ,p.ModelNo  
    )  
   SELECT OrderId  
    ,OrderNo  
    ,CustomerID  
    ,CustomerName  
    ,SalesmanId  
    ,SalesmanName  
    ,ReferredName  
    ,ProductId  
    ,ProductTitle  
    ,ModelNo  
    ,InvoiceAmt  
    ,GSTAmount  
    ,SalesmanCommission  
    ,InteriorCommission  
    ,OrderStatus  
    ,TotalProfit  
    ,ApprovedDate  
    ,DeliveryDate  
    ,TotalCostPriceByOrder  
    ,TotalCount  
    ,SUM(InvoiceAmt) OVER () AS TotalInvoiceAmt  
    ,SUM(GSTAmount) OVER () AS TotalGSTAmount  
    ,SUM(TotalCostPriceByOrder) OVER () AS TotalCostPrice  
    ,SUM(SalesmanCommission) OVER () AS TotalSalesmanCommission  
    ,SUM(InteriorCommission) OVER () AS TotalInteriorCommission  
    ,SUM(TotalProfit) OVER () AS TotalProfitAllOrders  
   FROM ProductLineProfits  
   ORDER BY CASE   
     WHEN @SortBy = 'OrderNo'  
      AND @SortOrder = 'ASC'  
      THEN OrderNo  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'OrderNo'  
      AND @SortOrder = 'DESC'  
      THEN OrderNo  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'CustomerName'  
      AND @SortOrder = 'DESC'  
      THEN CustomerName  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'CustomerName'  
      AND @SortOrder = 'ASC'  
      THEN CustomerName  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'SalesmanName'  
      AND @SortOrder = 'DESC'  
      THEN SalesmanName  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'SalesmanName'  
      AND @SortOrder = 'ASC'  
      THEN SalesmanName  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ReferredName'  
      AND @SortOrder = 'DESC'  
      THEN ReferredName  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ReferredName'  
      AND @SortOrder = 'ASC'  
      THEN ReferredName  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'CostPrice'  
      AND @SortOrder = 'ASC'  
      THEN TotalCostPriceByOrder  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'CostPrice'  
      AND @SortOrder = 'DESC'  
      THEN TotalCostPriceByOrder  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'InvoiceAmt'  
      AND @SortOrder = 'ASC'  
      THEN InvoiceAmt  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'InvoiceAmt'  
      AND @SortOrder = 'DESC'  
      THEN InvoiceAmt  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'GSTAmount'  
      AND @SortOrder = 'ASC'  
      THEN GSTAmount  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'GSTAmount'  
      AND @SortOrder = 'DESC'  
      THEN GSTAmount  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'SalesmanCommission'  
      AND @SortOrder = 'ASC'  
      THEN SalesmanCommission  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'SalesmanCommission'  
      AND @SortOrder = 'DESC'  
      THEN SalesmanCommission  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'InteriorCommission'  
      AND @SortOrder = 'ASC'  
      THEN InteriorCommission  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'InteriorCommission'  
      AND @SortOrder = 'DESC'  
      THEN InteriorCommission  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'TotalProfit'  
      AND @SortOrder = 'ASC'  
      THEN TotalProfit  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'TotalProfit'  
      AND @SortOrder = 'DESC'  
      THEN TotalProfit  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ProductTitle'  
      AND @SortOrder = 'ASC'  
      THEN ProductTitle  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ProductTitle'  
      AND @SortOrder = 'DESC'  
      THEN ProductTitle  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ProductId'  
      AND @SortOrder = 'ASC'  
      THEN ProductId  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ProductId'  
      AND @SortOrder = 'DESC'  
      THEN ProductId  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ModelNo'  
      AND @SortOrder = 'ASC'  
      THEN ModelNo  
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ModelNo'  
      AND @SortOrder = 'DESC'  
      THEN ModelNo  
     END DESC  
    ,CASE   
     WHEN @SortBy = 'ApproveDate'  
      AND @SortOrder = 'ASC'  
      THEN ApprovedDateSort
     END ASC  
    ,CASE   
     WHEN @SortBy = 'ApproveDate'  
      AND @SortOrder = 'DESC'  
      THEN ApprovedDateSort
     END DESC  
    ,CASE   
     WHEN @SortBy = 'DeliveryDate'  
      AND @SortOrder = 'ASC'  
      THEN DeliveryDateSort
     END ASC  
    ,CASE   
     WHEN @SortBy = 'DeliveryDate'  
      AND @SortOrder = 'DESC'  
      THEN DeliveryDateSort
     END DESC
    ,OrderId ASC
    ,ProductId ASC
    OFFSET(@PageIndex - 1) * @PageSize ROWS
  
   FETCH NEXT @PageSize ROWS ONLY  
  END  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg VARCHAR(MAX);  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID);  
  SET @ErrorMsg = ERROR_MESSAGE();  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
  
  THROW;  
 END CATCH  
END