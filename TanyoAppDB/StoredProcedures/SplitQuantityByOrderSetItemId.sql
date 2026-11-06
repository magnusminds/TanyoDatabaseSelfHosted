/*
	EXEC dbo.SplitQuantityByOrderSetItemId
		@OrderSetItemId = 35632
		,@OrderId = 53458
		,@SplitQuantity = 1
		,@TenantId = 2
		,@UserId = 4279
*/
CREATE     PROC [dbo].[SplitQuantityByOrderSetItemId]
(
	@OrderSetItemId BIGINT
	,@OrderId BIGINT
	,@SplitQuantity BIGINT
	,@TenantId BIGINT
	,@UserId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY

	--Product split quantity only allow if order is "In Progress" status
	IF EXISTS
	(
		SELECT TOP 1 1
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
		WHERE osi.OrderSetItemId = @OrderSetItemId
		AND o.OrderId = @OrderId
		AND o.Status IN (0, 1, 2, 8, 9)
		AND o.TenantId = @TenantId
	)
	BEGIN
		SELECT -1 AS [Status]
			,'Product is not allowed for split quantity.' AS [Message]

		RETURN
	END

	--Product split quantity only allow if item don't have add-ons
	IF EXISTS
	(
		SELECT TOP 1 1
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
		WHERE osi.OrderSetItemId = @OrderSetItemId
		AND o.OrderId = @OrderId
		AND o.TenantId = @TenantId
		AND osi.ParentOrderSetItemId IS NOT NULL
	)
	BEGIN
		SELECT -2 AS [Status]
			,'Product with add-on is not allowed for split quantity.' AS [Message]

		RETURN
	END

	DECLARE @CurrentQuantity NUMERIC(18 ,2)
		,@UpdateQuantity NUMERIC(18 ,2)
		,@GSTType BIT
		,@OrderNo VARCHAR(20)
		,@DeliveryNo VARCHAR(50)
		,@NewOrderSetItemId BIGINT
		,@SubjectTypeId BIGINT
		,@SubjectId BIGINT
		,@DateUtc DATETIME = GETUTCDATE()
		,@DateOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()

	SELECT @CurrentQuantity = osi.Quantity
		,@GSTType = o.GSTType
		,@OrderNo = o.OrderNo
		,@SubjectTypeId = osi.SubjectTypeId
		,@SubjectId = osi.SubjectId
	FROM OrderSetItems osi WITH (NOLOCK)
	INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
	WHERE osi.OrderSetItemId = @OrderSetItemId
	AND o.OrderId = @OrderId
	AND o.TenantId = @TenantId

	SELECT @UpdateQuantity = @CurrentQuantity - @SplitQuantity

	--Calculation for current order set item
	BEGIN
		UPDATE osi
		SET osi.Quantity = @UpdateQuantity
			,osi.GrossTotal = (osi.UnitPrice * @UpdateQuantity)
			,osi.Discount = ((osi.UnitPrice * @UpdateQuantity) * osi.DiscountPrice) / 100
			,osi.TotalAmount = (osi.UnitPrice * @UpdateQuantity) - (((osi.UnitPrice * @UpdateQuantity) * osi.DiscountPrice) / 100)
		FROM OrderSetItems osi
		WHERE osi.OrderSetItemId = @OrderSetItemId

		DECLARE @InteriorCommission TABLE
		(
			OrderSetItemId BIGINT
			,InteriorCommission NUMERIC(18,2)
		)

		INSERT INTO @InteriorCommission
		(
			OrderSetItemId
			,InteriorCommission
		)
		SELECT x.OrderSetItemId
			,x.InteriorCommission
		FROM dbo.fn_CalculateInteriorCommission(@OrderID) x

		UPDATE osi
		SET osi.InteriorCommission = x.InteriorCommission
		FROM OrderSetItems osi
		INNER JOIN @InteriorCommission x ON x.OrderSetItemId = osi.OrderSetItemId
		WHERE osi.OrderSetItemId = @OrderSetItemId

		DECLARE @SalesmanCommission TABLE
		(
			OrderSetItemId BIGINT
			,SalesmanCommission NUMERIC(18,2)
		)

		INSERT INTO @SalesmanCommission
		(
			OrderSetItemId
			,SalesmanCommission
		)
		SELECT x.OrderSetItemId
			,x.SalesmanCommission
		FROM dbo.fn_CalculateSalesmanCommission(@OrderID) x

		UPDATE osi
		SET osi.SalesmanCommission = x.SalesmanCommission
		FROM OrderSetItems osi
		INNER JOIN @SalesmanCommission x ON x.OrderSetItemId = osi.OrderSetItemId
		WHERE osi.OrderSetItemId = @OrderSetItemId

		IF @GSTType = 0
		BEGIN
			UPDATE osi
			SET osi.AmountBeforeGST = CAST((osi.TotalAmount * 100) / (100 + osi.GST) AS NUMERIC(18, 2))
				,osi.CGSTAmount = CAST(((osi.TotalAmount * osi.GST) / (100 + osi.GST)) / 2 AS NUMERIC(18, 2))
				,osi.SGSTAmount = CAST(((osi.TotalAmount * osi.GST) / (100 + osi.GST)) / 2 AS NUMERIC(18, 2))
				,osi.UpdatedBy = @UserID
				,osi.UpdatedDate = @DateOffset
				,osi.UpdatedUTCDate = @DateUtc
			FROM dbo.OrderSetItems osi
			WHERE osi.OrderSetItemId = @OrderSetItemId
		END
		ELSE
		BEGIN
			UPDATE osi
			SET osi.AmountBeforeGST = CAST(osi.TotalAmount AS NUMERIC(18, 2))
				,osi.CGSTAmount = CAST(((osi.TotalAmount * osi.GST) / 100) / 2 AS NUMERIC(18, 2))
				,osi.SGSTAmount = CAST(((osi.TotalAmount * osi.GST) / 100) / 2 AS NUMERIC(18, 2))
				,osi.UpdatedBy = @UserID
				,osi.UpdatedDate = @DateOffset
				,osi.UpdatedUTCDate = @DateUtc
			FROM dbo.OrderSetItems osi
			WHERE osi.OrderSetItemId = @OrderSetItemId
		END
	END

	--Calculation for new order set item
	BEGIN
		SELECT @DeliveryNo = @OrderNo + '_' + CAST(MAX(IIF(ISNULL(osi.DeliveryNo, '') <> '', CAST(RIGHT(osi.DeliveryNo, CHARINDEX('_', REVERSE(osi.DeliveryNo)) - 1) AS INT), 0)) + 1 AS VARCHAR(10))
		FROM OrderSetItems osi WITH (NOLOCK)
		WHERE osi.OrderId = @OrderId

		INSERT INTO OrderSetItems (ParentOrderSetItemId, OrderId, OrderSetId, DeliveryNo, SubjectTypeId, SubjectId, DeliveryDate, Quantity, UnitPrice, DiscountPrice, GrossTotal, Discount, TotalAmount, AmountBeforeGST, CGSTAmount, SGSTAmount, ProductImage, Width, Height, Depth, Diameter, Comment, ItemStatus, ReceiveDate, ProvidedMaterial, CreatedBy, CreatedDate, CreatedUTCDate, DeliveryComment, GST, CostPrice, IsDeleted, OfferId, InstantUnitPrice, InstantWidth, InstantHeight, InstantDepth, InstantDiameter, InstantCostPrice, ReadyToDeliveredDate, DefaultProductVendorId, IsQuantityOnHold, StockQty, DimensionUnitId)
		SELECT ParentOrderSetItemId
			,OrderId
			,OrderSetId
			,@DeliveryNo AS DeliveryNo
			,SubjectTypeId
			,SubjectId
			,DeliveryDate
			,@SplitQuantity AS Quantity
			,UnitPrice
			,DiscountPrice
			,(osi.UnitPrice * @SplitQuantity) AS GrossTotal
			,((osi.UnitPrice * @SplitQuantity) * osi.DiscountPrice) / 100 AS Discount
			,(osi.UnitPrice * @SplitQuantity) - (((osi.UnitPrice * @SplitQuantity) * osi.DiscountPrice) / 100) AS TotalAmount
			,0 AS AmountBeforeGST
			,0 AS CGSTAmount
			,0 AS SGSTAmount
			,ProductImage
			,Width
			,Height
			,Depth
			,Diameter
			,Comment
			,ItemStatus
			,ReceiveDate
			,ProvidedMaterial
			,@UserId
			,@DateOffset
			,@DateUtc
			,DeliveryComment
			,GST
			,CostPrice
			,IsDeleted
			,OfferId
			,InstantUnitPrice
			,InstantWidth
			,InstantHeight
			,InstantDepth
			,InstantDiameter
			,InstantCostPrice
			,ReadyToDeliveredDate
			,DefaultProductVendorId
			,IsQuantityOnHold
			,StockQty
			,DimensionUnitId
		FROM OrderSetItems osi WITH (NOLOCK)
		WHERE osi.OrderId = @OrderId
		AND osi.OrderSetItemId = @OrderSetItemId

		SELECT @NewOrderSetItemId = SCOPE_IDENTITY()

		INSERT INTO OrderSetItemImages (OrderSetItemId, DrawImage, CreatedBy, CreatedDate, CreatedUTCDate, FileType, FileURL)
		SELECT @NewOrderSetItemId
			,osii.DrawImage
			,@UserId
			,@DateOffset
			,@DateUtc
			,osii.FileType
			,osii.FileURL
		FROM OrderSetItemImages osii WITH (NOLOCK)
		WHERE osii.OrderSetItemId = @OrderSetItemId

		DECLARE @NewInteriorCommission TABLE
		(
			OrderSetItemId BIGINT
			,InteriorCommission NUMERIC(18,2)
		)

		INSERT INTO @NewInteriorCommission
		(
			OrderSetItemId
			,InteriorCommission
		)
		SELECT x.OrderSetItemId
			,x.InteriorCommission
		FROM dbo.fn_CalculateInteriorCommission(@OrderID) x

		UPDATE osi
		SET osi.InteriorCommission = x.InteriorCommission
		FROM OrderSetItems osi
		INNER JOIN @NewInteriorCommission x ON x.OrderSetItemId = osi.OrderSetItemId
		WHERE osi.OrderSetItemId = @NewOrderSetItemId

		DECLARE @NewSalesmanCommission TABLE
		(
			OrderSetItemId BIGINT
			,SalesmanCommission NUMERIC(18,2)
		)

		INSERT INTO @NewSalesmanCommission
		(
			OrderSetItemId
			,SalesmanCommission
		)
		SELECT x.OrderSetItemId
			,x.SalesmanCommission
		FROM dbo.fn_CalculateSalesmanCommission(@OrderID) x

		UPDATE osi
		SET osi.SalesmanCommission = x.SalesmanCommission
		FROM OrderSetItems osi
		INNER JOIN @NewSalesmanCommission x ON x.OrderSetItemId = osi.OrderSetItemId
		WHERE osi.OrderSetItemId = @NewOrderSetItemId

		IF @GSTType = 0
		BEGIN
			UPDATE osi
			SET osi.AmountBeforeGST = CAST((osi.TotalAmount * 100) / (100 + osi.GST) AS NUMERIC(18, 2))
				,osi.CGSTAmount = CAST(((osi.TotalAmount * osi.GST) / (100 + osi.GST)) / 2 AS NUMERIC(18, 2))
				,osi.SGSTAmount = CAST(((osi.TotalAmount * osi.GST) / (100 + osi.GST)) / 2 AS NUMERIC(18, 2))
				,osi.UpdatedBy = @UserID
				,osi.UpdatedDate = @DateOffset
				,osi.UpdatedUTCDate = @DateUtc
			FROM dbo.OrderSetItems osi
			WHERE osi.OrderSetItemId = @NewOrderSetItemId
		END
		ELSE
		BEGIN
			UPDATE osi
			SET osi.AmountBeforeGST = CAST(osi.TotalAmount AS NUMERIC(18, 2))
				,osi.CGSTAmount = CAST(((osi.TotalAmount * osi.GST) / 100) / 2 AS NUMERIC(18, 2))
				,osi.SGSTAmount = CAST(((osi.TotalAmount * osi.GST) / 100) / 2 AS NUMERIC(18, 2))
				,osi.UpdatedBy = @UserID
				,osi.UpdatedDate = @DateOffset
				,osi.UpdatedUTCDate = @DateUtc
			FROM dbo.OrderSetItems osi
			WHERE osi.OrderSetItemId = @NewOrderSetItemId
		END
	END

	--Activity Log
	DECLARE @OrderSubjectTypeId INT
		,@ProductSubjectTypeId INT
		,@ActivityMessage VARCHAR(MAX)

	SELECT @OrderSubjectTypeId = st.SubjectTypeId
	FROM SubjectTypes st WITH (NOLOCK)
	WHERE st.TenantId = @TenantID
	AND st.SubjectTypeName = 'Orders'

	SELECT @ProductSubjectTypeId = st.SubjectTypeId
	FROM SubjectTypes st WITH (NOLOCK)
	WHERE st.TenantId = @TenantID
	AND st.SubjectTypeName = 'Products'

	SELECT @ActivityMessage = 'Product ' + p.ProductTitle + ' quantity has been split.'
	FROM Products p WITH (NOLOCK)
	WHERE p.ProductId = @SubjectId
	AND @ProductSubjectTypeId = @SubjectTypeId
	
	EXEC dbo.SaveActivityLog @SubjectTypeId = @OrderSubjectTypeId
			,@SubjectId = @OrderId
			,@Description = @ActivityMessage
			,@Action = 'UPDATE'
			,@CreatedBy = @UserId
			,@CreatedDate = @DateOffset
			,@CreatedUTCDate = @DateUtc;

	SELECT 1 AS [Status]
		,'Product has been split successfully.' AS [Message]

    END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX)

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ErrorMsg = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog 
		     @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

	END CATCH

END

GO

