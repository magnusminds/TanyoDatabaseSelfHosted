/*
	EXEC [dbo].[GetReadyToDeliveryCountForMfgDashboard] @TenantId = 2
*/
CREATE PROCEDURE [dbo].[GetReadyToDeliveryCountForMfgDashboard] 
	@TenantId BIGINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @ProductSubjectTypeId INT;

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes
	WHERE SubjectTypeName = 'Products'
		AND IsDeleted = 0
		AND TenantId = @TenantId;

	SELECT COUNT(*) AS ReadyToDeliveryCount
	FROM OrderSetItems osi WITH(NOLOCK)
	INNER JOIN Orders o WITH(NOLOCK) ON osi.OrderId = o.OrderId
		AND o.TenantId = @TenantId
		AND o.STATUS != 9
		AND o.IsArchive = 0
	LEFT JOIN Customers c WITH(NOLOCK) ON o.CustomerID = c.CustomerId
		AND c.TenantId = @TenantId
	LEFT JOIN AspNetUsers u WITH(NOLOCK) ON o.CreatedBy = u.UserId
		AND u.IsDeleted = 0 
		AND u.IsActive = 1
	LEFT JOIN Products p WITH(NOLOCK) ON osi.SubjectId = p.ProductId
		AND osi.SubjectTypeId = @ProductSubjectTypeId
		AND p.TenantId = @TenantId
		AND p.STATUS != 3
	LEFT JOIN Categories cat WITH(NOLOCK) ON p.CategoryId = cat.CategoryId
		AND cat.TenantId = @TenantId
		AND cat.IsDeleted = 0
	WHERE osi.IsDeleted = 0
		AND osi.ItemStatus = 2
		AND osi.ParentOrderSetItemId IS NULL;

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

