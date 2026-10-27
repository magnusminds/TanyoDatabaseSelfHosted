-- =============================================  
-- Author  : MagnusMinds  
-- Ref   : Kasar field on Order (Review Order page)  
-- Create date : 2026-Oct-13  
-- Description : Add / Update / Remove Kasar amount applied on the Total Order Amount.  
--      Validates tenant flag (TenantConfigurations.IsKasarEnabled), order stage,  
--      value range, updates Orders.KasarAmount and writes the ActivityLogs entry.  
-- Prerequisites:  
--      1) dbo.Orders.KasarAmount column exists (see ..\Schema\AddKasarAmountToOrders.sql)  
--      2) dbo.Orders.TotalAmt computed column subtracts ISNULL(KasarAmount, 0)  
--      3) dbo.TenantConfigurations.IsKasarEnabled column exists  
-- =============================================  
/*  
 EXEC [dbo].[UpdateOrderKasar]  
  @OrderId = 271505  
  ,@TenantId = 1207  
  ,@UserId = 13307  
  ,@KasarAmount = 12  
*/  
CREATE PROCEDURE [dbo].[UpdateOrderKasar] (  
 @OrderId BIGINT  
 ,@TenantId INT  
 ,@UserId INT  
 ,@KasarAmount DECIMAL(18, 2)  
 ,@ReturnMessage VARCHAR(500) = '' OUTPUT  
 ,@Status BIT = 0 OUTPUT  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @OrderNo VARCHAR(50)  
   ,@OrderStatus INT  
   ,@OldKasarAmount DECIMAL(18, 2) = 0  
   ,@TotalAmt DECIMAL(18, 2) = 0  
   ,@MaxKasarAmount DECIMAL(18, 2) = 0  
   ,@IsKasarEnabled BIT = 0  
   ,@OrderSubjectTypeId INT  
   ,@ActivityDescription NVARCHAR(500)  
   ,@ActivityAction VARCHAR(20)  
   ,@DateUtc DATETIME = GETUTCDATE()  
   ,@DateOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()  
  
  -- Order must belong to the tenant  
  SELECT @OrderNo = OrderNo  
   ,@OrderStatus = Status  
   ,@OldKasarAmount = ISNULL(KasarAmount, 0)  
   ,@TotalAmt = ISNULL(TotalAmt, 0)  
  FROM Orders WITH (NOLOCK)  
  WHERE OrderId = @OrderId  
   AND TenantId = @TenantId;  
  
  IF @OrderNo IS NULL  
  BEGIN  
   SET @Status = 0  
   SET @ReturnMessage = 'Order not found.';  
  
   SELECT @Status AS [Status]  
    ,@ReturnMessage AS [Message]  
  
   RETURN;  
  END  
  
  -- Tenant level Kasar flag (managed from BackOffice / DB only)  
  SELECT @IsKasarEnabled = ISNULL(IsKasarEnabled, 0)  
  FROM TenantConfigurations WITH (NOLOCK)  
  WHERE TenantId = @TenantId;  
  
  IF ISNULL(@IsKasarEnabled, 0) = 0  
  BEGIN  
   SET @Status = 0  
   SET @ReturnMessage = 'Kasar is not enabled for this tenant.';  
  
   SELECT @Status AS [Status]  
    ,@ReturnMessage AS [Message]  
  
   RETURN;  
  END  
  
  -- Allowed from Approved stage onwards, except Delivered  
  -- Approved = 2, InProgress = 3, Completed = 4, MaterialReceive = 7  
  IF @OrderStatus NOT IN (  
    2  
    ,3  
    ,4  
    ,7  
    )  
  BEGIN  
   SET @Status = 0  
   SET @ReturnMessage = 'Kasar can be applied from Approved stage only and cannot be updated once order is Delivered.';  
  
   SELECT @Status AS [Status]  
    ,@ReturnMessage AS [Message]  
  
   RETURN;  
  END  
  
  IF @KasarAmount < 0  
   OR @KasarAmount > 999999999999  
  BEGIN  
   SET @Status = 0  
   SET @ReturnMessage = 'Invalid kasar amount.';  
  
   SELECT @Status AS [Status]  
    ,@ReturnMessage AS [Message]  
  
   RETURN;  
  END  
  
  -- TotalAmt is already net of the applied Kasar, so base total = TotalAmt + OldKasarAmount  
  SET @MaxKasarAmount = ROUND(@TotalAmt + @OldKasarAmount, 0);  
  
  IF @KasarAmount > @MaxKasarAmount  
  BEGIN  
   SET @Status = 0  
   SET @ReturnMessage = 'Kasar amount cannot exceed the Total Order Amount.';  
  
   SELECT @Status AS [Status]  
    ,@ReturnMessage AS [Message]  
  
   RETURN;  
  END  
  
  BEGIN TRANSACTION UpdateOrderKasar;  
  
  UPDATE Orders  
  SET KasarAmount = @KasarAmount  
   ,UpdatedBy = @UserId  
   ,UpdatedDate = @DateOffset  
   ,UpdatedUTCDate = @DateUtc  
  WHERE OrderId = @OrderId  
   AND TenantId = @TenantId;  
  
  -- Activity log : apply / update / remove  
  IF @OldKasarAmount <> @KasarAmount  
  BEGIN  
   SELECT @OrderSubjectTypeId = SubjectTypeId  
   FROM SubjectTypes WITH (NOLOCK)  
   WHERE SubjectTypeName = 'Orders'  
    AND TenantId = @TenantId  
    AND IsDeleted = 0;  
  
   IF @OldKasarAmount = 0  
   BEGIN  
    SET @ActivityDescription = 'Kasar amount ' + CAST(@KasarAmount AS NVARCHAR(50)) + ' has been applied for Inquiry ' + CAST(@OrderNo AS NVARCHAR(50)) + '.';  
    SET @ActivityAction = 'CREATE';  
   END  
   ELSE IF @KasarAmount = 0  
   BEGIN  
    SET @ActivityDescription = 'Kasar amount ' + CAST(@OldKasarAmount AS NVARCHAR(50)) + ' has been removed for Inquiry ' + CAST(@OrderNo AS NVARCHAR(50)) + '.';  
    SET @ActivityAction = 'DELETE';  
   END  
   ELSE  
   BEGIN  
    SET @ActivityDescription = 'Kasar amount updated from ' + CAST(@OldKasarAmount AS NVARCHAR(50)) + ' to ' + CAST(@KasarAmount AS NVARCHAR(50)) + ' for Inquiry ' + CAST(@OrderNo AS NVARCHAR(50)) + '.';  
    SET @ActivityAction = 'UPDATE';  
   END  
  
   EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId  
    ,@SubjectId = @OrderId  
    ,@Description = @ActivityDescription  
    ,@Action = @ActivityAction  
    ,@CreatedBy = @UserId  
    ,@CreatedDate = @DateOffset  
    ,@CreatedUTCDate = @DateUtc;  
  END  
  
  COMMIT TRANSACTION UpdateOrderKasar;  
  
  SET @Status = 1;  
  SET @ReturnMessage = 'success';  
  
  SELECT @Status AS [Status]  
   ,@ReturnMessage AS [Message]  
 END TRY  
  
 BEGIN CATCH  
  IF @@TRANCOUNT > 0  
   ROLLBACK TRANSACTION UpdateOrderKasar;  
  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg VARCHAR(MAX);  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID);  
  SET @ErrorMsg = ERROR_MESSAGE();  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
  
  SET @Status = 0;  
  SET @ReturnMessage = @ErrorMsg;  
  
  SELECT @Status AS [Status]  
   ,@ReturnMessage AS [Message]  
 END CATCH  
END;

GO

