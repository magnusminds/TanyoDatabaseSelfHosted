
/*  
    EXEC [dbo].[DeleteOrder]  
        @OrderId = '84',  
        @DeletedBy = 1,  
        @ResultMessage = '' OUTPUT  
  
    Multiple Orders:  
    EXEC [dbo].[DeleteOrder]  
        @OrderId = '84,85,86',  
        @DeletedBy = 1,  
        @ResultMessage = '' OUTPUT  
*/  
CREATE PROCEDURE [dbo].[DeleteOrder_V2] (  
 @OrderId VARCHAR(MAX)  
 ,@DeletedBy BIGINT  
 ,@ResultMessage VARCHAR(MAX) = '' OUTPUT  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 DECLARE @Status BIT = 0  
  ,@Message VARCHAR(200)  
  ,@Error VARCHAR(MAX)  
  ,@ErrorMsg VARCHAR(MAX)  
  ,@ObjectName VARCHAR(500)  
  ,@IncOrderId BIGINT  
  ,@OrderSetId BIGINT  
  ,@TenantId INT  
  ,@OrderIndex INT = 1  
  ,@OrderCount INT  
  ,@OrderSetIndex INT  
  ,@OrderSetCount INT  
  ,@dtoffset DATETIMEOFFSET = SYSDATETIMEOFFSET()  
  ,@dtutc DATETIME = GETUTCDATE();  
  
 BEGIN TRY  
  /*==============================================================  
            1. Prepare Order List  
        ==============================================================*/  
  DROP TABLE IF EXISTS #DelOrder;  
  DROP TABLE IF EXISTS #OrderList;  
  
   SELECT DISTINCT TRY_CAST(TRIM(ORD.value) AS BIGINT) AS OrderId  
   INTO #DelOrder  
   FROM STRING_SPLIT(TRIM(@OrderId), ',') ORD  
   WHERE TRY_CAST(TRIM(ORD.value) AS BIGINT) IS NOT NULL;  
  
  /*==============================================================  
            2. Get Orders  
        ==============================================================*/  
  SELECT ROW_NUMBER() OVER (  
    ORDER BY ORD.OrderId  
    ) AS ID  
   ,ORD.OrderId  
   ,ORD.OrderNo  
   ,ORD.TenantId  
   ,ORD.Status  
  INTO #OrderList  
  FROM dbo.Orders ORD  
  INNER JOIN #DelOrder DORD ON DORD.OrderId = ORD.OrderId;  
  
  SELECT @OrderCount = COUNT(1)  
  FROM #OrderList;  
  
  IF NOT EXISTS (  
    SELECT 1  
    FROM #DelOrder  
    WHERE OrderId NOT IN (  
      SELECT OrderId  
      FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK)  
      WHERE TenantId = @TenantId  
      )  
    )  
  BEGIN  
   THROW 50001  
    ,'One or more orders not found.'  
    ,1;  
  END  
  
  IF EXISTS (  
    SELECT 1  
    FROM dbo.Orders WITH (UPDLOCK, HOLDLOCK)  
    WHERE OrderId IN (SELECT OrderId FROM #DelOrder)  
     AND Status = 9  
     AND TenantId = @TenantId  
    )  
  BEGIN  
   THROW 50002  
    ,'One or more orders have already been deleted.'  
    ,1;  
  END  
  
  BEGIN TRANSACTION DeleteOrderV2;  
  
  /*==============================================================  
            3. Process Each Order  
        ==============================================================*/  
  WHILE @OrderIndex <= @OrderCount  
  BEGIN  
   SELECT @IncOrderId = OrderId  
    ,@TenantId = TenantId  
   FROM #OrderList  
   WHERE ID = @OrderIndex;  
  
   DROP TABLE IF EXISTS #OrderSetList;  
  
    SELECT ROW_NUMBER() OVER (  
      ORDER BY OS.OrderSetId  
      ) AS ID  
     ,OS.OrderSetId  
    INTO #OrderSetList  
    FROM dbo.OrderSets OS  
    WHERE OS.OrderId = @IncOrderId  
     AND OS.IsDeleted = 0;  
  
   SELECT @OrderSetCount = COUNT(1)  
   FROM #OrderSetList;  
  
   SET @OrderSetIndex = 1;  
  
   WHILE @OrderSetIndex <= @OrderSetCount  
   BEGIN  
    SELECT @OrderSetId = OrderSetId  
    FROM #OrderSetList  
    WHERE ID = @OrderSetIndex;  
  
    EXEC dbo.DeleteOrderSet_V2 @OrderSetId = @OrderSetId  
     ,@DeletedBy = @DeletedBy  
     ,@TenantId = @TenantId  
     ,@ResultMessage = @ResultMessage OUTPUT;  
  
    IF @ResultMessage <> ''  
    BEGIN  
     RAISERROR (  
       '%s'  
       ,16  
       ,1  
       ,@ResultMessage  
       )  
  
     RETURN  
    END  
  
    SET @OrderSetIndex = @OrderSetIndex + 1;  
   END;  
  
   /*----------------------------------------------------------  
                Mark Order Comments as deleted  
            ----------------------------------------------------------*/  
   UPDATE OC  
   SET OC.Status = 9  
   FROM dbo.OrderComments OC  
   WHERE OC.OrderId = @IncOrderId;  
  
   /*----------------------------------------------------------  
                Mark Payments as deleted  
            ----------------------------------------------------------*/  
   UPDATE PTS  
   SET PTS.IsDeleted = 1  
    ,PTS.UpdatedBy = @DeletedBy  
    ,PTS.UpdatedDate = GETDATE()  
    ,PTS.UpdatedUTCDate = GETUTCDATE()  
   FROM dbo.Payments PTS  
   WHERE PTS.OrderId = @IncOrderId;  
  
   /*----------------------------------------------------------  
                Mark Order as deleted  
            ----------------------------------------------------------*/  
   UPDATE ORD  
   SET ORD.Status = 9  
    ,ORD.UpdatedBy = @DeletedBy  
    ,ORD.UpdatedDate = GETDATE()  
    ,ORD.UpdatedUTCDate = GETUTCDATE()  
   FROM dbo.Orders ORD  
   WHERE ORD.OrderId = @IncOrderId;  
  
   /*----------------------------------------------------------  
                Next Order  
            ----------------------------------------------------------*/  
   SET @OrderIndex = @OrderIndex + 1;  
  END;  
  
  /*==============================================================  
            6. Success Response  
        ==============================================================*/  
  SET @Status = 1;  
  SET @ResultMessage = '';  
  SET @Error = NULL;  
  
  COMMIT TRANSACTION DeleteOrderV2;  
 END TRY  
  
 BEGIN CATCH  
  IF XACT_State() > 0  
   ROLLBACK TRANSACTION  
  
  IF @ResultMessage IS NULL  
   OR @ResultMessage = ''  
  BEGIN  
   DECLARE @ErrorMessage VARCHAR(MAX);  
  
   SET @ErrorMessage = ERROR_MESSAGE();  
   SET @ResultMessage = 'Error in DeleteOrder_V2: ' + @ErrorMessage;  
  END  
 END CATCH  
END

GO

