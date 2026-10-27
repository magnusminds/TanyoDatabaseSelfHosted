/*  
EXEC MarkAsReadyToDelivered  
    @TenantId = 2  
    ,@UserId = 4279  
    ,@Comments = 'Ready for delivery'  
    ,@DeliveredList = '1001,1002,1003'  
*/  
CREATE PROCEDURE [dbo].[MarkAsReadyToDelivered] (  
 @TenantId BIGINT  
 ,@UserId BIGINT  
 ,@Comments VARCHAR(MAX) = NULL  
 ,@DeliveredList VARCHAR(MAX)  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  

 ------------------------------------------------------------  
  -- Validation  
  ------------------------------------------------------------  
  IF ISNULL(LTRIM(RTRIM(@DeliveredList)), '') = ''  
  BEGIN  
   SELECT CAST(0 AS BIT) AS Status  
    ,'Please select at least one product.' AS Message;  
  
   RETURN;  
  END  

  BEGIN TRAN MarkAsReadyToDelivered;  
  
  IF NOT EXISTS (  
      SELECT 1  
      FROM STRING_SPLIT(@DeliveredList, ',') s  
      WHERE TRY_CAST(s.value AS BIGINT) IN (  
          SELECT OrderSetItemId   
          FROM dbo.OrderSetItems WITH (UPDLOCK, HOLDLOCK)  
          WHERE IsDeleted = 0  
      )  
  )  
  BEGIN  
      THROW 50001, 'One or more order items not found.', 1;  
  END  
  
  -- 2. Check if already Ready To Deliver (2)  
  IF EXISTS (  
    SELECT 1  
    FROM dbo.OrderSetItems WITH (UPDLOCK, HOLDLOCK)  
    WHERE OrderSetItemId IN (  
      SELECT TRY_CAST(value AS BIGINT)  
      FROM STRING_SPLIT(@DeliveredList, ',')  
      )  
     AND ItemStatus = 2  
     AND IsDeleted = 0  
    )  
  BEGIN  
   THROW 50002  
    ,'One or more order items are already marked as Ready To Deliver.'  
    ,1;  
  END  
  
  
  
  ------------------------------------------------------------  
  -- Subject Type  
  ------------------------------------------------------------  
  DECLARE @OrderSubjectTypeId INT;  
  DECLARE @DT DATETIMEOFFSET = SYSDATETIMEOFFSET();  
  DECLARE @DTUTC DATETIME = GETUTCDATE();  
  
  SELECT @OrderSubjectTypeId = SubjectTypeId  
  FROM SubjectTypes WITH (NOLOCK)  
  WHERE TenantId = @TenantId  
   AND SubjectTypeName = 'Orders';  
  
  ------------------------------------------------------------  
  -- Temp Table  
  ------------------------------------------------------------  
  CREATE TABLE #OrderSetItems (OrderSetItemId BIGINT PRIMARY KEY);  
  
  INSERT INTO #OrderSetItems (OrderSetItemId)  
  SELECT DISTINCT TRY_CAST(value AS BIGINT)  
  FROM STRING_SPLIT(@DeliveredList, ',')  
  WHERE TRY_CAST(value AS BIGINT) IS NOT NULL;  
  
  ------------------------------------------------------------  
  -- Update OrderSetItems  
  ------------------------------------------------------------  
  UPDATE OSI  
  SET DeliveryComment = @Comments  
   ,ItemStatus = 2 -- ReadyToDelivered  
   ,ReadyToDeliveredDate = CAST(GETDATE() AS DATE)  
   ,DeliveryDate = GETDATE()  
   ,UpdatedBy = @UserId  
   ,UpdatedDate = SYSDATETIMEOFFSET()  
   ,UpdatedUTCDate = GETUTCDATE()  
  FROM OrderSetItems OSI WITH (NOLOCK)  
  INNER JOIN #OrderSetItems T ON T.OrderSetItemId = OSI.OrderSetItemId;  
  
  ------------------------------------------------------------  
  -- Update Manufacturing Workflows  
  ------------------------------------------------------------  
  UPDATE OMW  
  SET CompletionDate = GETDATE()  
   ,ManufacturingStatus = 2 -- Completed  
   ,UpdatedBy = @UserId  
   ,UpdatedDate = SYSDATETIMEOFFSET()  
   ,UpdatedUTCDate = GETUTCDATE()  
  FROM OrderManufacturingWorkflows OMW WITH (NOLOCK)  
  INNER JOIN #OrderSetItems T ON T.OrderSetItemId = OMW.OrderSetItemId;  
  
  ------------------------------------------------------------  
  -- Manufacturing Activity Log  
  -- Manufacturing Order has been completed by contractor  
  ------------------------------------------------------------  
  INSERT INTO ManufacturingActivityLogs (  
   OrderManufacturingWorkflowId  
   ,Description  
   ,Action  
   ,ManufacturingWorkflowId  
   ,ProductId  
   ,CreatedBy  
   ,CreatedDate  
   ,CreatedUTCDate  
   )  
  SELECT OMW.OrderManufacturingWorkflowId  
   ,'Manufacturing Order has been completed by ' + ISNULL(AU.FirstName + ' ' + AU.LastName, '') + ' contractor for ' + ISNULL(MW.WorkflowName, '') + '.'  
   ,'COMPLETED'  
   ,OMW.ManufacturingWorkflowId  
   ,OSI.SubjectId  
   ,@UserId  
   ,SYSDATETIMEOFFSET()  
   ,GETUTCDATE()  
  FROM OrderManufacturingWorkflows OMW WITH (NOLOCK)  
  INNER JOIN #OrderSetItems T ON T.OrderSetItemId = OMW.OrderSetItemId  
  INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = OMW.OrderSetItemId  
  LEFT JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = OMW.ContractorUserID  
  LEFT JOIN ManufacturingWorkflows MW WITH (NOLOCK) ON MW.ManufacturingWorkflowId = OMW.ManufacturingWorkflowId;  
  
  ------------------------------------------------------------  
  -- Ready To Deliver Manufacturing Log  
  -- SAME AS LINQ  
  -- Insert only when all workflows completed  
  ------------------------------------------------------------  
  INSERT INTO ManufacturingActivityLogs (  
   OrderManufacturingWorkflowId  
   ,Description  
   ,Action  
   ,ManufacturingWorkflowId  
   ,ProductId  
   ,CreatedBy  
   ,CreatedDate  
   ,CreatedUTCDate  
   )  
  SELECT OMW.OrderManufacturingWorkflowId  
   ,'Manufacturing Order has been Ready to deliver.'  
   ,'UPDATE'  
   ,OMW.ManufacturingWorkflowId  
   ,OSI.SubjectId  
   ,@UserId  
   ,SYSDATETIMEOFFSET()  
   ,GETUTCDATE()  
  FROM OrderManufacturingWorkflows OMW WITH (NOLOCK)  
  INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = OMW.OrderSetItemId  
  INNER JOIN #OrderSetItems T ON T.OrderSetItemId = OMW.OrderSetItemId  
  INNER JOIN (  
   SELECT OrderId  
    ,OrderSetItemId  
   FROM OrderManufacturingWorkflows WITH (NOLOCK)  
   GROUP BY OrderId  
    ,OrderSetItemId  
   HAVING COUNT(*) = SUM(CASE   
      WHEN ManufacturingStatus = 2  
       THEN 1  
      ELSE 0  
      END)  
   ) C ON C.OrderId = OMW.OrderId  
   AND C.OrderSetItemId = OMW.OrderSetItemId;  
  
  ------------------------------------------------------------  
  -- Order Activity Logs  
  ------------------------------------------------------------  
  DECLARE @Inc INT = 1;  
  DECLARE @Cnt INT;  
  DECLARE @SubjectId BIGINT;  
  DECLARE @Description VARCHAR(MAX);  
  
  CREATE TABLE #ActivityLogData (  
   RowId INT IDENTITY(1, 1)  
   ,SubjectId BIGINT  
   ,Description VARCHAR(MAX)  
   );  
  
  INSERT INTO #ActivityLogData (  
   SubjectId  
   ,Description  
   )  
  SELECT OSI.OrderId  
   ,'Product ' + ISNULL(P.ProductTitle, '') + ' has been Ready to deliver.'  
  FROM OrderSetItems OSI WITH (NOLOCK)  
  INNER JOIN #OrderSetItems T ON T.OrderSetItemId = OSI.OrderSetItemId  
  INNER JOIN Products P WITH (NOLOCK) ON P.ProductId = OSI.SubjectId;  
  
  SELECT @Cnt = COUNT(1)  
  FROM #ActivityLogData;  
  
  WHILE @Cnt >= @Inc  
  BEGIN  
   SELECT @SubjectId = SubjectId  
    ,@Description = Description  
   FROM #ActivityLogData  
   WHERE RowId = @Inc;  
  
   EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId  
    ,@SubjectId = @SubjectId  
    ,@Description = @Description  
    ,@Action = 'UPDATE'  
    ,@CreatedBy = @UserId  
    ,@CreatedDate = @DT  
    ,@CreatedUTCDate = @DTUTC;  
  
   SET @Inc = @Inc + 1;  
  END;  
  
  DROP TABLE #ActivityLogData;  
  
  ------------------------------------------------------------  
  -- Update Vendor PO Item Status  
  ------------------------------------------------------------  
  UPDATE POI  
  SET POI.Status = 5 -- MaterialReady  
   ,POI.POItemMaterialReadyDate = GETDATE()  
  FROM POProductItems POI WITH (NOLOCK)  
  INNER JOIN #OrderSetItems T ON T.OrderSetItemId = POI.VendorOrderSetItemId;  
  
  ------------------------------------------------------------  
  -- Update PO Header Status  
  -- If all PO Items are MaterialReady & Completed  
  ------------------------------------------------------------  
  UPDATE PO  
  SET PO.Status = 5  
   ,PO.POMaterialReadyDate = GETDATE()  
   ,PO.UpdatedBy = @UserId  
   ,PO.UpdatedDate = SYSDATETIMEOFFSET()  
   ,PO.UpdatedUTCDate = GETUTCDATE()  
  FROM POProducts PO WITH (NOLOCK)  
  WHERE EXISTS (  
    SELECT 1  
    FROM POProductItems POI WITH (NOLOCK)  
    INNER JOIN #OrderSetItems T ON T.OrderSetItemId = POI.VendorOrderSetItemId  
    WHERE POI.POProductId = PO.POProductId  
    )  
   AND NOT EXISTS (  
    SELECT 1  
    FROM POProductItems POI WITH (NOLOCK)  
    WHERE POI.POProductId = PO.POProductId  
     AND ISNULL(POI.Status, 0) NOT IN (  
      4  
      ,5  
      )  
    );  
  
  ------------------------------------------------------------  
  -- Success  
  ------------------------------------------------------------  
  COMMIT TRAN MarkAsReadyToDelivered;  
  
  SELECT CAST(1 AS BIT) AS Status  
   ,'Products marked as Ready To Deliver successfully.' AS Message;  
 END TRY  
  
 BEGIN CATCH  
  IF @@TRANCOUNT > 0  
   ROLLBACK TRAN MarkAsReadyToDelivered;  
  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg VARCHAR(MAX)  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID)  
  SET @ErrorMsg = ERROR_MESSAGE()  
  
  -- Append TenantId and OrderId(s) to the description saved in DBErrorLog  
  DECLARE @ErrOrderIds VARCHAR(MAX);  
  
  SELECT @ErrOrderIds = STRING_AGG(CAST(X.OrderId AS VARCHAR(20)), ',')  
  FROM (  
   SELECT DISTINCT OSI.OrderId  
   FROM dbo.OrderSetItems OSI WITH (NOLOCK)  
   WHERE OSI.OrderSetItemId IN (  
     SELECT TRY_CAST(value AS BIGINT)  
     FROM STRING_SPLIT(@DeliveredList, ',')  
     )  
   ) X;  
  
  SET @ErrorMsg = @ErrorMsg + ' | TenantId: ' + ISNULL(CAST(@TenantId AS VARCHAR(20)), 'NULL')  
   + ' | OrderId: ' + ISNULL(@ErrOrderIds, 'NULL');  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg  
  
  SELECT CAST(0 AS BIT) AS Status  
   ,ERROR_MESSAGE() AS Message;  
 END CATCH  
END

GO

