/*
	EXEC [dbo].[GetManufacturingOrderCountForMfgDashboard] @TenantId = 2
*/
CREATE PROCEDURE [dbo].[GetManufacturingOrderCountForMfgDashboard] 
	@TenantId BIGINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT COUNT(*) AS ManufacturingOrderCount
	FROM OrderManufacturingWorkflows omw
	INNER JOIN Orders o WITH(NOLOCK) ON omw.OrderId = o.OrderId
		AND o.TenantId = @TenantId
		AND o.STATUS != 9
		AND o.IsArchive = 0
	LEFT JOIN AspNetUsers u WITH(NOLOCK) ON omw.ContractorUserID = u.UserId
		AND omw.SupervisorUserID = u.UserId
		AND u.IsDeleted = 0 
		AND u.IsActive = 1
	INNER JOIN ManufacturingWorkflows mw WITH(NOLOCK) ON omw.ManufacturingWorkflowId = mw.ManufacturingWorkflowId
		AND mw.TenantId = @TenantId
		AND mw.IsDeleted = 0
	LEFT JOIN OrderSetItems osi WITH(NOLOCK) ON omw.OrderSetItemId = osi.OrderSetItemId
		AND osi.IsDeleted = 0
		AND osi.ItemStatus = 1
	LEFT JOIN Products p WITH(NOLOCK) ON osi.SubjectId = p.ProductId
		AND p.TenantId = @TenantId
	LEFT JOIN Categories c WITH(NOLOCK) ON p.CategoryId = c.CategoryId
		AND c.TenantId = @TenantId
		AND c.IsDeleted = 0
	WHERE omw.ManufacturingStatus != 2
		AND osi.OrderSetItemId IS NOT NULL;

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

