/*
====================================================================
Procedure Name: [dbo].[GetCustomerDetailsById]
Description   : Returns detailed customer info for API use.
Author        : MagnusMinds
Creted Date   : 04/07/2025
Last Modified : [Date]
Modified By   : [Name]
====================================================================
Parameters:
    @CustomerId - ID of the customer to fetch.
    @TenantId   - ID of the tenant to scope the data.
====================================================================
	EXEC [dbo].[GetCustomerDetailsById]
		@CustomerId = 720
		,@TenantId = 2
*/
CREATE PROCEDURE [dbo].[GetCustomerDetailsById]
(
	@CustomerId BIGINT
	,@TenantId INT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @TotalVisits BIGINT
			,@TotalOrders BIGINT
			,@RefCustomerId BIGINT
			,@InteriorCommissionPercentage NUMERIC(18, 2)

		SELECT @RefCustomerId = cref.CustomerId
			,@InteriorCommissionPercentage =
				CASE
					WHEN ISNULL(cref.InteriorCommissionPer, 0) > 0
						THEN cref.InteriorCommissionPer
					ELSE ISNULL(t.ArchitectDiscount, 0)
				END
		FROM Customers c WITH (NOLOCK)
		INNER JOIN Tenants t WITH (NOLOCK) ON t.TenantId = c.TenantId
		LEFT JOIN Customers cref WITH (NOLOCK) ON cref.CustomerId = c.RefferedBy
			AND cref.CustomerTypeId = 2 --Interior
		WHERE c.CustomerId = @CustomerId
		AND c.TenantId = @TenantId
		AND c.IsDeleted = 0
		AND c.CustomerTypeId IN (1, 2) --Customer and Interior

		SELECT @TotalVisits = COUNT(1)
		FROM CustomerVisits cv WITH (NOLOCK)
		WHERE cv.CustomerId = @CustomerId

		SELECT @TotalOrders = COUNT(1)
		FROM Orders o WITH (NOLOCK)
		WHERE o.CustomerId = @CustomerId
		AND o.TenantId = @TenantId
		AND o.Status <> 9 --Deleted

		SELECT c.CustomerId
			,c.FirstName + ' ' + ISNULL(c.LastName, '') AS FullName
			,c.PhoneNumber
			,@TotalVisits AS TotalVisits
			,@TotalOrders AS TotalOrders
			,au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS CreatedBy
			,FORMAT(c.CreatedDate, 'dd/MM/yyyy hh:mm tt') AS CreatedOn
			,IIF(c.CustomerTypeId = 1, 'Customer', 'Interior') AS [Type]
			,IIF(@RefCustomerId > 0, @InteriorCommissionPercentage, 0) AS InteriorCommissionPercentage
			,CASE
				WHEN @RefCustomerId > 0 AND (@InteriorCommissionPercentage >= 1 AND @InteriorCommissionPercentage <= 5)
					THEN '#0d0df2'
				WHEN @RefCustomerId > 0 AND (@InteriorCommissionPercentage > 5 AND @InteriorCommissionPercentage <= 15)
					THEN '#ad7000'
				WHEN @RefCustomerId > 0 AND (@InteriorCommissionPercentage > 15)
					THEN '#cd0303'
				ELSE ''
				END AS InteriorCommissionColor
			,CASE
				WHEN @RefCustomerId > 0 AND (@InteriorCommissionPercentage >= 1 AND @InteriorCommissionPercentage <= 5)
					THEN '#0d0df2'
				WHEN @RefCustomerId > 0 AND (@InteriorCommissionPercentage > 5 AND @InteriorCommissionPercentage <= 15)
					THEN '#ad7000'
				WHEN @RefCustomerId > 0 AND (@InteriorCommissionPercentage > 15)
					THEN '#cd0303'
				ELSE ''
				END AS InteriorCommission
			,C.EmailId
			,C.GSTNo
			,C.CompanyName
			,CR.FirstName + ' ' + ISNULL(CR.LastName, '') AS RefferedByName
			,C.RefferedBy AS RefferedBy
			,C.CustomerTypeId
		FROM Customers c WITH (NOLOCK)
		INNER JOIN AspNetUsers au WITH (NOLOCK) ON au.UserId = c.CreatedBy
		LEFT JOIN Customers CR WITH (NOLOCK) ON CR.CustomerId = c.RefferedBy
		WHERE c.CustomerId = @CustomerId
		AND c.TenantId = @TenantId
		AND c.IsDeleted = 0
		AND c.CustomerTypeId IN (1, 2, 4) --Customer and Interior and Dealer( from the whatsapp bot and vedor dealer we created an order so support dealer as 4)
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
			,@ErrorSeverity INT
			,@ErrorState INT;

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE();

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				);
	END CATCH
END

GO

