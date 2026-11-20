------------------------[dbo].[SaveOrder]

CREATE PROCEDURE [dbo].[SaveOrder]
(
	@OrderID BIGINT
	,@OrderType VARCHAR(1)
	,@TenantID BIGINT
	,@UserID BIGINT
	,@RefreshInquiry BIT
	,@JsonObject NVARCHAR(MAX)
	,@LocationID BIGINT = NULL
	,@isFromBackOrder BIT = NULL 
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
			,@LumpsumDiscount NUMERIC(18,2)
			,@DeliveryCharge SMALLINT
		    ,@DeliveryAmount NUMERIC(9,2)
			,@DeliveryAmountCollectionType INT
			,@InteriorCommissionPer NUMERIC (5,2)
 
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
			,@DeliveryAmount =  DeliveryAmount
			,@DeliveryAmountCollectionType = DeliveryAmountCollectionType
			,@Comment = Comments
			,@Remarks = Remarks
			,@GSTType = GSTType
		FROM OPENJSON(@JsonObject)
		WITH (
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
				,LumpsumDiscount NUMERIC(18,2) '$.LumpsumDiscount'
				,DeliveryCharge NVARCHAR(MAX) '$.DeliveryCharge'
				,DeliveryAmount NUMERIC(18,2) '$.DeliveryAmount'
				,DeliveryAmountCollectionType NVARCHAR(MAX) '$.DeliveryAmountCollectionType'
			)
		SELECT @ReferedByID = RefferedBy 
		from Customers 
		WHERE CustomerId = @CustomerId

		SELECT @InteriorCommissionPer= COALESCE(NULLIF(c.InteriorCommissionPer,0),t.ArchitectDiscount,0)
		FROM Customers c
		INNER JOIN Tenants t ON t.TenantId=c.TenantId
		WHERE c.CustomerId=@ReferedByID 
			AND c.CustomerTypeId=2
 
		SELECT @InquiryExpirationDays = t.InquiryExpirationDays
		FROM dbo.Tenants t WITH (NOLOCK)
		WHERE t.TenantId = @TenantID
		SELECT @ProductSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
		AND st.SubjectTypeName = 'Products'
 
		SELECT @FabricSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
		AND st.SubjectTypeName = 'Fabrics'
 
		SELECT @PolishSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
		AND st.SubjectTypeName = 'Polish'
 
		SELECT @OrderSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
		AND st.SubjectTypeName = 'Orders'
 
		SELECT @LabourSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
		AND st.SubjectTypeName = 'Labours'
 
		SELECT @RawMaterialSubjectTypeId = st.SubjectTypeId
		FROM SubjectTypes st WITH (NOLOCK)
		WHERE st.TenantId = @TenantID
		AND st.SubjectTypeName = 'RawMaterials'
 
		IF OBJECT_ID('tempdb..#OrderSetItemResult') IS NOT NULL
			DROP TABLE #OrderSetItemResult
 
		IF OBJECT_ID('tempdb..#tmpOrderSets') IS NOT NULL
			DROP TABLE #tmpOrderSets
 
		IF OBJECT_ID('tempdb..#tmpOrderSetItems') IS NOT NULL
			DROP TABLE #tmpOrderSetItems
 
		IF OBJECT_ID('tempdb..#tmpOrderSetItemsAddOns') IS NOT NULL
			DROP TABLE #tmpOrderSetItemsAddOns
		CREATE TABLE #OrderSetItemResult
		(
			GroupID BIGINT IDENTITY (1, 1)
			,OrderSetItemId BIGINT
		)
 
		CREATE TABLE #tmpOrderSets
		(
			ID BIGINT IDENTITY
			,OrderSetId BIGINT
			,SetName VARCHAR(MAX)
			,GroupID BIGINT
		)
 
		CREATE TABLE #tmpOrderSetItems
		(
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
			,OfferId int
			,InstantUnitPrice NUMERIC(18, 2)
			,InstantWidth NUMERIC(18, 2)
			,InstantHeight NUMERIC(18, 2)
			,InstantDepth NUMERIC(18, 2)
			,InstantDiameter NUMERIC(18, 2)
			,InstantCostPrice NUMERIC(18, 2)
		)
 
		CREATE TABLE #tmpOrderSetItemsAddOns
		(
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
			,OfferId int
		    ,InstantUnitPrice NUMERIC(18, 2)
			,InstantWidth NUMERIC(18, 2)
			,InstantHeight NUMERIC(18, 2)
			,InstantDepth NUMERIC(18, 2)
			,InstantDiameter NUMERIC(18, 2)
		    ,InstantCostPrice NUMERIC(18, 2)
		)
 
		INSERT INTO #tmpOrderSets
		(
			OrderSetId
			,SetName
			,GroupID
		)
		SELECT OrderSetId
			,SetName
			,GroupID
		FROM OPENJSON(@JsonObject, '$.OrderSetRequestDto')
		WITH (
				OrderSetId NVARCHAR(MAX) '$.OrderSetId'
				,SetName NVARCHAR(MAX) '$.SetName'
				,GroupID NVARCHAR(MAX) '$.groupId'
			)
		ORDER BY GroupID
 
		INSERT INTO #tmpOrderSetItems
		(
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
		FROM OPENJSON(@JsonObject, '$.OrderSetRequestDto')
		WITH (
				OrderSetId NVARCHAR(MAX) '$.OrderSetId'
				,SetName NVARCHAR(MAX) '$.SetName'
				,GroupID NVARCHAR(MAX) '$.groupId'
				,OrderSetItems NVARCHAR(MAX) '$.OrderSetItemRequestDto' AS JSON
			) AS oss
		CROSS APPLY OPENJSON(OrderSetItems,'$')
		WITH (
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
				,AddOns NVARCHAR(MAX) '$.AddOns' AS JSON
			) AS osi
		ORDER BY osi.ParentGroupID, osi.GroupID
 
		INSERT INTO #tmpOrderSetItemsAddOns
		(
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
		FROM OPENJSON(@JsonObject, '$.OrderSetRequestDto')
		WITH (
				OrderSetId NVARCHAR(MAX) '$.OrderSetId'
				,SetName NVARCHAR(MAX) '$.SetName'
				,GroupID NVARCHAR(MAX) '$.groupId'
				,OrderSetItems NVARCHAR(MAX) '$.OrderSetItemRequestDto' AS JSON
			) AS oss
		CROSS APPLY OPENJSON(OrderSetItems,'$')
		WITH (
				OrderSetItemId NVARCHAR(MAX) '$.OrderSetItemId'
				,GroupID NVARCHAR(MAX) '$.groupId'
				,ParentGroupID NVARCHAR(MAX) '$.parentGroupId'
				,SubjectTypeId NVARCHAR(MAX) '$.SubjectTypeId'
				,SubjectId NVARCHAR(MAX) '$.SubjectId'
				,AddOns NVARCHAR(MAX) '$.AddOns' AS JSON
			) AS ossi
		CROSS APPLY OPENJSON(AddOns,'$')
		WITH (
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
			) AS osia
		ORDER BY ossi.ParentGroupID, osia.ParentGroupID, osia.GroupID
 
		BEGIN TRAN
			IF @OrderID = 0
			BEGIN
				--INSERT INTO ErrorLogs (UserID, TenantID, RequestPath, ErrorMessage, CreatedBy, CreatedDate, CreatedUTCDate)
				--SELECT @UserID, @TenantID, 'Insert', @JsonObject, @UserID, @DateOffset, @DateUtc
 
				TRUNCATE TABLE #OrderSetItemResult
 
				SELECT @OrderNo = dbo.GetOrderNumber(@OrderType, @TenantID)
 
				--Add Order
				INSERT INTO dbo.Orders
				(
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
					,IsBackOrder
					,TentativeDeliveryDate
				)
				SELECT @OrderNo
					,@CustomerID
					,0 --Inquiry
					,@TenantID
					,CASE WHEN @OrderType = 'R' THEN 1 ELSE 2 END
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
					,@isFromBackOrder
					,@TentativeDeliveryDate

				SELECT @NewOrderID = SCOPE_IDENTITY()

				IF @LumpsumDiscount IS NOT NULL  AND @LumpsumDiscount > 0
				BEGIN
						INSERT INTO dbo.ActivityLogs
						(
							SubjectTypeId
							,SubjectId
							,Description
							,Action
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT @OrderSubjectTypeId
							,@NewOrderID
							,'Lumpsum Discount has been added.'
							,'UPDATE'
							,@UserID
							,@DateOffset
							,@DateUtc
				END
				
				IF @NewOrderID > 0
				BEGIN
					--Add Order Comment
					IF ISNULL(@Comment, '') <> ''
					BEGIN
						INSERT INTO dbo.OrderComments
						(
							OrderId
							,Status
							,Comments
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT @NewOrderID
							,0 --Inquiry
							,@Comment
							,@UserID
							,@DateOffset
							,@DateUtc
					END

					--Add Order Remark
					IF ISNULL(@Remarks, '') <> ''
					BEGIN
						INSERT INTO dbo.OrderComments
						(
							OrderId
							,Status
							,Comments
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
							,Remarks
						)
						SELECT @NewOrderID
							,0 --Inquiry
							,''
							,@UserID
							,@DateOffset
							,@DateUtc
							,@Remarks
					END
 
					--Add Order Address
					IF @BillingAddressID > 0
					BEGIN
						INSERT INTO dbo.OrderAddresses
						(
							OrderId
							,CustomerAddressId
							,FirstName
							,LastName
							,EmailId
							,PhoneNumber
							,AddressType
							,Street1
							,Street2
							,Landmark
							,Area
							,City
							,State
							,ZipCode
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT TOP 1 @NewOrderID
							,ca.CustomerAddressId
							,c.FirstName
							,ISNULL(c.LastName, '')
							,c.EmailId
							,c.PhoneNumber
							,'Billing'
							,ca.Street1
							,ca.Street2
							,ca.Landmark
							,ca.Area
							,ca.City
							,ca.State
							,ca.ZipCode
							,@UserID
							,@DateOffset
							,@DateUtc
						FROM dbo.CustomerAddresses ca WITH (NOLOCK)
						INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
						WHERE ca.CustomerId = @CustomerID
						AND ca.CustomerAddressId = @BillingAddressID
					END
					ELSE
					BEGIN
						INSERT INTO dbo.OrderAddresses
						(
							OrderId
							,CustomerAddressId
							,FirstName
							,LastName
							,EmailId
							,PhoneNumber
							,AddressType
							,Street1
							,Street2
							,Landmark
							,Area
							,City
							,State
							,ZipCode
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT TOP 1 @NewOrderID
							,ca.CustomerAddressId
							,c.FirstName
							,ISNULL(c.LastName, '')
							,c.EmailId
							,c.PhoneNumber
							,'Billing'
							,ca.Street1
							,ca.Street2
							,ca.Landmark
							,ca.Area
							,ca.City
							,ca.State
							,ca.ZipCode
							,@UserID
							,@DateOffset
							,@DateUtc
						FROM dbo.CustomerAddresses ca WITH (NOLOCK)
						INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
						WHERE ca.CustomerId = @CustomerID
						AND ca.IsDefault = 1
						AND ca.IsDeleted = 0
					END
 
					IF @ShippingAddressID > 0
					BEGIN
						INSERT INTO dbo.OrderAddresses
						(
							OrderId
							,CustomerAddressId
							,FirstName
							,LastName
							,EmailId
							,PhoneNumber
							,AddressType
							,Street1
							,Street2
							,Landmark
							,Area
							,City
							,State
							,ZipCode
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT TOP 1 @NewOrderID
							,ca.CustomerAddressId
							,c.FirstName
							,ISNULL(c.LastName, '')
							,c.EmailId
							,c.PhoneNumber
							,'Shipping'
							,ca.Street1
							,ca.Street2
							,ca.Landmark
							,ca.Area
							,ca.City
							,ca.State
							,ca.ZipCode
							,@UserID
							,@DateOffset
							,@DateUtc
						FROM dbo.CustomerAddresses ca WITH (NOLOCK)
						INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
						WHERE ca.CustomerId = @CustomerID
						AND ca.CustomerAddressId = @ShippingAddressID
						AND ca.IsDeleted = 0
					END
					ELSE
					BEGIN
						INSERT INTO dbo.OrderAddresses
						(
							OrderId
							,CustomerAddressId
							,FirstName
							,LastName
							,EmailId
							,PhoneNumber
							,AddressType
							,Street1
							,Street2
							,Landmark
							,Area
							,City
							,State
							,ZipCode
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT TOP 1 @NewOrderID
							,ca.CustomerAddressId
							,c.FirstName
							,ISNULL(c.LastName, '')
							,c.EmailId
							,c.PhoneNumber
							,'Shipping'
							,ca.Street1
							,ca.Street2
							,ca.Landmark
							,ca.Area
							,ca.City
							,ca.State
							,ca.ZipCode
							,@UserID
							,@DateOffset
							,@DateUtc
						FROM dbo.CustomerAddresses ca WITH (NOLOCK)
						INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
						WHERE ca.CustomerId = @CustomerID
						AND ca.IsDefault = 1
						AND ca.IsDeleted = 0
					END
 
					--Create Order Activity Log
					INSERT INTO dbo.ActivityLogs
					(
						SubjectTypeId
						,SubjectId
						,Description
						,Action
						,CreatedBy
						,CreatedDate
						,CreatedUTCDate
					)
					SELECT @OrderSubjectTypeId
						,@NewOrderID
						,'Inquiry has been created.'
						,'CREATE'
						,@UserID
						,@DateOffset
						,@DateUtc
				END
			END
			ELSE
			BEGIN
				--INSERT INTO ErrorLogs (UserID, TenantID, RequestPath, ErrorMessage, CreatedBy, CreatedDate, CreatedUTCDate)
				--SELECT @UserID, @TenantID, 'Update', @JsonObject, @UserID, @DateOffset, @DateUtc
 
				TRUNCATE TABLE #OrderSetItemResult
 
				SELECT @NewOrderID = @OrderID
 
				IF EXISTS (SELECT 1 FROM dbo.Orders WITH (NOLOCK) WHERE OrderId = @NewOrderID)
				BEGIN
					DECLARE @Status INT
 
					SELECT @Status = o.Status
					FROM dbo.Orders o WITH (NOLOCK)
					WHERE o.OrderId = @NewOrderID
					--Update Order
					UPDATE o
					SET o.IsFreeDelivery = ISNULL(@IsFreeDelivery, 0)
						,o.GSTType = @GSTType
						,o.CustomerID = @CustomerId
						--,o.RefferedBy = @ReferedByID
						,o.TentativeDeliveryDate = @TentativeDeliveryDate
						,o.LumpsumDiscount = @LumpsumDiscount
						,o.DeliveryCharge = @DeliveryCharge
						,o.DeliveryAmount = @DeliveryAmount
						,o.DeliveryAmountCollectionType = @DeliveryAmountCollectionType
						,o.LocationID = @LocationID
					FROM dbo.Orders o
					WHERE o.OrderId = @NewOrderID

					--Add Order Comment
					IF ISNULL(@Comment, '') <> ''
					BEGIN
						INSERT INTO dbo.OrderComments
						(
							OrderId
							,Status
							,Comments
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT @NewOrderID
							,@Status
							,@Comment
							,@UserID
							,@DateOffset
							,@DateUtc
					END

					--Add Order Remarks
					IF ISNULL(@Remarks, '') <> ''
					BEGIN
						INSERT INTO dbo.OrderComments
						(
							OrderId
							,Status
							,Comments
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
							,Remarks
						)
						SELECT @NewOrderID
							,@Status
							,''
							,@UserID
							,@DateOffset
							,@DateUtc
							,@Remarks
					END
 
					--Add Order Address
					SELECT @OrderAddressId = 0
					SELECT @OrderAddressId = oa.OrderAddressId
					FROM dbo.OrderAddresses oa WITH (NOLOCK)
					WHERE oa.OrderId = @NewOrderID
					AND oa.AddressType = 'Billing'
 
					IF @OrderAddressId > 0
					BEGIN
						IF @BillingAddressID > 0
						BEGIN
							UPDATE oa
							SET oa.CustomerAddressId = ca.CustomerAddressId
								,oa.FirstName = c.FirstName
								,oa.LastName = ISNULL(c.LastName, '')
								,oa.EmailId = c.EmailId
								,oa.PhoneNumber = c.PhoneNumber
								,oa.Street1 = ca.Street1
								,oa.Street2 = ca.Street2
								,oa.Landmark = ca.Landmark
								,oa.Area = ca.Area
								,oa.City = ca.City
								,oa.State = ca.State
								,oa.ZipCode = ca.ZipCode
								,oa.UpdatedBy = @UserID
								,oa.UpdatedDate = @DateOffset
								,oa.UpdatedUTCDate = @DateUtc
							FROM dbo.OrderAddresses oa
							INNER JOIN dbo.CustomerAddresses ca WITH (NOLOCK) ON ca.CustomerId = @CustomerID
								AND ca.CustomerAddressId = @BillingAddressID
							INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
							WHERE oa.OrderAddressId = @OrderAddressId
						END
						ELSE
						BEGIN
							;WITH cte AS (
								SELECT TOP 1 @NewOrderID AS OrderID
									,ca.CustomerAddressId
									,c.FirstName
									,c.LastName
									,c.EmailId
									,c.PhoneNumber
									,ca.Street1
									,ca.Street2
									,ca.Landmark
									,ca.Area
									,ca.City
									,ca.State
									,ca.ZipCode
								FROM dbo.CustomerAddresses ca WITH (NOLOCK)
								INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
								WHERE ca.CustomerId = @CustomerID
								AND ca.IsDefault = 1
								AND ca.IsDeleted = 0
							)
							UPDATE oa
							SET oa.CustomerAddressId = c.CustomerAddressId
								,oa.FirstName = c.FirstName
								,oa.LastName = ISNULL(c.LastName, '')
								,oa.EmailId = c.EmailId
								,oa.PhoneNumber = c.PhoneNumber
								,oa.Street1 = c.Street1
								,oa.Street2 = c.Street2
								,oa.Landmark = c.Landmark
								,oa.Area = c.Area
								,oa.City = c.City
								,oa.State = c.State
								,oa.ZipCode = c.ZipCode
								,oa.UpdatedBy = @UserID
								,oa.UpdatedDate = @DateOffset
								,oa.UpdatedUTCDate = @DateUtc
							FROM dbo.OrderAddresses oa
							INNER JOIN cte c ON c.OrderID = oa.OrderID
								AND oa.AddressType = 'Billing'
						END
					END
					ELSE
					BEGIN
						INSERT INTO dbo.OrderAddresses
						(
							OrderId
							,CustomerAddressId
							,FirstName
							,LastName
							,EmailId
							,PhoneNumber
							,AddressType
							,Street1
							,Street2
							,Landmark
							,Area
							,City
							,State
							,ZipCode
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT TOP 1 @NewOrderID
							,ca.CustomerAddressId
							,c.FirstName
							,ISNULL(c.LastName, '')
							,c.EmailId
							,c.PhoneNumber
							,'Billing'
							,ca.Street1
							,ca.Street2
							,ca.Landmark
							,ca.Area
							,ca.City
							,ca.State
							,ca.ZipCode
							,@UserID
							,@DateOffset
							,@DateUtc
						FROM dbo.CustomerAddresses ca WITH (NOLOCK)
						INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
						WHERE ca.CustomerId = @CustomerID
						AND ca.CustomerAddressId = @BillingAddressID
						AND ca.IsDeleted = 0
					END
 
					SELECT @OrderAddressId = 0
					SELECT @OrderAddressId = oa.OrderAddressId
					FROM dbo.OrderAddresses oa WITH (NOLOCK)
					WHERE oa.OrderId = @NewOrderID
					AND oa.AddressType = 'Shipping'
 
					IF @OrderAddressId > 0
					BEGIN
						IF @ShippingAddressID > 0
						BEGIN
							UPDATE oa
							SET oa.CustomerAddressId = ca.CustomerAddressId
								,oa.FirstName = c.FirstName
								,oa.LastName = ISNULL(c.LastName, '')
								,oa.EmailId = c.EmailId
								,oa.PhoneNumber = c.PhoneNumber
								,oa.Street1 = ca.Street1
								,oa.Street2 = ca.Street2
								,oa.Landmark = ca.Landmark
								,oa.Area = ca.Area
								,oa.City = ca.City
								,oa.State = ca.State
								,oa.ZipCode = ca.ZipCode
								,oa.UpdatedBy = @UserID
								,oa.UpdatedDate = @DateOffset
								,oa.UpdatedUTCDate = @DateUtc
							FROM dbo.OrderAddresses oa
							INNER JOIN dbo.CustomerAddresses ca WITH (NOLOCK) ON ca.CustomerId = @CustomerID
								AND ca.CustomerAddressId = @ShippingAddressID
							INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
							WHERE oa.OrderAddressId = @OrderAddressId
						END
						ELSE
						BEGIN
							;WITH cte AS (
								SELECT TOP 1 @NewOrderID AS OrderID
									,ca.CustomerAddressId
									,c.FirstName
									,c.LastName
									,c.EmailId
									,c.PhoneNumber
									,ca.Street1
									,ca.Street2
									,ca.Landmark
									,ca.Area
									,ca.City
									,ca.State
									,ca.ZipCode
								FROM dbo.CustomerAddresses ca WITH (NOLOCK)
								INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
								WHERE ca.CustomerId = @CustomerID
								AND ca.IsDefault = 1
								AND ca.IsDeleted = 0
							)
							UPDATE oa
							SET oa.CustomerAddressId = c.CustomerAddressId
								,oa.FirstName = c.FirstName
								,oa.LastName = ISNULL(c.LastName, '')
								,oa.EmailId = c.EmailId
								,oa.PhoneNumber = c.PhoneNumber
								,oa.Street1 = c.Street1
								,oa.Street2 = c.Street2
								,oa.Landmark = c.Landmark
								,oa.Area = c.Area
								,oa.City = c.City
								,oa.State = c.State
								,oa.ZipCode = c.ZipCode
								,oa.UpdatedBy = @UserID
								,oa.UpdatedDate = @DateOffset
								,oa.UpdatedUTCDate = @DateUtc
							FROM dbo.OrderAddresses oa
							INNER JOIN cte c ON c.OrderID = oa.OrderID
								AND oa.AddressType = 'Shipping'
						END
					END
					ELSE
					BEGIN
						INSERT INTO dbo.OrderAddresses
						(
							OrderId
							,CustomerAddressId
							,FirstName
							,LastName
							,EmailId
							,PhoneNumber
							,AddressType
							,Street1
							,Street2
							,Landmark
							,Area
							,City
							,State
							,ZipCode
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
						)
						SELECT TOP 1 @NewOrderID
							,ca.CustomerAddressId
							,c.FirstName
							,ISNULL(c.LastName, '')
							,c.EmailId
							,c.PhoneNumber
							,'Shipping'
							,ca.Street1
							,ca.Street2
							,ca.Landmark
							,ca.Area
							,ca.City
							,ca.State
							,ca.ZipCode
							,@UserID
							,@DateOffset
							,@DateUtc
						FROM dbo.CustomerAddresses ca WITH (NOLOCK)
						INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = ca.CustomerId
						WHERE ca.CustomerId = @CustomerID
						AND ca.CustomerAddressId = @ShippingAddressID
						AND ca.IsDeleted = 0
					END
					
					/*
					--Create Order Activity Log
					INSERT INTO dbo.ActivityLogs
					(
						SubjectTypeId
						,SubjectId
						,Description
						,Action
						,CreatedBy
						,CreatedDate
						,CreatedUTCDate
					)
					SELECT @OrderSubjectTypeId
						,@NewOrderID
						,'Order has been updated.'
						,'UPDATE'
						,@UserID
						,@DateOffset
						,@DateUtc
					*/
				END
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
					,@DefaultProductVendorId =  NULL
 
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
 
					--SELECT * FROM #tmpOrderSets
					--WHERE ID = @incSets
 
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
						INSERT INTO dbo.OrderSets
						(
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
 
						--UPDATE #tmpOrderSets
						--SET OrderSetId = @NewOrderSetId
						--WHERE ID = @incSets
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
						LEFT JOIN ProductVendorMapping AS pvm on  pvm.ProductId = #tmpOrderSetItems.SubjectId 
						AND pvm.IsDefault = 1
						AND #tmpOrderSetItems.SubjectTypeId = @ProductSubjectTypeId
						WHERE OrderSetGroupID = @OrderSetGroupID
						AND GroupID = @incSetItems
 
						PRINT(@DefaultProductVendorId)
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
							INSERT INTO dbo.OrderSetItems
							(
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
								,'' AS ProductImage
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
							FROM #tmpOrderSetItems osi
							WHERE GroupID = @incSetItems
							AND OrderSetGroupID = @OrderSetGroupID
 
							SELECT @NewOrderSetItemId = SCOPE_IDENTITY()
 
							--UPDATE #tmpOrderSetItems
							--SET OrderSetItemId = @NewOrderSetItemId
							--WHERE GroupID = @incSetItems
							--AND OrderSetGroupID = @OrderSetGroupID
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
 
							--SELECT *
							--FROM #tmpOrderSetItemsAddOns
							--WHERE OrderSetItemGroupID = @OrderSetItemGroupId
							--AND OrderSetGroupID = @OrderSetGroupID
							--AND GroupID = @incSetItemAddOns

							SELECT @DefaultProductVendorId = pvm.VendorId
							FROM #tmpOrderSetItemsAddOns
							LEFT JOIN ProductVendorMapping AS pvm on  pvm.ProductId = #tmpOrderSetItemsAddOns.SubjectId 
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
								INSERT INTO dbo.OrderSetItems
								(
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
									,'' AS ProductImage
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
								FROM #tmpOrderSetItemsAddOns osia
								WHERE OrderSetItemGroupID = @OrderSetItemGroupId
								AND OrderSetGroupID = @OrderSetGroupID
								AND GroupID = @incSetItemAddOns
 
								SELECT @NewOrderSetItemAddOnId = SCOPE_IDENTITY()
							END
							SET @incSetItemAddOns = @incSetItemAddOns + 1
						END
 
						SET @incSetItems = @incSetItems + 1
					END
 
					SET @incSets = @incSets + 1
				END
 
				IF @RefreshInquiry = 1
				BEGIN
					--Add Product Image in OrderSetItem
					UPDATE osi
					SET osi.GST = IIF(osi.ParentOrderSetItemId IS NULL, c.GST, 18)
					FROM dbo.OrderSetItems osi
					INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
					INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
					LEFT JOIN dbo.ProductImages pii WITH (NOLOCK) ON pii.ProductId = osi.SubjectId
						AND pii.IsCover = 1
					WHERE osi.SubjectTypeId = @ProductSubjectTypeId
					AND osi.IsDeleted = 0
					AND osi.OrderId = @NewOrderID
 
					--Add Fabric Image in OrderSetItem
					UPDATE osi
					SET osi.GST = IIF(osi.ParentOrderSetItemId IS NULL, f.GST, 18)
					FROM dbo.OrderSetItems osi
					INNER JOIN dbo.Fabrics f WITH (NOLOCK) ON f.FabricId = osi.SubjectId
					WHERE osi.SubjectTypeId = @FabricSubjectTypeId
					AND osi.IsDeleted = 0
					AND osi.OrderId = @NewOrderID
 
					--Add Polish Image in OrderSetItem
					UPDATE osi
					SET osi.GST = IIF(osi.ParentOrderSetItemId IS NULL, p.GST, 18)
					FROM dbo.OrderSetItems osi
					INNER JOIN dbo.Polish p WITH (NOLOCK) ON p.PolishId = osi.SubjectId
					WHERE osi.SubjectTypeId = @PolishSubjectTypeId
					AND osi.IsDeleted = 0
					AND osi.OrderId = @NewOrderID
				END
				ELSE
				BEGIN
					--Add Product Image in OrderSetItem
					UPDATE osi
					SET osi.ProductImage = pii.ImagePath
						,osi.GST = IIF(osi.ParentOrderSetItemId IS NULL, c.GST, 18)
					FROM dbo.OrderSetItems osi
					INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
					INNER JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
					LEFT JOIN dbo.ProductImages pii WITH (NOLOCK) ON pii.ProductId = osi.SubjectId
						AND pii.IsCover = 1
					WHERE osi.SubjectTypeId = @ProductSubjectTypeId
					AND osi.OrderId = @NewOrderID
					AND osi.IsDeleted = 0
					AND osi.UpdatedBy IS NULL
 
					--Add Fabric Image in OrderSetItem
					UPDATE osi
					SET osi.ProductImage = f.ImagePath
						,osi.GST = IIF(osi.ParentOrderSetItemId IS NULL, f.GST, 18)
					FROM dbo.OrderSetItems osi
					INNER JOIN dbo.Fabrics f WITH (NOLOCK) ON f.FabricId = osi.SubjectId
					WHERE osi.SubjectTypeId = @FabricSubjectTypeId
					AND osi.OrderId = @NewOrderID
					AND osi.IsDeleted = 0
					AND osi.UpdatedBy IS NULL
 
					--Add Polish Image in OrderSetItem
					UPDATE osi
					SET osi.ProductImage = p.ImagePath
						,osi.GST = IIF(osi.ParentOrderSetItemId IS NULL, p.GST, 18)
					FROM dbo.OrderSetItems osi
					INNER JOIN dbo.Polish p WITH (NOLOCK) ON p.PolishId = osi.SubjectId
					WHERE osi.SubjectTypeId = @PolishSubjectTypeId
					AND osi.OrderId = @NewOrderID
					AND osi.IsDeleted = 0
					AND osi.UpdatedBy IS NULL
				END
 
				--Delete OrderProductCharges
				DELETE FROM dbo.OrderProductCharges
				WHERE OrderId = @NewOrderID
 
				--Add RawMaterials in OrderProductCharges
				INSERT INTO dbo.OrderProductCharges
				(
					OrderId
					,OrderSetItemId
					,EntityTypeId
					,EntityId
					,Price
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
				)
				SELECT @NewOrderID
					,osi.OrderSetItemId
					,pm.SubjectTypeId
					,pm.SubjectId
					,pm.Qty * rm.UnitPrice AS Price
					,@UserID
					,@DateOffset
					,@DateUtc
				FROM OrderSetItems osi WITH (NOLOCK)
				INNER JOIN ProductMaterials pm WITH (NOLOCK) ON pm.ProductId = osi.SubjectId
				INNER JOIN RawMaterials rm WITH (NOLOCK) ON rm.RawMaterialId = pm.SubjectId
				WHERE osi.OrderId = @NewOrderID
				AND osi.SubjectTypeId = @ProductSubjectTypeId
				AND pm.SubjectTypeId = @RawMaterialSubjectTypeId
 
				--Add Polish in OrderProductCharges
				INSERT INTO dbo.OrderProductCharges
				(
					OrderId
					,OrderSetItemId
					,EntityTypeId
					,EntityId
					,Price
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
				)
				SELECT @NewOrderID
					,osi.OrderSetItemId
					,pm.SubjectTypeId
					,pm.SubjectId
					,pm.Qty * p.UnitPrice AS Price
					,@UserID
					,@DateOffset
					,@DateUtc
				FROM OrderSetItems osi WITH (NOLOCK)
				INNER JOIN ProductMaterials pm WITH (NOLOCK) ON pm.ProductId = osi.SubjectId
				INNER JOIN Polish p WITH (NOLOCK) ON p.PolishId = pm.SubjectId
				WHERE osi.OrderId = @NewOrderID
				AND osi.SubjectTypeId = @ProductSubjectTypeId
				AND pm.SubjectTypeId = @PolishSubjectTypeId
 
				--Add Labours in OrderProductCharges
				INSERT INTO dbo.OrderProductCharges
				(
					OrderId
					,OrderSetItemId
					,EntityTypeId
					,EntityId
					,Price
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
				)
				SELECT @NewOrderID
					,osi.OrderSetItemId
					,@LabourSubjectTypeId
					,pl.ProductLabourId
					,pl.Amount AS Price
					,@UserID
					,@DateOffset
					,@DateUtc
				FROM OrderSetItems osi WITH (NOLOCK)
				INNER JOIN ProductLabours pl WITH (NOLOCK) ON pl.ProductId = osi.SubjectId
				WHERE osi.OrderId = @NewOrderID
				AND pl.IsDeleted = 0
 
				--Update GST Calculation
				EXEC dbo.UpdateOrderGST
					@OrderID = @NewOrderID
					,@GSTType = @GSTType
					,@UserID = @UserID
					,@TenantID = @TenantID

					--Create Archive Entries
					EXEC dbo.SaveArchive_Order
						@OrderID = @NewOrderID,
						@UserId = @UserID
			END


			UPDATE os
			SET InteriorCommission = x.InteriorCommission
			FROM OrderSetItems os
			CROSS APPLY dbo.fn_CalculateInteriorCommission (@OrderID) x
			WHERE os.OrderSetItemId = x.OrderSetItemId

			UPDATE os
			SET SalesmanCommission = x.SalesmanCommission
			FROM OrderSetItems os
			CROSS APPLY dbo.fn_CalculateSalesmanCommission (@OrderID) x
			WHERE os.OrderSetItemId = x.OrderSetItemId
			
		COMMIT TRAN
 
		IF OBJECT_ID('tempdb..#OrderSetItemResult') IS NOT NULL
			DROP TABLE #OrderSetItemResult
 
		IF OBJECT_ID('tempdb..#tmpOrderSets') IS NOT NULL
			DROP TABLE #tmpOrderSets
 
		IF OBJECT_ID('tempdb..#tmpOrderSetItems') IS NOT NULL
			DROP TABLE #tmpOrderSetItems
 
		IF OBJECT_ID('tempdb..#tmpOrderSetItemsAddOns') IS NOT NULL
			DROP TABLE #tmpOrderSetItemsAddOns
 
	END TRY
BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

