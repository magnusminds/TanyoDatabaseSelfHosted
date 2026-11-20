/*
	EXEC [dbo].[GetReadyToManufacturerCountForMfgDashboard] @TenantId = 2
*/
CREATE PROCEDURE [dbo].[GetReadyToManufacturerCountForMfgDashboard] 
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

	SELECT COUNT(*) AS ReadyToManufacturerCount
	FROM OrderSetItems osi WITH(NOLOCK)
	INNER JOIN Orders o ON osi.OrderId = o.OrderId
		AND o.TenantId = @TenantId
		AND o.STATUS = 3
		AND o.IsArchive = 0
	INNER JOIN Products p WITH(NOLOCK) ON osi.SubjectId = p.ProductId
		AND p.TenantId = @TenantId
		AND p.STATUS != 3
	INNER JOIN Categories c WITH(NOLOCK) ON p.CategoryId = c.CategoryId
		AND c.TenantId = @TenantId
		AND c.IsDeleted = 0
	WHERE osi.IsDeleted = 0
		AND osi.SubjectTypeId = @ProductSubjectTypeId
		AND osi.ItemStatus = 0;

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

