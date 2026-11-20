/*
	EXEC [dbo].[GetDeliveredCountForMfgDashboard] @TenantId = 2
*/
CREATE PROCEDURE [dbo].[GetDeliveredCountForMfgDashboard] @TenantId BIGINT
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @ProductSubjectTypeId INT;
	DECLARE @PolishSubjectTypeId INT;
	DECLARE @FabricSubjectTypeId INT;

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH(NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND IsDeleted = 0
		AND TenantId = @TenantId;

	SELECT @PolishSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH(NOLOCK)
	WHERE SubjectTypeName = 'Polish'
		AND IsDeleted = 0
		AND TenantId = @TenantId;

	SELECT @FabricSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH(NOLOCK)
	WHERE SubjectTypeName = 'Fabrics'
		AND IsDeleted = 0
		AND TenantId = @TenantId;

	SELECT COUNT(*) AS DeliveredCount
	FROM OrderSetItems osi WITH(NOLOCK)
	INNER JOIN Orders o ON osi.OrderId = o.OrderId
		AND o.TenantId = @TenantId
		AND o.STATUS != 9
	LEFT JOIN Customers c WITH(NOLOCK) ON o.CustomerID = c.CustomerId
		AND c.TenantId = @TenantId
		AND c.IsDeleted = 0
	LEFT JOIN AspNetUsers u WITH(NOLOCK) ON o.CreatedBy = u.UserId
		AND u.IsDeleted = 0 
		AND u.IsActive = 1
	LEFT JOIN Products p WITH(NOLOCK) ON osi.SubjectId = p.ProductId
		AND osi.SubjectTypeId = @ProductSubjectTypeId
		AND p.TenantId = @TenantId
		AND p.STATUS != 3
	LEFT JOIN Polish pol WITH(NOLOCK) ON osi.SubjectId = pol.PolishId
		AND osi.SubjectTypeId = @PolishSubjectTypeId
		AND pol.TenantId = @TenantId
		AND pol.IsDeleted = 0
	LEFT JOIN Fabrics f WITH(NOLOCK) ON osi.SubjectId = f.FabricId
		AND osi.SubjectTypeId = @FabricSubjectTypeId
		AND f.TenantId = @TenantId
		AND f.IsDeleted = 0
	LEFT JOIN Categories cat WITH(NOLOCK) ON p.CategoryId = cat.CategoryId
		AND cat.TenantId = @TenantId
		AND cat.IsDeleted = 0
	WHERE osi.IsDeleted = 0
		AND osi.ItemStatus = 3
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

