CREATE PROCEDURE [dbo].[HFJob_GetOrderAddressesWithMissingLatLong]
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SELECT OA.CustomerAddressId
		,OA.City
		,OA.STATE
		,OA.ZipCode
		,OA.OrderAddressId
	FROM OrderAddresses OA WITH (NOLOCK)
	WHERE ISNULL(OA.ZipCode, '') <> ''
		AND (
				OA.Latitude IS NULL
			OR OA.Longitude IS NULL
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

