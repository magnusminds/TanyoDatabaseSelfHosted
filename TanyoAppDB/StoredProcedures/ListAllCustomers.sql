/*
	EXEC dbo.ListAllCustomers
		@TenantId = 1
		,@Search = ''
		,@CustomerTypeId = -1
*/
CREATE   PROC [dbo].[ListAllCustomers]
(
	@TenantId BIGINT
	,@Search VARCHAR(50)
	,@CustomerTypeId INT = -1
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;


	BEGIN TRY
	SELECT c.CustomerId
		,c.CustomerTypeId
		,c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
		,c.PhoneNumber
		,c.CustomerTenantID
	FROM dbo.Customers c WITH (NOLOCK)
	WHERE c.IsDeleted = 0
	AND c.TenantId = @TenantId
	AND (@CustomerTypeId = -1 OR c.CustomerTypeId = @CustomerTypeId)
	AND @Search IS NOT NULL AND ((c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @Search + '%')

	UNION ALL

	SELECT l.LabelId AS CustomerId
		,0 AS CustomerTypeId
		,l.LabelName + ' (' + CAST(COUNT(c.CustomerId) AS VARCHAR) + ')' AS CustomerName
		,'' AS PhoneNumber
		,NULL CustomerTenantID
	FROM dbo.Labels l WITH (NOLOCK)
	INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.LabelId = l.LabelId
		AND c.IsDeleted = 0
	WHERE l.IsDeleted = 0
	AND l.TenantId = @TenantId
	AND (@CustomerTypeId = -1 OR @CustomerTypeId = 0)
	AND @Search IS NOT NULL AND (l.LabelName LIKE '%' + @Search + '%')
	GROUP BY l.LabelId, l.LabelName
	ORDER BY 3

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

