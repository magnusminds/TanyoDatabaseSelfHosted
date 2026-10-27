CREATE PROCEDURE [dbo].[ImportVendor] (
	@WrkVendorID BIGINT
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
			,@VendorId BIGINT
			,@VendorName VARCHAR(200)
			,@VendorCode VARCHAR(50)
			,@VendorEmailId VARCHAR(200)
			,@VendorPhone VARCHAR(20)
			,@GST VARCHAR(20)
			,@ContactPersonName VARCHAR(200)
			,@ContactPersonEmail VARCHAR(200)
			,@ContactPersonPhone VARCHAR(20)
			,@PaymentTermsInDays VARCHAR(20)
			,@TenantLogo VARCHAR(800)
			,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@dtUTC DATETIME = GETUTCDATE()

		SELECT @WrkImportFileID = WrkImportFileID
			,@VendorName = VendorName
			,@VendorCode = VendorCode
			,@VendorEmailId = VendorEmailId
			,@VendorPhone = VendorPhone
			,@GST = GST
			,@ContactPersonName = ContactPersonName
			,@ContactPersonEmail = ContactPersonEmail
			,@ContactPersonPhone = ContactPersonPhone
			,@PaymentTermsInDays = PaymentTermsInDays
		FROM WrkImportVendors WITH (NOLOCK)
		WHERE WrkVendorID = @WrkVendorID;

		SELECT @TenantId = TenantId
		FROM WrkImportFiles WITH (NOLOCK)
		WHERE WrkImportFileID = @WrkImportFileID;

		SELECT @TenantLogo = LogoPath
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId

		IF ISNULL(@VendorName, '') = ''
		BEGIN
			SET @ErrorMessage = 'Vendor Name is required. ';
		END
		ELSE
		BEGIN
			
			IF LEN(TRIM(@VendorName)) > 150
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Vendor Name cannot exceed 150 characters. ';
			END
			ELSE IF PATINDEX('%[^A-Za-z0-9&./()'' -]%', TRIM(@VendorName)) > 0
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Please enter valid vendor name. ';
			END

			IF EXISTS
			(
				SELECT 1
				FROM Vendors WITH (NOLOCK)
				WHERE UPPER(TRIM(VendorName))
					  = UPPER(TRIM(@VendorName))
				  AND TenantId = @TenantId
			)
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Vendor Name already exists for this tenant. ';
			END

		END
		IF ISNULL(@VendorCode, '') = ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Vendor Code is required. ';
		END
		ELSE
		BEGIN
			SET @VendorCode = TRIM(@VendorCode);

			IF LEN(@VendorCode) <> 6
				OR PATINDEX('%[^A-Z0-9]%', @VendorCode) > 0
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Vendor Code must be exactly 6 alphanumeric characters. ';
			END
			IF EXISTS (
					SELECT 1
					FROM Vendors WITH (NOLOCK)
					WHERE UPPER(VendorCode) = UPPER(@VendorCode)
						AND TenantId = @TenantId
					)
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Vendor Code already exists for this tenant. ';
			END
		END

		IF ISNULL(@VendorEmailId, '') = ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Email Id is required. ';
		END
		ELSE
		BEGIN
			IF (
					@VendorEmailId NOT LIKE '%@%.%'
					OR @VendorEmailId LIKE '% %'
					)
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Please enter valid email id. ';
			END
		END
		IF ISNULL(@VendorPhone, '') = ''
		BEGIN
			SET @ErrorMessage  = @ErrorMessage + 'Phone Number is required. ';
		END
		ELSE
		BEGIN
			IF (
				TRIM(@VendorPhone) LIKE '%[^0-9+]%'
				OR TRIM(@VendorPhone) LIKE '_%[+]%'
				OR (TRIM(@VendorPhone) LIKE '+%' AND LEN(TRIM(@VendorPhone)) > 16)
				OR (TRIM(@VendorPhone) NOT LIKE '+%' AND LEN(TRIM(@VendorPhone)) > 15)
				OR (TRIM(@VendorPhone) LIKE '+%' AND LEN(TRIM(@VendorPhone)) < 2)
			)
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Please enter valid vendor phone number. ';
			END
			IF EXISTS (
					SELECT 1
					FROM Vendors WITH (NOLOCK)
					WHERE VendorPhone = @VendorPhone
						AND TenantId = @TenantId
					)
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Phone Number already exists. ';
			END
		END
		IF ISNULL(TRIM(@ContactPersonPhone), '') <> ''
			AND (
				TRIM(@ContactPersonPhone) LIKE '%[^0-9+]%'
				OR TRIM(@ContactPersonPhone) LIKE '_%[+]%'
				OR (TRIM(@ContactPersonPhone) LIKE '+%' AND LEN(TRIM(@ContactPersonPhone)) > 16)
				OR (TRIM(@ContactPersonPhone) NOT LIKE '+%' AND LEN(TRIM(@ContactPersonPhone)) > 15)
				OR (TRIM(@ContactPersonPhone) LIKE '+%' AND LEN(TRIM(@ContactPersonPhone)) < 2)
			)
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Please enter valid contact person phone number. ';
		END

		IF ISNULL(@ContactPersonEmail, '') <> ''
			AND (
				@ContactPersonEmail NOT LIKE '%@%.%'
				OR @ContactPersonEmail LIKE '% %'
				)
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Please enter valid contact person email id. ';
		END

		IF ISNULL(@ContactPersonName, '') <> ''
			AND PATINDEX('%[^a-zA-Z ]%', @ContactPersonName) > 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Please enter valid contact person name. ';
		END

		IF ISNULL(@GST, '') <> ''
		BEGIN
			IF LEN(@GST) > 15
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'GST should have 15 characters. ';
			END

			IF EXISTS (
					SELECT 1
					FROM Vendors WITH (NOLOCK)
					WHERE UPPER(GST) = UPPER(@GST)
						AND TenantId = @TenantId
					)
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'GST Number already exist. ';
			END

			IF @GST NOT LIKE '[0-9][0-9][A-Z][A-Z][A-Z][A-Z][A-Z]%'
			BEGIN
				SET @ErrorMessage = @ErrorMessage + 'Please enter valid GST Number. ';
			END
		END

		IF ISNULL(@PaymentTermsInDays, '') = ''
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Payment Term Days is required. ';
		END
		IF TRY_CAST(@PaymentTermsInDays AS INT) IS NULL
			OR CAST(@PaymentTermsInDays AS INT) <= 0
		BEGIN
			SET @ErrorMessage = @ErrorMessage + 'Payment Term Days must be positive integer. ';
		END

		IF @ErrorMessage = ''
		BEGIN
			INSERT INTO Vendors (
				
				 VendorName
				,VendorEmailId
				,VendorPhone
				,GST
				,TenantId
				,ContactPersonName
				,ContactPersonEmail
				,ContactPersonPhone
				,Status
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,PaymentTermsInDays
				,VendorCode			
				
				)
			VALUES (
				TRIM(@VendorName)
				,TRIM(@VendorEmailId)
				,TRIM(@VendorPhone)
				,TRIM(@GST)
				,@TenantId
				,TRIM(@ContactPersonName)
				,TRIM(@ContactPersonEmail)
				,TRIM(@ContactPersonPhone)
				,1
				,@UserId
				,@dt
				,@dtUTC
				,CAST(@PaymentTermsInDays AS INT)
				,TRIM(@VendorCode)
				);

			SET @VendorId = SCOPE_IDENTITY();

			UPDATE WrkImportVendors
			SET STATUS = 2
				,ErrorMessage = NULL
			WHERE WrkVendorID = @WrkVendorID;
		END
		ELSE
		BEGIN
			UPDATE WrkImportVendors
			SET STATUS = 3
				,ErrorMessage = @ErrorMessage
			WHERE WrkVendorID = @WrkVendorID;
		END

		UPDATE WrkImportFiles
		SET Success = CASE 
				WHEN @ErrorMessage = ''
					THEN ISNULL(Success, 0) + 1
				ELSE ISNULL(Success,0)
				END
			,Failed = CASE 
				WHEN @ErrorMessage <> ''
					THEN ISNULL(Failed, 0) + 1
				ELSE ISNULL(Failed,0)
				END
			,STATUS = 2
			,TotalRecords = @TotalRecords
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @dtUTC
			,ProcessStartDate = CASE WHEN @ProcessStartDate IS NULL THEN ProcessStartDate ELSE @ProcessStartDate END
			,ProcessEndDate = CASE WHEN @ProcessEndDate IS NULL THEN ProcessEndDate ELSE @ProcessEndDate END
		WHERE WrkImportFileID = @WrkImportFileID;

		SELECT @VendorId AS VendorId
			,@TenantId AS TenantId
			,CASE WHEN @ErrorMessage = '' THEN @TenantLogo ELSE NULL END AS TenantLogo
			,@ErrorMessage AS ErrorMessage;


		COMMIT;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK;

		SELECT NULL AS VendorId
			,@TenantId AS TenantId
			,NULL AS TenantLogo
			,ERROR_MESSAGE() AS ErrorMessage;
	END CATCH
END

GO

