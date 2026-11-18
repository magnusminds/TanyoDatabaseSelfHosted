CREATE   PROCEDURE [dbo].[zCreateLead_Upload]
(	
	@CustomerId BIGINT
	,@Status INT
	,@Inquiry NVARCHAR(MAX)
	,@SalesmanId BIGINT = NULL
	,@LeadSourceId BIGINT = NULL
	,@Other VARCHAR(MAX) = NULL
	,@InquiryAbout BIGINT = NULL
	,@InquiryFor NVARCHAR(MAX) = NULL
	,@LocationID BIGINT = NULL
	,@RefferedBy BIGINT = NULL
	,@PurchaseUrgencyId BIGINT = NULL
	,@CustomerBehaviorId BIGINT = NULL
	,@CloseLookupValueId INT = NULL
	,@TenantId BIGINT
	,@UserId BIGINT
)	
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ReturnMessage VARCHAR (1024) = ''

    IF @CustomerId IS NULL OR @CustomerId = 0
	BEGIN		
		SET @ReturnMessage = 'Customer not found';
		--RAISERROR(@ReturnMessage, 10, 1); 
		--RETURN;
        THROW 50001,@ReturnMessage , 1;
	END

	DECLARE @FirstName NVARCHAR(100)
		,@LastName NVARCHAR(100)
		,@PhoneNumber NVARCHAR(50)
		,@Email NVARCHAR(200)
		,@DefaultLocationId BIGINT
		,@NewLeadId BIGINT
		,@dt DATETIMEOFFSET =  SYSDATETIMEOFFSET()
		,@dtUTC DATETIME = GETUTCDATE()
		,@Date DATE = GETDATE()

	SELECT @FirstName = FirstName
		,@LastName = LastName
		,@PhoneNumber = PhoneNumber
		,@Email = EmailId
	FROM Customers WITH (NOLOCK)
	WHERE CustomerId = @CustomerId
		AND TenantId = @TenantId
		and IsDeleted = 0;

    IF @FirstName IS NULL
	BEGIN
		SET @ReturnMessage = 'Customer not found';
		--RAISERROR(@ReturnMessage, 10, 1); 
		--RETURN;
        THROW 50001,@ReturnMessage , 1;
	END

	IF @SalesmanId IS NOT NULL
	AND NOT EXISTS
	(
	    SELECT 1
	    FROM AspNetUsers AU WITH (NOLOCK)
		INNER JOIN UserTenantMapping UTM on au.UserId = utm.UserId 
	    WHERE au.UserId = @SalesmanId
		and utm.TenantId = @TenantId
		and utm.IsDeleted = 0
		and au.IsDeleted = 0
	)
	BEGIN
	    SET @SalesmanId = NULL;
	END

	IF ISNULL(@LocationID,0) = 0
	BEGIN
	
		IF ISNULL(@SalesmanId,0) = 0
		begin 

			select top 1 @DefaultLocationId = LocationID
			from LocationUserMapping
			where UserID =@UserId
			and IsDefault = 1
			order by LocationUserMappingID
		end
		else 
		begin		
			select top 1 @DefaultLocationId = LocationID
			from LocationUserMapping
			where UserID =@SalesmanId
			and IsDefault = 1
			order by LocationUserMappingID
		end
		
		SET @LocationID = @DefaultLocationId;
	END

	DECLARE @LeadNumber NVARCHAR(50);
	DECLARE @Counter INT;

	BEGIN TRY

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
			,ISNULL(@SalesmanId,0)
			,@UserId
			,@UserId
			,@dt
			,@dtUTC
			);

		
	END TRY

	BEGIN CATCH

		THROW;
	END CATCH
END;

GO

