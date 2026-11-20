
/*
	EXEC [dbo].[CountOfManufacturing]
	 @CurrentUserId  = 449
	,@TenantId  = 1
	,@ManufacturingWorkflowId  = 5
	,@ManufacturingStatus  = 1
*/
CREATE   PROC [dbo].[CountOfManufacturing]
(
    @TenantId int
    ,@CurrentUserId bigint
    ,@ManufacturingWorkflowId int
    ,@ManufacturingStatus int
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;
		DECLARE @ProductSubjectTypeId INT;

	SELECT  @ProductSubjectTypeId = SubjectTypeId 
		FROM SubjectTypes 
		WHERE SubjectTypeName = 'Products' 
		AND TenantId =  @TenantId

	BEGIN TRY
		;WITH ManufacturingOrders AS ( 
			SELECT	x.OrderManufacturingWorkflowId AS ManufacturingOrderID,
				x.ManufacturingWorkflowId AS ManufacturingWorkflowID,
				orderSetItem.DeliveryNo AS ManufacturingOrderNo,
				p.ModelNo,
				orderSetItem.ProductImage,
				p.ProductTitle,
				orderSetItem.Quantity AS Qty,
				orderSetItem.StockQty,
				o.TentativeDeliveryDate AS DeliveryDate,
				x.ManufacturingStatus AS Status,
				us.FirstName + ' ' + us.LastName AS SupervisorName,
				x.Position,
				o.OrderNo,
				x.OrderId,
				x.OrderSetItemId,
				createdBy.FirstName + ' ' + createdBy.LastName AS SalesmanName
			FROM dbo.OrderManufacturingWorkflows x
			JOIN dbo.Orders o ON x.OrderId = o.OrderId
			JOIN dbo.AspNetUsers uc ON x.ContractorUserID = uc.UserId
			JOIN dbo.AspNetUsers us ON x.SupervisorUserID = us.UserId
			JOIN dbo.AspNetUsers createdBy ON o.CreatedBy = createdBy.UserId
			JOIN dbo.OrderSetItems orderSetItem ON x.OrderId = orderSetItem.OrderId AND x.OrderSetItemId = orderSetItem.OrderSetItemId
			JOIN dbo.SubjectTypes st ON st.SubjectTypeId = @ProductSubjectTypeId
			JOIN dbo.Products p ON orderSetItem.SubjectId = p.ProductId
			JOIN dbo.ManufacturingWorkflows w ON x.ManufacturingWorkflowId = w.ManufacturingWorkflowId
			WHERE x.ManufacturingStatus = @ManufacturingStatus
			AND p.Status <> 3
			AND o.Status <> 9
			AND orderSetItem.IsDeleted <> 1
			AND x.ManufacturingWorkflowId = @ManufacturingWorkflowId
			AND orderSetItem.ItemStatus = 1
			AND ((x.ContractorUserID = @CurrentUserId) OR (x.SupervisorUserID = @CurrentUserId))
			AND (x.ManufacturingStatus IN (0,1,2,3,4))
			AND o.TenantId = @TenantId
		)

		SELECT COUNT(1) AS ManufacturingItemStatusCount
		FROM ManufacturingOrders
		WHERE (Position = 1)
		   OR (Position > 1
				AND EXISTS (
					SELECT 1
					FROM OrderManufacturingWorkflows parent
					WHERE parent.OrderManufacturingWorkflowId = ManufacturingOrders.ManufacturingOrderID - 1
					AND parent.ManufacturingStatus = 2
				)
		)

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

