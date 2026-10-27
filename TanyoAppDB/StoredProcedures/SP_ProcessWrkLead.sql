CREATE PROCEDURE [dbo].[SP_ProcessWrkLead] (
	@WrkLeadId bigint
	,@UserId INT
	,@TotalRecords INT
	,@ProcessStartDate DATETIMEOFFSET = NULL
	,@ProcessEndDate DATETIMEOFFSET = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #Categories

	DROP TABLE IF EXISTS #LeadResponse

	DECLARE @TenantId INT
		,@LeadRequestDetails VARCHAR(MAX)
		,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtUTC DATETIME = GETUTCDATE()
		,@ErrorMessage VARCHAR(MAX) = ''
		,@WrkImportFileID BIGINT
		,@CustomerName VARCHAR(128)
		,@CustomerFirstName VARCHAR(50)
		,@CustomerLastName VARCHAR(50)
		,@SalesmanName NVARCHAR (MAX)
		,@SalesmanFirstName NVARCHAR (MAX)
		,@SalesmanLastName NVARCHAR (MAX)
		,@PhoneNumber VARCHAR(50)
		,@Email  VARCHAR(100)
		,@ZipCode VARCHAR (6)
		,@Address VARCHAR (MAX)
		,@SalesmanUserId INT = 0
		,@Status VARCHAR(128)
		,@LeadStatus INT
		,@Notes NVARCHAR(MAX)
		,@LeadSource VARCHAR(250)
		,@LeadSourceId INT
		,@InquiryFor VARCHAR(MAX)
		,@CategoryName VARCHAR(MAX)
		,@PurchaseUrgency VARCHAR(250)
		,@PurchaseUrgencyId INT
		,@CustomerBehavior VARCHAR(250)
		,@CustomerBehaviorId INT
		,@CustomerId BIGINT = 0
		,@CustomerAddressId BIGINT = 0

	CREATE TABLE #LeadResponse
	(
	        LeadId bigint
            ,FirstName VARCHAR(50)
            ,LastName VARCHAR(50)
            ,Notes NVARCHAR (MAX)
            ,PhoneNumber VARCHAR(50)
            ,SalesmanId bigint
            ,Other  VARCHAR (MAX)
            ,Email VARCHAR(50)
            ,Priority INT 
            ,InquiryAbout VARCHAR (MAX)
            ,CustomerId BIGINT
            ,CloseLookupValueId INT
            ,RefferedBy BIGINT
            ,InquiryFor VARCHAR (MAX)
            ,LeadSourceId INT
            ,PurchaseUrgencyId INT
            ,CustomerBehaviorId INT
            ,CustomerAddressId INT
			,BuyingRangeValueId BIGINT
			,AlternateMobileNumber NVARCHAR(15) 
			,InquiryAreaRequirement DECIMAL(18,2)
			,AlternateSalesmanId BIGINT
			,ClientMeetingStageId INT
			,ArchitectMeetingStageId INT
			,LeadType INT
	)

	SELECT @TenantId = TenantId
		,@WrkImportFileID = WrkImportFileID
		,@CustomerName = CustomerName
		,@PhoneNumber = RIGHT(TRIM(PhoneNumber), 16)
		,@SalesmanName = SalesmanName
		,@Address = [Address]
		,@Status = [LeadStatus]
		,@Notes = Notes
		,@InquiryFor = InquiryFor
		,@LeadSource = LeadSource
		,@PurchaseUrgency = PurchaseUrgency
		,@CustomerBehavior = CustomerBehavior
	FROM dbo.WrkLead WITH (NOLOCK)
	WHERE WrkLeadId = @WrkLeadId;


	SELECT @LeadSourceId = LookupValueId
	FROM LookupValues LKV
	INNER JOIN Lookups LK ON LKV.LookupId = LK.LookupId
	WHERE TenantId = @TenantId
		AND LookupValueName = TRIM(@LeadSource)
		AND LookupName = 'LeadSources'
		AND LKV.IsDeleted = 0

	SELECT @PurchaseUrgencyId = LookupValueId
	FROM LookupValues LKV
	INNER JOIN Lookups LK ON LKV.LookupId = LK.LookupId
	WHERE TenantId = @TenantId
		AND LookupValueName = TRIM(@PurchaseUrgency)
		AND LookupName = 'PurchaseUrgency'
		AND LKV.IsDeleted = 0
	
	SELECT @CustomerBehaviorId = LookupValueId
	FROM LookupValues LKV
	INNER JOIN Lookups LK ON LKV.LookupId = LK.LookupId
	WHERE TenantId = @TenantId
		AND LookupValueName = TRIM(@CustomerBehavior)
		AND LookupName = 'CustomerBehavior'
		AND LKV.IsDeleted = 0

	SELECT TRIM(value) AS CategoryName
	INTO #Categories
	FROM STRING_SPLIT(TRIM(@InquiryFor),',')


	SELECT @CategoryName = STRING_AGG(CTS.CategoryName,',')
	FROM #Categories CTS
	LEFT JOIN Categories CT ON CT.CategoryName = CTS.CategoryName 
		AND CT.IsDeleted = 0 
		AND CT.TenantId = @TenantId
	WHERE CT.CategoryId IS NULL

	IF CHARINDEX(' ', TRIM(@CustomerName)) > 0
	BEGIN
	    SET @CustomerFirstName = LEFT(TRIM(@CustomerName),
	                                  CHARINDEX(' ', TRIM(@CustomerName)) - 1);
	
	    SET @CustomerLastName = LTRIM(SUBSTRING(TRIM(@CustomerName),
	                                            CHARINDEX(' ', TRIM(@CustomerName)) + 1,
	                                            LEN(TRIM(@CustomerName))));
	END
	ELSE
	BEGIN
	    SET @CustomerFirstName = TRIM(@CustomerName);
	    SET @CustomerLastName = NULL;
	END

	IF CHARINDEX(' ', TRIM(@SalesmanName)) > 0
	BEGIN
	    SET @SalesmanFirstName = LEFT(TRIM(@SalesmanName),
	                                  CHARINDEX(' ', TRIM(@SalesmanName)) - 1);
	
	    SET @SalesmanLastName = LTRIM(SUBSTRING(TRIM(@SalesmanName),
	                                            CHARINDEX(' ', TRIM(@SalesmanName)) + 1,
	                                            LEN(TRIM(@SalesmanName))));
	END
	ELSE
	BEGIN
	    SET @SalesmanFirstName = TRIM(@SalesmanName);
	    SET @SalesmanLastName = NULL;
	END

	   SELECT @SalesmanUserId = AU.UserId 
          FROM AspNetUsers AU WITH (NOLOCK)
          INNER JOIN UserTenantMapping UTM WITH (NOLOCK) ON AU.UserId = UTM.UserId AND UTM.IsDeleted = 0
          WHERE AU.FirstName = @SalesmanFirstName 
          AND AU.LastName = @SalesmanLastName 
          AND AU.IsDeleted = 0 
          AND UTM.TenantId = @TenantId

    IF ISNULL(TRIM(@CustomerName),'') = '' OR ISNULL(@CustomerFirstName,'') = ''
    BEGIN
        SET @ErrorMessage = @ErrorMessage + 'Customer Name is required. ';	
    END	

	IF ISNULL(TRIM(@PhoneNumber),'') = '' 
	BEGIN
	    SET @ErrorMessage = @ErrorMessage + 'Phone Number is required. ';
	END	

	IF PATINDEX('%[^A-Za-z0-9&./()'' -]%', @CustomerFirstName) > 0
			
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'First Name only Contain Character. ';
	END;

	--IF (
	--				LEN(REPLACE(TRIM(@PhoneNumber), ' ', '')) <> 10
	--				OR REPLACE(TRIM(@PhoneNumber), ' ', '') LIKE '%[^0-9]%'
	--		)

	IF (
        TRIM(@PhoneNumber) = ''
	    OR TRIM(@PhoneNumber) LIKE '%[^0-9+]%'
	    OR TRIM(@PhoneNumber) LIKE '_%[+]%'
	    OR (TRIM(@PhoneNumber) LIKE '+%' AND LEN(TRIM(@PhoneNumber)) > 16)
	    OR (TRIM(@PhoneNumber) NOT LIKE '+%' AND LEN(TRIM(@PhoneNumber)) > 15)
	    OR (TRIM(@PhoneNumber) LIKE '+%' AND LEN(TRIM(@PhoneNumber)) < 2)
	)
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Invalid phone number exists. ';
	END

	IF ISNULL(TRIM(@Status),'') <> '' AND TRIM(@Status) NOT IN (    
						'Assigned'
						,'Working'
						,'Qualified'
						,'Nurture'
						,'Disqualified'
						,'Closed'
						,'Delete'
						,'Unassigned')
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Invalid lead status. ';
	END

	IF ISNULL(@LeadSourceId,0) = 0 AND ISNULL(TRIM(@LeadSource),'') <> '' 
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Invalid How Did You Hear About Us. ';
	END

	IF ISNULL(@CategoryName,'') <> '' AND ISNULL(TRIM(@InquiryFor),'') <> ''
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Following Categories: ' + @CategoryName + ' do not exist or are deleted ' ;
	END

	IF ISNULL(@CustomerBehaviorId,0) = 0  AND ISNULL(TRIM(@CustomerBehavior),'') <> '' 
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Invalid Customer Behavior. ';
	END

	IF ISNULL(@PurchaseUrgencyId,0) = 0  AND ISNULL(TRIM(@PurchaseUrgency),'') <> ''  
	BEGIN
		SET @ErrorMessage = @ErrorMessage + 'Invalid Purchase Urgency. ';
	END

	IF ISNULL(TRIM(@SalesmanName),'') <> '' AND ISNULL(@SalesmanUserId,0) = 0
	BEGIN
	SET @ErrorMessage = @ErrorMessage + 'Salesman does not exist. ';
	END
	IF @ErrorMessage = ''
	BEGIN

			SET @LeadStatus = CASE TRIM(@Status)
			            WHEN 'Assigned'    THEN 0
			            WHEN 'Working'     THEN 1
			            WHEN 'Qualified'   THEN 2
			            WHEN 'Nurture'     THEN 3
			            WHEN 'Disqualified' THEN 4
			            WHEN 'Closed'      THEN 5
			            WHEN 'Delete'      THEN 6
			            WHEN 'Unassigned'  THEN 7
						ELSE 7  -- Unassigned 
			          END;


			IF @SalesmanUserId > 0 AND  ISNULL(TRIM(@Status),'') = ''
			BEGIN
				SET @LeadStatus = 0
			END

		SELECT @CustomerId = CustomerId
		FROM Customers WITH (NOLOCK)
		WHERE PhoneNumber = @PhoneNumber
		AND IsDeleted = 0
		AND TenantID = @TenantID

		SELECT @CustomerAddressId = CustomerAddressId
		FROM CustomerAddresses WITH (NOLOCK)
		WHERE CustomerId = @CustomerId
		AND TRIM(FullAddress) = TRIM(@Address)
		AND ISDeleted = 0

		IF ISNULL(@CustomerAddressId, 0) > 0 OR ISNULL(@Address,'') = '' 
		BEGIN
		SELECT @LeadRequestDetails = (
				SELECT ISNULL(@CustomerId,0) AS 'customerDetails.CustomerId'
					,@CustomerFirstName AS 'customerDetails.firstName'
					,@CustomerLastName AS 'customerDetails.lastName'
					,@PhoneNumber AS 'customerDetails.phoneNumber'
					,NULL AS 'customerDetails.emailId'
					,NULL AS 'customerAddress.customerAddressId'
					,NULL AS 'customerAddress.addressType'
					,NULL AS 'customerAddress.street1'
					,NULL AS 'customerAddress.street2'
					,NULL AS 'customerAddress.area'
					,NULL AS 'customerAddress.city'
					,NULL AS 'customerAddress.state'
					,NULL AS 'customerAddress.zipCode'
					,NULL AS 'customerAddress.isDefault'
					,NULL AS 'customerAddress.latitude'
					,NULL AS 'customerAddress.longitude'
					,NULL AS 'customerAddress.country'
					,NULL AS 'customerAddress.fullAddress'
					,@LeadStatus AS 'leadDetails.status'
					,@Notes AS 'leadDetails.inquiry'
					,@SalesmanUserId AS 'leadDetails.salesmanId'
					,@LeadSourceId AS 'leadDetails.leadSourceId'
					,NULL AS 'leadDetails.other'
					,NULL AS 'leadDetails.inquiryAbout'
					,@InquiryFor AS 'leadDetails.inquiryFor'
					,NULL AS 'leadDetails.locationId'
					,NULL AS 'leadDetails.refferedBy'
					,@PurchaseUrgencyId AS 'leadDetails.purchaseUrgencyId'
					,@CustomerBehaviorId AS 'leadDetails.customerBehaviorId'
				FROM dbo.WrkLead
				WHERE WrkLeadId = @WrkLeadId
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				);
			END
			IF ISNULL(@CustomerAddressId, 0) = 0 AND ISNULL(@Address,'') <> '' 
			BEGIN
			  SELECT @LeadRequestDetails  = (
                     SELECT ISNULL(@CustomerId,0) AS 'customerDetails.CustomerId'
                         ,@CustomerFirstName AS 'customerDetails.firstName'
                         ,@CustomerLastName AS 'customerDetails.lastName'
                         ,@PhoneNumber AS 'customerDetails.phoneNumber'
                         ,NULL AS 'customerDetails.emailId'
                         ,0 AS 'customerAddress.customerAddressId'
                         ,'Home' AS 'customerAddress.addressType'
                         ,'' AS 'customerAddress.street1'
                         ,NULL AS 'customerAddress.street2'
                         ,NULL AS 'customerAddress.area'
                         ,'' AS 'customerAddress.city'
                         ,'' AS 'customerAddress.state'
                         ,'' AS 'customerAddress.zipCode'
                         ,1 AS 'customerAddress.isDefault'
                         ,NULL AS 'customerAddress.latitude'
                         ,NULL AS 'customerAddress.longitude'
                         ,NULL AS 'customerAddress.country'
                         ,@Address AS 'customerAddress.fullAddress'
                         ,@LeadStatus AS 'leadDetails.status'
                         ,@Notes AS 'leadDetails.inquiry'
                         ,@SalesmanUserId AS 'leadDetails.salesmanId'
                         ,@LeadSourceId AS 'leadDetails.leadSourceId'
                         ,NULL AS 'leadDetails.other'
                         ,NULL AS 'leadDetails.inquiryAbout'
                         ,@InquiryFor AS 'leadDetails.inquiryFor'
                         ,NULL AS 'leadDetails.locationId'
                         ,NULL AS 'leadDetails.refferedBy'
                         ,@PurchaseUrgencyId AS 'leadDetails.purchaseUrgencyId'
                         ,@CustomerBehaviorId AS 'leadDetails.customerBehaviorId'
               FROM dbo.WrkLead
               WHERE WrkLeadId = @WrkLeadId
               FOR JSON PATH
                   ,WITHOUT_ARRAY_WRAPPER
               );
			   END

		BEGIN TRY
			INSERT INTO #LeadResponse
			EXEC dbo.CreateLeadWithCustomerDetails @LeadRequestDetails = @LeadRequestDetails
				,@TenantId = @TenantId
				,@UserId = @UserId;
		END TRY

		BEGIN CATCH
			SELECT ERROR_NUMBER() AS ErrorNumber
				,ERROR_MESSAGE() AS ErrorMessage
				,ERROR_LINE() AS ErrorLine
				,ERROR_PROCEDURE() AS ErrorProcedure;

			SET @ErrorMessage = ERROR_MESSAGE();

			DECLARE @ObjectName VARCHAR(500)    
			SET @ObjectName = OBJECT_NAME(@@PROCID) 

			EXEC dbo.SaveDBErrorLog         
				@ObjectName = @ObjectName
				,@ErrorMsg = @ErrorMessage; 
		END CATCH
	END

	IF @ErrorMessage = ''
		UPDATE dbo.WrkLead
		SET STATUS = 2
			,ErrorMessage = NULL
		WHERE WrkLeadId = @WrkLeadId;
	ELSE
		UPDATE dbo.WrkLead
		SET STATUS = 3
			,ErrorMessage = @ErrorMessage
		WHERE WrkLeadId = @WrkLeadId;

	BEGIN TRY
		UPDATE WrkImportFiles
		SET Success = CASE 
				WHEN @ErrorMessage = ''
					THEN ISNULL(Success, 0) + 1
				ELSE ISNULL(Success, 0)
				END
			,Failed = CASE 
				WHEN @ErrorMessage = ''
					THEN ISNULL(Failed, 0)
				ELSE ISNULL(Failed, 0) + 1
				END
			,TotalRecords = @TotalRecords
			,STATUS = 2
			,ProcessStartDate = CASE 
				WHEN @ProcessStartDate IS NULL
					THEN ProcessStartDate
				ELSE @ProcessStartDate
				END
			,ProcessEndDate = CASE 
				WHEN @ProcessEndDate IS NULL
					THEN ProcessEndDate
				ELSE @ProcessEndDate
				END
			,UpdatedBy = @UserId
			,UpdatedDate = @dt
			,UpdatedUTCDate = @dtUTC
		WHERE WrkImportFileID = @WrkImportFileID;

	IF @ErrorMessage = ''
		SELECT LeadId
			,@TenantId AS TenantId
			,NULL AS ErrorMessage
		FROM #LeadResponse;
	ELSE
		SELECT CAST(0 AS BIGINT) AS LeadId
			,@TenantId AS TenantId
			,@ErrorMessage AS ErrorMessage;

	END TRY

	BEGIN CATCH
		DECLARE @ErrorMsg2 VARCHAR(MAX)
		SET @ErrorMsg2 = ERROR_MESSAGE()
		
		DECLARE @ObjectName2 VARCHAR(500)    
		
		SET @ObjectName2 = OBJECT_NAME(@@PROCID) 

	EXEC dbo.SaveDBErrorLog                
		@ObjectName = @ObjectName2              -- reuse @ObjectName declared above
		,@ErrorMsg = @ErrorMsg2;

		SELECT CAST(0 AS BIGINT) AS LeadId
		,@TenantId AS TenantId
		,ERROR_MESSAGE() AS ErrorMessage
	END CATCH
    END

GO

