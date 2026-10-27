/*
EXEC SaveCustomerDetails
     @TenantID = 2,
	 @ParentCustomerId = 1035826,
     @CustomerFirstName = 'Tanyo',
     @CustomerLastName = 'Dev',
     @CustomerPhoneNumber = '9876543210',
     @UserID = 1035826;

*/
CREATE PROCEDURE [dbo].[SaveCustomerDetails] (
	@TenantID INT
	,@ParentCustomerId BIGINT
	,@CustomerFirstName VARCHAR(50)
	,@CustomerLastName VARCHAR(50)
	,@CustomerPhoneNumber VARCHAR(16) = NULL
	,@UserID INT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @NewCustomerId BIGINT
		,@Date DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@DateUtc DATETIME = GETUTCDATE();

	DROP TABLE IF EXISTS #CustomerDetails

		--IF EXISTS (	SELECT 1
		--			FROM Customers WITH (NOLOCK)
		--			WHERE PhoneNumber = @CustomerPhoneNumber
		--				AND TenantId = @TenantID
		--				AND IsDeleted = 0)
		--BEGIN
		--		SET @CustomerPhoneNumber = NULL
		--END
	BEGIN TRY
		BEGIN TRAN SaveCustomerDetails;

		SELECT *
		INTO #CustomerDetails
		FROM Customers WITH (NOLOCK)
		WHERE CustomerId = @ParentCustomerId

		SELECT @NewCustomerId = CustomerId
		FROM Customers WITH (NOLOCK)
		WHERE PhoneNumber = @CustomerPhoneNumber
			AND TenantId = @TenantID
			AND IsDeleted = 0
			AND CustomerTypeId = 1;

		IF @NewCustomerId IS NULL
		BEGIN
			INSERT INTO Customers (
				CustomerTypeId
				,FirstName
				,LastName
				,PhoneNumber
				,GSTNo
				,RefferedBy
				,Discount
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,IsSubscribe
				,IsVerified
				,Birthday
				,Anniversary
				,Profession
				,CompanyName
				,LabelId
				,LocationID
				,InteriorCommissionPer
				,CustomerTenantID
				,PANNo
				,ProfessionId
				)
			SELECT 1
				,@CustomerFirstName
				,@CustomerLastName
				,@CustomerPhoneNumber
				,GSTNo
				,RefferedBy
				,Discount
				,@TenantID
				,IsDeleted
				,@UserID
				,@Date
				,@DateUtc
				,IsSubscribe
				,IsVerified
				,Birthday
				,Anniversary
				,Profession
				,CompanyName
				,LabelId
				,LocationID
				,InteriorCommissionPer
				,CustomerTenantID
				,PANNo
				,ProfessionId
			FROM #CustomerDetails;

			SET @NewCustomerID = SCOPE_IDENTITY();
		END

		COMMIT TRAN SaveCustomerDetails;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN SaveCustomerDetails;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH

	SELECT @NewCustomerID AS CustomerID;
END

GO

