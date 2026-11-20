/*
	EXEC dbo.ListAllDealerByTag
		@TenantId = 1
		,@TagId = 10018
*/
CREATE   PROC [dbo].[ListAllDealerByTag]
(
	@TenantId BIGINT
	,@TagId BIGINT
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
	AND c.LabelId = @TagId
	AND c.CustomerTypeId = 4
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

