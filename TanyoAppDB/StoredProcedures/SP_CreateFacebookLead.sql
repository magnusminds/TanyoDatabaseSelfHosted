CREATE  PROCEDURE [dbo].[SP_CreateFacebookLead] (
    @TenantId INT,
    @LeadgenId VARCHAR(30),
    @PageId VARCHAR(30),
    @FormId VARCHAR(30) = NULL,
    @AdId VARCHAR(30) = NULL,
    @AdName NVARCHAR(300) = NULL,
    @AdsetId VARCHAR(30) = NULL,
    @AdsetName NVARCHAR(300) = NULL,
    @CampaignId VARCHAR(30) = NULL,
    @CampaignName NVARCHAR(300) = NULL,
    @Platform VARCHAR(20) = NULL,
    @IsOrganic BIT = NULL,
    @FbCreatedTime DATETIME2 = NULL,
    @FullName NVARCHAR(200) = NULL,
    @Email NVARCHAR(256) = NULL,
    @PhoneNumber NVARCHAR(50) = NULL,
    @City NVARCHAR(100) = NULL,
    @RawFieldData NVARCHAR(MAX) = NULL,
    @IsTestLead BIT = 0,
    @UserId INT = 1,
    @LeadStatus INT = 7 -- 7 = Unassigned; the showroom assigns it from the Leads grid
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @dt DATETIMEOFFSET = SYSDATETIMEOFFSET(),
        @dtUTC DATETIME = GETUTCDATE(),
        @ErrorMessage NVARCHAR(2000) = N'',
        @CrmLeadId BIGINT = 0,
        @FbLeadId BIGINT = 0,
        @CustomerId BIGINT = 0,
        @LeadSourceId BIGINT = NULL,
        @MainLocationId BIGINT = NULL,
        @FirstName NVARCHAR(500) = NULL,
        @LastName NVARCHAR(500) = NULL,
        @Phone NVARCHAR(50) = N'',
        @PhoneRaw NVARCHAR(50) = LTRIM(RTRIM(ISNULL(@PhoneNumber, N''))),
        @EmailClean NVARCHAR(256) = LTRIM(RTRIM(ISNULL(@Email, N''))),
        @HasError BIT = 0,
        @ErrNumber INT = 0,
        @ErrMessage NVARCHAR(4000) = N'',
        @ErrSeverity INT = 0,
        @ErrLine INT = 0,
        @ErrProc SYSNAME = N'';

    ------------------------------------------------------------------
    -- 0. Duplicate delivery guard (Service Bus is at-least-once).
    --    Checked BEFORE any write so a redelivery can never create a
    --    second Lead for the same LeadgenId.
    ------------------------------------------------------------------
    IF EXISTS (
        SELECT 1
        FROM [dbo].[FbLeads]
        WHERE LeadgenId = @LeadgenId
            AND Status = 'Imported'
            AND CrmLeadId IS NOT NULL
    )
    BEGIN
        SELECT TOP 1
            @CrmLeadId = CrmLeadId
        FROM [dbo].[FbLeads]
        WHERE LeadgenId = @LeadgenId
            AND Status = 'Imported'
            AND CrmLeadId IS NOT NULL
        ORDER BY FbLeadId DESC;

        SELECT @CrmLeadId AS CrmLeadId, @TenantId AS TenantId, NULLIF(@ErrorMessage, N'') AS ErrorMessage;

        RETURN;
    END

    ------------------------------------------------------------------
    -- 1. Claim/refresh the staging row OUTSIDE the create transaction so a
    --    failure still leaves a visible Failed/Pending history row.
    ------------------------------------------------------------------
    IF @IsTestLead = 1
    BEGIN
        IF EXISTS (SELECT 1 FROM [dbo].[FbLeads] WHERE LeadgenId = @LeadgenId)
            UPDATE [dbo].[FbLeads]
            SET Status = 'Skipped',
                LastError = N'This is a test lead from Meta, so it was not added to the CRM.',
                ProcessedAt = SYSDATETIME()
            WHERE LeadgenId = @LeadgenId;
        ELSE
            INSERT INTO [dbo].[FbLeads] (
                TenantId, LeadgenId, PageId, FormId, AdId, AdName, AdsetId, AdsetName,
                CampaignId, CampaignName, Platform, IsOrganic, FbCreatedTime,
                FullName, Email, PhoneNumber, City, RawFieldData, IsTestLead,
                Status, LastError, ReceivedAt, ProcessedAt, CreatedDate, CreatedUTCDate)
            VALUES (
                @TenantId, @LeadgenId, @PageId, @FormId, @AdId, @AdName, @AdsetId, @AdsetName,
                @CampaignId, @CampaignName, @Platform, @IsOrganic, @FbCreatedTime,
                @FullName, @EmailClean, @PhoneRaw, @City, @RawFieldData, 1,
                'Skipped', N'This is a test lead from Meta, so it was not added to the CRM.', SYSDATETIME(), SYSDATETIME(), @dt, @dtUTC);

        SELECT 0 AS CrmLeadId, @TenantId AS TenantId, NULL AS ErrorMessage;

        RETURN;
    END

    IF EXISTS (SELECT 1 FROM [dbo].[FbLeads] WHERE LeadgenId = @LeadgenId)
    BEGIN
        -- Retry of a previously Failed/Pending delivery: reuse the row.
        UPDATE [dbo].[FbLeads]
        SET TenantId = @TenantId,
            PageId = @PageId,
            FormId = @FormId,
            AdId = @AdId,
            AdName = @AdName,
            AdsetId = @AdsetId,
            AdsetName = @AdsetName,
            CampaignId = @CampaignId,
            CampaignName = @CampaignName,
            Platform = ISNULL(@Platform, Platform),
            IsOrganic = ISNULL(@IsOrganic, IsOrganic),
            FbCreatedTime = ISNULL(@FbCreatedTime, FbCreatedTime),
            FullName = @FullName,
            Email = @EmailClean,
            PhoneNumber = @PhoneRaw,
            City = @City,
            RawFieldData = @RawFieldData,
            Status = 'Pending',
            LastError = NULL,
            ProcessedAt = NULL
        WHERE LeadgenId = @LeadgenId;

        SELECT @FbLeadId = FbLeadId
        FROM [dbo].[FbLeads]
        WHERE LeadgenId = @LeadgenId;
    END
    ELSE
    BEGIN
        INSERT INTO [dbo].[FbLeads] (
            TenantId, LeadgenId, PageId, FormId, AdId, AdName, AdsetId, AdsetName,
            CampaignId, CampaignName, Platform, IsOrganic, FbCreatedTime,
            FullName, Email, PhoneNumber, City, RawFieldData, IsTestLead,
            Status, LastError, ReceivedAt, ProcessedAt, CreatedDate, CreatedUTCDate)
        VALUES (
            @TenantId, @LeadgenId, @PageId, @FormId, @AdId, @AdName, @AdsetId, @AdsetName,
            @CampaignId, @CampaignName, @Platform, @IsOrganic, @FbCreatedTime,
            @FullName, @EmailClean, @PhoneRaw, @City, @RawFieldData, 0,
            'Pending', NULL, SYSDATETIME(), NULL, @dt, @dtUTC);

        SET @FbLeadId = CAST(SCOPE_IDENTITY() AS BIGINT);
    END

    ------------------------------------------------------------------
    -- 2. Validate + normalize
    ------------------------------------------------------------------
    IF (@PhoneRaw = N'' AND @EmailClean = N'')
    BEGIN
        SET @ErrorMessage = N'Please verify the lead; it has neither a phone number nor an email address.';
        SET @HasError = 1;
    END

    IF @TenantId IS NULL
        OR @LeadgenId IS NULL
        OR @PageId IS NULL
    BEGIN
        SET @ErrorMessage = N'Missing tenant, page or lead identifier.';
        SET @HasError = 1;
    END

    -- Keep the leading "+", drop every other non-digit ("011 98765 43210" -> "0119876543210").
    IF @PhoneRaw <> N''
    BEGIN
        SET @Phone = @PhoneRaw;

        IF LEFT(@Phone, 1) = '+'
        BEGIN
            SET @Phone = STUFF(@Phone, 1, 1, '');

            WHILE PATINDEX('%[^0-9]%', @Phone) > 0
                SET @Phone = STUFF(@Phone, PATINDEX('%[^0-9]%', @Phone), 1, '');

            SET @Phone = '+' + @Phone;
        END
        ELSE
        BEGIN
            WHILE PATINDEX('%[^0-9]%', @Phone) > 0
                SET @Phone = STUFF(@Phone, PATINDEX('%[^0-9]%', @Phone), 1, '');
        END
    END

    -- Name split (mirrors SP_ProcessWrkLead)
    DECLARE @SpaceIndex INT = CHARINDEX(' ', LTRIM(RTRIM(ISNULL(@FullName, ''))));

    IF (@SpaceIndex > 0)
    BEGIN
        SET @FirstName = SUBSTRING(@FullName, 1, @SpaceIndex - 1);
        SET @LastName = SUBSTRING(@FullName, @SpaceIndex + 1, LEN(@FullName));
    END
    ELSE
    BEGIN
        SET @FirstName = @FullName;
        SET @LastName = '';
    END

    IF (@FirstName IS NULL OR @FirstName = '')
    BEGIN
        SET @ErrorMessage = N'Please verify the lead; it has no name.';
        SET @HasError = 1;
    END

    ------------------------------------------------------------------
    -- 3. Tenant-scoped lookups / find-or-match
    ------------------------------------------------------------------
    DECLARE @LookupTenantId INT = @TenantId;

    IF @LookupTenantId IS NOT NULL
    BEGIN
        SELECT @LeadSourceId = LV.LookupValueId
        FROM [dbo].[LookupValues] LV WITH (NOLOCK)
            INNER JOIN [dbo].[Lookups] LS WITH (NOLOCK)
                ON LS.LookupId = LV.LookupId
        WHERE LTRIM(RTRIM(LS.LookupName)) = 'LeadSources'
            AND LTRIM(RTRIM(LV.LookupValueName)) = 'Facebook Lead Ads'
            AND LS.TenantId = @LookupTenantId
            AND LV.IsDeleted = 0
            AND LS.IsDeleted = 0;

        IF @LeadSourceId IS NULL
        BEGIN
            SET @ErrorMessage = N'Please add the "Facebook Lead Ads" option under Master Setup > Lookups > Lead Sources.';
            SET @HasError = 1;
        END

        -- The automated capture has no authenticated user or salesman, so the shared create SP would
        -- leave the lead with no location (it defaults from the assigned user's LocationUserMapping).
        -- Assign the tenant's Main location: SaveTenant seeds exactly one Locations row named 'Main'.
        SELECT TOP (1) @MainLocationId = LOC.LocationID
        FROM [dbo].[Locations] LOC WITH (NOLOCK)
        WHERE LOC.TenantId = @LookupTenantId
            AND LTRIM(RTRIM(LOC.LocationName)) = N'Main'
            AND LOC.IsDeleted = 0
        ORDER BY LOC.LocationID;

        -- Exact match on the normalized AND the raw form (Customers may store either).
        IF @Phone <> N''
        BEGIN
            SELECT TOP 1 @CustomerId = CustomerId
            FROM [dbo].[Customers]
            WHERE IsDeleted = 0
                AND TenantId = @LookupTenantId
                AND (PhoneNumber = @Phone OR PhoneNumber = @PhoneRaw)
            ORDER BY CustomerId;
        END
    END

    ------------------------------------------------------------------
    -- 4. Persist the CRM Lead through the shared V4 SP
    ------------------------------------------------------------------
    IF @HasError = 0
    BEGIN
        DECLARE @Notes NVARCHAR(MAX);

        SET @Notes = 'Meta Lead Ads - ' + ISNULL(@Platform, 'Facebook') + '| Lead ID: '
            + ISNULL(CONVERT(VARCHAR(30), @LeadgenId), 'N/A')
            + CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(@CampaignName, ''))), '') IS NOT NULL THEN ' | Campaign: ' + @CampaignName
                ELSE ''
              END
            + CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(@AdName, ''))), '') IS NOT NULL THEN ' | Ad: ' + @AdName
                ELSE ''
              END
            + CASE
                WHEN NULLIF(LTRIM(RTRIM(ISNULL(@City, ''))), '') IS NOT NULL THEN ' | City: ' + @City
                ELSE ''
              END;

        DECLARE @Payload NVARCHAR(MAX);

        -- FOR JSON handles all escaping (names/answers can contain quotes).
        -- customerAddress is emitted as an EMPTY object -> CreateLeadWithCustomerDetails sets
        -- @SkipAddress = 1, so no blank CustomerAddresses row is created for a lead we only know a city for.
        SET @Payload = (
        SELECT
            CASE WHEN @CustomerId > 0 THEN @CustomerId ELSE NULL END AS 'customerDetails.CustomerId',
            @FirstName AS 'customerDetails.firstName',
            @LastName AS 'customerDetails.lastName',
            CASE WHEN @Phone <> N'' THEN @Phone ELSE NULL END AS 'customerDetails.phoneNumber',
            CASE WHEN @EmailClean <> N'' THEN @EmailClean ELSE NULL END AS 'customerDetails.emailId',
            JSON_QUERY('{}') AS 'customerAddress',
            @LeadStatus AS 'leadDetails.status',
            @Notes AS 'leadDetails.inquiry',
            NULL AS 'leadDetails.salesmanId',
            @LeadSourceId AS 'leadDetails.leadSourceId',
            @RawFieldData AS 'leadDetails.other',
            NULL AS 'leadDetails.inquiryAbout',
            NULL AS 'leadDetails.inquiryFor',
            @MainLocationId AS 'leadDetails.locationId',
            NULL AS 'leadDetails.refferedBy',
            NULL AS 'leadDetails.purchaseUrgencyId',
            NULL AS 'leadDetails.customerBehaviorId'
        -- WITHOUT_ARRAY_WRAPPER: FOR JSON PATH on this single-row SELECT otherwise emits
        -- "[{...}]", and CreateLeadWithCustomerDetails reads "$.leadDetails.status" (object root),
        -- so every path would resolve NULL and it would throw "Lead status is required." The app's
        -- own lead-creation callers send an object, so this payload must be an object too.
        FOR JSON PATH, WITHOUT_ARRAY_WRAPPER);

        BEGIN TRY
            BEGIN TRANSACTION CreateFacebookLead;

            -- POSITIONAL CONTRACT: #FbLeadResponse must declare, and the INSERT must list,
            -- EXACTLY the 25 columns CreateLeadWithCustomerDetails returns, in its order
            -- (final SELECT of that SP). Only LeadId is read, but INSERT...EXEC fails on a count
            -- mismatch, so any change to that SP requires changing this block.
            CREATE TABLE #FbLeadResponse (
                LeadId BIGINT,
                FirstName NVARCHAR(500),
                LastName NVARCHAR(500),
                Notes NVARCHAR(MAX),
                PhoneNumber NVARCHAR(50),
                SalesmanId BIGINT,
                Other NVARCHAR(MAX),
                Email NVARCHAR(256),
                Priority NVARCHAR(50),
                InquiryAbout INT,
                CustomerId BIGINT,
                CloseLookupValueId INT,
                RefferedBy NVARCHAR(100),
                InquiryFor INT,
                LeadSourceId INT,
                PurchaseUrgencyId INT,
                CustomerBehaviorId INT,
                CustomerAddressId BIGINT,
                BuyingRangeValueId INT,
                AlternateMobileNumber VARCHAR(500),
                InquiryAreaRequirement NVARCHAR(500),
                AlternateSalesmanId INT,
                ClientMeetingStageId INT,
                ArchitectMeetingStageId INT,
                LeadType NVARCHAR(50));

            INSERT INTO #FbLeadResponse (
                LeadId, FirstName, LastName, Notes, PhoneNumber, SalesmanId, Other, Email,
                Priority, InquiryAbout, CustomerId, CloseLookupValueId, RefferedBy, InquiryFor,
                LeadSourceId, PurchaseUrgencyId, CustomerBehaviorId, CustomerAddressId,
                BuyingRangeValueId, AlternateMobileNumber, InquiryAreaRequirement,
                AlternateSalesmanId, ClientMeetingStageId, ArchitectMeetingStageId, LeadType)
            EXEC dbo.CreateLeadWithCustomerDetails
                @LeadRequestDetails = @Payload,
                @TenantId = @TenantId,
                @UserId = @UserId;

            SELECT @CrmLeadId = LeadId
            FROM #FbLeadResponse;

            UPDATE [dbo].[FbLeads]
            SET Status = 'Imported',
                CrmLeadId = @CrmLeadId,
                PhoneNumber = CASE WHEN @Phone <> N'' THEN @Phone ELSE PhoneNumber END,
                LastError = NULL,
                ProcessedAt = SYSDATETIME()
            WHERE FbLeadId = @FbLeadId;

            COMMIT TRANSACTION CreateFacebookLead;
        END TRY
        BEGIN CATCH
            SELECT @ErrNumber = ERROR_NUMBER(),
                @ErrMessage = ERROR_MESSAGE(),
                @ErrSeverity = ERROR_SEVERITY(),
                @ErrLine = ERROR_LINE(),
                @ErrProc = ERROR_PROCEDURE();

            IF @@TRANCOUNT > 0
                ROLLBACK TRANSACTION CreateFacebookLead;

            -- 50001 = the deliberate business-validation THROW used by CreateLeadWithCustomerDetails
            -- and this SP. Anything else is unexpected (deadlock, timeout, conversion, schema drift):
            -- park nothing, log it, and RE-THROW so the Service Bus message is abandoned and redelivered.
            IF @ErrNumber <> 50001
            BEGIN
                BEGIN TRY
                    DECLARE @ObjectName VARCHAR(500) = ISNULL(@ErrProc, OBJECT_NAME(@@PROCID)),
                        @ErrorMsg NVARCHAR(4000) = ISNULL(@ErrMessage, N'Unknown error in SP_CreateFacebookLead');

                    EXEC dbo.SaveDBErrorLog
                        @ObjectName = @ObjectName,
                        @ErrorMsg = @ErrorMsg;
                END TRY
                BEGIN CATCH
                    -- Error logging must never mask the original failure.
                END CATCH;

                THROW;
            END

            SET @ErrorMessage = LEFT(ISNULL(@ErrMessage, N'The lead could not be created.'), 2000);

            UPDATE [dbo].[FbLeads]
            SET Status = 'Failed',
                CrmLeadId = NULL,
                LastError = @ErrorMessage,
                ProcessedAt = SYSDATETIME()
            WHERE FbLeadId = @FbLeadId;
        END CATCH;
    END

    ------------------------------------------------------------------
    -- 5. Single, uniform result set on the validation-failure path too
    --    (the create path above returns via this same statement).
    ------------------------------------------------------------------
    IF @HasError = 1
    BEGIN
        UPDATE [dbo].[FbLeads]
        SET Status = 'Failed',
            LastError = @ErrorMessage,
            ProcessedAt = SYSDATETIME()
        WHERE FbLeadId = @FbLeadId
            AND Status <> 'Imported';
    END

    SELECT @CrmLeadId AS CrmLeadId, @TenantId AS TenantId, NULLIF(@ErrorMessage, N'') AS ErrorMessage;
END

GO

