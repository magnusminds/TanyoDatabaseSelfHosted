/*    
EXEC [dbo].[CreateLeadWithCustomerDetails]      
    @LeadRequestDetails = '{    
  "customerDetails": {    
    "CustomerId": 350765,    
    "firstName": "Tanmay",    
    "lastName": "B",    
    "phoneNumber": "8565555555",    
    "emailId": "mm.aloko@gmail.com"    
  },    
  "customerAddress": {    
    "customerId": 350765,    
    "customerAddressId": 179405,    
    "addressType": "Home",    
    "street1": "503 & 506",    
    "street2": "Mauryansh Elanza, Shyamal Cross Road, Parekh’s Hospital",    
    "area": "Jodhpur Village",    
    "city": "Ahmedabad",    
    "state": "Gujarat",    
    "zipCode": "380015",    
    "isDefault": true,    
    "latitude": "23.0129387",    
    "longitude": "72.5298645",    
    "country": "India",    
    "fullAddress": "MagnusMinds IT Solution"    
  },    
  "leadDetails": {    
    "id": 0,    
    "customerId": 350765,    
    "status": 1,    
    "inquiryFor": "BED",    
    "locationId": 40207    
  }    
}',    
    @TenantId = 1206,    
    @UserId   = 13312;    
*/
CREATE PROCEDURE [dbo].[CreateLeadWithCustomerDetails] (
	@LeadRequestDetails VARCHAR(MAX)
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
		,@Email VARCHAR(100)
		,@CustomerAddressId BIGINT
		,@AddressType VARCHAR(50)
		,@Street1 VARCHAR(200)
		,@Street2 VARCHAR(200)
		,@Area VARCHAR(100)
		,@City VARCHAR(100)
		,@State VARCHAR(100)
		,@ZipCode VARCHAR(6)
		,@IsDefault BIT
		,@Latitude VARCHAR(25)
		,@Longitude VARCHAR(25)
		,@Country VARCHAR(MAX)
		,@FullAddress VARCHAR(MAX)
		,@ReturnMessage VARCHAR(1024) = ''
		,@NewLeadId BIGINT
		,@LeadNumber NVARCHAR(50)
		,@DefaultLocationId BIGINT
		,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtUTC DATETIME = GETUTCDATE()
		,@Date DATE = GETDATE()
		,@LeadCustomerId BIGINT
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
		,@CompanyName VARCHAR(200)
		,@CloseLookupValueId INT
		,@BuyingRangeValueId BIGINT
		,@AlternateMobileNumber VARCHAR(15)
		,@InquiryAreaRequirement DECIMAL(18, 2)
		,@AlternateSalesmanId BIGINT
		,@ClientMeetingStageId INT
		,@ArchitectMeetingStageId INT
		,@LeadType INT
		,@SkipAddress BIT = 0

	SELECT @CustomerId = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.CustomerId')
		,@FirstName = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.firstName')
		,@LastName = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.lastName')
		,@PhoneNumber = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.phoneNumber')
		,@Email = JSON_VALUE(@LeadRequestDetails, '$.customerDetails.emailId')
		,@CompanyName = COALESCE(NULLIF(JSON_VALUE(@LeadRequestDetails, '$.leadDetails.companyName'), ''), JSON_VALUE(@LeadRequestDetails, '$.customerDetails.companyName'));

	SELECT @CustomerAddressId = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.customerAddressId')
		,@AddressType = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.addressType')
		,@Street1 = ISNULL(JSON_VALUE(@LeadRequestDetails, '$.customerAddress.street1'), '')
		,@Street2 = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.street2')
		,@Area = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.area')
		,@City = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.city')
		,@State = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.state')
		,@ZipCode = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.zipCode')
		,@IsDefault = CAST(JSON_VALUE(@LeadRequestDetails, '$.customerAddress.isDefault') AS BIT)
		,@Latitude = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.latitude')
		,@Longitude = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.longitude')
		,@Country = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.country')
		,@FullAddress = JSON_VALUE(@LeadRequestDetails, '$.customerAddress.fullAddress');

	SELECT @Status = JSON_VALUE(@LeadRequestDetails, '$.leadDetails.status')
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

	IF @Status IS NULL
	BEGIN
		SET @ReturnMessage = 'Lead status is required.';

		--RAISERROR(@ReturnMessage, 10, 1);       
		--RETURN;      
		THROW 50001
			,@ReturnMessage
			,1;
	END

	BEGIN TRY
		BEGIN TRANSACTION CreateLeadWithCustomerDetails;

		IF ISNULL(@CustomerId, 0) = 0
		BEGIN
			IF @FirstName IS NULL
				OR TRIM(@FirstName) = ''
			BEGIN
				SET @ReturnMessage = 'Customer first name is required';

				--RAISERROR(@ReturnMessage, 10, 1);       
				--RETURN;      
				THROW 50001
					,@ReturnMessage
					,1;
			END

			IF ISNULL(TRIM(@PhoneNumber), '') = ''
			BEGIN
				SET @ReturnMessage = 'Customer phone number is required';

				--RAISERROR(@ReturnMessage, 10, 1);       
				--RETURN;      
				THROW 50001
					,@ReturnMessage
					,1;
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

				--RAISERROR(@ReturnMessage, 10, 1);     
				--RETURN;    
				THROW 50001
					,@ReturnMessage
					,1;
			END
		END

		IF ISNULL(@CustomerId, 0) = 0
		BEGIN
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

				SELECT @FirstName = FirstName
					,@LastName = LastName
					,@PhoneNumber = PhoneNumber
					,@Email = EmailId
				FROM Customers WITH (NOLOCK)
				WHERE CustomerId = @CustomerId
					AND TenantId = @TenantId
					AND IsDeleted = 0;
					--SET @ReturnMessage = 'A customer with this phone number already exists.';      
					--THROW 50001,@ReturnMessage , 1;      
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
			SELECT @FirstName = FirstName
				,@LastName = LastName
				,@PhoneNumber = PhoneNumber
				,@Email = EmailId
			FROM Customers WITH (NOLOCK)
			WHERE CustomerId = @CustomerId
				AND TenantId = @TenantId
				AND IsDeleted = 0;

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
				AND CustomerTypeId IN (
					1
					,2
					)
				AND CustomerTypeId <> @TargetCustomerTypeId;
		END

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
					,@FullAddress

				SET @CustomerAddressId = SCOPE_IDENTITY();
			END
					--ELSE  
					--BEGIN  
					-- IF NOT EXISTS (  
					--   SELECT 1  
					--   FROM CustomerAddresses WITH (NOLOCK)  
					--   WHERE CustomerAddressId = @CustomerAddressId  
					--    AND CustomerId = @CustomerId  
					--    AND IsDeleted = 0  
					--   )  
					-- BEGIN  
					--  SET @ReturnMessage = 'Selected Customer Adress is already deleted, Please reselect.';  
					--  --RAISERROR(@ReturnMessage, 16, 1)    
					--  --RETURN;    
					--  THROW 50001  
					--   ,@ReturnMessage  
					--   ,1;  
					-- END  
					-- IF isnull(@IsDefault, 0) = 1  
					--  AND ISNULL(@CustomerId, 0) > 0  
					-- BEGIN  
					--  UPDATE CustomerAddresses  
					--  SET IsDefault = 0  
					--  WHERE CustomerId = @CustomerId  
					-- END  
					-- UPDATE CustomerAddresses  
					-- SET  
					--  --AddressType = @AddressType      
					--  -- ,Street1 = ISNULL(@Street1, '')      
					--  -- ,Street2 = @Street2      
					--  -- ,Landmark = @Landmark      
					--  -- ,Area = @Area      
					--  -- ,City = @City      
					--  -- ,STATE = @State      
					--  -- ,ZipCode = ISNULL(@ZipCode,ZipCode)      
					--  IsDefault = ISNULL(@IsDefault, 1)  
					--  --,Latitude = @Latitude      
					--  --,Longitude = @Longitude      
					--  --,Country = @Country      
					--  --,FullAddress = @FullAddress      
					--  ,UpdatedBy = @UserId  
					--  ,UpdatedDate = @dt  
					--  ,UpdatedUTCDate = @dtUTC  
					-- WHERE CustomerAddressId = @CustomerAddressId     --  AND CustomerId = @CustomerId  
					--  AND IsDeleted = 0;  
					--END  
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

		IF ISNULL(@LocationID, 0) = 0
		BEGIN
			DECLARE @LookupUserId BIGINT = ISNULL(NULLIF(@SalesmanId, 0), @UserId);

			SELECT TOP 1 @DefaultLocationId = LocationID
			FROM LocationUserMapping
			WHERE UserID = @LookupUserId
				AND IsDefault = 1
			ORDER BY LocationUserMappingID;

			SET @LocationID = @DefaultLocationId;
		END

		SET @LeadNumber = dbo.GetLeadNumber(@TenantId);

		UPDATE TenantConfigurations
		SET LeadNumberCounter = LeadNumberCounter + 1
		WHERE TenantId = @TenantId;

		INSERT INTO Leads (
			FirstName
			,LastName
			,Notes
			,Source
			,Status
			,SalesmanId
			,SalesmanAssignDate
			,LastContactedDate
			,Other
			,TenantId
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			,Email
			,PhoneNumber
			,InquiryAbout
			,LocationID
			,CloseLookupValueId
			,InquiryFor
			,RefferedBy
			,CustomerId
			,LeadSourceId
			,LeadNumber
			,PurchaseUrgencyId
			,CustomerBehaviorId
			,ArchitectBehaviorId
			,VisitForId
			,CompanyName
			,BuyingRangeValueId
			,AlternateMobileNumber
			,InquiryAreaRequirement
			,AlternateSalesmanId
			,ClientMeetingStageId
			,ArchitectMeetingStageId
			,LeadType
			)
		VALUES (
			@FirstName
			,@LastName
			,@Inquiry
			,0
			,@Status
			,@SalesmanId
			,CASE 
				WHEN @SalesmanId IS NOT NULL
					THEN @Date
				ELSE NULL
				END
			,@Date
			,@Other
			,@TenantId
			,@UserId
			,@dt
			,@dtUTC
			,@Email
			,@PhoneNumber
			,@InquiryAbout
			,@LocationID
			,@CloseLookupValueId
			,@InquiryFor
			,@RefferedBy
			,@CustomerId
			,@LeadSourceId
			,@LeadNumber
			,@PurchaseUrgencyId
			,@CustomerBehaviorId
			,@ArchitectBehaviorId
			,@VisitForId
			,@CompanyName
			,@BuyingRangeValueId
			,@AlternateMobileNumber
			,@InquiryAreaRequirement
			,@AlternateSalesmanId
			,@ClientMeetingStageId
			,@ArchitectMeetingStageId
			,@LeadType
			);

		SET @NewLeadId = SCOPE_IDENTITY();

		INSERT INTO LeadLogs (
			LeadId
			,SalesmanId
			,SentBy
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			)
		VALUES (
			@NewLeadId
			,ISNULL(@SalesmanId, 0)
			,@UserId
			,@UserId
			,@dt
			,@dtUTC
			);

		COMMIT TRANSACTION CreateLeadWithCustomerDetails;

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
		WHERE l.LeadId = @NewLeadId;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION CreateLeadWithCustomerDetails;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg NVARCHAR(4000);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		 THROW
	END CATCH
END;

GO

