CREATE   PROCEDURE [dbo].[ReportCustomerLedger]  
     @TenantId INT = NULL  
    ,@CustomerId BIGINT = NULL  
    ,@FromDate DATE = NULL  
    ,@ToDate DATE = NULL  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
  
    DECLARE  
         @CustomerName NVARCHAR(200)  
        ,@TotalDebitAmount DECIMAL(18,2)  
        ,@TotalCreditAmount DECIMAL(18,2)  
        ,@OutstandingAmount DECIMAL(18,2)  
        ,@FinalJson NVARCHAR(MAX);  
  
    CREATE TABLE #Orders  
    (  
         OrderId BIGINT  
        ,CustomerId BIGINT  
        ,OrderDate DATE  
        ,OrderNo NVARCHAR(50)  
        ,DebitAmount DECIMAL(18,2)  
    );  
  
    CREATE TABLE #Payments  
    (  
         PaymentId BIGINT  
        ,OrderId BIGINT  
        ,PaymentDate DATE  
        ,CreditAmount DECIMAL(18,2)  
        ,PaymentType NVARCHAR(50)  
    );  
  
    CREATE TABLE #SalesReturns  
    (  
         ReturnId BIGINT  
        ,OrderId BIGINT  
        ,ReturnDate DATE  
        ,InwardNo NVARCHAR(50)  
        ,DebitAmount DECIMAL(18,2)  
    );  
  
    INSERT INTO #Orders (OrderId, CustomerId, OrderDate, OrderNo, DebitAmount)  
    SELECT  
         o.OrderId  
        ,o.CustomerId  
        ,CAST(o.ApprovedDate AS DATE)  
        ,o.OrderNo  
        ,ROUND(ISNULL(o.TotalAmt, o.TotalAmount), 0)  
    FROM Orders o  
    WHERE o.TenantId = @TenantId  
      AND o.CustomerId = @CustomerId  
      AND CAST(o.ApprovedDate AS DATE) BETWEEN @FromDate AND @ToDate  
      AND o.Status NOT IN (0, 1, 8, 9);  
  
    INSERT INTO #Payments (PaymentId, OrderId, PaymentDate, CreditAmount, PaymentType)  
    SELECT  
         p.PaymentId  
        ,p.OrderId  
        ,CAST(p.ReceivedDate AS DATE)  
        ,p.ReceivedAmount  
        ,CAST(p.PaymentType AS NVARCHAR(50))  
    FROM Payments p  
    WHERE p.TenantId = @TenantId  
      AND p.OrderId IN (SELECT OrderId FROM #Orders)  
      AND p.IsDeleted = 0  
      AND p.PaymentStatus = 1;  
  
    /*  
      Sales Return appears in the Debit column as a negative amount.  
      Return value = InwardDetailsEntry.Quantity * OrderSetItems.UnitSalePrice  
      (linked by InwardEntry.OrderId and InwardDetailsEntry.OrderSetItemId).  
    */  
    INSERT INTO #SalesReturns (ReturnId, OrderId, ReturnDate, InwardNo, DebitAmount)  
    SELECT  
         ie.InwardId  
        ,ie.OrderId  
        ,CAST(ie.CreatedDate AS DATE)  
        ,ie.InwardEntryNumber  
        ,-SUM(ISNULL(ide.Quantity, 0) * ISNULL(osi.UnitSalePrice, 0))  
    FROM InwardEntry ie  
    INNER JOIN InwardDetailsEntry ide  
        ON ide.InwardId = ie.InwardId  
       AND ide.IsDeleted = 0  
       AND ide.OrderSetItemId IS NOT NULL  
    INNER JOIN OrderSetItems osi  
        ON osi.OrderSetItemId = ide.OrderSetItemId  
       AND osi.OrderId = ie.OrderId  
       AND osi.IsDeleted = 0  
    WHERE ie.TenantId = @TenantId  
      AND ie.CustomerId = @CustomerId  
      AND ie.IsDeleted = 0  
      AND ie.InwardType = 3  
      AND ie.OrderId IN (SELECT OrderId FROM #Orders)  
      AND CAST(ie.CreatedDate AS DATE) BETWEEN @FromDate AND @ToDate  
    GROUP BY  
         ie.InwardId  
        ,ie.OrderId  
        ,CAST(ie.CreatedDate AS DATE)  
        ,ie.InwardEntryNumber;  
  
    SELECT @CustomerName = ISNULL(FirstName, '') + ' ' + ISNULL(LastName, '')  
    FROM Customers  
    WHERE CustomerId = @CustomerId  
      AND TenantId = @TenantId;  
  
    DECLARE @TotalOrderDebitAmount DECIMAL(18,2);  
    DECLARE @TotalSalesReturnAmount DECIMAL(18,2);  
  
    SELECT @TotalOrderDebitAmount = SUM(ISNULL(DebitAmount, 0))  
    FROM #Orders;  
  
    SELECT @TotalSalesReturnAmount = SUM(ISNULL(DebitAmount, 0))  
    FROM #SalesReturns;  
  
    SELECT @TotalDebitAmount = ISNULL(@TotalOrderDebitAmount, 0) + ISNULL(@TotalSalesReturnAmount, 0);  
  
    SELECT @TotalCreditAmount = SUM(ISNULL(CreditAmount, 0))  
    FROM #Payments;  
  
    SET @OutstandingAmount = ISNULL(@TotalDebitAmount, 0) - ISNULL(@TotalCreditAmount, 0);  
  
    SET @FinalJson =  
    (  
        SELECT  
             ISNULL(@CustomerName, '') AS CustomerName  
            ,ISNULL(@TotalDebitAmount, 0) AS TotalDebitAmount  
            ,ISNULL(@TotalCreditAmount, 0) AS TotalCreditAmount  
            ,ISNULL(@OutstandingAmount, 0) AS OutstandingAmount  
            ,(  
                SELECT  
                     o.OrderNo AS OrderNo  
                    ,o.OrderDate AS OrderDate  
                    ,o.DebitAmount AS DebitAmount  
                    ,JSON_QUERY(COALESCE(  
                        (  
                            SELECT  
                                 sr.ReturnId AS ReturnId  
                                ,sr.ReturnDate AS ReturnDate  
                                ,sr.InwardNo AS InwardNo  
                                ,sr.DebitAmount AS DebitAmount  
                            FROM #SalesReturns sr  
                            WHERE sr.OrderId = o.OrderId  
                            ORDER BY sr.ReturnDate DESC  
                            FOR JSON PATH  
                        ), '[]')) AS SalesReturns  
                    ,JSON_QUERY(COALESCE(  
                        (  
                            SELECT  
                                 p.PaymentId AS PaymentId  
                                ,p.PaymentDate AS PaymentDate  
                                ,p.CreditAmount AS CreditAmount  
                                ,p.PaymentType AS PaymentType  
                            FROM #Payments p  
                            WHERE p.OrderId = o.OrderId  
                            ORDER BY p.PaymentDate DESC  
                            FOR JSON PATH  
                        ), '[]')) AS Payments  
                FROM #Orders o  
                ORDER BY o.OrderDate DESC  
                FOR JSON PATH  
            ) AS Orders  
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER  
    );  
  
    SELECT ISNULL(@FinalJson, '{}') AS JsonResult;  
  
    DROP TABLE IF EXISTS #Orders;  
    DROP TABLE IF EXISTS #Payments;  
    DROP TABLE IF EXISTS #SalesReturns;  
END;