CREATE   PROCEDURE [dbo].[CreateComplain] (
	@ComplainRequestDetails VARCHAR(MAX)
	,@TenantId BIGINT
	,@UserId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CustomerId BIGINT
		,@FirstName VARCHAR(50)
		,@LastName VARCHAR(50)
		,@PhoneNumber VARCHAR(50)
		,@CustomerAddressId BIGINT
		,@AddressType VARCHAR(50)
		,@Street1 VARCHAR(200)
		,@Street2 VARCHAR(200)
		,@Area VARCHAR(100)
		,@City VARCHAR(100)
		,@State VARCHAR(100)
		,@ZipCode VARCHAR(20)
		,@IsDefault BIT
		,@Latitude VARCHAR(25)
		,@Longitude VARCHAR(25)
		,@Country VARCHAR(100)
		,@FullAddress VARCHAR(MAX)
		,@OrderId BIGINT
		,@OrderSetItemId BIGINT
		,@ProductTitle VARCHAR(500)
		,@Description VARCHAR(MAX)
		,@ComplainId BIGINT
		,@ComplainKey VARCHAR(128)
		,@Status INT
		,@Priority INT
		,@IsFree BIT
		,@SalesmanId INT
		,@ReturnMessage VARCHAR(1024)
		,@SkipAddress BIT = 0
		,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtUTC DATETIME = GETUTCDATE();

	SELECT @CustomerId = JSON_VALUE(@ComplainRequestDetails, '$.customerDetails.customerId')
		,@FirstName = JSON_VALUE(@ComplainRequestDetails, '$.customerDetails.firstName')
		,@LastName = JSON_VALUE(@ComplainRequestDetails, '$.customerDetails.lastName')
		,@PhoneNumber = JSON_VALUE(@ComplainRequestDetails, '$.customerDetails.phoneNumber');

	SELECT @CustomerAddressId = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.customerAddressId')
		,@AddressType = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.addressType')
		,@Street1 = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.street1')
		,@Street2 = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.street2')
		,@Area = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.area')
		,@City = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.city')
		,@State = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.state')
		,@ZipCode = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.zipCode')
		,@IsDefault = CAST(JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.isDefault') AS BIT)
		,@Latitude = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.latitude')
		,@Longitude = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.longitude')
		,@Country = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.country')
		,@FullAddress = JSON_VALUE(@ComplainRequestDetails, '$.addressDetails.fullAddress');

	SELECT @OrderId = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.orderId')
		,@OrderSetItemId = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.orderSetItemId')
		,@ProductTitle = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.productTitle')
		,@Description = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.description')
		,@Status = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.status')
		,@Priority = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.priority')
		,@IsFree = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.isFree')
		,@SalesmanId = JSON_VALUE(@ComplainRequestDetails, '$.complainDetails.salesmanId');

	IF JSON_QUERY(@ComplainRequestDetails, '$.addressDetails') IS NULL
		OR JSON_QUERY(@ComplainRequestDetails, '$.addressDetails') = '{}'
	BEGIN
		SET @SkipAddress = 1;
	END

	BEGIN TRY
		BEGIN TRANSACTION;

		IF ISNULL(@OrderSetItemId, 0) > 0
		BEGIN
			IF EXISTS (
					SELECT 1
					FROM Complains WITH (NOLOCK)
					WHERE OrderSetItemId = @OrderSetItemId
						AND TenantId = @TenantId
						AND STATUS <> 3 -- Close
					)
			BEGIN
				SET @ReturnMessage = 'Complaint already exists.';

				THROW 50001
					,@ReturnMessage
					,1;
			END
		END

		IF ISNULL(@CustomerId, 0) = 0
		BEGIN
			IF ISNULL(LTRIM(RTRIM(@FirstName)), '') = ''
			BEGIN
				SET @ReturnMessage = 'Customer first name is required';

				THROW 50001
					,@ReturnMessage
					,1;
			END

			IF ISNULL(TRIM(@PhoneNumber), '') = ''
			BEGIN
				SET @ReturnMessage = 'Customer phone number is required.';

				THROW 50001
					,@ReturnMessage
					,1;
			END

			IF EXISTS (
					SELECT 1
					FROM Customers WITH (NOLOCK)
					WHERE PhoneNumber = @PhoneNumber
						AND TenantId = @TenantId
						AND IsDeleted = 0
					)
			BEGIN
				
				SELECT @CustomerId = CustomerId
                FROM Customers WITH (NOLOCK)
                WHERE PhoneNumber = @PhoneNumber 
                AND TenantId = @TenantId 
                AND IsDeleted = 0

                SELECT
                    @FirstName   = FirstName
                    ,@LastName    = LastName
                    ,@PhoneNumber = PhoneNumber
                FROM Customers WITH (NOLOCK)
                WHERE CustomerId = @CustomerId
                AND TenantId   = @TenantId
                AND IsDeleted  = 0;

				--SET @ReturnMessage = 'A customer with this phone number already exists.';

				--THROW 50001
				--	,@ReturnMessage
				--	,1;
			END
			ELSE
			BEGIN
				DECLARE @UserLocationId INT

                SELECT @UserLocationId = lum.LocationId
                FROM LocationUserMapping lum WITH (NOLOCK)
                WHERE lum.UserId = @UserId
                AND lum.IsDefault = 1

				INSERT INTO Customers (
					CustomerTypeId
					,FirstName
					,LastName
					,PhoneNumber
					,TenantId
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,IsDeleted
					,LocationID
					)
				VALUES (
					1
					,@FirstName
					,ISNULL(@LastName, '')
					,@PhoneNumber
					,@TenantId
					,@UserId
					,@dt
					,@dtUTC
					,0
					,@UserLocationId
					);

				SET @CustomerId = SCOPE_IDENTITY();
			END
		END
		ELSE
		BEGIN
			IF NOT EXISTS (
					SELECT 1
					FROM Customers WITH (NOLOCK)
					WHERE CustomerId = @CustomerId
						AND TenantId = @TenantId
						AND IsDeleted = 0
					)
			BEGIN
				SET @ReturnMessage = 'Customer not found.';

				THROW 50001
					,@ReturnMessage
					,1;
			END
		END

		IF @SkipAddress = 0
		BEGIN
			IF ISNULL(@CustomerAddressId, 0) = 0
			BEGIN
				INSERT INTO CustomerAddresses (
					CustomerId
					,AddressType
					,Street1
					,Street2
					,Area
					,City
					,STATE
					,ZipCode
					,IsDefault
					,Latitude
					,Longitude
					,Country
					,FullAddress
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,IsDeleted
					)
				VALUES (
					@CustomerId
					,@AddressType
					,ISNULL(@Street1,'')
					,@Street2
					,ISNULL(@Area, '')
					,@City
					,@State
					,@ZipCode
					,ISNULL(@IsDefault, 1)
					,@Latitude
					,@Longitude
					,@Country
					,@FullAddress
					,@UserId
					,@dt
					,@dtUTC
					,0
					);

				SET @CustomerAddressId = SCOPE_IDENTITY();
			END
			ELSE
			BEGIN
				IF NOT EXISTS (
						SELECT 1
						FROM CustomerAddresses WITH (NOLOCK)
						WHERE CustomerAddressId = @CustomerAddressId
							AND CustomerId = @CustomerId
							AND IsDeleted = 0
						)
				BEGIN
					SET @ReturnMessage = 'Customer address not found.';

					THROW 50001
						,@ReturnMessage
						,1;
				END

			END
		END


		SELECT @ComplainKey = dbo.GetComplainKey('C')

		INSERT INTO Complains (
			OrderId
			,ComplainKey
			,Title
			,Description
			,STATUS
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			,OrderSetItemId
			,CustomerId
			,TenantId
			,SalesmanId
			,IsFree
			,Address
			,Priority
			,CustomerAddressId
			)
		VALUES (
			@OrderId
			,@ComplainKey
			,@ProductTitle
			,@Description
			,@Status
			,@UserId
			,@dt
			,@dtUTC
			,@OrderSetItemId
			,@CustomerId
			,@TenantId
			,@SalesmanId
			,ISNULL(@IsFree,1)
			,ISNULL(
			     CONCAT_WS(', ',
			         NULLIF(@Street1, ''),
			         NULLIF(@FullAddress, ''),
			         NULLIF(@Street2, ''),
			         NULLIF(@Area, ''),
			         NULLIF(@City, ''),
			         NULLIF(@State, ''),
			         NULLIF(@ZipCode, ''),
			         NULLIF(@Country, '')
			     ),
			     ''
			 )
			,@Priority
			,@CustomerAddressId
			);

		SET @ComplainId = SCOPE_IDENTITY();

		COMMIT TRANSACTION;

		SELECT C.ComplainId
			,C.ComplainKey AS ComplainNo
			,C.CustomerId
			,C.Address
			,@CustomerAddressId AS CustomerAddressId
			,C.OrderId
			,C.OrderSetItemId
			,C.Title AS ProductTitle
			,C.Description
			,C.STATUS
		FROM Complains C
		WHERE C.ComplainId = @ComplainId;
	END TRY

BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
		THROW;	
	END CATCH
END

GO

