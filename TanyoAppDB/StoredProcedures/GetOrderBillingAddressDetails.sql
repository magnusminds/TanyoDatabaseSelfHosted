CREATE   PROCEDURE GetOrderBillingAddressDetails (@OrderId BIGINT)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SELECT OA.OrderAddressId
	    ,OA.OrderId
		,OA.CustomerAddressId
		,OA.Street1
		,ISNULL(OA.Street2, '') AS Street2
		,ISNULL(OA.Landmark, '') AS Landmark
		,OA.Area
		,OA.City
		,OA.State
		,OA.ZipCode
		,OA.Latitude
		,OA.Longitude
	FROM OrderAddresses OA WITH (NOLOCK)
	WHERE OA.OrderId = @OrderId
		AND OA.AddressType = 'Billing'

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

