/*  
EXEC [dbo].[DeliverOrderSetItem_Bulk_V2]  
    @TenantId = 2,  
    @OrderSetItemId = '11423,11424',  
    @UserId = 4279,  
*/  
CREATE PROCEDURE [dbo].[DeliverOrderSetItem_Bulk_V2] (  
 @TenantId INT  
 ,@OrderSetItemId VARCHAR(MAX)  
 ,@UserId INT  
 ,@Comment VARCHAR(MAX) = NULL  
 ,@WarehouseId BIGINT = NULL  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
 SET XACT_ABORT OFF;  
  
 DECLARE @IsRestrictDeliveryWithoutFullPayment BIT  
  ,@CheckProductStock BIT  
  ,@OtherWarehouseId BIGINT  
  ,@ProductSubjectTypeId INT  
  ,@ReturnStatus BIT = 1  
  ,@ReturnMessage VARCHAR(MAX) = ''  
  ,@UnpaidOrderNos VARCHAR(MAX) = ''  
  ,@LowStockOrderNos VARCHAR(MAX) = ''  
  ,@CheckRawMaterialStock BIT  
  ,@ProductUnavailableInWarehouseDetails VARCHAR(MAX) = ''  
  
 DROP TABLE IF EXISTS #OrderSetItemIds;  
  
 DROP TABLE IF EXISTS #Candidates;  
  
 DROP TABLE IF EXISTS #UnpaidOrders;  
  
 DROP TABLE IF EXISTS #ProductStockNeeded;  
  
 DROP TABLE IF EXISTS #StockShortfall;  
  
 DROP TABLE IF EXISTS #ChildResult;  
  
 DROP TABLE IF EXISTS #ExceededQtyItems;  
  
  SELECT DISTINCT TRY_CAST(value AS BIGINT) AS OrderSetItemId  
  INTO #OrderSetItemIds  
  FROM STRING_SPLIT(@OrderSetItemId, ',')  
  WHERE TRY_CAST(value AS BIGINT) IS NOT NULL;  
  
 IF NOT EXISTS (  
   SELECT 1  
   FROM #OrderSetItemIds  
   )  
 BEGIN  
  SELECT CAST(0 AS BIT) AS ReturnCode  
   ,'No valid OrderSetItemId provided.' AS ReturnMessage;  
  
  RETURN;  
 END  
  
 SELECT @IsRestrictDeliveryWithoutFullPayment = IsRestrictDeliveryWithoutFullPayment  
  ,@CheckProductStock = CheckProductStock  
  ,@CheckRawMaterialStock = CheckRawMaterialStock  
 FROM Tenants WITH (NOLOCK)  
 WHERE TenantId = @TenantId;  
  
 SELECT @ProductSubjectTypeId = SubjectTypeId  
 FROM SubjectTypes WITH (NOLOCK)  
 WHERE SubjectTypeName = 'Products'  
  AND TenantId = @TenantId  
  AND IsDeleted = 0;  
  
 IF @WarehouseId IS NOT NULL  
 BEGIN  
  IF NOT EXISTS (  
    SELECT 1  
    FROM Warehouse WITH (NOLOCK)  
    WHERE Id = @WarehouseId  
     AND TenantId = @TenantId  
     AND IsDeleted = 0  
    )  
  BEGIN  
   SELECT CAST(0 AS BIT) AS ReturnCode  
    ,'Provided WarehouseId is invalid or does not belong to the tenant.' AS ReturnMessage;  
  
   RETURN;  
  END  
  
  SET @OtherWarehouseId = @WarehouseId;  
 END  
 ELSE  
 BEGIN  
  SELECT TOP 1 @OtherWarehouseId = Id  
  FROM Warehouse WITH (NOLOCK)  
  WHERE TenantId = @TenantId  
   AND Name = 'Other'  
   AND IsDeleted = 0;  
  
  IF @OtherWarehouseId IS NULL  
  BEGIN  
   SELECT CAST(0 AS BIT) AS ReturnCode  
    ,'''Other'' warehouse not found for tenant.' AS ReturnMessage;  
  
   RETURN;  
  END  
 END  
  
 -- 4. Build candidate set with a stable row number for WHILE looping  
 SELECT ROW_NUMBER() OVER (  
   ORDER BY OSI.OrderSetItemId  
   ) AS Rn  
  ,OSI.OrderSetItemId  
  ,OSI.OrderId  
  ,OSI.SubjectId AS ProductId  
  ,OSI.SubjectTypeId  
  ,OSI.Quantity  
  ,O.OrderNo  
  ,O.TotalAmt  
 INTO #Candidates  
 FROM OrderSetItems OSI WITH (NOLOCK)  
 INNER JOIN #OrderSetItemIds X ON X.OrderSetItemId = OSI.OrderSetItemId  
 INNER JOIN Orders O WITH (NOLOCK) ON O.OrderId = OSI.OrderId  
 WHERE OSI.IsDeleted = 0  
  AND O.TenantId = @TenantId;  
  
 IF NOT EXISTS (  
   SELECT 1  
   FROM #Candidates  
   )  
 BEGIN  
  SELECT CAST(0 AS BIT) AS ReturnCode  
   ,'No matching, non-deleted order set items found for tenant.' AS ReturnMessage;  
  
  RETURN;  
 END  
  
 IF @IsRestrictDeliveryWithoutFullPayment = 1  
 BEGIN  
   ;  
  
  WITH Paid  
  AS (  
   SELECT OrderId  
    ,SUM(ReceivedAmount) AS ReceivedAmount  
   FROM Payments WITH (NOLOCK)  
   WHERE PaymentStatus = 1  
    AND IsDeleted = 0  
   GROUP BY OrderId  
   )  
  SELECT DISTINCT C.OrderId  
   ,C.OrderNo  
  INTO #UnpaidOrders  
  FROM #Candidates C  
  LEFT JOIN Paid P ON P.OrderId = C.OrderId  
  WHERE ISNULL(ROUND(P.ReceivedAmount, 0), 0) < ISNULL(ROUND(C.TotalAmt, 0), 0);  
  
  SELECT @UnpaidOrderNos = STRING_AGG(OrderNo, ',')  
  FROM #UnpaidOrders;  
 END  
  
 IF @CheckProductStock = 1  
  OR @CheckRawMaterialStock = 1  
 BEGIN  
  SELECT C.ProductId  
   ,SUM(C.Quantity) AS NeededQuantity  
  INTO #ProductStockNeeded  
  FROM #Candidates C  
  WHERE C.SubjectTypeId = @ProductSubjectTypeId  
  GROUP BY C.ProductId;  
  
  SELECT PSN.ProductId  
  INTO #StockShortfall  
  FROM #ProductStockNeeded PSN  
  INNER JOIN ProductQuantitiesByWarehouse PQW WITH (NOLOCK) ON PQW.ProductId = PSN.ProductId  
   AND PQW.WarehouseId = @OtherWarehouseId  
  WHERE ISNULL(PQW.Quantity, 0) < PSN.NeededQuantity;  
  
  IF EXISTS (  
    SELECT 1  
    FROM #StockShortfall  
    )  
  BEGIN  
    ;  
  
   WITH LowStockOrders  
   AS (  
    SELECT DISTINCT C.OrderNo  
    FROM #Candidates C  
    INNER JOIN #StockShortfall SS ON SS.ProductId = C.ProductId  
    )  
   SELECT @LowStockOrderNos = STRING_AGG(OrderNo, ',')  
   FROM LowStockOrders;  
  END  
 END  
  
 SELECT C.OrderSetItemId  
  ,C.OrderNo  
  ,C.ProductId  
  ,ISNULL(P.ProductTitle, '') AS ProductTitle  
 INTO #ExceededQtyItems  
 FROM #Candidates C  
 INNER JOIN Products P WITH (NOLOCK) ON P.ProductId = C.ProductId  
 LEFT JOIN ProductQuantitiesByWarehouse PQW WITH (NOLOCK) ON PQW.ProductId = C.ProductId  
  AND PQW.WarehouseId = @OtherWarehouseId  
 WHERE C.SubjectTypeId = @ProductSubjectTypeId  
  AND PQW.ProductId IS NULL;  
  
 IF EXISTS (  
   SELECT 1  
   FROM #ExceededQtyItems  
   )  
 BEGIN  
  SELECT @ProductUnavailableInWarehouseDetails = STRING_AGG(CAST(OrderNo AS NVARCHAR(MAX)) + ' - ' + ProductTitles, CHAR(13) + CHAR(10))  
  FROM (  
   SELECT OrderNo  
    ,STRING_AGG(CAST(ProductTitle AS NVARCHAR(MAX)), ', ') AS ProductTitles  
   FROM #ExceededQtyItems  
   GROUP BY OrderNo  
   ) X;  
 END  
  
 IF @UnpaidOrderNos <> ''  
  OR @LowStockOrderNos <> ''  
  OR @ProductUnavailableInWarehouseDetails <> ''  
 BEGIN  
  SET @ReturnStatus = 0;  
  
  --IF @UnpaidOrderNos <> ''  
  -- SET @ReturnMessage = @ReturnMessage  
  --  + CASE WHEN @ReturnMessage <> '' THEN ' | ' ELSE '' END  
  --  + 'Delivery cannot be processed until full payment is received for orders: ' + @UnpaidOrderNos;  
  --IF @LowStockOrderNos <> ''  
  -- SET @ReturnMessage = @ReturnMessage  
  --  + CASE WHEN @ReturnMessage <> '' THEN ' | ' ELSE '' END  
  --  + 'Delivery cannot be processed due to insufficient stock in the Other warehouse for the following orders ' + @LowStockOrderNos;  
  SELECT @ReturnStatus AS ReturnCode  
   ,CASE   
    WHEN ISNULL(@UnpaidOrderNos, '') <> ''  
     THEN 'Delivery cannot be processed until full payment is received for orders: '  
    ELSE ''  
    END AS PaymentReturnMessage  
   ,CASE   
    WHEN ISNULL(@LowStockOrderNos, '') <> ''  
     THEN 'Delivery cannot be processed due to insufficient stock in the Other warehouse for the following orders: '  
    ELSE ''  
    END AS ProductQuantityReturnMessage  
   ,CASE   
    WHEN ISNULL(@ProductUnavailableInWarehouseDetails, '') <> ''  
     THEN 'Delivery cannot be processed due to requested Product Items is not available in selected warehouse: '  
    ELSE ''  
    END AS ProductUnavailableInWarehouseReturnMessage  
   ,@UnpaidOrderNos AS UnpaidOrderNos  
   ,@LowStockOrderNos AS LowStockOrderNos  
   ,@ProductUnavailableInWarehouseDetails AS ProductUnavailableInWarehouseDetails;  
  
  RETURN;  
 END  
  
 DECLARE @Cnt INT = (  
   SELECT COUNT(*)  
   FROM #Candidates  
   )  
  ,@i INT = 1  
  ,@CurrentOrderSetItemId BIGINT  
  ,@CurrentOrderId BIGINT  
  ,@CurrentProductId BIGINT  
  ,@CurrentQuantity NUMERIC(18, 2)  
  ,@WarehouseDetailsJson VARCHAR(MAX)  
  ,@ChildReturnCode BIT  
  ,@ChildReturnMessage VARCHAR(512)  
  ,@Aborted BIT = 0  
  
 CREATE TABLE #ChildResult (  
  ReturnCode BIT  
  ,ReturnMessage VARCHAR(512)  
  ,ReturnOrderId BIGINT  
  );  
  
 BEGIN TRY  
  BEGIN TRAN;  
  
  IF NOT EXISTS (  
    SELECT 1  
    FROM #OrderSetItemIds  
    WHERE OrderSetItemId IN (  
      SELECT OrderSetItemId  
      FROM dbo.OrderSetItems WITH (UPDLOCK, HOLDLOCK)  
      WHERE IsDeleted = 0  
      )  
    )  
  BEGIN  
   THROW 50001  
    ,'One or more order items not found.'  
    ,1;  
  END  
  
  IF EXISTS (  
    SELECT 1  
    FROM dbo.OrderSetItems WITH (UPDLOCK, HOLDLOCK)  
    WHERE OrderSetItemId IN (  
      SELECT OrderSetItemId  
      FROM #OrderSetItemIds  
      )  
     AND ItemStatus = 3 -- Delivered  
     AND IsDeleted = 0  
    )  
  BEGIN  
   THROW 50002  
    ,'One or more order items have already been delivered.'  
    ,1;  
  END  
  
  WHILE @i <= @Cnt  
  BEGIN  
   SELECT @CurrentOrderSetItemId = OrderSetItemId  
    ,@CurrentOrderId = OrderId  
    ,@CurrentProductId = ProductId  
    ,@CurrentQuantity = Quantity  
   FROM #Candidates  
   WHERE Rn = @i;  
  
   SET @WarehouseDetailsJson = (  
     SELECT @OtherWarehouseId AS WarehouseId  
      ,@CurrentQuantity AS DeliverQuantity  
     FOR JSON PATH  
     );  
  
   TRUNCATE TABLE #ChildResult;  
  
   INSERT INTO #ChildResult  
   EXEC dbo.DeliverOrderSetItem @TenantId = @TenantId  
    ,@ProductId = @CurrentProductId  
    ,@OrderSetItemId = @CurrentOrderSetItemId  
    ,@OrderId = @CurrentOrderId  
    ,@UserId = @UserId  
    ,@WarehouseDetails = @WarehouseDetailsJson  
    ,@Comment = @Comment;  
  
   SELECT @ChildReturnCode = ReturnCode  
    ,@ChildReturnMessage = ReturnMessage  
   FROM #ChildResult;  
  
   IF @@TRANCOUNT = 0  
   BEGIN  
    SET @Aborted = 1;  
    SET @ReturnStatus = 0;  
    SET @ReturnMessage = 'OrderSetItemId ' + CAST(@CurrentOrderSetItemId AS VARCHAR(20)) + ': ' + @ChildReturnMessage;  
  
    BREAK;  
   END  
  
   IF @ChildReturnCode = 0  
   BEGIN  
    SET @Aborted = 1;  
    SET @ReturnStatus = 0;  
    SET @ReturnMessage = 'OrderSetItemId ' + CAST(@CurrentOrderSetItemId AS VARCHAR(20)) + ': ' + @ChildReturnMessage;  
  
    IF @@TRANCOUNT > 0  
     ROLLBACK TRAN;  
  
    BREAK;  
   END  
  
   SET @i = @i + 1;  
  END  
  
  IF @Aborted = 0  
  BEGIN  
   IF @@TRANCOUNT > 0  
    COMMIT TRAN;  
  
   SET @ReturnStatus = 1;  
   SET @ReturnMessage = 'All selected items have been delivered successfully.';  
  END  
 END TRY  
  
 BEGIN CATCH  
  IF @@TRANCOUNT > 0  
   ROLLBACK TRAN;  
  
  SET @ReturnStatus = 0;  
  SET @ReturnMessage = 'Batch delivery failed: ' + ERROR_MESSAGE();  
  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg VARCHAR(MAX)  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID)  
  SET @ErrorMsg = ERROR_MESSAGE()  
  
  -- Append TenantId and OrderId to the description saved in DBErrorLog  
  SET @ErrorMsg = @ErrorMsg + ' | TenantId: ' + ISNULL(CAST(@TenantId AS VARCHAR(20)), 'NULL')  
   + ' | OrderId: ' + ISNULL(CAST(@CurrentOrderId AS VARCHAR(20)), 'NULL')  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
 END CATCH  
  
 SELECT @ReturnStatus AS ReturnCode  
  ,@ReturnMessage AS PaymentReturnMessage  
  ,@ReturnMessage AS ProductQuantityReturnMessage  
  ,'' AS ProductUnavailableInWarehouseReturnMessage  
  ,@ProductUnavailableInWarehouseDetails AS ProductUnavailableInWarehouseDetails  
  ,@UnpaidOrderNos AS UnpaidOrderNos  
  ,@LowStockOrderNos AS LowStockOrderNos;  
END

GO

