CREATE PROCEDURE [dbo].[ImportCustomer] (
	@WrkCustomerID BIGINT
	,@UserId INT
	,@TotalRecords INT
	,@ProcessStartDate DATETIMEOFFSET = NULL
	,@ProcessEndDate DATETIMEOFFSET = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRAN;

		DECLARE @TenantId BIGINT
			,@WrkImportFileID BIGINT
			,@ErrorMessage VARCHAR(MAX) = ''
			,@CustomerId BIGINT
			,@FirstName VARCHAR(MAX)
			,@LastName VARCHAR(MAX)
			,@EmailID VARCHAR(MAX)
			,@PrimaryContactNumber VARCHAR(MAX)
			,@AlternateContactNumber VARCHAR(MAX)
			,@AltName VARCHAR(50)
			,@GSTNo VARCHAR(MAX)
			,@ZipCode VARCHAR(MAX)
			,@Profession VARCHAR(20)
			,@CompanyName VARCHAR(30)
			,@Street1 VARCHAR(MAX)
			,@Street2 VARCHAR(MAX)
			,@Landmark VARCHAR(MAX)
			,@Area VARCHAR(MAX)
			,@City VARCHAR(MAX)
			,@State VARCHAR(MAX)
			,@Birthday VARCHAR(20)
			,@ProfessionId INT = NULL
			,@TenantLogo VARCHAR(800)
			,@LocationID BIGINT = NULL
			,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@dtUTC DATETIME = GETUTCDATE();

		SELECT @WrkImportFileID = WrkImportFileID
			,@FirstName = FirstName
			,@LastName = LastName
			,@EmailID = EmailID
			,@PrimaryContactNumber = PrimaryContactNumber
			,@AlternateContactNumber = AlternateContactNumber
			,@AltName = AltName
			,@GSTNo = GSTNo
			,@Profession = Profession
			,@CompanyName = CompanyName
			,@Street1 = Street1
			,@Street2 = Stree2
			,@Landmark = Landmark
			,@Area = Area
			,@City = City
			,@State = STATE
			,@ZipCode = ZipCode
			,@Birthday = Birthday
		FROM WrkImportCustomers WITH (NOLOCK)
		WHERE WrkCustomerID = @WrkCustomerID;

		SELECT TOP 1 @TenantId = TenantId
		FROM WrkImportFiles WITH (NOLOCK)
		WHERE WrkImportFileID = @WrkImportFileID;

		SELECT @TenantLogo = LogoPath
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId

		IF EXISTS (
				SELECT 1
				FROM Customers WITH (NOLOCK)
				WHERE PhoneNumber = @PrimaryContactNumber
					AND TenantId = @TenantId
					AND IsDeleted = 0
					AND CustomerTypeId = 1
				)
		BEGIN
			SET @ErrorMessage = 'This record already exists. ';
		END

		IF ISNULL(TRIM(@PrimaryContactNumber), '') = ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Primary Contact Number is blank. ';
		END

        IF (
			TRIM(@PrimaryContactNumber) LIKE '%[^0-9+]%'
			OR TRIM(@PrimaryContactNumber) LIKE '_%[+]%'
			OR (TRIM(@PrimaryContactNumber) LIKE '+%' AND LEN(TRIM(@PrimaryContactNumber)) > 16)
			OR (TRIM(@PrimaryContactNumber) NOT LIKE '+%' AND LEN(TRIM(@PrimaryContactNumber)) > 15)
			OR (TRIM(@PrimaryContactNumber) LIKE '+%' AND LEN(TRIM(@PrimaryContactNumber)) < 2)
		)
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Primary Contact Number is not in the correct format. ';
		END

		IF ISNULL(TRIM(@AlternateContactNumber), '') <> ''
			AND (
				TRIM(@AlternateContactNumber) LIKE '%[^0-9+]%'
				OR TRIM(@AlternateContactNumber) LIKE '_%[+]%'
				OR (TRIM(@AlternateContactNumber) LIKE '+%' AND LEN(TRIM(@AlternateContactNumber)) > 16)
				OR (TRIM(@AlternateContactNumber) NOT LIKE '+%' AND LEN(TRIM(@AlternateContactNumber)) > 15)
				OR (TRIM(@AlternateContactNumber) LIKE '+%' AND LEN(TRIM(@AlternateContactNumber)) < 2)
			)
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Alternate Contact Number is not in the correct format. ';
		END
		
		IF ISNULL(@Birthday,'') <> ''
			AND TRY_CONVERT(date, @Birthday, 103) IS NULL
		BEGIN
		    SET @ErrorMessage = @ErrorMessage + 'Invalid Birthday Format! Please enter birthday in the valid format: DD/MM/YYYY. For example, 25/12/1990. '
		END

		IF ISNULL(@FirstName, '') = ''
			OR PATINDEX('%[^a-zA-Z]%', @FirstName) > 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + ' FirstName Name is not in the correct format. ';
		END

		IF ISNULL(@LastName, '') <> ''
			AND PATINDEX('%[^a-zA-Z]%', @LastName) > 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + ' Last Name is not in the correct format. ';
		END

		IF ISNULL(@AltName, '') <> ''
			AND PATINDEX('%[^a-zA-Z]%', @AltName) > 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + ' Alternate Name is not in the correct format. ';
		END

		IF ISNULL(@EmailID, '') <> ''			
			AND 
				(
					@EmailID NOT LIKE '%@%.%'
					OR @EmailID LIKE '% %'
					OR @EmailID LIKE '%@%@%'
				)
		BEGIN
			SET @ErrorMessage = @ErrorMessage + ' Email iD is not in the correct format. ';
		END

		IF ISNULL(@GSTNo, '') <> ''
			AND @GSTNo NOT LIKE '[0-9][0-9][A-Z][A-Z][A-Z][A-Z][A-Z]%'
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'GSTNo is not in the correct format. ';
		END

		IF ISNULL(@Profession, '') <> ''
			AND PATINDEX('%[^a-zA-Z0-9_]%', TRIM(@Profession)) > 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Profession is not in the correct format. ';
		END

		IF ISNULL(@CompanyName, '') <> ''
			AND PATINDEX('%[^a-zA-Z0-9_ ]%', TRIM(@CompanyName)) > 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Company Name is not in the correct format. ';
		END

		IF (ISNULL(@Street1, '') <> ''
			OR ISNULL(@Street2, '') <> ''
			OR ISNULL(@Landmark, '') <> ''
			OR ISNULL(@Area, '') <> ''
			OR ISNULL(@City, '') <> ''
			OR ISNULL(@State, '') <> ''
			OR ISNULL(@ZipCode, '') <> '')
		BEGIN
			IF ISNULL(@Street1, '') = ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Street1 is not in the correct format. ';
			END

			IF ISNULL(@City, '') = ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'City is not in the correct format. ';
			END

			IF ISNULL(@State, '') = ''
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'State is not in the correct format. ';
			END
			
			IF ISNULL(@ZipCode, '') <> ''
				AND @ZipCode NOT LIKE '[0-9][0-9][0-9][0-9][0-9][0-9]'
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Pincode is not in the correct format or blank. ';
			END
		END

		IF @ErrorMessage = ''
		BEGIN
				
			SELECT @ProfessionId = LookupValueId
			FROM Lookups LK WITH (NOLOCK)
			INNER JOIN LookupValues LKV WITH (NOLOCK) on LK.LookupId = LKV.LookupId
			WHERE LookupName = 'Profession'
			and LK.TenantId = @TenantId
			and LK.IsDeleted = 0
			and LKV.IsDeleted = 0
			AND TRIM(LKV.LookupValueName) = TRIM(@Profession)			


			IF ISNULL(@ProfessionId,0) > 0 AND ISNULL(@Profession, '') <> ''
			BEGIN

				INSERT INTO LookupValues
				(
					LookupId
					,LookupValueName
					,IsDeleted
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
				)
				SELECT LookupId
					  ,TRIM(@Profession)
					  ,0
					  ,@UserId
					  ,@dt
					  ,@dtUTC
				FROM Lookups 
				WHERE LookupName = 'Profession'
					 and TenantId = @TenantId

				SET @ProfessionId = SCOPE_IDENTITY()
			END

			select @LocationID = LUM.LocationID 
			from LocationUserMapping LUM WITH (NOLOCK)
			INNER JOIN Locations L WITH (NOLOCK) ON L.LocationID = LUM.LocationID 
			where UserID = @UserID
			and IsDefault = 1
			AND L.IsDeleted = 0

			INSERT INTO Customers (
	
				CustomerTypeId
				,FirstName
				,LastName
				,EmailId
				,PhoneNumber
				,AltPhoneNumber
				,GSTNo
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,Birthday
				,Profession
				,CompanyName
				,AltName
				,ProfessionId
				,LocationID
				)
			VALUES (
				 1
				,TRIM(@FirstName)
				,TRIM(@LastName)
				,TRIM(@EmailID)
				,TRIM(@PrimaryContactNumber)
				,TRIM(@AlternateContactNumber)
				,TRIM(@GSTNo)
				,@TenantId
				,0
				,@UserId
				,@dt
				,@dtUTC
				,CONVERT(date, TRIM(@Birthday), 103)
				,TRIM(@Profession)
				,TRIM(@CompanyName)
				,TRIM(@AltName)
				,@ProfessionId
				,@LocationID
				);

			SET @CustomerId = SCOPE_IDENTITY();

			IF @CustomerId IS NOT NULL
				AND
				(
					(ISNULL(@Street1, '') <> ''
					AND ISNULL(@City, '') <> ''
					AND ISNULL(@State, '') <> ''
					AND ISNULL(@ZipCode, '') <> '')
				)
			BEGIN
				INSERT INTO CustomerAddresses (
					
					 CustomerId
					,AddressType
					,Street1
					,Street2
					,Landmark
					,Area
					,City
					,State
					,ZipCode
					,IsDefault
					,IsDeleted
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,GSTNo					

					)
				VALUES (
					@CustomerId
					,'Home'
					,TRIM(@Street1)
					,ISNULL(@Street2, '')
					,ISNULL(@Landmark, '')
					,TRIM(ISNULL(@Area, ''))
					,TRIM(@City)
					,TRIM(@State)
					,TRIM(@ZipCode)
					,1	
					,0
					,@UserId
					,@dt
					,@dtUTC
					,TRIM(@GSTNo)
					);
			END

			UPDATE WrkImportCustomers
			SET STATUS = 2
				,ErrorMessage = NULL
			WHERE WrkCustomerID = @WrkCustomerID;
		END
		ELSE
		BEGIN
			UPDATE WrkImportCustomers
			SET STATUS = 3
				,ErrorMessage = @ErrorMessage
			WHERE WrkCustomerID = @WrkCustomerID;
		END

		UPDATE WrkImportFiles
		SET Success = CASE 
				WHEN @ErrorMessage = ''
					THEN ISNULL(Success, 0) + 1
				ELSE ISNULL(Success,0)
				END
			,Failed = CASE 
				WHEN @ErrorMessage = ''
					THEN ISNULL(Failed,0)
				ELSE ISNULL(Failed, 0) + 1
				END
			,STATUS = 2
			,TotalRecords = @TotalRecords
			,ProcessStartDate = CASE WHEN @ProcessStartDate IS NULL THEN ProcessStartDate ELSE @ProcessStartDate END
			,ProcessEndDate = CASE WHEN @ProcessEndDate IS NULL THEN ProcessEndDate ELSE @ProcessEndDate END
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @dtUTC
		WHERE WrkImportFileID = @WrkImportFileID;

		SELECT @CustomerId AS CustomerId
			,@TenantId AS TenantId
			,CASE WHEN @ErrorMessage = '' THEN @TenantLogo ELSE NULL END AS TenantLogo
			,@ErrorMessage AS ErrorMessage;

		COMMIT;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX)

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ErrorMsg = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog
			@ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg

		SELECT NULL AS CustomerId
			,@TenantId AS TenantId
			,NULL AS TenantLogo 
			,ERROR_MESSAGE() AS ErrorMessage;
	END CATCH
END

GO

