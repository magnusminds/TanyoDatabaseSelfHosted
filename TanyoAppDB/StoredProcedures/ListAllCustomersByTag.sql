

/*
	EXEC dbo.ListAllCustomersByTag
		@TenantId = 1
		,@TagId = 10018
*/
CREATE   PROC [dbo].[ListAllCustomersByTag]
(
	@TenantId BIGINT
	,@TagId BIGINT
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
		,NULL AS CustomerTenantID
	FROM dbo.Customers c WITH (NOLOCK)
	WHERE c.IsDeleted = 0
	AND c.TenantId = @TenantId
	AND c.LabelId = @TagId
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

