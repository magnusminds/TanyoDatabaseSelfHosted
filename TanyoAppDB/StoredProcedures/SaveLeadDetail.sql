CREATE PROC [dbo].[SaveLeadDetail] (
	@CustomerName VARCHAR(200)
	,@PhoneNumber VARCHAR(16)
	,@InquiryFor VARCHAR(200)
	,@Status INT
	,@LeadSourceId INT
	,@Notes VARCHAR(500)
	,@SalesmanId INT
	,@TenantId INT
	,@UserId INT
	,@CreatedDate DATETIMEOFFSET
	,@CreatedUTCDate DATETIME
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @CustomerId BIGINT = 0
			,@LocationId INT
			,@dt DATE = GETDATE()

		SELECT @LocationId = LocationID
		FROM LocationUserMapping
		WHERE UserID = @UserId
			AND IsDefault = 1

		IF EXISTS (
				SELECT TOP 1 1
				FROM Customers c WITH (NOLOCK)
				WHERE c.PhoneNumber = @PhoneNumber
					AND c.TenantId = @TenantId
					AND c.IsDeleted = 0
				)
		BEGIN
			SELECT @CustomerId = c.CustomerId
			FROM Customers c WITH (NOLOCK)
			WHERE c.PhoneNumber = @PhoneNumber
				AND c.TenantId = @TenantId
				AND c.IsDeleted = 0
		END
		ELSE
		BEGIN
			INSERT INTO Customers (
				CustomerTypeId
				,FirstName
				,PhoneNumber
				,TenantId
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			SELECT 1
				,@CustomerName
				,@PhoneNumber
				,@TenantId
				,@UserId
				,@CreatedDate
				,@CreatedUTCDate

			SELECT @CustomerId = SCOPE_IDENTITY()
		END

		INSERT INTO Leads (
			FirstName
			,PhoneNumber
			,Notes
			,[Source]
			,Email
			,Priority
			,Status
			,SalesmanId
			,SalesmanAssignDate
			,LastContactedDate
			,TenantId
			,CreatedBy
			,LocationID
			,InquiryFor
			,CustomerId
			,LeadSourceId
			,CreatedDate
			,CreatedUTCDate
			)
		SELECT @CustomerName
			,@PhoneNumber
			,@Notes
			,0
			,''
			,0
			,0
			,@SalesmanId
			,@dt
			,@dt
			,@TenantId
			,@UserId
			,@LocationId
			,@InquiryFor
			,@CustomerId
			,@LeadSourceId
			,@CreatedDate
			,@CreatedUTCDate
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

