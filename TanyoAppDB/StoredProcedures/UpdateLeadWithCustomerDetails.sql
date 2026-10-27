CREATE PROCEDURE [dbo].[UpdateLeadWithCustomerDetails] (
	@LeadRequestDetails VARCHAR(MAX)
	,@TenantId BIGINT
	,@UserId BIGINT
	,@IsPortal BIT = 0
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CustomerId BIGINT
		,@FirstName VARCHAR(50)
		,@LastName VARCHAR(50)
		,@PhoneNumber VARCHAR(50)
		,@Email VARCHAR(100)
		,@CustomerAddressId BIGINT
		,@AddrCustomerId BIGINT
		,@AddressType VARCHAR(50)
		,@Street1 VARCHAR(200)
		,@Street2 VARCHAR(200)
		,@Landmark VARCHAR(200)
		,@Area VARCHAR(100)
		,@City VARCHAR(100)
		,@State VARCHAR(100)
		,@ZipCode VARCHAR(6)
		,@IsDefault BIT
		,@Latitude VARCHAR(25)
		,@Longitude VARCHAR(25)
		,@Country VARCHAR(MAX)
		,@FullAddress VARCHAR(MAX)
		,@LeadId BIGINT
		,@Status INT
		,@Inquiry NVARCHAR(MAX)
		,@SalesmanId BIGINT
		,@LeadSourceId BIGINT
		,@Other VARCHAR(MAX)
		,@InquiryAbout BIGINT
		,@InquiryFor NVARCHAR(MAX)
		,@LocationID BIGINT
		,@RefferedBy BIGINT
		,@PurchaseUrgencyId BIGINT
		,@CustomerBehaviorId BIGINT
		,@ArchitectBehaviorId BIGINT
		,@VisitForId BIGINT
		,@CompanyName NVARCHAR(200)
		,@CloseLookupValueId INT
		,@ReturnMessage VARCHAR(1024) = ''
		,@ExistingPhoneNumber VARCHAR(50)
		,@PrevSalesmanId BIGINT
		,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtUTC DATETIME = GETUTCDATE()
		,@Date DATE = GETDATE()
		,@SkipAddress BIT = 0
		,@BuyingRangeValueId BIGINT
		,@AlternateMobileNumber VARCHAR(15)
		,@InquiryAreaRequirement DECIMAL(18, 2)
		,@AlternateSalesmanId BIGINT
		,@ClientMeetingStageId INT
		,@ArchitectMeetingStageId INT
		,@LeadType INT;

	SELECT @CustomerId = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.CustomerId')
		,@FirstName = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.firstName')
		,@LastName = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.lastName')
		,@PhoneNumber = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.phoneNumber')
		,@Email = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.emailId')
		,@CompanyName = COALESCE(NULLIF(JSON_VALUE(@LeadRequestDetails, '$.leadDetails.companyName'), ''), JSON_VALUE(@LeadRequestDetails, '$.customerDetails.companyName'));

	SELECT @CustomerAddressId = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.customerAddressId')
		,@AddrCustomerId = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.customerId')
		,@AddressType = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.addressType')
		,@Street1 = ISNULL(JSON_VALUE(@LeadRequestDetails, '$.customerAddress.street1'), '')
		,@Street2 = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.street2')
		,@Landmark = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.landmark')
		,@Area = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.area')
		,@City = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.city')
		,@State = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.state')
		,@ZipCode = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.zipCode')
		,@IsDefault = CAST(JSON_VALUE(@LeadRequestDetails, '$.customerAddress.isDefault') AS BIT)
		,@Latitude = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.latitude')
		,@Longitude = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.longitude')
		,@Country = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.country')
		,@FullAddress = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.fullAddress');

	SELECT @LeadId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.id')
		,@Status = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.status')
		,@Inquiry = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.inquiry')
		,@SalesmanId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.salesmanId')
		,@LeadSourceId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.leadSourceId')
		,@Other = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.other')
		,@InquiryAbout = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.inquiryAbout')
		,@InquiryFor = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.inquiryFor')
		,@LocationID = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.locationId')
		,@RefferedBy = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.refferedBy')
		,@PurchaseUrgencyId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.purchaseUrgencyId')
		,@CustomerBehaviorId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.customerBehaviorId')
		,@CloseLookupValueId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.closeLookupValueId')
		,@BuyingRangeValueId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.buyingRangeValueId')
		,@AlternateMobileNumber = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.alternateMobileNumber')
		,@InquiryAreaRequirement = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.inquiryAreaRequirement')
		,@AlternateSalesmanId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.alternateSalesmanId')
		,@ClientMeetingStageId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.clientMeetingStageId')
		,@ArchitectMeetingStageId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.architectMeetingStageId')
		,@LeadType = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.leadType')
		,@ArchitectBehaviorId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.architectBehaviorId')
		,@VisitForId = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.visitForId');

	IF JSON_QUERY(@LeadRequestDetails, '$.customerAddress') IS NULL
		OR JSON_QUERY(@LeadRequestDetails, '$.customerAddress') = '{}'
	BEGIN
		SET @SkipAddress = 1;
	END

	IF ISNULL(@LeadId, 0) = 0
	BEGIN
		SET @ReturnMessage = 'Lead ID is required.';

		THROW 50001
			,@ReturnMessage
			,1;
	END

	IF @Status IS NULL
	BEGIN
		SET @ReturnMessage = 'Lead status is required.';

		THROW 50001
			,@ReturnMessage
			,1;
	END

	-- Verify lead exists and belongs to this tenant    
	IF NOT EXISTS (
			SELECT 1
			FROM Leads WITH (NOLOCK)
			WHERE LeadId = @LeadId
				AND TenantId = @TenantId
				AND Status <> 6
			)
	BEGIN
		SET @ReturnMessage = 'Lead not found.';

		THROW 50001
			,@ReturnMessage
			,1;
	END

	IF @FirstName IS NULL
		OR TRIM(@FirstName) = ''
	BEGIN
		SET @ReturnMessage = 'Customer first name is required.';

		THROW 50001
			,@ReturnMessage
			,1;
	END

	IF @PhoneNumber IS NULL
		OR TRIM(@PhoneNumber) = ''
	BEGIN
		SET @ReturnMessage = 'Phone Number is required.';

		THROW 50001
			,@ReturnMessage
			,1;
	END

	BEGIN TRANSACTION UpdateLeadWithCustomerDetails;

	BEGIN TRY
		IF ISNULL(@CustomerId, 0) = 0
		BEGIN
			-- Phone must be unique within tenant    
			IF EXISTS (
					SELECT 1
					FROM Customers WITH (NOLOCK)
					WHERE PhoneNumber = @PhoneNumber
						AND TenantId = @TenantId
					)
			BEGIN
				SELECT @CustomerId = CustomerId
				FROM Customers WITH (NOLOCK)
				WHERE PhoneNumber = @PhoneNumber
					AND TenantId = @TenantId

				SELECT @FirstName = FirstName
					,@LastName = LastName
					,@PhoneNumber = PhoneNumber
					,@Email = EmailId
				FROM Customers WITH (NOLOCK)
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId
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
					,EmailId
					,CompanyName
					,PhoneNumber
					,RefferedBy
					,TenantId
					,IsDeleted
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,LocationID
					)
				SELECT CASE 
						WHEN ISNULL(@LeadType, 0) = 1
							THEN 2
						ELSE 1
						END
					,@FirstName
					,ISNULL(@LastName, '')
					,@Email
					,@CompanyName
					,@PhoneNumber
					,@RefferedBy
					,@TenantId
					,0
					,@UserId
					,@dt
					,@dtUTC
					,@UserLocationId

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
					)
			BEGIN
				SET @ReturnMessage = 'Customer not found with customerID: ' + CAST(@CustomerId AS VARCHAR(100));

				THROW 50001
					,@ReturnMessage
					,1;
			END

			IF @IsPortal = 1
			BEGIN
				SELECT @ExistingPhoneNumber = PhoneNumber
				FROM Customers WITH (NOLOCK)
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId

				IF @PhoneNumber <> @ExistingPhoneNumber
					AND EXISTS (
						SELECT 1
						FROM Customers WITH (NOLOCK)
						WHERE PhoneNumber = @PhoneNumber
							AND TenantId = @TenantId
							AND CustomerId <> @CustomerId
						)
				BEGIN
					SET @ReturnMessage = 'Another customer with this phone number already exists.';

					THROW 50001
						,@ReturnMessage
						,1;
				END

				-- Update customer details    
				UPDATE Customers
				SET FirstName = @FirstName
					,LastName = ISNULL(@LastName, '')
					,EmailId = @Email
					,PhoneNumber = @PhoneNumber
					,RefferedBy = IIF(ISNULL(@RefferedBy, 0) = 0, NULL, @RefferedBy)
					,UpdatedBy = @UserId
					,UpdatedDate = @dt
					,UpdatedUTCDate = @dtUTC
					,IsDeleted = 0
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId
			END
			ELSE
			BEGIN
				IF @FirstName IS NULL
					OR TRIM(@FirstName) = ''
				BEGIN
					SET @ReturnMessage = 'Customer first name is required.';

					THROW 50001
						,@ReturnMessage
						,1;
				END

				IF @PhoneNumber IS NULL
					OR TRIM(@PhoneNumber) = ''
				BEGIN
					SET @ReturnMessage = 'Phone Number is required.';

					THROW 50001
						,@ReturnMessage
						,1;
				END

				SELECT @ExistingPhoneNumber = PhoneNumber
				FROM Customers WITH (NOLOCK)
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId

				IF @PhoneNumber <> @ExistingPhoneNumber
					AND EXISTS (
						SELECT 1
						FROM Customers WITH (NOLOCK)
						WHERE PhoneNumber = @PhoneNumber
							AND TenantId = @TenantId
							AND CustomerId <> @CustomerId
						)
				BEGIN
					SET @ReturnMessage = 'Another customer with this phone number already exists.';

					THROW 50001
						,@ReturnMessage
						,1;
				END

				-- Update customer details    
				UPDATE Customers
				SET FirstName = @FirstName
					,LastName = ISNULL(@LastName, '')
					,PhoneNumber = @PhoneNumber
					,RefferedBy = IIF(ISNULL(@RefferedBy, 0) = 0, NULL, @RefferedBy)
					,UpdatedBy = @UserId
					,UpdatedDate = @dt
					,UpdatedUTCDate = @dtUTC
					,IsDeleted = 0
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId
			END
		END

		-- Keep the customer type in sync with the lead type
		DECLARE @TargetCustomerTypeId INT = CASE 
				WHEN ISNULL(@LeadType, 0) = 1
					THEN 2
				ELSE 1
				END;

		UPDATE Customers
		SET CustomerTypeId = @TargetCustomerTypeId
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @dtUTC
		WHERE CustomerId = @CustomerId
			AND TenantId = @TenantId
			AND CustomerTypeId IN (1, 2)
			AND CustomerTypeId <> @TargetCustomerTypeId;

		SELECT @FirstName = FirstName
			,@LastName = LastName
			,@PhoneNumber = PhoneNumber
			,@Email = EmailId
		FROM Customers WITH (NOLOCK)
		WHERE CustomerId = @CustomerId
			AND TenantId = @TenantId

		IF NULLIF(TRIM(@CompanyName), '') IS NOT NULL
			AND EXISTS (
				SELECT 1
				FROM Customers WITH (NOLOCK)
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId
					AND ISNULL(CompanyName, '') <> @CompanyName
				)
		BEGIN
			UPDATE Customers
			SET CompanyName = @CompanyName
				,UpdatedBy = @UserId
				,UpdatedDate = @dt
				,UpdatedUTCDate = @dtUTC
			WHERE CustomerId = @CustomerId
				AND TenantId = @TenantId;
		END

		IF @SkipAddress = 0
		BEGIN
			IF ISNULL(@CustomerAddressId, 0) = 0
			BEGIN
				IF isnull(@IsDefault, 0) = 1
					AND ISNULL(@CustomerId, 0) > 0
				BEGIN
					UPDATE CustomerAddresses
					SET IsDefault = 0
					WHERE CustomerId = @CustomerId
				END

				INSERT INTO CustomerAddresses (
					CustomerId
					,AddressType
					,Street1
					,Street2
					,Landmark
					,Area
					,City
					,STATE
					,ZipCode
					,IsDefault
					,IsDeleted
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,Latitude
					,Longitude
					,Country
					,FullAddress
					)
				SELECT @CustomerId
					,@AddressType
					,ISNULL(@Street1, '')
					,@Street2
					,@Landmark
					,ISNULL(@Area, '')
					,@City
					,@State
					,ISNULL(@ZipCode, '')
					,ISNULL(@IsDefault, 0)
					,0
					,@UserId
					,@dt
					,@dtUTC
					,@Latitude
					,@Longitude
					,@Country
					,@FullAddress;

				SET @CustomerAddressId = SCOPE_IDENTITY();
			END
			ELSE
			BEGIN
				-- Verify address belongs to this customer + tenant    
				IF NOT EXISTS (
						SELECT 1
						FROM CustomerAddresses WITH (NOLOCK)
						WHERE CustomerAddressId = @CustomerAddressId
							AND CustomerId = @CustomerId
							AND IsDeleted = 0
						)
				BEGIN
					SET @ReturnMessage = 'Selected Customer Address is already deleted, Please reselect.';

					THROW 50001
						,@ReturnMessage
						,1;
				END

				IF isnull(@IsDefault, 0) = 1
					AND ISNULL(@CustomerId, 0) > 0
				BEGIN
					UPDATE CustomerAddresses
					SET IsDefault = 0
					WHERE CustomerId = @CustomerId
				END

				UPDATE CustomerAddresses
				SET IsDefault = ISNULL(@IsDefault, 1)
					,UpdatedBy = @UserId
					,UpdatedDate = @dt
					,UpdatedUTCDate = @dtUTC
				WHERE CustomerAddressId = @CustomerAddressId
					AND CustomerId = @CustomerId
					AND IsDeleted = 0;
			END
		END

		IF @SalesmanId IS NOT NULL
			AND NOT EXISTS (
				SELECT 1
				FROM AspNetUsers AU WITH (NOLOCK)
				INNER JOIN UserTenantMapping UTM ON AU.UserId = UTM.UserId
				WHERE AU.UserId = @SalesmanId
					AND UTM.TenantId = @TenantId
					AND UTM.IsDeleted = 0
					AND AU.IsDeleted = 0
				)
		BEGIN
			SET @SalesmanId = NULL;
		END

		SELECT @PrevSalesmanId = SalesmanId
		FROM Leads WITH (NOLOCK)
		WHERE LeadId = @LeadId;

		IF @Status <> 5
			SET @CloseLookupValueId = NULL;

		UPDATE Leads
		SET FirstName = @FirstName
			,LastName = @LastName
			,Notes = @Inquiry
			,Status = @Status
			,SalesmanId = @SalesmanId
			,SalesmanAssignDate = CASE 
				WHEN @SalesmanId IS NOT NULL
					AND @SalesmanId <> ISNULL(@PrevSalesmanId, 0)
					THEN @Date
				ELSE SalesmanAssignDate
				END
			,LastContactedDate = @Date
			,Other = @Other
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @dtUTC
			,Email = @Email
			,PhoneNumber = @PhoneNumber
			,InquiryAbout = @InquiryAbout
			,LocationID = CASE 
				WHEN ISNULL(@LocationID, 0) > 0
					THEN @LocationID
				ELSE LocationID
				END
			,CloseLookupValueId = @CloseLookupValueId
			,InquiryFor = @InquiryFor
			,RefferedBy = IIF(ISNULL(@RefferedBy, 0) = 0, NULL, @RefferedBy)
			,CustomerId = @CustomerId
			,LeadSourceId = @LeadSourceId
			,PurchaseUrgencyId = @PurchaseUrgencyId
			,CustomerBehaviorId = @CustomerBehaviorId
			,ArchitectBehaviorId = @ArchitectBehaviorId
			,VisitForId = @VisitForId
			,CompanyName = ISNULL(@CompanyName, CompanyName)
			,BuyingRangeValueId = @BuyingRangeValueId
			,AlternateMobileNumber = @AlternateMobileNumber
			,InquiryAreaRequirement = @InquiryAreaRequirement
			,AlternateSalesmanId = @AlternateSalesmanId
			,ClientMeetingStageId = @ClientMeetingStageId
			,ArchitectMeetingStageId = @ArchitectMeetingStageId
			,LeadType = @LeadType
		WHERE LeadId = @LeadId
			AND TenantId = @TenantId
			AND Status <> 6;

		IF ISNULL(@SalesmanId, 0) <> ISNULL(@PrevSalesmanId, 0)
			AND ISNULL(@SalesmanId, 0) > 0
		BEGIN
			INSERT INTO LeadLogs (
				LeadId
				,SalesmanId
				,SentBy
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				@LeadId
				,ISNULL(@SalesmanId, 0)
				,@UserId
				,@UserId
				,@dt
				,@dtUTC
				);
		END

		COMMIT TRANSACTION UpdateLeadWithCustomerDetails;

		SELECT l.LeadId
			,l.FirstName
			,l.LastName
			,l.Notes
			,l.PhoneNumber
			,l.SalesmanId
			,l.Other
			,l.Email
			,l.Priority
			,l.InquiryAbout
			,l.CustomerId
			,l.CloseLookupValueId
			,l.RefferedBy
			,l.InquiryFor
			,l.LeadSourceId
			,l.PurchaseUrgencyId
			,l.CustomerBehaviorId
			,@CustomerAddressId AS CustomerAddressId
			,l.BuyingRangeValueId
			,l.AlternateMobileNumber
			,l.InquiryAreaRequirement
			,l.AlternateSalesmanId
			,l.ClientMeetingStageId
			,l.ArchitectMeetingStageId
			,l.LeadType
		FROM Leads l WITH (NOLOCK)
		WHERE l.LeadId = @LeadId;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION UpdateLeadWithCustomerDetails;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg NVARCHAR(4000);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		-- ONLY log true unexpected system/database errors (bypasses business validation throws using 50001)
		IF ERROR_NUMBER() <> 50001
		BEGIN
			EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
				,@ErrorMsg = @ErrorMsg;
		END

		-- Semicolon required before parameterless THROW per T-SQL syntax rules
		;THROW;
	END CATCH
END

GO

