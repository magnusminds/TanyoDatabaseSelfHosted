CREATE PROCEDURE [dbo].[SaveArchive_Order] (
	@OrderID BIGINT
	,@UserId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @dt DATE

		SELECT @dt = GETDATE()

		--IF EXISTS (SELECT TOP 1 1 
		--		   FROM dbo.Orders o
		--		   WHERE o.OrderID = @OrderID 
		--		   AND o.CreatedDate BETWEEN  @dt AND DATEADD(d, 1, @dt)) 
		--		   And EXISTS (SELECT	a.OrderId
		--						FROM	dbo.Archive_Orders  a
		--						WHERE	a.OrderID = @OrderID)
		--BEGIN
		--	-- Return if the order was created today
		--	RETURN
		--END
		DECLARE @NewOrderVersionId INT = (
				SELECT ISNULL(MAX(VersionId), 0) + 1
				FROM dbo.Archive_Orders WITH (NOLOCK)
				WHERE OrderId = @OrderID
				);

		INSERT INTO dbo.Archive_Orders (
			VersionId
			,OrderId
			,OrderNo
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
			,TentativeDeliveryDate
			,ApprovedDate
			,DeliveryCharges
			,UpdatedBy
			,UpdatedDate
			,UpdatedUTCDate
			,SalesmanId
			,InteriorCommissionPer
			)
		SELECT @NewOrderVersionId
			,OrderID
			,OrderNo
			,CustomerID
			,Status
			,TenantID
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
			,AdvanceAmount
			,GSTTaxAmount
			,OfferDiscount
			,IsFreeDelivery
			,@UserId
			,CreatedDate
			,CreatedUTCDate
			,RefferedBy
			,LumpsumDiscount
			,DeliveryCharge
			,DeliveryAmount
			,DeliveryAmountCollectionType
			,TentativeDeliveryDate
			,ApprovedDate
			,DeliveryCharges
			,UpdatedBy
			,UpdatedDate
			,UpdatedUTCDate
			,SalesmanId
			,InteriorCommissionPer
		FROM dbo.Orders WITH (NOLOCK)
		WHERE OrderId = @OrderID;

		DECLARE @NewOrderSetVersionId INT = (
				SELECT ISNULL(MAX(VersionId), 0) + 1
				FROM dbo.Archive_OrderSets WITH (NOLOCK)
				WHERE OrderId = @OrderID
				);

		INSERT INTO dbo.Archive_OrderSets (
			VersionId
			,Archive_OrderVersionId
			,OrderSetId
			,OrderId
			,SetName
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			)
		SELECT @NewOrderSetVersionId
			,@NewOrderVersionId
			,OrderSetId
			,OrderID
			,SetName
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
		FROM OrderSets OS WITH (NOLOCK)
		WHERE OS.OrderId = @OrderID

		DECLARE @NewSetVersionId INT = (
				SELECT ISNULL(MAX(VersionId), 0) + 1
				FROM dbo.Archive_OrderSetItems WITH (NOLOCK)
				WHERE OrderId = @OrderID
				);

		INSERT INTO dbo.Archive_OrderSetItems (
			VersionId
			,Archive_OrderVersionId
			,Archive_OrderSetsVersionId
			,OrderId
			,OrderSetItemId
			,ParentOrderSetItemId
			,OrderSetId
			,SubjectTypeId
			,SubjectId
			,Width
			,Height
			,Depth
			,Diameter
			,DimensionUnitId
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
			,SalesmanCommission
			,InteriorCommission
			,OfferPercentage
			)
		SELECT @NewSetVersionId
			,@NewOrderVersionId
			,@NewOrderSetVersionId
			,OrderId
			,OrderSetItemId
			,ParentOrderSetItemId
			,OrderSetId
			,SubjectTypeId
			,SubjectId
			,Width
			,Height
			,Depth
			,Diameter
			,DimensionUnitId
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
			,SalesmanCommission
			,InteriorCommission
			,osi.OfferPercentage
		FROM OrderSetItems osi WITH (NOLOCK)
		WHERE osi.OrderId = @OrderID
			AND osi.IsDeleted = 0
			--SELECT *
			--FROM dbo.Archive_Orders
			--WHERE OrderId = @OrderID;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

