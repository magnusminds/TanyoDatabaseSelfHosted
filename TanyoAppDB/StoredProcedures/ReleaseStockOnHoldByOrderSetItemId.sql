CREATE PROCEDURE [dbo].[ReleaseStockOnHoldByOrderSetItemId]
(
	@OrderSetItemId BIGINT
	,@OrderId BIGINT
	,@UserId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
		

	BEGIN TRY
	DECLARE @NowUTC DATETIME = GETUTCDATE();
	DECLARE @NowUTCOffset DATETIMEOFFSET = SYSDATETIMEOFFSET();
	DECLARE @TenantId INT
	DECLARE @SalesmanId INT
	DECLARE @AnnouncementId BIGINT 
	DECLARE @ProductId BIGINT
	DECLARE @HoldQuantity NUMERIC(18,2)
	DECLARE @OldQty NUMERIC(18,2)
	DECLARE @OrderNo VARCHAR(50)
	DECLARE @LogDescription VARCHAR(500)

	-- Check Stock on Hold and Release if any
	IF EXISTS (
		SELECT 1
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN StockOnHold soh WITH (NOLOCK) ON soh.OrderSetItemId = osi.OrderSetItemId
			AND soh.IsStockOnHold = 1
		WHERE osi.OrderSetItemId = @OrderSetItemId
			AND osi.OrderId = @OrderId
	)
	BEGIN

		SELECT @TenantId = o.TenantId
			,@ProductId = osi.SubjectId
			,@HoldQuantity = osi.Quantity
			,@OrderNo = o.OrderNo
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
		WHERE osi.OrderSetItemId = @OrderSetItemId
		AND osi.OrderId = @OrderId

		SELECT @OldQty = Quantity
		FROM ProductQuantities WITH (NOLOCK)
		WHERE ProductId = @ProductId

		SET @LogDescription = 'Inventory released from hold and updated from ' + CAST(@OldQty AS VARCHAR(20)) + ' to ' + CAST((@OldQty + @HoldQuantity) AS VARCHAR(20)) + ' ( + ' + CAST(@HoldQuantity AS VARCHAR(20)) + ' ) for ' + @OrderNo + '.'

		-- Add back to ProductQuantities + its own InventoryLogs entry
		EXEC dbo.AddProductSaleableQuantity
			@TenantId = @TenantId
			,@UserId = @UserId
			,@ProductId = @ProductId
			,@Quantity = @HoldQuantity
			,@Description = @LogDescription

		UPDATE osi
		SET osi.IsQuantityOnHold = 0
			,osi.UpdatedBy = @UserId
			,osi.UpdatedDate = @NowUTCOffset
			,osi.UpdatedUTCDate = @NowUTC
		FROM OrderSetItems osi
		WHERE osi.OrderSetItemId = @OrderSetItemId
		AND osi.OrderId = @OrderId

		UPDATE SOH
		SET SOH.IsStockOnHold = 0
			,SOH.UpdatedBy = @UserId
			,SOH.UpdatedUTCDate = @NowUTC
			,SOH.UpdatedDate = @NowUTCOffset
		FROM StockOnHold soh
		WHERE soh.OrderSetItemId = @OrderSetItemId
		AND soh.OrderId = @OrderId
		AND soh.IsStockOnHold = 1

		--Send Announcement to all Salesman
		INSERT INTO Announcements
		(
			Message
			,TenantId
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
		)
		SELECT PT.ProductTitle +' ( '+ PT.ModelNo +' ) - Quantity '+ CAST(soh.Quantity AS VARCHAR(128))+ ' has been released.'
			,o.TenantId
			,O.SalesmanId
			,@NowUTCOffset
			,@NowUTC
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
		INNER JOIN StockOnHold soh WITH (NOLOCK) ON soh.OrderSetItemId = osi.OrderSetItemId
		INNER JOIN Products PT WITH (NOLOCK) ON PT.ProductId = OSI.SubjectId
		WHERE osi.OrderSetItemId = @OrderSetItemId
		AND osi.OrderId = @OrderId

		SET @AnnouncementId = SCOPE_IDENTITY()

		SELECT u.UserId AS SalesmanId
		INTO #SalesManUserId
		FROM AspNetUsers U WITH (NOLOCK)
		INNER JOIN UserTenantMapping UTM WITH (NOLOCK) ON U.UserId = UTM.UserId AND UTM.IsDeleted = 0
		INNER JOIN AspNetUserRoles UR WITH (NOLOCK) ON UR.UserId = U.Id
		INNER JOIN AspNetRoles R WITH (NOLOCK) ON R.Id = UR.RoleId
		WHERE LOWER(R.Name) = 'SalesRepresentative_' + cast (@TenantId as varchar(128))
		AND u.IsDeleted = 0
		AND u.IsActive = 1
		AND r.TenantId = @TenantId
		AND UTM.TenantId = @TenantId 

		INSERT INTO AnnouncementsUserMapping
		(
			AnnouncementId
			,NotificationType
			,IsRead
			,SentTo
			,SentBy
			,ApplicationType
			,TenantId
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
		)
		SELECT 
			@AnnouncementId
			,'ReleaseStock'
			,0
			,SalesmanId
			,@UserId
			,2 
			,@TenantId
			,@UserId
			,@NowUTCOffset
			,@NowUTC
		FROM #SalesManUserId
	END

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

