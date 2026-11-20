/*
	EXEC dbo.ListAllDealer
		@TenantId = 127
		,@Search = 'Tanyo'
*/
CREATE PROC [dbo].[ListAllDealer] (
	@TenantId BIGINT
	,@Search VARCHAR(50)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT c.CustomerId AS DealerId
		,4 AS DealerTypeId
		,c.FirstName + ' ' + ISNULL(c.LastName, '') AS DealerName
		,c.PhoneNumber
		,c.CustomerTenantID AS DealerTenantID
	FROM dbo.Customers c WITH (NOLOCK)
	WHERE c.IsDeleted = 0
		AND c.TenantId = @TenantId
		AND c.CustomerTypeId = 4
		AND @Search IS NOT NULL
		AND ((c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @Search + '%')
	
	UNION ALL
	
	SELECT l.LabelId
		,0 AS DealerTypeId
		,l.LabelName + ' (' + CAST(COUNT(c.CustomerId) AS VARCHAR) + ')' AS DealerName
		,'' AS PhoneNumber
		,NULL DealerTenantID
	FROM dbo.Labels l WITH (NOLOCK)
	INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.LabelId = l.LabelId
		AND c.IsDeleted = 0
	WHERE l.IsDeleted = 0
		AND l.TenantId = @TenantId
		AND @Search IS NOT NULL
		AND (l.LabelName LIKE '%' + @Search + '%')
	GROUP BY l.LabelId
		,l.LabelName
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

