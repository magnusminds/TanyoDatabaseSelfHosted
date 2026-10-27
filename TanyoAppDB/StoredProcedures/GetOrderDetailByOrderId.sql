/*  
 EXEC GetOrderDetailByOrderId  
  @TenantId = 1207  
  ,@OrderId = 260985  
*/
CREATE PROCEDURE [dbo].[GetOrderDetailByOrderId] (  
 @TenantId INT  
 ,@OrderId BIGINT  
 )  
WITH ENCRYPTION
AS
BEGIN  
 BEGIN TRY  
  DECLARE @ProductSubjectTypeId INT  
   ,@FabricSubjectTypeId INT  
   ,@PolishSubjectTypeId INT  
   ,@ReceivedAmount NUMERIC(18, 2)  
   ,@InteriorCommission VARCHAR(10)  
   ,@TotalSetAmount NUMERIC(18, 2)  
   ,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()  
   ,@InteriorCommissionPer NUMERIC(18, 2)  
  
  SELECT @ReceivedAmount = Round(SUM(ISNULL(ReceivedAmount, 0)), 0)  
  FROM Payments WITH (NOLOCK)  
  WHERE OrderId = @OrderId  
   AND TenantId = @TenantId  
   AND IsDeleted = 0  
   AND PaymentStatus = 1 -- Approved  
  
  SELECT @InteriorCommissionPer = COALESCE(
        NULLIF(ORD.INTERIORCOMMISSIONPER, 0),
        0
    )
    FROM Orders ORD WITH (NOLOCK)
    WHERE ORD.OrderId = @OrderId
        AND ORD.TenantId = @TenantId;
  
  IF (  
    @InteriorCommissionPer >= 1  
    AND @InteriorCommissionPer <= 5  
    )  
   SET @InteriorCommission = '#0d0df2';  
  ELSE IF (  
    @InteriorCommissionPer > 5  
    AND @InteriorCommissionPer <= 15  
    )  
   SET @InteriorCommission = '#ad7000';  
  ELSE IF (@InteriorCommissionPer > 15)  
   SET @InteriorCommission = '#cd0303';  
  
  --SELECT @TotalSetAmount = SUM(ISNULL(TotalAmount, 0))  
  --FROM OrderSetItems WITH (NOLOCK)  
  --WHERE OrderId = @OrderId  
  -- AND IsDeleted = 0  
  --GROUP BY OrderSetId  
  SELECT ORD.OrderId  
   ,ORD.OrderNo  
   ,ORD.Status AS [Status]  
   ,ORD.CreatedDate  
   ,CONCAT (  
    AU.FirstName  
    ,' '  
    ,AU.LastName  
    ) AS SalesmanName  
   ,AU.PhoneNumber AS SalesmanNamePhoneNumber  
   ,ORD.UpdatedDate AS InquiryLastUpdatedDate  
   --,encryptedOrderNo  
   ,ORD.CustomerID  
   ,@InteriorCommission AS InteriorCommision  
   ,ORD.GrossTotal  
   ,ORD.Discount AS TotalLineItemDiscount  
   ,ORD.TotalAmount AS OrderAmount  
   ,ORD.AmountBeforeGST AS ProductAmount  
   ,ORD.CGSTAmount  
   ,ORD.SGSTAmount  
   ,ORD.DeliveryCharges  
   ,ISNULL(@ReceivedAmount, 0) AS AdvanceAmount -- ORD.AdvanceAmount  -- From payments?  
   ,(ROUND(ISNULL(ORD.TotalAmt, 0), 0) + ISNULL(ORD.KasarAmount, 0) - (ISNULL(ROUND(ORD.AmountBeforeGST, 0), 0) + ISNULL(ROUND(ORD.CGSTAmount, 0), 0) + ISNULL(ROUND(ORD.SGSTAmount, 0), 0))) AS RoundOff  
   ,ORD.TotalAmount - ISNULL(ORD.KasarAmount, 0) - ISNULL(@ReceivedAmount, 0) AS PayableAmount  
   ,ORD.DeliveryDate  
   ,ORD.TentativeDeliveryDate  
   ,ORD.Comments  
   ,ORD.GSTType  
   ,ORD.OfferDiscount AS OfferAmount -- From offer Table  
   --,ORD.REMARKS  
   ,ORD.IsFreeDelivery  
   --,VoiceRecord  
   ,ORD.ApprovedDate  
   ,T.IsAutoManufacture AS IsAutoManufacture  
   --,newOrderStatusLabelName  
   ,ISNULL(ORD.LumpsumDiscount, 0) AS LumpsumDiscount  
   ,ISNULL(ORD.DeliveryAmount, 0) AS DeliveryAmount  
   ,ORD.DeliveryAmountCollectionType  
   ,ORD.DeliveryCharge  
   ,ORD.SalesmanId AS SalesmanId -- ID Or Name  
   ,ORD.LocationID --ID Or Name  
   ,ORD.IsPinned  
   ,ORD.IsFlagged  
   ,ORD.IsArchive  
   ,ORD.SpecialDiscount  
   ,CONCAT (  
    C.FirstName  
    ,' '  
    ,ISNULL(C.LastName, '')  
    ) AS CustomerFullName  
   ,C.PhoneNumber AS CustomerPhoneNumber  
   ,ORD.OrderType  
   ,ORD.TotalAmt AS TotalAmount  
   ,ROUND((ISNULL(ORD.AmountBeforeGST, 0) + ISNULL(ORD.CGSTAmount, 0) + ISNULL(ORD.SGSTAmount, 0)) - (ROUND(ISNULL(@ReceivedAmount, 0), 0) + ISNULL(ORD.OfferDiscount, 0)) + (  
     CASE   
      WHEN (ORD.DeliveryAmountCollectionType = 2) -- Cash  
       OR (ORD.DeliveryCharge <> 3) -- ExtraWithAmount  
       THEN 0  
      ELSE ISNULL(ORD.DeliveryAmount, 0)  
      END  
     ) - ISNULL(ORD.LumpsumDiscount, 0) - ISNULL(ORD.KasarAmount, 0), 0) AS TotalPayableAmount  
   ,AU.IsDeleted AS IsSalesmanDeleted  
   ,ORD.RefferedBy
   ,ORD.KasarAmount
  FROM Orders ORD WITH (NOLOCK)  
  INNER JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = ORD.SalesmanId  
  INNER JOIN Customers C WITH (NOLOCK) ON C.CustomerId = ORD.CustomerID  
  INNER JOIN Tenants T WITH (NOLOCK) ON ORD.TenantId = T.TenantId  
  WHERE ORD.OrderId = @OrderId  
   AND ORD.TenantId = @TenantId  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg NVARCHAR(4000);  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID);  
  SET @ErrorMsg = ERROR_MESSAGE();  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
 END CATCH  
END

GO

