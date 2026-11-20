CREATE   PROCEDURE HFJob_GetCustomerAddressesWithMissingLatLong
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SELECT CA.CustomerAddressId
		,CA.City
		,CA.STATE
		,CA.ZipCode
	FROM CustomerAddresses CA WITH (NOLOCK)
	WHERE CA.IsDeleted = 0
		AND ISNULL(CA.ZipCode, '') <> ''
		AND (
				CA.Latitude IS NULL
			OR CA.Longitude IS NULL
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

