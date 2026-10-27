CREATE PROCEDURE [dbo].[SplitSaveOrder] (  
 @OrderID BIGINT  
 ,@OrderType VARCHAR(1)  
 ,@TenantID BIGINT  
 ,@UserID BIGINT  
 ,@RefreshInquiry BIT  
 ,@JsonObject NVARCHAR(MAX)  
 ,@LocationID BIGINT = NULL  
 ,@isFromBackOrder BIT = NULL  
 ,@ReturnOrderID BIGINT = 0 OUTPUT  
 ,@ReturnStatus BIT = 0 OUTPUT  
 ,@ReturnMessage VARCHAR(100) = NULL OUTPUT  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @NewOrderID BIGINT  
   ,@OrderNo VARCHAR(50)  
   ,@GSTType BIT  
   ,@InquiryExpirationDays INT  
   ,@TentativeDeliveryDate DATE  
   ,@CustomerID BIGINT  
   ,@Comment NVARCHAR(MAX)  
   ,@Remarks NVARCHAR(MAX)  
   ,@BillingAddressID BIGINT  
   ,@ShippingAddressID BIGINT  
   ,@OrderAddressId BIGINT  
   ,@IsFreeDelivery BIT  
   ,@ProductSubjectTypeId BIGINT  
   ,@FabricSubjectTypeId BIGINT  
   ,@PolishSubjectTypeId BIGINT  
   ,@OrderSubjectTypeId BIGINT  
   ,@LabourSubjectTypeId BIGINT  
   ,@RawMaterialSubjectTypeId BIGINT  
   ,@Date DATETIME = GETDATE()  
   ,@DateUtc DATETIME = GETUTCDATE()  
   ,@DateOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()  
   ,@ReferedByID BIGINT  
   ,@LumpsumDiscount NUMERIC(18, 2)  
   ,@DeliveryCharge SMALLINT  
   ,@DeliveryAmount NUMERIC(9, 2)  
   ,@DeliveryAmountCollectionType INT  
   ,@InteriorCommissionPer NUMERIC(5, 2)  
   ,@SalesmanCommissionPer NUMERIC(5, 2)  
   ,@CustomerDefaultAddressId BIGINT  
  DECLARE @cntSets BIGINT  
   ,@incSets BIGINT = 1  
   ,@cntSetItems BIGINT  
   ,@incSetItems BIGINT = 1  
   ,@cntSetItemAddOns BIGINT  
   ,@incSetItemAddOns BIGINT = 1  
  DECLARE @NewOrderSetId BIGINT  
   ,@OrderSetId BIGINT  
   ,@OrderSetName VARCHAR(MAX)  
   ,@OrderSetGroupID BIGINT  
   ,@NewOrderSetItemId BIGINT  
   ,@OrderSetItemId BIGINT  
   ,@OrderSetItemGroupId BIGINT  
   ,@NewOrderSetItemAddOnId BIGINT  
   ,@OrderSetItemAddOnId BIGINT  
   ,@DefaultProductVendorId BIGINT  
  
  SELECT @CustomerId = CustomerId  
   ,@BillingAddressID = BillingAddressID  
   ,@ShippingAddressID = ShippingAddressID  
   ,@TentativeDeliveryDate = TentativeDeliveryDate  
   ,@IsFreeDelivery = IsFreeDelivery  
   ,@LumpsumDiscount = LumpsumDiscount  
   ,@DeliveryCharge = DeliveryCharge  
   ,@DeliveryAmount = DeliveryAmount  
   ,@DeliveryAmountCollectionType = DeliveryAmountCollectionType  
   ,@Comment = Comments  
   ,@Remarks = Remarks  
  FROM OPENJSON(@JsonObject) WITH (  
    OrderId NVARCHAR(MAX) '$.OrderId'  
    ,CustomerId NVARCHAR(MAX) '$.CustomerID'  
    ,BillingAddressID NVARCHAR(MAX) '$.BillingAddressID'  
    ,ShippingAddressID NVARCHAR(MAX) '$.ShippingAddressID'  
    ,GrossTotal NVARCHAR(MAX) '$.GrossTotal'  
    ,Discount NVARCHAR(MAX) '$.Discount'  
    ,TotalAmount NVARCHAR(MAX) '$.TotalAmount'  
    ,GstTaxAmount NVARCHAR(MAX) '$.GSTTaxAmount'  
    ,DeliveryCharges NVARCHAR(MAX) '$.DeliveryCharges'  
    ,IsFreeDelivery NVARCHAR(MAX) '$.IsFreeDelivery'  
    ,TentativeDeliveryDate NVARCHAR(MAX) '$.TentativeDeliveryDate'  
    ,Comments NVARCHAR(MAX) '$.Comments'  
    ,Remarks NVARCHAR(MAX) '$.Remarks'  
    ,GSTType NVARCHAR(MAX) '$.GSTType'  
    ,LumpsumDiscount NUMERIC(18, 2) '$.LumpsumDiscount'  
    ,DeliveryCharge NVARCHAR(MAX) '$.DeliveryCharge'  
    ,DeliveryAmount NUMERIC(18, 2) '$.DeliveryAmount'  
    ,DeliveryAmountCollectionType NVARCHAR(MAX) '$.DeliveryAmountCollectionType'  
    )  
  
  DECLARE @UserHashId NVARCHAR(900)  
   ,@RoleId NVARCHAR(900)  
  
  SELECT @UserHashId = Id  
  FROM AspNetUsers WITH (NOLOCK)  
  WHERE UserId = @UserId  
   AND IsDeleted = 0  
  
  SELECT @RoleId = RoleId  
  FROM AspNetUserRoles WITH (NOLOCK)  
  WHERE USERID = @UserHashId  
  
  SELECT @ReferedByID = RefferedBy  
  FROM Customers WITH (NOLOCK)  
  WHERE CustomerId = @CustomerId  
  
  SELECT @InteriorCommissionPer = COALESCE(NULLIF(c.InteriorCommissionPer, 0), t.ArchitectDiscount, 0)  
  FROM Customers c WITH (NOLOCK)  
  INNER JOIN Tenants t WITH (NOLOCK) ON t.TenantId = c.TenantId  
  WHERE c.CustomerId = @ReferedByID  
   AND c.CustomerTypeId = 2  
  
  SELECT @SalesmanCommissionPer = asp.CommissionPer  
  FROM dbo.AspNetUsers AS asp WITH (NOLOCK)  
  WHERE UserId = @UserID  
  
  SELECT @InquiryExpirationDays = t.InquiryExpirationDays  
  FROM dbo.Tenants t WITH (NOLOCK)  
  WHERE t.TenantId = @TenantID  
  
  SELECT @ProductSubjectTypeId = MAX(CASE   
     WHEN st.SubjectTypeName = 'Products'  
      THEN st.SubjectTypeId  
     END)  
   ,@FabricSubjectTypeId = MAX(CASE   
     WHEN st.SubjectTypeName = 'Fabrics'  
      THEN st.SubjectTypeId  
     END)  
   ,@PolishSubjectTypeId = MAX(CASE   
     WHEN st.SubjectTypeName = 'Polish'  
      THEN st.SubjectTypeId  
     END)  
   ,@OrderSubjectTypeId = MAX(CASE   
     WHEN st.SubjectTypeName = 'Orders'  
      THEN st.SubjectTypeId  
     END)  
   ,@LabourSubjectTypeId = MAX(CASE   
     WHEN st.SubjectTypeName = 'Labours'  
      THEN st.SubjectTypeId  
     END)  
   ,@RawMaterialSubjectTypeId = MAX(CASE   
     WHEN st.SubjectTypeName = 'RawMaterials'  
      THEN st.SubjectTypeId  
     END)  
  FROM SubjectTypes st WITH (NOLOCK)  
  WHERE st.TenantId = @TenantID  
  
  IF OBJECT_ID('tempdb..#OrderSetItemResult') IS NOT NULL  
   DROP TABLE #OrderSetItemResult  
  
  IF OBJECT_ID('tempdb..#tmpOrderSets') IS NOT NULL  
   DROP TABLE #tmpOrderSets  
  
  IF OBJECT_ID('tempdb..#tmpOrderSetItems') IS NOT NULL  
   DROP TABLE #tmpOrderSetItems  
  
  IF OBJECT_ID('tempdb..#tmpOrderSetItemsAddOns') IS NOT NULL  
   DROP TABLE #tmpOrderSetItemsAddOns  
  
  IF OBJECT_ID('tempdb..#UpdateOrdersetItem') IS NOT NULL  
   DROP TABLE #UpdateOrdersetItem  
  
  CREATE TABLE #OrderSetItemResult (  
   GroupID BIGINT IDENTITY(1, 1)  
   ,OrderSetItemId BIGINT  
   )  
  
  CREATE TABLE #tmpOrderSets (  
   ID BIGINT IDENTITY  
   ,OrderSetId BIGINT  
   ,SetName VARCHAR(MAX)  
   ,GroupID BIGINT  
   )  
  
  CREATE TABLE #tmpOrderSetItems (  
   ID BIGINT IDENTITY  
   ,OrderSetItemId BIGINT  
   ,GroupID BIGINT  
   ,OrderSetGroupID BIGINT  
   ,SubjectTypeId BIGINT  
   ,SubjectId BIGINT  
   ,Width NUMERIC(18, 2)  
   ,Height NUMERIC(18, 2)  
   ,Depth NUMERIC(18, 2)  
   ,Diameter NUMERIC(18, 2)  
   ,Quantity NUMERIC(18, 2)  
   ,UnitPrice NUMERIC(18, 2)  
   ,DiscountPrice NUMERIC(18, 2)  
   ,Discount NUMERIC(18, 2)  
   ,GrossTotal NUMERIC(18, 2)  
   ,TotalAmount NUMERIC(18, 2)  
   ,Comment VARCHAR(MAX)  
   ,ReceiveDate DATETIMEOFFSET  
   ,ProvidedMaterial NUMERIC(18, 2)  
   ,ParentOrderSetItemId BIGINT  
   ,OfferId INT  
   ,InstantUnitPrice NUMERIC(18, 2)  
   ,InstantWidth NUMERIC(18, 2)  
   ,InstantHeight NUMERIC(18, 2)  
   ,InstantDepth NUMERIC(18, 2)  
   ,InstantDiameter NUMERIC(18, 2)  
   ,InstantCostPrice NUMERIC(18, 2)  
   ,ProductImage VARCHAR(MAX)  
   )  
  
  CREATE TABLE #tmpOrderSetItemsAddOns (  
   ID BIGINT IDENTITY  
   ,OrderSetItemId BIGINT  
   ,GroupID BIGINT  
   ,OrderSetItemGroupID BIGINT  
   ,OrderSetGroupID BIGINT  
   ,SubjectTypeId BIGINT  
   ,SubjectId BIGINT  
   ,Width NUMERIC(18, 2)  
   ,Height NUMERIC(18, 2)  
   ,Depth NUMERIC(18, 2)  
   ,Diameter NUMERIC(18, 2)  
   ,Quantity NUMERIC(18, 2)  
   ,UnitPrice NUMERIC(18, 2)  
   ,DiscountPrice NUMERIC(18, 2)  
   ,Discount NUMERIC(18, 2)  
   ,GrossTotal NUMERIC(18, 2)  
   ,TotalAmount NUMERIC(18, 2)  
   ,Comment NVARCHAR(MAX)  
   ,ReceiveDate DATETIMEOFFSET  
   ,ProvidedMaterial NUMERIC(18, 2)  
   ,ParentOrderSetItemId BIGINT  
   ,OfferId INT  
   ,InstantUnitPrice NUMERIC(18, 2)  
   ,InstantWidth NUMERIC(18, 2)  
   ,InstantHeight NUMERIC(18, 2)  
   ,InstantDepth NUMERIC(18, 2)  
   ,InstantDiameter NUMERIC(18, 2)  
   ,InstantCostPrice NUMERIC(18, 2)  
   ,ProductImage VARCHAR(MAX)  
   )  
  
  INSERT INTO #tmpOrderSets (  
   OrderSetId  
   ,SetName  
   ,GroupID  
   )  
  SELECT OrderSetId  
   ,SetName  
   ,GroupID  
  FROM OPENJSON(@JsonObject, '$.OrderSetRequestDto') WITH (  
    OrderSetId NVARCHAR(MAX) '$.OrderSetId'  
    ,SetName NVARCHAR(MAX) '$.SetName'  
    ,GroupID NVARCHAR(MAX) '$.groupId'  
    )  
  ORDER BY GroupID  
  
  INSERT INTO #tmpOrderSetItems (  
   OrderSetItemId  
   ,GroupID  
   ,OrderSetGroupID  
   ,SubjectTypeId  
   ,SubjectId  
   ,Width  
   ,Height  
   ,Depth  
   ,Diameter  
   ,Quantity  
   ,UnitPrice  
   ,DiscountPrice  
   ,Discount  
   ,GrossTotal  
   ,TotalAmount  
   ,Comment  
   ,ReceiveDate  
   ,ProvidedMaterial  
   ,ParentOrderSetItemId  
   ,OfferId  
   ,InstantUnitPrice  
   ,InstantWidth  
   ,InstantHeight  
   ,InstantDepth  
   ,InstantDiameter  
   ,InstantCostPrice  
   ,ProductImage  
   )  
  SELECT osi.OrderSetItemId  
   ,osi.GroupID  
   ,osi.ParentGroupID  
   ,osi.SubjectTypeId  
   ,osi.SubjectId  
   ,osi.Width  
   ,osi.Height  
   ,osi.Depth  
   ,osi.Diameter  
   ,osi.Quantity  
   ,osi.UnitPrice  
   ,osi.DiscountPrice  
   ,osi.Discount  
   ,osi.GrossTotal  
   ,osi.TotalAmount  
   ,osi.Comment  
   ,osi.ReceiveDate  
   ,osi.ProvidedMaterial  
   ,osi.ParentOrderSetItemId  
   ,osi.offerId  
   ,osi.InstantUnitPrice  
   ,osi.InstantWidth  
   ,osi.InstantHeight  
   ,osi.InstantDepth  
   ,osi.InstantDiameter  
   ,osi.InstantCostPrice  
   ,osi.ProductImage  
  FROM OPENJSON(@JsonObject, '$.OrderSetRequestDto') WITH (  
    OrderSetId NVARCHAR(MAX) '$.OrderSetId'  
    ,SetName NVARCHAR(MAX) '$.SetName'  
    ,GroupID NVARCHAR(MAX) '$.groupId'  
    ,OrderSetItems NVARCHAR(MAX) '$.OrderSetItemRequestDto' AS JSON  
    ) AS oss  
  CROSS APPLY OPENJSON(OrderSetItems, '$') WITH (  
    OrderSetItemId NVARCHAR(MAX) '$.OrderSetItemId'  
    ,GroupID NVARCHAR(MAX) '$.groupId'  
    ,ParentGroupID NVARCHAR(MAX) '$.parentGroupId'  
    ,SubjectTypeId NVARCHAR(MAX) '$.SubjectTypeId'  
    ,SubjectId NVARCHAR(MAX) '$.SubjectId'  
    ,Width NVARCHAR(MAX) '$.Width'  
    ,Height NVARCHAR(MAX) '$.Height'  
    ,Depth NVARCHAR(MAX) '$.Depth'  
    ,Diameter NVARCHAR(MAX) '$.Diameter'  
    ,Quantity NVARCHAR(MAX) '$.Quantity'  
    ,UnitPrice NVARCHAR(MAX) '$.UnitPrice'  
    ,DiscountPrice NVARCHAR(MAX) '$.DiscountPrice'  
    ,Discount NVARCHAR(MAX) '$.Discount'  
    ,GrossTotal NVARCHAR(MAX) '$.GrossTotal'  
    ,TotalAmount NVARCHAR(MAX) '$.TotalAmount'  
    ,Comment NVARCHAR(MAX) '$.Comment'  
    ,ReceiveDate NVARCHAR(MAX) '$.ReceiveDate'  
    ,ProvidedMaterial NVARCHAR(MAX) '$.ProvidedMaterial'  
    ,ParentOrderSetItemId NVARCHAR(MAX) '$.ParentOrderSetItemId'  
    ,OfferId INT '$.OfferId'  
    ,InstantUnitPrice NVARCHAR(MAX) '$.InstantUnitPrice'  
    ,InstantWidth NVARCHAR(MAX) '$.InstantWidth'  
    ,InstantHeight NVARCHAR(MAX) '$.InstantHeight'  
    ,InstantDepth NVARCHAR(MAX) '$.InstantDepth'  
    ,InstantDiameter NVARCHAR(MAX) '$.InstantDiameter'  
    ,InstantCostPrice NVARCHAR(MAX) '$.InstantCostPrice'  
    ,ProductImage NVARCHAR(MAX) '$.ProductImage'  
    ,AddOns NVARCHAR(MAX) '$.AddOns' AS JSON  
    ) AS osi  
  ORDER BY osi.ParentGroupID  
   ,osi.GroupID  
  
  INSERT INTO #tmpOrderSetItemsAddOns (  
   OrderSetItemId  
   ,GroupID  
   ,OrderSetItemGroupID  
   ,OrderSetGroupID  
   ,SubjectTypeId  
   ,SubjectId  
   ,Width  
   ,Height  
   ,Depth  
   ,Diameter  
   ,Quantity  
   ,UnitPrice  
   ,DiscountPrice  
   ,Discount  
   ,GrossTotal  
   ,TotalAmount  
   ,Comment  
   ,ReceiveDate  
   ,ProvidedMaterial  
   ,ParentOrderSetItemId  
   ,OfferId  
   ,InstantUnitPrice  
   ,InstantWidth  
   ,InstantHeight  
   ,InstantDepth  
   ,InstantDiameter  
   ,InstantCostPrice  
   ,ProductImage  
   )  
  SELECT osia.OrderSetItemId  
   ,osia.GroupID  
   ,ossi.GroupID  
   ,ossi.ParentGroupID  
   ,osia.SubjectTypeId  
   ,osia.SubjectId  
   ,osia.Width  
   ,osia.Height  
   ,osia.Depth  
   ,osia.Diameter  
   ,osia.Quantity  
   ,osia.UnitPrice  
   ,osia.DiscountPrice  
   ,osia.Discount  
   ,osia.GrossTotal  
   ,osia.TotalAmount  
   ,osia.Comment  
   ,osia.ReceiveDate  
   ,osia.ProvidedMaterial  
   ,osia.ParentOrderSetItemId  
   ,osia.OfferId  
   ,osia.InstantUnitPrice  
   ,osia.InstantWidth  
   ,osia.InstantHeight  
   ,osia.InstantDepth  
   ,osia.InstantDiameter  
   ,osia.InstantCostPrice  
   ,osia.ProductImage  
  FROM OPENJSON(@JsonObject, '$.OrderSetRequestDto') WITH (  
    OrderSetId NVARCHAR(MAX) '$.OrderSetId'  
    ,SetName NVARCHAR(MAX) '$.SetName'  
    ,GroupID NVARCHAR(MAX) '$.groupId'  
    ,OrderSetItems NVARCHAR(MAX) '$.OrderSetItemRequestDto' AS JSON  
    ) AS oss  
  CROSS APPLY OPENJSON(OrderSetItems, '$') WITH (  
    OrderSetItemId NVARCHAR(MAX) '$.OrderSetItemId'  
    ,GroupID NVARCHAR(MAX) '$.groupId'  
    ,ParentGroupID NVARCHAR(MAX) '$.parentGroupId'  
    ,SubjectTypeId NVARCHAR(MAX) '$.SubjectTypeId'  
    ,SubjectId NVARCHAR(MAX) '$.SubjectId'  
    ,AddOns NVARCHAR(MAX) '$.AddOns' AS JSON  
    ) AS ossi  
  CROSS APPLY OPENJSON(AddOns, '$') WITH (  
    OrderSetItemId NVARCHAR(MAX) '$.OrderSetItemId'  
    ,GroupID NVARCHAR(MAX) '$.groupId'  
    ,ParentGroupID NVARCHAR(MAX) '$.parentGroupId'  
    ,SubjectTypeId NVARCHAR(MAX) '$.SubjectTypeId'  
    ,SubjectId NVARCHAR(MAX) '$.SubjectId'  
    ,Width NVARCHAR(MAX) '$.Width'  
    ,Height NVARCHAR(MAX) '$.Height'  
    ,Depth NVARCHAR(MAX) '$.Depth'  
    ,Diameter NVARCHAR(MAX) '$.Diameter'  
    ,Quantity NVARCHAR(MAX) '$.Quantity'  
    ,UnitPrice NVARCHAR(MAX) '$.UnitPrice'  
    ,DiscountPrice NVARCHAR(MAX) '$.DiscountPrice'  
    ,Discount NVARCHAR(MAX) '$.Discount'  
    ,GrossTotal NVARCHAR(MAX) '$.GrossTotal'  
    ,TotalAmount NVARCHAR(MAX) '$.TotalAmount'  
    ,Comment NVARCHAR(MAX) '$.Comment'  
    ,ReceiveDate NVARCHAR(MAX) '$.ReceiveDate'  
    ,ProvidedMaterial NVARCHAR(MAX) '$.ProvidedMaterial'  
    ,ParentOrderSetItemId NVARCHAR(MAX) '$.ParentOrderSetItemId'  
    ,OfferId NVARCHAR(MAX) '$.OfferId'  
    ,InstantUnitPrice NVARCHAR(MAX) '$.InstantUnitPrice'  
    ,InstantWidth NVARCHAR(MAX) '$.InstantWidth'  
    ,InstantHeight NVARCHAR(MAX) '$.InstantHeight'  
    ,InstantDepth NVARCHAR(MAX) '$.InstantDepth'  
    ,InstantDiameter NVARCHAR(MAX) '$.InstantDiameter'  
    ,InstantCostPrice NVARCHAR(MAX) '$.InstantCostPrice'  
    ,ProductImage NVARCHAR(MAX) '$.ProductImage'  
    ) AS osia  
  ORDER BY ossi.ParentGroupID  
   ,osia.ParentGroupID  
   ,osia.GroupID  
  
  UPDATE tosi  
  SET tosi.InstantCostPrice = CASE   
    WHEN (  
      p.Width = tosi.Width  
      AND p.Height = tosi.Height  
      AND p.Depth = tosi.Depth  
      )  
     THEN IIF(p.CostPrice = 0, p.RetailerPrice, p.CostPrice)  
      --ELSE [dbo].[GetProductCostPriceByDimension](p.ProductId, tosi.Width, tosi.Height, tosi.Depth)  
    ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantID, p.ProductId, tosi.Width, tosi.Height, tosi.Depth, 1, @OrderId)  
    END  
  FROM #tmpOrderSetItems tosi  
  INNER JOIN Products p ON p.ProductId = tosi.SubjectId  
  WHERE tosi.SubjectTypeId = @ProductSubjectTypeId  
  
  UPDATE tosi  
  SET tosi.InstantCostPrice = IIF(f.UnitPrice = 0, f.RetailerPrice, f.UnitPrice)  
   ,tosi.ProductImage = f.ImagePath  
  FROM #tmpOrderSetItems tosi  
  INNER JOIN Fabrics f ON f.FabricId = tosi.SubjectId  
  WHERE tosi.SubjectTypeId = @FabricSubjectTypeId  
  
  UPDATE tosi  
  SET tosi.InstantCostPrice = CASE   
    WHEN (  
      p.Width = tosi.Width  
      AND p.Height = tosi.Height  
      AND p.Depth = tosi.Depth  
      )  
     THEN IIF(p.CostPrice = 0, p.RetailerPrice, p.CostPrice)  
      --ELSE [dbo].[GetProductCostPriceByDimension](p.ProductId, tosi.Width, tosi.Height, tosi.Depth)  
    ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantID, p.ProductId, tosi.Width, tosi.Height, tosi.Depth, 1, @OrderId)  
    END  
  FROM #tmpOrderSetItemsAddOns tosi  
  INNER JOIN Products p ON p.ProductId = tosi.SubjectId  
  WHERE tosi.SubjectTypeId = @ProductSubjectTypeId  
  
  UPDATE tosi  
  SET tosi.InstantCostPrice = IIF(f.UnitPrice = 0, f.RetailerPrice, f.UnitPrice)  
   ,tosi.ProductImage = f.ImagePath  
  FROM #tmpOrderSetItemsAddOns tosi  
  INNER JOIN Fabrics f ON f.FabricId = tosi.SubjectId  
  WHERE tosi.SubjectTypeId = @FabricSubjectTypeId  
  
  CREATE TABLE #UpdateOrdersetItem (  
   ID INT IDENTITY(1, 1)  
   ,OrderId BIGINT  
   ,OrderSetItemId BIGINT  
   ,NewQuantity NUMERIC(18, 2)  
   ,OldQuantity NUMERIC(18, 2)  
   )  
  
  INSERT INTO #UpdateOrdersetItem (  
   OrderId  
   ,OrderSetItemId  
   ,NewQuantity  
   ,OldQuantity  
   )  
  SELECT OSI.OrderID AS OrderId  
   ,TOSI.OrderSetItemId AS OrderSetItemId  
   ,TOSI.Quantity AS NewQuantity  
   ,OSI.Quantity AS OldQuantity  
  FROM #tmpOrderSetItems TOSI  
  LEFT JOIN dbo.OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = TOSI.OrderSetItemId  
  WHERE ISNULL(OSI.OrderSetItemId, 0) <> 0  
   AND (OSI.Quantity - TOSI.Quantity) <> 0;  
  
  INSERT INTO #UpdateOrdersetItem (  
   OrderId  
   ,OrderSetItemId  
   ,NewQuantity  
   ,OldQuantity  
   )  
  SELECT OSI.OrderID AS OrderId  
   ,TOSIA.OrderSetItemId AS OrderSetItemId  
   ,TOSIA.Quantity AS NewQuantity  
   ,OSI.Quantity AS OldQuantity  
  FROM #tmpOrderSetItemsAddOns TOSIA  
  LEFT JOIN dbo.OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = TOSIA.OrderSetItemId  
  WHERE ISNULL(OSI.OrderSetItemId, 0) <> 0  
   AND (OSI.Quantity - TOSIA.Quantity) <> 0  
  
  SELECT @GSTType = GSTType  
  FROM Tenants t WITH (NOLOCK)  
  WHERE t.TenantId = @TenantID  
  
  TRUNCATE TABLE #OrderSetItemResult  
  
  IF @OrderID = 0  
  BEGIN  
   SELECT @OrderNo = dbo.GetOrderNumber(@OrderType, @TenantID)  
  
   UPDATE TenantConfigurations  
   SET OrderNumberCounter = OrderNumberCounter + 1  
   WHERE TenantId = @TenantId  
    AND OrderNumberGenerationType = 1  
  
   --Add Order  
   INSERT INTO dbo.Orders (  
    OrderNo  
    ,CustomerID  
    ,Status  
    ,TenantId  
    ,OrderType  
    ,InquiryExpirationDate  
    ,InquiryLastUpdatedDate  
    ,GSTType  
    ,GrossTotal  
    ,Discount  
    ,TotalAmount  
    ,AmountBeforeGST  
    ,CGSTAmount  
    ,SGSTAmount  
    ,GSTTaxAmount  
    ,AdvanceAmount  
    ,OfferDiscount  
    ,IsFreeDelivery  
    ,CreatedBy  
    ,CreatedDate  
    ,CreatedUTCDate  
    ,RefferedBy  
    ,LumpsumDiscount  
    ,DeliveryCharge  
    ,DeliveryAmount  
    ,DeliveryAmountCollectionType  
    ,LocationID  
    ,SalesmanId  
    ,InteriorCommissionPer  
    ,SalesmanCommissionPer  
    ,IsBackOrder  
    ,TentativeDeliveryDate  
    )  
   SELECT @OrderNo  
    ,@CustomerID  
    ,0 --Inquiry  
    ,@TenantID  
    ,CASE   
     WHEN @OrderType = 'R'  
      THEN 1  
     ELSE 2  
     END  
    ,DATEADD(DAY, @InquiryExpirationDays, @DateOffset)  
    ,@DateOffset  
    ,@GSTType  
    ,0 AS GrossTotal  
    ,0 AS Discount  
    ,0 AS TotalAmount  
    ,0 AS AmountBeforeGST  
    ,0 AS CGSTAmount  
    ,0 AS SGSTAmount  
    ,0 AS GSTTaxAmount  
    ,0 AS AdvanceAmount  
    ,0 AS OfferDiscount  
    ,ISNULL(@IsFreeDelivery, 0)  
    ,@UserID  
    ,@DateOffset  
    ,@DateUtc  
    ,@ReferedByID  
    ,@LumpsumDiscount  
    ,@DeliveryCharge  
    ,@DeliveryAmount  
    ,@DeliveryAmountCollectionType  
    ,@LocationID  
    ,@UserID  
    ,@InteriorCommissionPer  
    ,@SalesmanCommissionPer  
    ,@isFromBackOrder  
    ,@TentativeDeliveryDate  
  
   SELECT @NewOrderID = SCOPE_IDENTITY()  
  
   --Add Order Address  
   SELECT @CustomerDefaultAddressId = 0  
  
   SELECT @CustomerDefaultAddressId = ca.CustomerAddressId  
   FROM dbo.CustomerAddresses ca WITH (NOLOCK)  
   INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId  
   WHERE ca.CustomerId = @CustomerID  
    AND ca.IsDefault = 1  
    AND ca.IsDeleted = 0  
  
   EXEC dbo.SaveOrderBillingAddress @OrderId = @NewOrderID  
    ,@BillingAddressID = @CustomerDefaultAddressId  
    ,@UserId = @UserID  
  
   EXEC dbo.SaveOrderShippingAddress @OrderId = @NewOrderID  
    ,@ShippingAddressID = @CustomerDefaultAddressId  
    ,@UserId = @UserID  
  
   --Create Order Activity Log  
   EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId  
    ,@SubjectId = @NewOrderID  
    ,@Description = 'Inquiry has been created.'  
    ,@Action = 'CREATE'  
    ,@CreatedBy = @UserID  
    ,@CreatedDate = @DateOffset  
    ,@CreatedUTCDate = @DateUtc;  
  END  
  ELSE  
  BEGIN  
   SELECT @NewOrderID = @OrderID  
  
   SELECT @GSTType = GSTType  
   FROM Orders o WITH (NOLOCK)  
   WHERE o.OrderId = @NewOrderID  
    AND o.TenantId = @TenantID  
  
   --Update Order  
   UPDATE o  
   SET o.IsFreeDelivery = ISNULL(@IsFreeDelivery, 0)  
    --,o.GSTType = @GSTType  
    ,o.CustomerID = @CustomerId  
    --,o.RefferedBy = @ReferedByID  
    ,o.TentativeDeliveryDate = @TentativeDeliveryDate  
    ,o.LumpsumDiscount = @LumpsumDiscount  
    ,o.DeliveryCharge = @DeliveryCharge  
    ,o.DeliveryAmount = @DeliveryAmount  
    ,o.DeliveryAmountCollectionType = @DeliveryAmountCollectionType  
    ,o.LocationID = @LocationID  
    ,o.SalesmanCommissionPer = @SalesmanCommissionPer  
   FROM dbo.Orders o  
   WHERE o.OrderId = @NewOrderID  
  END  
  
  IF @LumpsumDiscount IS NOT NULL  
   AND @LumpsumDiscount > 0  
  BEGIN  
   EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId  
    ,@SubjectId = @NewOrderID  
    ,@Description = 'Lumpsum Discount has been added.'  
    ,@Action = 'UPDATE'  
    ,@CreatedBy = @UserID  
    ,@CreatedDate = @DateOffset  
    ,@CreatedUTCDate = @DateUtc;  
  END  
  
  --Add Order Comment  
  IF ISNULL(@Comment, '') <> ''  
  BEGIN  
   EXEC dbo.SaveOrderComment @OrderId = @NewOrderID  
    ,@Status = 0  
    ,@Comment = @Comment  
    ,@Remarks = NULL  
    ,@CreatedBy = @UserID  
    ,@CreatedDate = @DateOffset  
    ,@CreatedUTCDate = @DateUtc;  
  END  
  
  --Add Order Remark  
  IF ISNULL(@Remarks, '') <> ''  
  BEGIN  
   EXEC dbo.SaveOrderComment @OrderId = @NewOrderID  
    ,@Status = 0  
    ,@Comment = NULL  
    ,@Remarks = @Remarks  
    ,@CreatedBy = @UserID  
    ,@CreatedDate = @DateOffset  
    ,@CreatedUTCDate = @DateUtc;  
  END  
  
  IF @NewOrderID > 0  
  BEGIN  
   SELECT @cntSets = NULL  
    ,@incSets = 1  
    ,@cntSetItems = NULL  
    ,@incSetItems = 1  
    ,@cntSetItemAddOns = NULL  
    ,@incSetItemAddOns = 1  
  
   SELECT @NewOrderSetId = NULL  
    ,@OrderSetId = NULL  
    ,@OrderSetName = NULL  
    ,@OrderSetGroupID = NULL  
    ,@NewOrderSetItemId = NULL  
    ,@OrderSetItemId = NULL  
    ,@OrderSetItemGroupId = NULL  
    ,@NewOrderSetItemAddOnId = NULL  
    ,@OrderSetItemAddOnId = NULL  
    ,@DefaultProductVendorId = NULL  
  
   SELECT @cntSets = COUNT(1)  
   FROM #tmpOrderSets  
  
   WHILE (@incSets <= @cntSets)  
   BEGIN  
    SELECT @NewOrderSetId = NULL  
     ,@OrderSetId = NULL  
     ,@OrderSetName = NULL  
     ,@OrderSetGroupID = NULL  
     ,@cntSetItems = NULL  
     ,@incSetItems = 1  
  
    SELECT @OrderSetId = OrderSetId  
     ,@OrderSetName = SetName  
     ,@OrderSetGroupID = GroupID  
    FROM #tmpOrderSets  
    WHERE ID = @incSets  
  
    IF @OrderSetId > 0  
    BEGIN  
     UPDATE os  
     SET os.SetName = @OrderSetName  
      ,os.UpdatedBy = @UserID  
      ,os.UpdatedDate = @DateOffset  
      ,os.UpdatedUTCDate = @DateUtc  
     FROM dbo.OrderSets os  
     WHERE os.OrderSetId = @OrderSetId  
      AND os.IsDeleted = 0  
      AND os.OrderId = @NewOrderID  
  
     SELECT @NewOrderSetId = @OrderSetId  
    END  
    ELSE  
    BEGIN  
     INSERT INTO dbo.OrderSets (  
      OrderId  
      ,SetName  
      ,CreatedBy  
      ,CreatedDate  
      ,CreatedUTCDate  
      )  
     SELECT @NewOrderID  
      ,SetName  
      ,@UserID  
      ,@DateOffset  
      ,@DateUtc  
     FROM #tmpOrderSets  
     WHERE ID = @incSets  
  
     SELECT @NewOrderSetId = SCOPE_IDENTITY()  
    END  
  
    SELECT @cntSetItems = COUNT(1)  
    FROM #tmpOrderSetItems  
    WHERE OrderSetGroupID = @OrderSetGroupID  
  
    WHILE (@incSetItems <= @cntSetItems)  
    BEGIN  
     SELECT @NewOrderSetItemId = NULL  
      ,@OrderSetItemId = NULL  
      ,@OrderSetItemGroupId = NULL  
      ,@cntSetItemAddOns = NULL  
      ,@incSetItemAddOns = 1  
  
     SELECT @OrderSetItemId = OrderSetItemId  
      ,@OrderSetItemGroupId = GroupID  
     FROM #tmpOrderSetItems  
     WHERE OrderSetGroupID = @OrderSetGroupID  
      AND GroupID = @incSetItems  
  
     SELECT @DefaultProductVendorId = pvm.VendorId  
     FROM #tmpOrderSetItems  
     LEFT JOIN ProductVendorMapping AS pvm WITH (NOLOCK) ON pvm.ProductId = #tmpOrderSetItems.SubjectId  
      AND pvm.IsDefault = 1  
      AND #tmpOrderSetItems.SubjectTypeId = @ProductSubjectTypeId  
     WHERE OrderSetGroupID = @OrderSetGroupID  
      AND GroupID = @incSetItems  
  
     IF @OrderSetItemId > 0  
     BEGIN  
      UPDATE osi  
      SET osi.SubjectTypeId = ossi.SubjectTypeId  
       ,osi.SubjectId = ossi.SubjectId  
       ,osi.Width = ossi.Width  
       ,osi.Height = ossi.Height  
       ,osi.Depth = ossi.Depth  
       ,osi.Diameter = ossi.Diameter  
       ,osi.Quantity = ossi.Quantity  
       ,osi.UnitPrice = ossi.UnitPrice  
       ,osi.DiscountPrice = ossi.DiscountPrice  
       ,osi.Discount = ossi.Discount  
       ,osi.GrossTotal = ossi.GrossTotal  
       ,osi.TotalAmount = ossi.TotalAmount  
       ,osi.Comment = ossi.Comment  
       ,osi.ReceiveDate = ossi.ReceiveDate  
       ,osi.ProvidedMaterial = ossi.ProvidedMaterial  
       ,osi.UpdatedBy = @UserID  
       ,osi.UpdatedDate = @DateOffset  
       ,osi.UpdatedUTCDate = @DateUtc  
       ,osi.InstantUnitPrice = ossi.InstantUnitPrice  
       ,osi.InstantWidth = ossi.InstantWidth  
       ,osi.InstantHeight = ossi.InstantHeight  
       ,osi.InstantDepth = ossi.InstantDepth  
       ,osi.InstantDiameter = ossi.InstantDiameter  
       ,osi.InstantCostPrice = ossi.InstantCostPrice  
       ,osi.DefaultProductVendorId = @DefaultProductVendorId  
       ,osi.ProductImage = ossi.ProductImage  
      FROM dbo.OrderSetItems osi  
      INNER JOIN #tmpOrderSetItems ossi ON ossi.OrderSetItemId = osi.OrderSetItemId  
       AND ossi.GroupID = @incSetItems  
       AND ossi.OrderSetGroupID = @OrderSetGroupID  
      WHERE osi.OrderSetItemId = @OrderSetItemId  
       AND osi.OrderId = @NewOrderID  
       AND osi.IsDeleted = 0  
  
      SELECT @NewOrderSetItemId = @OrderSetItemId  
     END  
     ELSE  
     BEGIN  
      INSERT INTO dbo.OrderSetItems (  
       OrderId  
       ,OrderSetId  
       ,SubjectTypeId  
       ,SubjectId  
       ,Width  
       ,Height  
       ,Depth  
       ,Diameter  
       ,Quantity  
       ,UnitPrice  
       ,DiscountPrice  
       ,Discount  
       ,GrossTotal  
       ,TotalAmount  
       ,AmountBeforeGST  
       ,CGSTAmount  
       ,SGSTAmount  
       ,ProductImage  
       ,Comment  
       ,ItemStatus  
       ,ReceiveDate  
       ,ProvidedMaterial  
       ,CreatedBy  
       ,CreatedDate  
       ,CreatedUTCDate  
       ,OfferId  
       ,InstantUnitPrice  
       ,InstantWidth  
       ,InstantHeight  
       ,InstantDepth  
       ,InstantDiameter  
       ,InstantCostPrice  
       ,DefaultProductVendorId  
       ,MRP  
       )  
      SELECT @NewOrderID  
       ,@NewOrderSetId  
       ,osi.SubjectTypeId  
       ,osi.SubjectId  
       ,osi.Width  
       ,osi.Height  
       ,osi.Depth  
       ,osi.Diameter  
       ,osi.Quantity  
       ,osi.UnitPrice  
       ,osi.DiscountPrice  
       ,osi.Discount  
       ,osi.GrossTotal  
       ,osi.TotalAmount  
       ,0 AS AmountBeforeGST  
       ,0 AS CGST  
       ,0 AS SGST  
       ,osi.ProductImage  
       ,osi.Comment  
       ,0 --Status  
       ,osi.ReceiveDate  
       ,osi.ProvidedMaterial  
       ,@UserID  
       ,@DateOffset  
       ,@DateUtc  
       ,osi.OfferId  
       ,osi.InstantUnitPrice  
       ,osi.InstantWidth  
       ,osi.InstantHeight  
       ,osi.InstantDepth  
       ,osi.InstantDiameter  
       ,osi.InstantCostPrice  
       ,@DefaultProductVendorId  
       ,CASE   
        WHEN osi.OfferId > 0  
         THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, osi.SubjectId, osi.Width, osi.Height, osi.Depth, 2,@NewOrderID)  
        ELSE 0  
        END  
      FROM #tmpOrderSetItems osi  
      WHERE GroupID = @incSetItems  
       AND OrderSetGroupID = @OrderSetGroupID  
  
      SELECT @NewOrderSetItemId = SCOPE_IDENTITY();  
  
      INSERT INTO #UpdateOrdersetItem (  
       OrderId  
       ,OrderSetItemId  
       ,NewQuantity  
       ,OldQuantity  
       )  
      SELECT @NewOrderID AS OrderId  
       ,@NewOrderSetItemId AS OrderSetItemId  
       ,OSI.Quantity AS NewQuantity  
       ,0 AS OldQuantity  
      FROM dbo.OrderSetItems OSI WITH (NOLOCK)  
      WHERE OSI.OrderSetItemId = @NewOrderSetItemId;  
     END  
  
     SELECT @cntSetItemAddOns = COUNT(1)  
     FROM #tmpOrderSetItemsAddOns  
     WHERE OrderSetItemGroupID = @OrderSetItemGroupId  
      AND OrderSetGroupID = @OrderSetGroupID  
  
     UPDATE #tmpOrderSetItemsAddOns  
     SET ParentOrderSetItemId = @NewOrderSetItemId  
     WHERE OrderSetItemGroupID = @OrderSetItemGroupId  
      AND OrderSetGroupID = @OrderSetGroupID  
  
     WHILE (@incSetItemAddOns <= @cntSetItemAddOns)  
     BEGIN  
      SELECT @NewOrderSetItemAddOnId = NULL  
       ,@OrderSetItemAddOnId = NULL  
  
      SELECT @OrderSetItemAddOnId = OrderSetItemId  
      FROM #tmpOrderSetItemsAddOns  
      WHERE OrderSetItemGroupID = @OrderSetItemGroupId  
       AND OrderSetGroupID = @OrderSetGroupID  
       AND GroupID = @incSetItemAddOns  
  
      SELECT @DefaultProductVendorId = pvm.VendorId  
      FROM #tmpOrderSetItemsAddOns  
      LEFT JOIN ProductVendorMapping AS pvm WITH (NOLOCK) ON pvm.ProductId = #tmpOrderSetItemsAddOns.SubjectId  
       AND pvm.IsDefault = 1  
       AND #tmpOrderSetItemsAddOns.SubjectTypeId = @ProductSubjectTypeId  
      WHERE OrderSetGroupID = @OrderSetGroupID  
       AND GroupID = @incSetItems  
  
      IF @OrderSetItemAddOnId > 0  
      BEGIN  
       UPDATE osi  
       SET osi.SubjectTypeId = osia.SubjectTypeId  
        ,osi.SubjectId = osia.SubjectId  
        ,osi.Width = osia.Width  
        ,osi.Height = osia.Height  
        ,osi.Depth = osia.Depth  
        ,osi.Diameter = osia.Diameter  
        ,osi.Quantity = osia.Quantity  
        ,osi.UnitPrice = osia.UnitPrice  
        ,osi.DiscountPrice = osia.DiscountPrice  
        ,osi.Discount = osia.Discount  
        ,osi.GrossTotal = osia.GrossTotal  
        ,osi.TotalAmount = osia.TotalAmount  
        ,osi.Comment = osia.Comment  
        ,osi.ReceiveDate = osia.ReceiveDate  
        ,osi.ProvidedMaterial = osia.ProvidedMaterial  
        ,osi.UpdatedBy = @UserID  
        ,osi.UpdatedDate = @DateOffset  
        ,osi.UpdatedUTCDate = @DateUtc  
        ,osi.InstantUnitPrice = osia.InstantUnitPrice  
        ,osi.InstantWidth = osia.InstantWidth  
        ,osi.InstantHeight = osia.InstantHeight  
        ,osi.InstantDepth = osia.InstantDepth  
        ,osi.InstantDiameter = osia.InstantDiameter  
        ,osi.InstantCostPrice = osia.InstantCostPrice  
        ,osi.DefaultProductVendorId = @DefaultProductVendorId  
        ,osi.ProductImage = osia.ProductImage  
       FROM dbo.OrderSetItems osi  
       INNER JOIN #tmpOrderSetItemsAddOns osia ON osia.OrderSetItemId = osi.OrderSetItemId  
        AND OrderSetItemGroupID = @OrderSetItemGroupId  
        AND OrderSetGroupID = @OrderSetGroupID  
        AND GroupID = @incSetItemAddOns  
       WHERE osi.OrderSetItemId = @OrderSetItemAddOnId  
        AND osi.IsDeleted = 0  
        AND osi.OrderId = @NewOrderID  
  
       SELECT @NewOrderSetItemAddOnId = @OrderSetItemAddOnId  
      END  
      ELSE  
      BEGIN  
       INSERT INTO dbo.OrderSetItems (  
        OrderId  
        ,OrderSetId  
        ,ParentOrderSetItemId  
        ,SubjectTypeId  
        ,SubjectId  
        ,Width  
        ,Height  
        ,Depth  
        ,Diameter  
        ,Quantity  
        ,UnitPrice  
        ,DiscountPrice  
        ,Discount  
        ,GrossTotal  
        ,TotalAmount  
        ,AmountBeforeGST  
        ,CGSTAmount  
        ,SGSTAmount  
        ,ProductImage  
        ,Comment  
        ,ItemStatus  
        ,ReceiveDate  
        ,ProvidedMaterial  
        ,CreatedBy  
        ,CreatedDate  
        ,CreatedUTCDate  
        ,OfferId  
        ,InstantUnitPrice  
        ,InstantWidth  
        ,InstantHeight  
        ,InstantDepth  
        ,InstantDiameter  
        ,InstantCostPrice  
        ,DefaultProductVendorId  
        ,MRP  
        )  
       SELECT @NewOrderID  
        ,@NewOrderSetId  
        ,osia.ParentOrderSetItemId  
        ,osia.SubjectTypeId  
        ,osia.SubjectId  
        ,osia.Width  
        ,osia.Height  
        ,osia.Depth  
        ,osia.Diameter  
        ,osia.Quantity  
        ,osia.UnitPrice  
        ,osia.DiscountPrice  
        ,osia.Discount  
        ,osia.GrossTotal  
        ,osia.TotalAmount  
        ,0 AS AmountBeforeGST  
        ,0 AS CGST  
        ,0 AS SGST  
        ,osia.ProductImage  
        ,osia.Comment  
        ,0 --Status  
        ,osia.ReceiveDate  
        ,osia.ProvidedMaterial  
        ,@UserID  
        ,@DateOffset  
        ,@DateUtc  
        ,osia.OfferId  
        ,osia.InstantUnitPrice  
        ,osia.InstantWidth  
        ,osia.InstantHeight  
        ,osia.InstantDepth  
        ,osia.InstantDiameter  
        ,osia.InstantCostPrice  
        ,@DefaultProductVendorId  
        ,CASE   
         WHEN osia.OfferId > 0  
          THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, osia.SubjectId, osia.Width, osia.Height, osia.Depth, 2,@NewOrderID)  
         ELSE 0  
         END  
       FROM #tmpOrderSetItemsAddOns osia  
       WHERE OrderSetItemGroupID = @OrderSetItemGroupId  
        AND OrderSetGroupID = @OrderSetGroupID  
        AND GroupID = @incSetItemAddOns  
  
       SELECT @NewOrderSetItemAddOnId = SCOPE_IDENTITY()  
  
       INSERT INTO #UpdateOrdersetItem (  
        OrderId  
        ,OrderSetItemId  
        ,NewQuantity  
        ,OldQuantity  
        )  
       SELECT @NewOrderID AS OrderId  
        ,OSI.OrderSetItemId AS OrderSetItemId  
        ,OSI.Quantity AS NewQuantity  
        ,0 AS OldQuantity  
       FROM dbo.OrderSetItems OSI WITH (NOLOCK)  
       WHERE OSI.OrderSetItemId = @NewOrderSetItemAddOnId;  
      END  
  
      SET @incSetItemAddOns = @incSetItemAddOns + 1  
     END  
  
     SET @incSetItems = @incSetItems + 1  
    END  
  
    SET @incSets = @incSets + 1  
   END  
  
   EXEC RefreshInquiry @RefreshInquiry = @RefreshInquiry  
    ,@OrderID = @NewOrderID  
    ,@ProductSubjectTypeId = @ProductSubjectTypeId  
    ,@FabricSubjectTypeId = @FabricSubjectTypeId  
    ,@PolishSubjectTypeId = @PolishSubjectTypeId  
  
   EXEC SaveOrderProductCharges @TenantID = @TenantID  
    ,@UserID = @UserID  
    ,@OrderID = @NewOrderID  
  
   --Update GST Calculation  
   EXEC dbo.UpdateOrderGST @OrderID = @NewOrderID  
    ,@GSTType = @GSTType  
    ,@UserID = @UserID  
    ,@TenantID = @TenantID  
  
   --Create Archive Entries  
   EXEC dbo.SaveArchive_Order @OrderID = @NewOrderID  
    ,@UserId = @UserID  
  END  
  
  EXEC UpdateSalesmanCommissionByOrder @OrderID = @OrderID  
  
  EXEC UpdateInteriorCommissionByOrder @OrderID = @OrderID  
  
  -- Update Product Quantity after order Approved, In Progress, and Ready To Deliver  
  IF EXISTS (  
    SELECT TOP 1 1  
    FROM Orders WITH (NOLOCK)  
    WHERE OrderId = @NewOrderID  
     AND Status IN (  
      2  
      ,3  
      )  
    )  
   AND EXISTS (  
    SELECT 1  
    FROM AspNetRoleClaims ARC WITH (NOLOCK)  
    INNER JOIN AspNetRoles AR WITH (NOLOCK) ON ARC.RoleId = AR.Id  
     AND AR.IsDeleted = 0  
     AND AR.TenantId = @TenantId  
    WHERE ARC.RoleId = @RoleId  
     AND ARC.ClaimValue IN (  
     'Permissions.App.Order.OrderManageProducts'  
     ,'Permissions.General.Order.OrderManageProducts'  
     )  
    )  
  BEGIN  
   DECLARE @CntUpdateSetItems INT = 0  
    ,@Counter INT = 1  
   DECLARE @UpdatedOrderSetItemId BIGINT = 0  
    ,@OldQuantity NUMERIC(18, 2) = 0  
    ,@NewQuantity NUMERIC(18, 2) = 0  
    ,@UpdatedQuantity [numeric](18, 2) = 0  
  
   SELECT @CntUpdateSetItems = COUNT(OrderSetItemId)  
   FROM #UpdateOrdersetItem  
  
   WHILE @Counter <= @CntUpdateSetItems  
   BEGIN  
    SET @UpdatedOrderSetItemId = 0  
    SET @OldQuantity = 0  
    SET @NewQuantity = 0  
    SET @UpdatedQuantity = 0  
  
    SELECT @UpdatedOrderSetItemId = OrderSetItemId  
     ,@OldQuantity = OldQuantity  
     ,@NewQuantity = NewQuantity  
     ,@UpdatedQuantity = ISNULL(NewQuantity, 0) - ISNULL(OldQuantity, 0)  
    FROM #UpdateOrdersetItem  
    WHERE ID = @Counter  
  
    DECLARE @OrderApprovedStatus BIT = 1  
     ,@OrderApprovedMessage VARCHAR(100) = NULL  
  
    EXEC [dbo].[SaveOrderAfterApproved] @OrderID = @OrderID  
     ,@TenantID = @TenantID  
     ,@OrderSetItemId = @UpdatedOrderSetItemId  
     ,@UpdatedQuantity = @UpdatedQuantity  
     ,@UserID = @UserID  
     ,@ReturnStatus = @OrderApprovedStatus OUTPUT  
     ,@ReturnMessage = @OrderApprovedMessage OUTPUT  
  
    SELECT @ReturnStatus = @OrderApprovedStatus  
  
    SELECT @ReturnMessage = @OrderApprovedMessage  
  
    SELECT @ReturnOrderID = @NewOrderID  
  
    IF @ReturnStatus = 0  
    BEGIN  
     SET @ReturnMessage = @OrderApprovedMessage  
     RETURN  
    END  
  
    SET @Counter = @Counter + 1  
   END  
  END  
  
  SELECT @ReturnOrderID = @NewOrderID  
  
  SELECT @ReturnStatus = 1  
  
  SELECT @ReturnMessage = IIF(ISNULL(@OrderID, 0) > 0, 'Order updated successfully', 'Order saved successfully')  
  
  IF OBJECT_ID('tempdb..#OrderSetItemResult') IS NOT NULL  
   DROP TABLE #OrderSetItemResult  
  
  IF OBJECT_ID('tempdb..#tmpOrderSets') IS NOT NULL  
   DROP TABLE #tmpOrderSets  
  
  IF OBJECT_ID('tempdb..#tmpOrderSetItems') IS NOT NULL  
   DROP TABLE #tmpOrderSetItems  
  
  IF OBJECT_ID('tempdb..#tmpOrderSetItemsAddOns') IS NOT NULL  
   DROP TABLE #tmpOrderSetItemsAddOns  
  
  IF OBJECT_ID('tempdb..#UpdateOrdersetItem') IS NOT NULL  
   DROP TABLE #UpdateOrdersetItem  
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

