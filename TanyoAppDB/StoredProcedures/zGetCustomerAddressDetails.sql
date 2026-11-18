/*

EXEC GetCustomerAddressDetails
@CustomerId = 1

*/
CREATE PROCEDURE zGetCustomerAddressDetails (@CustomerId BIGINT)
WITH ENCRYPTION
AS
BEGIN
	SELECT CA.CustomerAddressId
		,CA.CustomerId
		,CA.AddressType
		,CA.Street1
		,CA.Street2
		,CA.Landmark
		,CA.Area
		,CA.City
		,CA.STATE
		,CA.ZipCode
		,CA.IsDefault
		,CA.IsDeleted
		,CA.CreatedBy
		,CA.CreatedDate
		,CA.CreatedUTCDate
		,CA.UpdatedBy
		,CA.UpdatedDate
		,CA.UpdatedUTCDate
		,CA.OtherAddressType
		,CA.Latitude
		,CA.Longitude
		,CA.CompanyName
		,CA.GSTNo
	FROM CustomerAddresses CA WITH (NOLOCK)
	WHERE CA.IsDeleted = 0
		AND CA.CustomerId = @CustomerId
END

GO

