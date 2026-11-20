/*
	EXEC [dbo].[GetProductStockDetails]
		@TenantId = 1
		,@ProductId = 199 
		,@WarehouseId = NULL
*/
CREATE PROCEDURE [dbo].[GetProductStockDetails]
(
	@TenantId BIGINT
	,@ProductId BIGINT
	,@WarehouseId BIGINT = NULL
)
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @dt DATETIMEOFFSET
	DECLARE @ProductSubjectTypeId INT

	DECLARE @InStockCnt NUMERIC(18,2)
		,@InquiryCnt NUMERIC(18,2)
		,@ReadyToDelivered NUMERIC(18,2)
		,@OnHoldCnt NUMERIC(18,2)

	SELECT @dt = SYSDATETIMEOFFSET()

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId
		AND IsDeleted = 0
	
	SELECT @InStockCnt = CAST(
			CASE 
				WHEN @WarehouseId IS NOT NULL THEN
					ISNULL((
						SELECT SUM(pqbw.Quantity)
						FROM ProductQuantitiesByWarehouse pqbw						
						WHERE pqbw.ProductId = @ProductId
						  AND pqbw.WarehouseId = @WarehouseId
					), 0)
				ELSE
					ISNULL(ia.Quantity, 0)
			END AS NUMERIC(18,2)
		)
	FROM ProductQuantities ia WITH (NOLOCK)
	WHERE ia.ProductId = @ProductId

	SELECT @InquiryCnt = ISNULL(SUM(vi.Quantity),0)
	FROM vw_InquiryItems vi WITH (NOLOCK)
	WHERE vi.TenantId = @TenantId
	AND vi.SubjectTypeId = @ProductSubjectTypeId
	AND vi.SubjectId = @ProductId

	--SELECT @ReadyToDelivered = ISNULL(SUM(vi.Quantity),0)
	--FROM vw_ReadyToDeliveredItems vi WITH (NOLOCK)
	--WHERE vi.TenantId = @TenantId
	--AND vi.SubjectTypeId = @ProductSubjectTypeId
	--AND vi.SubjectId = @ProductId

	SELECT @ReadyToDelivered = ISNULL(SUM(os.Quantity),0)
    FROM dbo.Orders o WITH (NOLOCK)
	INNER JOIN dbo.OrderSetItems os WITH (NOLOCK) ON os.OrderId = o.OrderId
	WHERE o.TenantId = @TenantId
	AND os.IsDeleted = 0
	AND os.SubjectId = @ProductId
    AND os.SubjectTypeId = @ProductSubjectTypeId
    AND (o.Status IN (3) AND os.ItemStatus = 2) --Order: InProgress, Item: Ready to Deliver

	SELECT @OnHoldCnt = ISNULL(SUM(vi.Quantity),0)
	FROM vw_HoldItems vi WITH (NOLOCK)
	WHERE vi.TenantId = @TenantId
	AND vi.HoldUptoDate > @dt
	AND vi.SubjectId = @ProductId

	SELECT p.ProductId
		,p.ProductTitle
		,p.ModelNo
		,@InStockCnt AS InStock
		,@InquiryCnt AS Inquiry
		,@ReadyToDelivered AS ReadyToDelivered
		,@OnHoldCnt AS OnHold
	FROM Products p WITH (NOLOCK)
	WHERE p.TenantId = @TenantId
	AND p.ProductId = @ProductId

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

