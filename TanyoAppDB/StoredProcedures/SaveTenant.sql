CREATE PROCEDURE [dbo].[SaveTenant] (
	@TenantName VARCHAR(150)
	,@FirstName VARCHAR(50)
	,@LastName VARCHAR(50)
	,@EmailId VARCHAR(50)
	,@PhoneNumber VARCHAR(50)
	,@PasswordHash VARCHAR(max)
	,@InstallationCharges DECIMAL(18, 2) = 0
	,@RecurringCharges DECIMAL(18, 2) = 0
	,@OrganizationType INT = NULL
	,@MobileDeviceId VARCHAR(100) = NULL
	,@RegisteredFCMToken VARCHAR(1000) = NULL
	,@City VARCHAR(100) = ''
	,@Address1 VARCHAR(150) = ''
	,@Address2 VARCHAR(150) = NULL
	,@Landmark VARCHAR(150) = ''
	,@State VARCHAR(100) = ''
	,@Pincode VARCHAR(6) = ''
	,@GSTNo VARCHAR(20) = ''
	,@GSTType BIT = 1
	,@IsAutoManufacture BIT = 0
	,@WebsiteURL VARCHAR(250) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		BEGIN TRAN SaveTenant

		DECLARE @TenantId INT
		DECLARE @UserId INT
		DECLARE @AspNetUsersId NVARCHAR(450)
		DECLARE @RoleId NVARCHAR(450)
		DECLARE @SystemRoleId NVARCHAR(450)
		DECLARE @Date DATETIME = GETDATE()
		DECLARE @DateUTC DATETIME = GETUTCDATE()
		DECLARE @ReferalCode CHAR(6)
		DECLARE @DateOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
		DECLARE @AspNetSystemUsersId NVARCHAR(450)
		DECLARE @SystemUserId INT

		SELECT @AspNetUsersId = NEWID()

		SELECT @AspNetSystemUsersId = NEWID()

		SELECT @RoleId = NEWID()

		SELECT @SystemRoleId = NEWID()

		--IF NOT EXISTS (  
		--  SELECT 1  
		--  FROM Tenants  
		--  WHERE TenantName = @TenantName  
		--  )  
		BEGIN
			-- Tenants  
			EXEC dbo.GetReferalCode @ReferalCode = @ReferalCode OUT

			--SELECT @ReferalCode   
			INSERT INTO Tenants (
				TenantName
				,FirstName
				,LastName
				,EmailId
				,PhoneNumber
				,StreetAddress1
				,StreetAddress2
				,Landmark
				,City
				,[State]
				,Pincode
				,InquiryExpirationDays
				,EnableEmailNotification
				,EnableSMSNotification
				,EnableWhatsappNotification
				,GSTNo
				,GSTType
				,CreatedBy
				,MasterOTP
				,IsAutoManufacture
				,AmountRoundMultiple
				,InstallationCharges
				,RecurringCharges
				,TenantInfoId
				,ReferalCode
				)
			SELECT @TenantName
				,@FirstName
				,@LastName
				,@EmailId
				,@PhoneNumber
				,@Address1
				,@Address2
				,@Landmark
				,@City
				,@State
				,@Pincode
				,10
				,0
				,0
				,0
				,@GSTNo
				,@GSTType
				,1
				,RIGHT(CAST(CRYPT_GEN_RANDOM(8) AS INT), 4)
				,@IsAutoManufacture
				,0
				,@InstallationCharges
				,@RecurringCharges
				,@OrganizationType
				,@ReferalCode

			SELECT @TenantId = SCOPE_IDENTITY()

			PRINT 'Tenant Created Successfully'

			INSERT INTO TenantConfigurations (
				TenantId
				,IsGSTVisibleForInvoice
				,IsGSTVisibleForQuotation
				,WebsiteURL
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			SELECT @TenantId
				,1
				,1
				,@WebsiteURL
				,1
				,@DateOffset
				,@DateUTC

			PRINT 'Tenant Configuration Created Successfully'

			INSERT INTO TenantContracts (
				TenantID
				,NosOfUsers
				,NosOfAdmin
				,PricePerSKU
				,OnBoardingDate
				,LiveDate
				,NextRenewAt
				,Status
				,LastUpdatedBy
				,LastUpdatedDate
				)
			SELECT @TenantId
				,0
				,0
				,0
				,@Date
				,DATEADD(MONTH, 1, @Date)
				,DATEADD(MONTH, 1, @Date)
				,1
				,1
				,SYSDATETIMEOFFSET()

			-- AspNetUsers  
			INSERT INTO AspNetUsers (
				Id
				,FirstName
				,LastName
				,UserName
				,NormalizedUserName
				,Email
				,NormalizedEmail
				,EmailConfirmed
				,PasswordHash
				,IsActive
				,IsDeleted
				,PhoneNumber
				,PhoneNumberConfirmed
				,TwoFactorEnabled
				,LockoutEnabled
				,AccessFailedCount
				,SecurityStamp
				,ConcurrencyStamp
				,MobileDeviceId
				,RegisteredFCMToken
				)
			SELECT @AspNetUsersId
				,@FirstName
				,@LastName
				,@EmailId
				,UPPER(@EmailId)
				,@EmailId
				,UPPER(@EmailId)
				,1
				,@PasswordHash --Password@1  
				,1
				,0
				,@PhoneNumber
				,0
				,0
				,0
				,0
				,NEWID()
				,NEWID()
				,@MobileDeviceId
				,@RegisteredFCMToken

			SELECT @UserId = SCOPE_IDENTITY()

			INSERT INTO AspNetUsers (
				Id
				,FirstName
				,LastName
				,UserName
				,NormalizedUserName
				,Email
				,NormalizedEmail
				,EmailConfirmed
				,PasswordHash
				,IsActive
				,IsDeleted
				,PhoneNumber
				,PhoneNumberConfirmed
				,TwoFactorEnabled
				,LockoutEnabled
				,AccessFailedCount
				,SecurityStamp
				,ConcurrencyStamp
				,MobileDeviceId
				,RegisteredFCMToken
				)
			SELECT @AspNetSystemUsersId
				,'System'
				,'User'
				,'system.user0' + CAST(@TenantId AS VARCHAR(16)) + '@yopmail.com'
				,UPPER('system.user0' + CAST(@TenantId AS VARCHAR(16)) + '@yopmail.com')
				,'system.user0' + CAST(@TenantId AS VARCHAR(16)) + '@yopmail.com'
				,UPPER('system.user0' + CAST(@TenantId AS VARCHAR(16)) + '@yopmail.com')
				,1
				,@PasswordHash --Password@1  
				,1
				,0
				,NULL
				,0
				,0
				,0
				,0
				,NEWID()
				,NEWID()
				,NULL
				,NULL

			SELECT @SystemUserId = SCOPE_IDENTITY()

			PRINT 'User Created Successfully'

			-- AspNetRoles  
			INSERT INTO AspNetRoles (
				Id
				,[Name]
				,NormalizedName
				,ConcurrencyStamp
				,TenantId
				)
			SELECT @RoleId
				,'Administrator_' + CAST(@TenantId AS VARCHAR(MAX))
				,'ADMINISTRATOR_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId
			
			UNION ALL
			
			SELECT NEWID() RoleId
				,'SalesRepresentative_' + CAST(@TenantId AS VARCHAR(MAX))
				,'SALESREPRESENTATIVE_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId
			
			UNION ALL
			
			SELECT NEWID() RoleId
				,'Approver_' + CAST(@TenantId AS VARCHAR(MAX))
				,'APPROVER_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId
			
			UNION ALL
			
			SELECT NEWID() RoleId
				,'Contractor_' + CAST(@TenantId AS VARCHAR(MAX))
				,'CONTRACTOR_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId
			
			UNION ALL
			
			SELECT NEWID() RoleId
				,'Gatekeeper_' + CAST(@TenantId AS VARCHAR(MAX))
				,'GATEKEEPER_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId
			
			UNION ALL
			
			SELECT NEWID() RoleId
				,'Supervisor_' + CAST(@TenantId AS VARCHAR(MAX))
				,'SUPERVISOR_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId
			
			UNION ALL
			
			SELECT @SystemRoleId
				,'SystemUser_' + CAST(@TenantId AS VARCHAR(MAX))
				,'SYSTEMUSER_' + CAST(@TenantId AS VARCHAR(MAX))
				,NEWID()
				,@TenantId

			PRINT 'Roles Created Successfully'

			-- AspNetUserRoles  
			INSERT INTO AspNetUserRoles (
				UserId
				,RoleId
				)
			SELECT @AspNetUsersId
				,@RoleId

			INSERT INTO AspNetUserRoles (
				UserId
				,RoleId
				)
			SELECT @AspNetSystemUsersId
				,@SystemRoleId

			PRINT 'User Role Created Successfully'

			-- AspNetRoleClaims  
			INSERT INTO AspNetRoleClaims (
				RoleId
				,ClaimType
				,ClaimValue
				)
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Workflow.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Workflow.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Workflow.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.User.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.User.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.User.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Unit.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Unit.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Unit.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.RolePermission.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.RolePermission.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.RolePermission.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.OrderWithInteriorsReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.OrderPaymentReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.OrderDeliveryScheduleReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.OrderBySalesmanReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.NotificationSummary'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.Notification'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.LeadAssignMentReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.LaborsbyContractorReporView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.ExceptionReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.DuesAmountReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.CountOfProductsReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.OrdersValueReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Report.ContractorProductReportView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.RawMaterial.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.RawMaterial.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.RawMaterial.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Profile.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Profile.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.ViewWholesalerPrice'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.ViewRetailerPrice'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.ViewCostPrice'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.QuantityView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.QuantityCreate'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.Quantity Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.Publish'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.InventoryView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.InventoryCreate'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Product.CostAnalyser'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.PortalAccess.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Polish.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Polish.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Polish.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Order.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.View'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Order.SendNotifications'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.SendNotifications'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Order.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.Delete'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Order.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.Create'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.NotificationSummary.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.NotificationManager.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.NotificationManagement.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingWorkflow.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingWorkflow.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingWorkflow.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingUser.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingUser.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingUser.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingOrders.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingOrders.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingOrders.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingCategories.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingCategories.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ManufacturingCategories.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Labour.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Labour.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Labour.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.LaborsbyContractor.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Interior.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Interior.SendGreetings'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Interior.Import'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Interior.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Interior.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Import.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Import.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Fabric.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Fabric.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Fabric.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.EmailConfiguration.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.EmailConfiguration.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ReceivablesView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ReadyToDeliver'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ProductsView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ProductByCategoryView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.PendingOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.PendingLeadInquiry'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.OrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.OrderMatrixInquiryView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.OrderMatrixInquirytoAprrovedView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.OrderMatrixAprrovedtoDeliveredView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ManufacturingWorkflows'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ManufacturingOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.InteriorsView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.InquiriesView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.InquiriesBySalesmanView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.InProgressLeadInquiry'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.GraphProductByCategoryView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.GraphInquiriesBySalesmanView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.GraphCustomerAddedView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.Delivered'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.CustomersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.CompletedLeadInquiry'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Dashboard.ApprovedOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Customer.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Customer.SendGreetings'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Customer.Import'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Customer.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Customer.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.ContractorProductReport.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Complain.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Complain.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Complain.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Company.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Company.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Company.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Comapny.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Category.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Category.Delete'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.Portal.Category.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingWorkflows.SubmitManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingWorkflows.RejectSubmitManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingWorkflows.RejectManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingWorkflows.DeclineManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingWorkflows.ApproveManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingWorkflows.AcceptManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingOrders.ManufacturingOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingOrders.ManufacturingOrdersdetailView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingDashboard.SupervisionOrderCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingDashboard.RejectOrdersCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingDashboard.PendingOrdersCountView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingDashboard.InProgressOrdersCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingDashboard.GetMultipleWorkflow'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.ManufacturingDashboard.CompletedOrdersCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.MfgApp.LabourReport.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.View'

			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.ShareQuotation'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.ShareQuotation'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.MaterialReceive'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.MaterialReceive'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.ExchangeOrderGstType'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.ExchangeOrderGstType'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.Delete'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.Delete'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.Decline'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.Decline'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.Create'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.Create'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Order.Approve'
			
			UNION ALL

			SELECT @RoleId
				,'permission'
				,'Permissions.General.Order.Approve'

			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Notification.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.MegaSearch.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingOrders.SubmitManufacturingOrder'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingOrders.ManufacturingOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingOrders.ManufacturingOrdersdetailView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingOrders.ApproveManufacturingOrders'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingOrders.AcceptManufacturingOrder'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingDashboard.SupervisionOrderCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingDashboard.PendingOrdersCountView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingDashboard.InProgressOrdersCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.ManufacturingDashboard.CompletedOrdersCount'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Interior.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Interior.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Inquiry.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Inquiry.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Fabric.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.ReceivedMaterialsView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.ReceivableOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.PendingOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.InquiryOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.FollowupOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.CustomerInquiriesView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Dashboard.ApprovedOrdersView'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Customer.View'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Customer.Create'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.General.BusinessSegments.Retail'
			
			UNION ALL
			
			SELECT @RoleId
				,'permission'
				,'Permissions.App.Catalog.View'

			PRINT 'User Role Claims Created Successfully'

			-- UserTenantMapping  
			INSERT INTO UserTenantMapping (
				UserId
				,TenantId
				,CreatedBy
				)
			SELECT @UserId
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT @SystemUserId
				,@TenantId
				,@SystemUserId

			PRINT 'User Tenant Mapping Created Successfully'
				-- NotificationTemplate  
				;

			WITH TempNotificationTemplate
			AS (
				SELECT 0.00 AS MinAmount
					,100000.00 AS MaxAmount
					,'High fives to [SalesmanName] for closing another order. A step closer to success! ??' AS NotificationMessage
				
				UNION ALL
				
				SELECT 100000.00
					,500000.00
					,'Cheers to [SalesmanName] for finalizing a deal. Together, we grow! ??'
				
				UNION ALL
				
				SELECT 500000.00
					,- 1.00
					,'Big shoutout to [SalesmanName] for finalizing a fantastic order. What an inspiration! ??'
				)
			INSERT INTO NotificationTemplate (
				MinAmount
				,MaxAmount
				,NotificationMessage
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			SELECT tnt.MinAmount
				,tnt.MaxAmount
				,tnt.NotificationMessage
				,@TenantId
				,0
				,@UserId
				,@Date
				,@DateUTC
			FROM TempNotificationTemplate AS tnt

			PRINT 'Notification Template Created Successfully'

			-- Lookups  
			INSERT INTO Lookups (
				LookupName
				,TenantId
				,CreatedBy
				)
			SELECT 'Unit'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'InquiryClosingReasons'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'BackInquiryClosingReasons'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Profession'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ProductCustomLabel'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ProductMaterial'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ProductColour'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ProductBrand'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'LeadSources'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'SpecializedIn'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'PurchaseUrgency'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'CustomerBehavior'
				,@TenantId
				,@UserId

			PRINT 'Lookups Created Successfully'

			INSERT INTO SubjectTypes (
				SubjectTypeName
				,Comments
				,TenantId
				,CreatedBy
				)
			SELECT 'Products'
				,'Products'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'RawMaterials'
				,'RawMaterials'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Polish'
				,'Polish'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Fabrics'
				,'Fabrics'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Customers'
				,'Customers'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ProductQuantity'
				,'ProductQuantity'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Orders'
				,'Orders'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Labours'
				,'Labours'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ASPNETUsers'
				,'ASPNETUsers'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Inquiries'
				,'Inquiries'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'RawMaterialInventory'
				,'RawMaterialInventory'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Inward'
				,'Inward'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Vendor'
				,'Vendor'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Employee'
				,'Employee'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'BackOrder'
				,'BackOrder'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Categories'
				,'Categories'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'ShareProducts'
				,'ShareProducts'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'POProducts'
				,'POProducts'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'PORawMaterials'
				,'PORawMaterials'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Offer'
				,'Offer'
				,@TenantId
				,@UserId

			PRINT 'SubjectTypes Created Successfully'

			INSERT INTO EmailCMS (
				KeyName
				,TenantID
				,CreatedBy
				)
			SELECT 'Order Inquiry'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Order Inquiry Reminder - 1'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Order Inquiry Reminder - 2'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Order Inquiry Reminder - 3'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Order Approved'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Order PDF V2'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'OrderDispatch PDF'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Product Cost Analyzer'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Birthday Email Template'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Anniversary Email Template'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Work Anniversary Email Template'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Welcome Email'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'Stock Transfer PDF'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'BuyingRange'
				,@TenantId
				,@UserId

			PRINT 'Email CMS Created Successfully'

			INSERT INTO EmailCMSDetails (
				EmailCMSID
				,Subject
				,EmailBody
				,TenantID
				,CreatedBy
				)
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Order Inquiry'
						AND ec1.TenantID = @TenantId
					)
				,'Order Inquiry'
				,
				'<table style="width: 600px; margin: auto; font-family: ''Nunito'', sans-serif; font-size: 14px; border: 1px solid #d68b33; border-radius: 10px; overflow: hidden; background: #f3f4f5;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="bor  















  
  
d  
  
er-bottom: 1px solid #d68b33; text-align: center; padding: 10px;">  <div><a style="width: 50px; height: 50px; margin: auto; display: inline-block; vertical-align: middle; background: #3e3e3e; padding: 5px; border-radius: 10px; box-sizing: border-box;" hre







  
  
  
  
  
f="" target="_blank" rel="noopener"> <img style="width: 100%; height: 100%;" src="##tenantLogoPath##" alt="" /> </a>  <div style="display: inline-block; vertical-align: middle; margin-left: 8px;">  <h3 style="margin: 0; font

  
  
  
  
  
  
  
-size: 22px; color: #3e3e3e; text-transform: uppercase; font-weight: 800;">##tenantName##</h3>  </div>  </div>  </td>  </tr>  <!-- Product Information Start -->  <tr>  <td style="text-align: left; padding: 20px 10px 15px;">  <h4 style="font-size: 22px; ma





  
  
  
  
  
  
  
rgin: 0 0 5px; font-weight: 400;">Hello <span style="font-weight: bold;"> ##customerName##! </span></h4>  <p style="margin: 0; font-size: 16px;">Thank you for inquiring about our products.</p>  </td>  </tr>  <tr>  <td>  <table style="width: 100%; backgrou







  
  
  
  
  
nd: #f3f4f5;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="padding: 5px 10px;">  <table style="width: 100%; background: #ffffff; padding: 10px; border-radius: 10px;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td>  <p style="font-size







  
  
  
  
  
: 14px; margin: 0; color: #000000; font-weight: 600;">Your Inquiry ID: <span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;"> ##orderNo## </span></p>  </td>  <td>  <p style="font-size: 14px; m







  
  
  
  
  
argin: 0; color: #000000; font-weight: 600;">Inquiry Date: <span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;"> ##orderDate## </span></p>  </td>  <td style="width: 40%;">  <p style="font-siz







  
  
  
  
  
e: 14px; margin: 0; color: #000000; font-weight: 600;">Salesman: <span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;"> ##salesmanName## - ##salesmanPhone## </span></p>  </td>  </tr>  </tbody>







  
  
  
  
  
  </table>  </td>  </tr>  <!-- Single Set Start -->  <tr>  <td style="text-align: center; vertical-align: top;"><br /><a style="font-family: Roboto, sans-serif; box-sizing: border-box; font-size: 0.8125rem; font-weight: 400; color: #ffffff; text-decoratio







  
  
  
  
  
n: none; text-align: center; cursor: pointer; display: inline-block; border-radius: 0.25rem; text-transform: capitalize; background: #0ab39c; margin: 0px; padding: 0.5rem 0.9rem; border: 1px solid #0ab39c;" href="##orderLink##" target="_blank" rel="noopen







  
  
  
  
  
er">See order details</a></td>  </tr>  <!-- Single Set End --><!-- Address Start -->  <tr>  <td>&nbsp;</td>  </tr>  <!-- Address Start --> <!-- Price Breakup Start -->  <tr>  <td style="padding: 5px 10px;">  <table style="width: 100%; background: #ffffff;







  
  
  
  
  
 border-radius: 10px;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td>  <p>We would be glad to help you more to finalise soon.</p>  <p>Please reach out to our team or interact directly with&nbsp;<span style="display: block; font-size: 14px; color: #







  
  
  
  
  
5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;">##salesmanName## at&nbsp;##salesmanPhone##</span></p>  </td>  </tr>  <tr>  <td>&nbsp;</td>  </tr>  </tbody>  </table>  </td>  </tr>  <!-- Price Breakup End --></tbody>  </table>  </td>  </tr> 







  
  
  
  
  
 <!-- Product Information End --> <!-- footer Start -->  <tr>  <td style="text-align: center; padding: 5px 10px 10px; font-weight: 500; font-size: 12px;">Powered by: <a style="display: inlne-block; text-decoration: none; color: #000000; font-weight: bold;







  
  
  
  
  
" href="https://magnusminds.net/" target="_blank" rel="noopener"> TANYO </a></td>  </tr>  <!-- footer End --></tbody>  </table>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Order Inquiry Reminder - 1'
						AND ec1.TenantID = @TenantId
					)
				,'Order Reminder'
				,
				'<table class="body-wrap" style="background-color: transparent; box-sizing: border-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;">  <tbody>  <tr>  <td style="vertical-align: top;">&nbsp;</td>  <td style="vertical-  







  
  
  
  
align: top;">  <div class="content" style="box-sizing: border-box; display: block; font-family: ''Roboto'',sans-serif; font-size: 14px; max-width: 600px; padding: 20px; margin: 0 auto 0 auto;">  <table class="main" style="border-radius: 3px; box-sizing: b







  
  
  
  
  
order-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;" border="0" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="background-color: #ffffff; border-radius: 7px; vertical-align: top;">&nbsp;  <table style="box-







  
  
  
  
  
sizing: border-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;" border="0" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="text-align: center;"><span style="font-size: 20px;">Order Reminder</span></td>  </tr> 







  
  
  
  
  
 <tr>  <td style="vertical-align: top;">&nbsp;  <div style="margin-bottom: 15px; text-align: center;">Hey, ##customerName##</div>  </td>  </tr>  <tr>  <td style="text-align: center; vertical-align: top;">Here is your order details</td>  </tr>  <tr>  <td s







  
  
  
  
  
tyle="text-align: center; vertical-align: top;">Click on the link below to see your order</td>  </tr>  <tr>  <td style="text-align: center; vertical-align: top;"><br /><a style="font-family: Roboto, sans-serif; box-sizing: border-box; font-size: 0.8125rem







  
  
  
  
  
; font-weight: 400; color: #ffffff; text-decoration: none; text-align: center; cursor: pointer; display: inline-block; border-radius: 0.25rem; text-transform: capitalize; background: #0ab39c; margin: 0px; padding: 0.5rem 0.9rem; border: 1px solid #0ab39c;





  
  
  
  
  
  
  
" href="##orderLink##" target="_blank" rel="noopener">See order details</a></td>  </tr>  </tbody>  </table>  </td>  </tr>  </tbody>  </table>  </div>  </td>  </tr>  </tbody>  </table>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Order Inquiry Reminder - 2'
						AND ec1.TenantID = @TenantId
					)
				,'Order Reminder'
				,
				'<table class="body-wrap" style="background-color: transparent; box-sizing: border-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;">  <tbody>  <tr>  <td style="vertical-align: top;">&nbsp;</td>  <td style="vertical-  







  
  
  
  
align: top;">  <div class="content" style="box-sizing: border-box; display: block; font-family: ''Roboto'',sans-serif; font-size: 14px; max-width: 600px; padding: 20px; margin: 0 auto 0 auto;">  <table class="main" style="border-radius: 3px; box-sizing: b







  
  
  
  
  
order-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;" border="0" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="background-color: #ffffff; border-radius: 7px; vertical-align: top;">&nbsp;  <table style="box-







  
  
  
  
  
sizing: border-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;" border="0" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="text-align: center;"><span style="font-size: 20px;">Order Reminder</span></td>  </tr> 







  
  
  
  
  
 <tr>  <td style="vertical-align: top;">&nbsp;  <div style="margin-bottom: 15px; text-align: center;">Hey, ##customerName##</div>  </td>  </tr>  <tr>  <td style="text-align: center; vertical-align: top;">Here is your order details</td>  </tr>  <tr>  <td s







  
  
  
  
  
tyle="text-align: center; vertical-align: top;">Click on the link below to see your order</td>  </tr>  <tr>  <td style="text-align: center; vertical-align: top;"><br /><a style="font-family: Roboto, sans-serif; box-sizing: border-box; font-size: 0.8125rem







  
  
  
  
  
; font-weight: 400; color: #ffffff; text-decoration: none; text-align: center; cursor: pointer; display: inline-block; border-radius: 0.25rem; text-transform: capitalize; background: #0ab39c; margin: 0px; padding: 0.5rem 0.9rem; border: 1px solid #0ab39c;





  
  
  
  
  
  
  
" href="##orderLink##" target="_blank" rel="noopener">See order details</a></td>  </tr>  </tbody>  </table>  </td>  </tr>  </tbody>  </table>  </div>  </td>  </tr>  </tbody>  </table>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Order Inquiry Reminder - 3'
						AND ec1.TenantID = @TenantId
					)
				,'Order Reminder'
				,
				'<table class="body-wrap" style="background-color: transparent; box-sizing: border-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;">  <tbody>  <tr>  <td style="vertical-align: top;">&nbsp;</td>  <td style="vertical- 













 

  
  
align: top;">  <div class="content" style="box-sizing: border-box; display: block; font-family: ''Roboto'',sans-serif; font-size: 14px; max-width: 600px; padding: 20px; margin: 0 auto 0 auto;">  <table class="main" style="border-radius: 3px; box-sizing: b







  
  
  
  
  
order-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;" border="0" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="background-color: #ffffff; border-radius: 7px; vertical-align: top;">&nbsp;  <table style="box-







  
  
  
  
  
sizing: border-box; font-family: ''Roboto'',sans-serif; font-size: 14px; margin: 0; width: 100%;" border="0" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="text-align: center;"><span style="font-size: 20px;">Order Reminder</span></td>  </tr> 







  
  
  
  
  
 <tr>  <td style="vertical-align: top;">&nbsp;  <div style="margin-bottom: 15px; text-align: center;">Hey, ##customerName##</div>  </td>  </tr>  <tr>  <td style="text-align: center; vertical-align: top;">Here is your order details</td> </tr>  <tr>  <td s 







 
  
  
  
  
  
  
  
  
tyle="text-align: center; vertical-align: top;">Click on the link below to see your order</td>  </tr>  <tr>  <td style="text-align: center; vertical-align: top;"><br /><a style="font-family: Roboto, sans-serif; box-sizing: border-box; font-size: 0.8125rem







  
  
  
  
  
; font-weight: 400; color: #ffffff; text-decoration: none; text-align: center; cursor: pointer; display: inline-block; border-radius: 0.25rem; text-transform: capitalize; background: #0ab39c; margin: 0px; padding: 0.5rem 0.9rem; border: 1px solid #0ab39c;






  
  
  
  
  
  
" href="##orderLink##" target="_blank" rel="noopener">See order details</a></td>  </tr>  </tbody>  </table>  </td>  </tr>  </tbody>  </table>  </div>  </td>  </tr>  </tbody>  </table>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Work Anniversary Email Template'
						AND ec1.TenantID = @TenantId
					)
				,'Order Approved'
				,
				'<html>  
  <link rel="shortcut icon" type="image/png">  
  <style type="text/css">  
#outlook a {  
 padding:0;  
}  
.ExternalClass {  
 width:100%;  
}  
.ExternalClass,  
.ExternalClass p,  
.ExternalClass span,  
.ExternalClass font,  
.ExternalClass td,  
.ExternalClass div {  
 line-height:100%;  
}  
.es-button {  
 mso-style-priority:100!important;  
 text-decoration:none!important;  
}  
a[x-apple-data-detectors] {  
 color:inherit!important;  
 text-decoration:none!important;  
 font-size:inherit!important;  
 font-family:inherit!important;  
 font-weight:inherit!important;  
 line-height:inherit!important;  
}  
.es-desk-hidden {  
 display:none;  
 float:left;  
 overflow:hidden;  
 width:0;  
 max-height:0;  
 line-height:0;  
 mso-hide:all;  
}  
@media only screen and (max-width:600px) {p, ul li, ol li, a { font-size:14px!important; line-height:150%!important } h1 { font-size:28px!important; text-align:center; line-height:120%!important } h2 { font-size:26px!important; text-align:center; line-hei





ght:120%!important } h3 { font-size:20px!important; text-align:center; line-height:120%!important } h1 a { font-size:28px!important } h2 a { font-size:26px!important } h3 a { font-size:20px!important } .es-menu td a { font-size:12px!important } .es-header





-body p, .es-header-body ul li, .es-header-body ol li, .es-header-body a { font-size:12px!important } .es-footer-body p, .es-footer-body ul li, .es-footer-body ol li, .es-footer-body a { font-size:14px!important } .es-infoblock p, .es-infoblock ul li, .es





-infoblock ol li, .es-infoblock a { font-size:11px!important } *[class="gmail-fix"] { display:none!important } .es-m-txt-c, .es-m-txt-c h1, .es-m-txt-c h2, .es-m-txt-c h3 { text-align:center!important } .es-m-txt-r, .es-m-txt-r h1, .es-m-txt-r h2, .es-m-t





xt-r h3 { text-align:right!important } .es-m-txt-l, .es-m-txt-l h1, .es-m-txt-l h2, .es-m-txt-l h3 { text-align:left!important } .es-m-txt-r img, .es-m-txt-c img, .es-m-txt-l img { display:inline!important } .es-button-border { display:block!important } a





.es-button { font-size:14px!important; display:block!important; border-left-width:0px!important; border-right-width:0px!important } .es-btn-fw { border-width:10px 0px!important; text-align:center!important } .es-adaptive table, .es-btn-fw, .es-btn-fw-brdr





, .es-left, .es-right { width:100%!important } .es-content table, .es-header table, .es-footer table, .es-content, .es-footer, .es-header { width:100%!important; max-width:600px!important } .es-adapt-td { display:block!important; width:100%!important } .a





dapt-img { width:100%!important; height:auto!important } .es-m-p0 { padding:0px!important } .es-m-p0r { padding-right:0px!important } .es-m-p0l { padding-left:0px!important } .es-m-p0t { padding-top:0px!important } .es-m-p0b { padding-bottom:0!important }





 .es-m-p20b { padding-bottom:20px!important } .es-mobile-hidden, .es-hidden { display:none!important } tr.es-desk-hidden, td.es-desk-hidden, table.es-desk-hidden { width:auto!important; overflow:visible!important; float:none!important; max-height:inherit!





important; line-height:inherit!important } tr.es-desk-hidden { display:table-row!important } table.es-desk-hidden { display:table!important } td.es-desk-menu-hidden { display:table-cell!important } .es-menu td { width:1%!important } table.es-table-not-ada





pt, .esd-block-html table { width:auto!important } table.es-social { display:inline-block!important } table.es-social td { display:inline-block!important } }  
@media screen and (max-width:384px) {.mail-message-content { width:414px!important } }  
</style>  
 <style>*{scrollbar-width: thin;scrollbar-color: #888 #f6f6f6;}/* Chrome, Edge, Safari */::-webkit-scrollbar {width: 10px;height: 10px;}::-webkit-scrollbar-track {background: #f6f6f6;}::-webkit-scrollbar-thumb {background: #888;border-radius: 6px;border:













2px solid #f6f6f6;}::-webkit-scrollbar-thumb:hover {box-shadow: inset 0 0 6px rgba(0,0,0,0.3);}textarea::-webkit-scrollbar-track {margin: 15px;}</style><base href="#"></head>  
 <body style="width:100%;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;padding:0;Margin:0">  
  <div dir="ltr" class="es-wrapper-color" lang="und">  
   <table class="es-wrapper" width="100%" cellspacing="0" cellpadding="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;padding:0;Margin:0;width:100%;height:100%;background-repeat:repeat;backgroun





d-position:center top">  
     <tbody><tr style="border-collapse:collapse">  
      <td valign="top" style="padding:0;Margin:0">  
       <table cellpadding="0" cellspacing="0" class="es-header" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%;background-color:transparent;b





ackground-repeat:repeat;background-position:center top">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="transparent" class="es-header-body" align="center" cellpadding="0" cellspacing="0" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:transparent;width:600px" role="none





">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-top:20px;padding-bottom:20px;padding-left:20px;padding-right:20px;background-position:left top">  
               <table cellpadding="0" cellspacing="0" class="es-left" align="left" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:left">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td class="es-m-p20b" align="left" style="padding:0;Margin:0;width:270px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="left" class="es-m-txt-c" style="padding:0;Margin:0;font-size:0"><a target="_blank" style="-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', aria





l, verdana, sans-serif;font-size:14px;text-decoration:underline;color:#999999"><img src="##tenantlogo##" alt="" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic" width="135"></a></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table>  
               </td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table>  
       <table cellpadding="0" cellspacing="0" class="es-content" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="#ffffff" class="es-content-body" align="center" cellpadding="0" cellspacing="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:#FFFFFF;width:600px">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="padding:0;Margin:0;background-position:center top;background-color:#202447" bgcolor="#202447">  
               <table cellpadding="0" cellspacing="0" width="100%" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="center" valign="top" style="padding:0;Margin:0;width:600px">  
                   <table cellpadding="0" cellspacing="0" width="100%" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-image:url(https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c





0b7efc174ad6/images/3021564570245556.gif);background-position:left top;background-repeat:no-repeat" background="https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/3021564570245556.gif" role="presentation">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" height="118" style="padding:0;Margin:0"></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0"><h1 style="Margin:0;line-height:36px;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;font-size:30px;font-style:normal;font-weight:bold;c





olor:#ffffff">Happy Work Anniversary<br></h1></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" height="118" style="padding:0;Margin:0"></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
             <tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-bottom:10px;padding-top:20px;padding-left:20px;padding-right:20px;background-position:center top">  
               <table cellpadding="0" cellspacing="0" width="100%" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="center" valign="top" style="padding:0;Margin:0;width:560px">  
                   <table cellpadding="0" cellspacing="0" width="100%" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-position:left top" role="presentation">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0;padding-bottom:10px"></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0;font-size:0"><a target="_blank" href="https://viewstripo.email" style="-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-family:helvetica, ''helveti





ca neue'', arial, verdana, sans-serif;font-size:14px;text-decoration:underline;color:#040404"><img src="##employeeimage##" alt="" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic" width="200"></a></td>  
                     </tr>  
        <tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0"><h3 style="Margin:0;line-height:24px;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;font-size:20px;font-style:normal





;font-weight:bold;color:#040404">##EmployeeName##</h3></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0;padding-bottom:5px"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial,





 verdana, sans-serif;line-height:21px;color:#999999"></p></td>  
                     </tr>  
                       
                     <tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-l" style="padding:0;Margin:0;padding-bottom:10px"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helv





etica neue'', arial, verdana, sans-serif;line-height:21px;color:#040404">##DynamicDescription##</p></td>  
                     </tr>  
                       
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table>  
       <table cellpadding="0" cellspacing="0" class="es-footer" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%;background-color:transparent;b





ackground-repeat:repeat;background-position:center top">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="#ffffff" class="es-footer-body" align="center" cellpadding="0" cellspacing="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:#FFFFFF;width:600px">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-top:20px;padding-bottom:20px;padding-left:20px;padding-right:20px;background-image:url(''https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/63821564496145694.jpg





'');background-position:left top;background-repeat:no-repeat;background-color:#333333" background="https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/63821564496145694.jpg" bgcolor="#333333">  
               <table cellpadding="0" cellspacing="0" class="es-left" align="left" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:left">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td class="es-m-p20b" align="left" style="padding:0;Margin:0;width:368px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="left" class="es-m-txt-c" style="padding:0;Margin:0"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, v





erdana, sans-serif;line-height:21px;color:#FFFFFF"><strong>Respectfully,</strong></p><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, v





erdana, sans-serif;line-height:21px;color:#FFFFFF"><strong>##tenantname##</strong></p><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, 





verdana, sans-serif;line-height:21px;color:#FFFFFF"></p></td>  
                  </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table>  
               <table cellpadding="0" cellspacing="0" class="es-right" align="right" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:right;background-position:left top" role="none">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="left" style="padding:0;Margin:0;width:172px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0;padding-top:10px;padding-bottom:10px;font-size:0">  
                       <table cellpadding="0" cellspacing="0" class="es-table-not-adapt es-social" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                         <tbody><tr style="border-collapse:collapse">  
                             <td align="center" valign="top "  style="cursor:pointer;padding:0;Margin:0;padding-right:10px"><a target="_blank" href="##tenantfacebookurl##"><img title="Facebook"  src="https://tlr.stripocdn.email/content/assets/img/social-i





cons/circle-colored/facebook-circle-colored.png" alt="Fb" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top"style="cursor:pointer;padding:0;Margin:0;padding-right:10px">  
                              <a target="_blank" href="##tenantlinkedurl##"><img title="Linkedin" src="https://tlr.stripocdn.email/content/assets/img/social-icons/circle-colored/linkedin-circle-colored.png" alt="In" width="24" height="24" style="display:b





lock;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top"style="cursor:pointer;padding:0;Margin:0;padding-right:10px"> <a target="_blank" href="##tenantmailurl##"><img title="Email" src="https://tlr.stripocdn.email/content/assets/img/other-icons/circle-co





lored/mail-circle-colored.png" alt="Email" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top" style="cursor:pointer;padding:0;Margin:0"><a target="_blank" href="##tenantskypeurl##"><img title="Skype" src="https://tlr.stripocdn.email/content/assets/img/messenger-icons/circle-colored/skype-ci





rcle-colored.png" alt="Skype" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                         </tr>  
                       </tbody></table></td>  
                     </tr>  
                       
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table></td>  
    </tr>  
   </tbody></table>  
  </div>  
</body></html>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Anniversary Email Template'
						AND ec1.TenantID = @TenantId
					)
				,'Order Approved'
				,
				'<html>  
  <link rel="shortcut icon" type="image/png">  
  <style type="text/css">  
#outlook a {  
 padding:0;  
}  
.ExternalClass {  
 width:100%;  
}  
.ExternalClass,  
.ExternalClass p,  
.ExternalClass span,  
.ExternalClass font,  
.ExternalClass td,  
.ExternalClass div {  
 line-height:100%;  
}  
.es-button {  
 mso-style-priority:100!important;  
 text-decoration:none!important;  
}  
a[x-apple-data-detectors] {  
 color:inherit!important;  
 text-decoration:none!important;  
 font-size:inherit!important;  
 font-family:inherit!important;  
 font-weight:inherit!important;  
 line-height:inherit!important;  
}  
.es-desk-hidden {  
 display:none;  
 float:left;  
 overflow:hidden;  
 width:0;  
 max-height:0;  
 line-height:0;  
 mso-hide:all;  
}  
@media only screen and (max-width:600px) {p, ul li, ol li, a { font-size:14px!important; line-height:150%!important } h1 { font-size:28px!important; text-align:center; line-height:120%!important } h2 { font-size:26px!important; text-align:center; line-hei





ght:120%!important } h3 { font-size:20px!important; text-align:center; line-height:120%!important } h1 a { font-size:28px!important } h2 a { font-size:26px!important } h3 a { font-size:20px!important } .es-menu td a { font-size:12px!important } .es-header





-body p, .es-header-body ul li, .es-header-body ol li, .es-header-body a { font-size:12px!important } .es-footer-body p, .es-footer-body ul li, .es-footer-body ol li, .es-footer-body a { font-size:14px!important } .es-infoblock p, .es-infoblock ul li, .es





-infoblock ol li, .es-infoblock a { font-size:11px!important } *[class="gmail-fix"] { display:none!important } .es-m-txt-c, .es-m-txt-c h1, .es-m-txt-c h2, .es-m-txt-c h3 { text-align:center!important } .es-m-txt-r, .es-m-txt-r h1, .es-m-txt-r h2, .es-m-t





xt-r h3 { text-align:right!important } .es-m-txt-l, .es-m-txt-l h1, .es-m-txt-l h2, .es-m-txt-l h3 { text-align:left!important } .es-m-txt-r img, .es-m-txt-c img, .es-m-txt-l img { display:inline!important } .es-button-border { display:block!important } a





.es-button { font-size:14px!important; display:block!important; border-left-width:0px!important; border-right-width:0px!important } .es-btn-fw { border-width:10px 0px!important; text-align:center!important } .es-adaptive table, .es-btn-fw, .es-btn-fw-brdr





, .es-left, .es-right { width:100%!important } .es-content table, .es-header table, .es-footer table, .es-content, .es-footer, .es-header { width:100%!important; max-width:600px!important } .es-adapt-td { display:block!important; width:100%!important } .a





dapt-img { width:100%!important; height:auto!important } .es-m-p0 { padding:0px!important } .es-m-p0r { padding-right:0px!important } .es-m-p0l { padding-left:0px!important } .es-m-p0t { padding-top:0px!important } .es-m-p0b { padding-bottom:0!important }





 .es-m-p20b { padding-bottom:20px!important } .es-mobile-hidden, .es-hidden { display:none!important } tr.es-desk-hidden, td.es-desk-hidden, table.es-desk-hidden { width:auto!important; overflow:visible!important; float:none!important; max-height:inherit!





important; line-height:inherit!important } tr.es-desk-hidden { display:table-row!important } table.es-desk-hidden { display:table!important } td.es-desk-menu-hidden { display:table-cell!important } .es-menu td { width:1%!important } table.es-table-not-ada





pt, .esd-block-html table { width:auto!important } table.es-social { display:inline-block!important } table.es-social td { display:inline-block!important } }  
@media screen and (max-width:384px) {.mail-message-content { width:414px!important } }  
</style>  
 <style>*{scrollbar-width: thin;scrollbar-color: #888 #f6f6f6;}/* Chrome, Edge, Safari */::-webkit-scrollbar {width: 10px;height: 10px;}::-webkit-scrollbar-track {background: #f6f6f6;}::-webkit-scrollbar-thumb {background: #888;border-radius: 6px;border: 





2px solid #f6f6f6;}::-webkit-scrollbar-thumb:hover {box-shadow: inset 0 0 6px rgba(0,0,0,0.3);}textarea::-webkit-scrollbar-track {margin: 15px;}</style><base href="#"></head>  
 <body style="width:100%;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;padding:0;Margin:0">  
  <div dir="ltr" class="es-wrapper-color" lang="und" >  
   <table class="es-wrapper" width="100%" cellspacing="0" cellpadding="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;padding:0;Margin:0;width:100%;height:100%;background-repeat:repeat;backgroun





d-position:center top">  
     <tbody><tr style="border-collapse:collapse">  
      <td valign="top" style="padding:0;Margin:0">  
       <table cellpadding="0" cellspacing="0" class="es-header" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%;background-color:transparent;b





ackground-repeat:repeat;background-position:center top">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="transparent" class="es-header-body" align="center" cellpadding="0" cellspacing="0" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:transparent;width:600px" role="none





">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-top:20px;padding-bottom:20px;padding-left:20px;padding-right:20px;background-position:left top">  
               <table cellpadding="0" cellspacing="0" class="es-left" align="left" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:left">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td class="es-m-p20b" align="left" style="padding:0;Margin:0;width:270px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="left" class="es-m-txt-c" style="padding:0;Margin:0;font-size:0"><a target="_blank" style="-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', aria





l, verdana, sans-serif;font-size:14px;text-decoration:underline;color:#999999"><img src="##tenantlogo##" alt="" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic" width="135"></a></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table>  
               </td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table>  
       <table cellpadding="0" cellspacing="0" class="es-content" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="#ffffff" class="es-content-body" align="center" cellpadding="0" cellspacing="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:#FFFFFF;width:600px">  
             <tbody><tr style="border-collapse:collapse">  
      <td align="left" style="padding:0;Margin:0;background-position:center top;background-color:#202447" bgcolor="#202447">  
               <table cellpadding="0" cellspacing="0" width="100%" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="center" valign="top" style="padding:0;Margin:0;width:600px">  
                   <table cellpadding="0" cellspacing="0" width="100%" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-image:url(https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c





0b7efc174ad6/images/3021564570245556.gif);background-position:left top;background-repeat:no-repeat" background="https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/3021564570245556.gif" role="presentation">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" height="118" style="padding:0;Margin:0"></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0"><h1 style="Margin:0;line-height:36px;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;font-size:30px;font-style:normal;font-weight:bold;c





olor:#ffffff">Happy Anniversary<br></h1></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" height="118" style="padding:0;Margin:0"></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
             <tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-bottom:10px;padding-top:20px;padding-left:20px;padding-right:20px;background-position:center top">  
               <table cellpadding="0" cellspacing="0" width="100%" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="center" valign="top" style="padding:0;Margin:0;width:560px">  
                   <table cellpadding="0" cellspacing="0" width="100%" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-position:left top" role="presentation">  
                     <tbody><tr style="border-collapse:collapse">  
                     <td align="center" class="es-m-txt-c" style="padding:0;Margin:0;padding-bottom:10px"></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0;font-size:0"><a target="_blank" href="https://viewstripo.email" style="-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-family:helvetica, ''helveti





ca neue'', arial, verdana, sans-serif;font-size:14px;text-decoration:underline;color:#040404"><img src="##employeeimage##" alt="" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic" width="200"></a></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0"><h3 style="Margin:0;line-height:24px;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;font-size:20px;font-style:normal





;font-weight:bold;color:#040404">##EmployeeName##</h3></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0;padding-bottom:5px"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial,





 verdana, sans-serif;line-height:21px;color:#999999"></p></td>  
                     </tr>  
                       
                     <tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-l" style="padding:0;Margin:0;padding-bottom:10px"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helv





etica neue'', arial, verdana, sans-serif;line-height:21px;color:#040404">##DynamicDescription##</p></td>  
                     </tr>  
                       
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table>  
       <table cellpadding="0" cellspacing="0" class="es-footer" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%;background-color:transparent;b





ackground-repeat:repeat;background-position:center top">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="#ffffff" class="es-footer-body" align="center" cellpadding="0" cellspacing="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:#FFFFFF;width:600px">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-top:20px;padding-bottom:20px;padding-left:20px;padding-right:20px;background-image:url(''https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/63821564496145694.jpg





'');background-position:left top;background-repeat:no-repeat;background-color:#333333" background="https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/63821564496145694.jpg" bgcolor="#333333">  
               <table cellpadding="0" cellspacing="0" class="es-left" align="left" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:left">  
                 <tbody><tr style="border-collapse:collapse">  
             <td class="es-m-p20b" align="left" style="padding:0;Margin:0;width:368px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="left" class="es-m-txt-c" style="padding:0;Margin:0"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, v





erdana, sans-serif;line-height:21px;color:#FFFFFF"><strong>Respectfully,</strong></p><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, v





erdana, sans-serif;line-height:21px;color:#FFFFFF"><strong>##tenantname##</strong></p><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, 





verdana, sans-serif;line-height:21px;color:#FFFFFF"></p></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table>  
               <table cellpadding="0" cellspacing="0" class="es-right" align="right" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:right;background-position:left top" role="none">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="left" style="padding:0;Margin:0;width:172px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0;padding-top:10px;padding-bottom:10px;font-size:0">  
                       <table cellpadding="0" cellspacing="0" class="es-table-not-adapt es-social" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                         <tbody><tr style="border-collapse:collapse">  
                             <td align="center" valign="top "  style="cursor:pointer;padding:0;Margin:0;padding-right:10px"><a target="_blank" href="##tenantfacebookurl##"><img title="Facebook"  src="https://tlr.stripocdn.email/content/assets/img/social-i





cons/circle-colored/facebook-circle-colored.png" alt="Fb" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top"style="cursor:pointer;padding:0;Margin:0;padding-right:10px">  
                              <a target="_blank" href="##tenantlinkedurl##"><img title="Linkedin" src="https://tlr.stripocdn.email/content/assets/img/social-icons/circle-colored/linkedin-circle-colored.png" alt="In" width="24" height="24" style="display:b





lock;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top"style="cursor:pointer;padding:0;Margin:0;padding-right:10px"> <a target="_blank" href="##tenantmailurl##"><img title="Email" src="https://tlr.stripocdn.email/content/assets/img/other-icons/circle-co





lored/mail-circle-colored.png" alt="Email" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top" style="cursor:pointer;padding:0;Margin:0"><a target="_blank" href="##tenantskypeurl##"><img title="Skype" src="https://tlr.stripocdn.email/content/assets/img/messenger-icons/circle-colored/skype-ci





rcle-colored.png" alt="Skype" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
             </tr>  
                       </tbody></table></td>  
                     </tr>  
                       
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table></td>  
     </tr>  
   </tbody></table>  
  </div>  
</body></html>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Birthday Email Template'
						AND ec1.TenantID = @TenantId
					)
				,'Order Approved'
				,
				'<html>  
  <link rel="shortcut icon" type="image/png">  
  <style type="text/css">  
#outlook a {  
 padding:0;  
}  
.ExternalClass {  
 width:100%;  
}  
.ExternalClass,  
.ExternalClass p,  
.ExternalClass span,  
.ExternalClass font,  
.ExternalClass td,  
.ExternalClass div {  
 line-height:100%;  
}  
.es-button { 
 mso-style-priority:100!important;  
 text-decoration:none!important;  
}  
a[x-apple-data-detectors] {  
 color:inherit!important;  
 text-decoration:none!important;  
 font-size:inherit!important;  
 font-family:inherit!important;  
 font-weight:inherit!important;  
 line-height:inherit!important;  
}  
.es-desk-hidden {  
 display:none;  
 float:left;  
 overflow:hidden;  
 width:0;  
 max-height:0;  
 line-height:0;  
 mso-hide:all;  
}  
@media only screen and (max-width:600px) {p, ul li, ol li, a { font-size:14px!important; line-height:150%!important } h1 { font-size:28px!important; text-align:center; line-height:120%!important } h2 { font-size:26px!important; text-align:center; line-hei





ght:120%!important } h3 { font-size:20px!important; text-align:center; line-height:120%!important } h1 a { font-size:28px!important } h2 a { font-size:26px!important } h3 a { font-size:20px!important } .es-menu td a { font-size:12px!important } .es-header





-body p, .es-header-body ul li, .es-header-body ol li, .es-header-body a { font-size:12px!important } .es-footer-body p, .es-footer-body ul li, .es-footer-body ol li, .es-footer-body a { font-size:14px!important } .es-infoblock p, .es-infoblock ul li, .es





-infoblock ol li, .es-infoblock a { font-size:11px!important } *[class="gmail-fix"] { display:none!important } .es-m-txt-c, .es-m-txt-c h1, .es-m-txt-c h2, .es-m-txt-c h3 { text-align:center!important } .es-m-txt-r, .es-m-txt-r h1, .es-m-txt-r h2, .es-m-t





xt-r h3 { text-align:right!important } .es-m-txt-l, .es-m-txt-l h1, .es-m-txt-l h2, .es-m-txt-l h3 { text-align:left!important } .es-m-txt-r img, .es-m-txt-c img, .es-m-txt-l img { display:inline!important } .es-button-border { display:block!important } a





.es-button { font-size:14px!important; display:block!important; border-left-width:0px!important; border-right-width:0px!important } .es-btn-fw { border-width:10px 0px!important; text-align:center!important } .es-adaptive table, .es-btn-fw, .es-btn-fw-brdr





, .es-left, .es-right { width:100%!important } .es-content table, .es-header table, .es-footer table, .es-content, .es-footer, .es-header { width:100%!important; max-width:600px!important } .es-adapt-td { display:block!important; width:100%!important } .a





dapt-img { width:100%!important; height:auto!important } .es-m-p0 { padding:0px!important } .es-m-p0r { padding-right:0px!important } .es-m-p0l { padding-left:0px!important } .es-m-p0t { padding-top:0px!important } .es-m-p0b { padding-bottom:0!important }





 .es-m-p20b { padding-bottom:20px!important } .es-mobile-hidden, .es-hidden { display:none!important } tr.es-desk-hidden, td.es-desk-hidden, table.es-desk-hidden { width:auto!important; overflow:visible!important; float:none!important; max-height:inherit!





important; line-height:inherit!important } tr.es-desk-hidden { display:table-row!important } table.es-desk-hidden { display:table!important } td.es-desk-menu-hidden { display:table-cell!important } .es-menu td { width:1%!important } table.es-table-not-ada





pt, .esd-block-html table { width:auto!important } table.es-social { display:inline-block!important } table.es-social td { display:inline-block!important } }  
@media screen and (max-width:384px) {.mail-message-content { width:414px!important } }  
</style>  
 <style>*{scrollbar-width: thin;scrollbar-color: #888 #f6f6f6;}/* Chrome, Edge, Safari */::-webkit-scrollbar {width: 10px;height: 10px;}::-webkit-scrollbar-track {background: #f6f6f6;}::-webkit-scrollbar-thumb {background: #888;border-radius: 6px;border: 





2px solid #f6f6f6;}::-webkit-scrollbar-thumb:hover {box-shadow: inset 0 0 6px rgba(0,0,0,0.3);}textarea::-webkit-scrollbar-track {margin: 15px;}</style><base href="#"></head>  
 <body style="width:100%;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;-webkit-text-size-adjust:100%;-ms-text-size-adjust:100%;padding:0;Margin:0">  
  <div dir="ltr" class="es-wrapper-color" lang="und">  
   <table class="es-wrapper" width="100%" cellspacing="0" cellpadding="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;padding:0;Margin:0;width:100%;height:100%;background-repeat:repeat;backgroun





d-position:center top">  
     <tbody><tr style="border-collapse:collapse">  
      <td valign="top" style="padding:0;Margin:0">  
    <table cellpadding="0" cellspacing="0" class="es-header" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%;background-color:transparent;b




ackground-repeat:repeat;background-position:center top">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="transparent" class="es-header-body" align="center" cellpadding="0" cellspacing="0" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:transparent;width:600px" role="none





">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-top:20px;padding-bottom:20px;padding-left:20px;padding-right:20px;background-position:left top">  
               <table cellpadding="0" cellspacing="0" class="es-left" align="left" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:left">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td class="es-m-p20b" align="left" style="padding:0;Margin:0;width:270px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="left" class="es-m-txt-c" style="padding:0;Margin:0;font-size:0"><a target="_blank" style="-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', aria





l, verdana, sans-serif;font-size:14px;text-decoration:underline;color:#999999"><img src="##tenantlogo##" alt="" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic" width="135"></a></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table>  
               </td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table>  
       <table cellpadding="0" cellspacing="0" class="es-content" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="#ffffff" class="es-content-body" align="center" cellpadding="0" cellspacing="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:#FFFFFF;width:600px">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="padding:0;Margin:0;background-position:center top;background-color:#202447" bgcolor="#202447">  
               <table cellpadding="0" cellspacing="0" width="100%" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="center" valign="top" style="padding:0;Margin:0;width:600px">  
                   <table cellpadding="0" cellspacing="0" width="100%" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-image:url(https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71









c

0b7efc174ad6/images/3021564570245556.gif);background-position:left top;background-repeat:no-repeat" background="https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/3021564570245556.gif" role="presentation">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" height="118" style="padding:0;Margin:0"></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0"><h1 style="Margin:0;line-height:36px;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;font-size:30px;font-style:normal;font-weight:bold;c





olor:#ffffff">Happy Birthday<br></h1></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" height="118" style="padding:0;Margin:0"></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
             <tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-bottom:10px;padding-top:20px;padding-left:20px;padding-right:20px;background-position:center top">  
               <table cellpadding="0" cellspacing="0" width="100%" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="center" valign="top" style="padding:0;Margin:0;width:560px">  
                   <table cellpadding="0" cellspacing="0" width="100%" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-position:left top" role="presentation">  
                     <tbody><tr style="border-collapse:collapse">  
             <td align="center" class="es-m-txt-c" style="padding:0;Margin:0;padding-bottom:10px"></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0;font-size:0"><a target="_blank" href="https://viewstripo.email" style="-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-family:helvetica, ''helveti





ca neue'', arial, verdana, sans-serif;font-size:14px;text-decoration:underline;color:#040404"><img src="##employeeimage##" alt="" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic" width="200"></a></td>  
        </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0"><h3 style="Margin:0;line-height:24px;mso-line-height-rule:exactly;font-family:helvetica, ''helvetica neue'', arial, verdana, sans-serif;font-size:20px;font-style:normal





;font-weight:bold;color:#040404">##EmployeeName##</h3></td>  
                     </tr>  
                     <tr style="border-collapse:collapse">  
                      <td align="center" style="padding:0;Margin:0;padding-bottom:5px"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial,





 verdana, sans-serif;line-height:21px;color:#999999"></p></td>  
                     </tr>  
                       
                     <tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-l" style="padding:0;Margin:0;padding-bottom:10px"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helv





etica neue'', arial, verdana, sans-serif;line-height:21px;color:#040404">##DynamicDescription##</p></td>  
                     </tr>  
                       
                   </tbody></table></td>  
                 </tr>  
               </tbody></table></td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table>  
       <table cellpadding="0" cellspacing="0" class="es-footer" align="center" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;table-layout:fixed !important;width:100%;background-color:transparent;b





ackground-repeat:repeat;background-position:center top">  
         <tbody><tr style="border-collapse:collapse">  
          <td align="center" style="padding:0;Margin:0">  
           <table bgcolor="#ffffff" class="es-footer-body" align="center" cellpadding="0" cellspacing="0" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;background-color:#FFFFFF;width:600px">  
             <tbody><tr style="border-collapse:collapse">  
              <td align="left" style="Margin:0;padding-top:20px;padding-bottom:20px;padding-left:20px;padding-right:20px;background-image:url(''https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/63821564496145694.jpg





'');background-position:left top;background-repeat:no-repeat;background-color:#333333" background="https://tlr.stripocdn.email/content/guids/CABINET_58bdfab47b91421ec71c0b7efc174ad6/images/63821564496145694.jpg" bgcolor="#333333">  
               <table cellpadding="0" cellspacing="0" class="es-left" align="left" role="none" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:left">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td class="es-m-p20b" align="left" style="padding:0;Margin:0;width:368px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                    <tbody><tr style="border-collapse:collapse">  
                      <td align="left" class="es-m-txt-c" style="padding:0;Margin:0"><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, v





erdana, sans-serif;line-height:21px;color:#FFFFFF"><strong>Respectfully,</strong></p><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, v





erdana, sans-serif;line-height:21px;color:#FFFFFF"><strong>##tenantname##</strong></p><p style="Margin:0;-webkit-text-size-adjust:none;-ms-text-size-adjust:none;mso-line-height-rule:exactly;font-size:14px;font-family:helvetica, ''helvetica neue'', arial, 





verdana, sans-serif;line-height:21px;color:#FFFFFF"></p></td>  
                     </tr>  
                   </tbody></table></td>  
                 </tr>  
               </tbody></table>  
               <table cellpadding="0" cellspacing="0" class="es-right" align="right" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px;float:right;background-position:left top" role="none">  
                 <tbody><tr style="border-collapse:collapse">  
                  <td align="left" style="padding:0;Margin:0;width:172px">  
                   <table cellpadding="0" cellspacing="0" width="100%" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                     <tbody><tr style="border-collapse:collapse">  
                      <td align="center" class="es-m-txt-c" style="padding:0;Margin:0;padding-top:10px;padding-bottom:10px;font-size:0">  
  <table cellpadding="0" cellspacing="0" class="es-table-not-adapt es-social" role="presentation" style="mso-table-lspace:0pt;mso-table-rspace:0pt;border-collapse:collapse;border-spacing:0px">  
                         <tbody><tr style="border-collapse:collapse">  
                             <td align="center" valign="top "  style="cursor:pointer;padding:0;Margin:0;padding-right:10px"><a target="_blank" href="##tenantfacebookurl##"><img title="Facebook"  src="https://tlr.stripocdn.email/content/assets/img/social-









i

cons/circle-colored/facebook-circle-colored.png" alt="Fb" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
        <td align="center" valign="top"style="cursor:pointer;padding:0;Margin:0;padding-right:10px">  
                              <a target="_blank" href="##tenantlinkedurl##"><img title="Linkedin" src="https://tlr.stripocdn.email/content/assets/img/social-icons/circle-colored/linkedin-circle-colored.png" alt="In" width="24" height="24" style="display:b





lock;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top"style="cursor:pointer;padding:0;Margin:0;padding-right:10px"> <a target="_blank" href="##tenantmailurl##"><img title="Email" src="https://tlr.stripocdn.email/content/assets/img/other-icons/circle-co





lored/mail-circle-colored.png" alt="Email" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                          <td align="center" valign="top" style="cursor:pointer;padding:0;Margin:0"><a target="_blank" href="##tenantskypeurl##"><img title="Skype" src="https://tlr.stripocdn.email/content/assets/img/messenger-icons/circle-colored/skype-ci





rcle-colored.png" alt="Skype" width="24" height="24" style="display:block;border:0;outline:none;text-decoration:none;-ms-interpolation-mode:bicubic"></a></td>  
                         </tr>  
                       </tbody></table></td>  
                     </tr>  
                       
                   </tbody></table></td>  
            </tr>  
               </tbody></table></td>  
             </tr>  
           </tbody></table></td>  
         </tr>  
       </tbody></table></td>  
     </tr>  
   </tbody></table>  
  </div>  
</body></html>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Order Approved'
						AND ec1.TenantID = @TenantId
					)
				,'Order Approved'
				,
				'<table style="width: 600px; margin: auto; font-family: ''Nunito'', sans-serif; font-size: 14px; border: 1px solid #d68b33; border-radius: 10px; overflow: hidden; background: #f3f4f5;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="bord  







  
  
  
  
er-bottom: 1px solid #d68b33; text-align: center; padding: 10px;">  <div><a style="width: 50px; height: 50px; margin: auto; display: inline-block; vertical-align: middle; background: #3e3e3e; padding: 5px; border-radius: 10px; box-sizing: border-box;" hre







  
  
  
  
  
f="" target="_blank" rel="noopener"> <img style="width: 100%; height: 100%;" src="##tenantLogoPath##" alt="" /> </a>  <div style="display: inline-block; vertical-align: middle; margin-left: 8px;">  <h3 style="margin: 0; font

  
  
  
  
  
  
  
-size: 22px; color: #3e3e3e; text-transform: uppercase; font-weight: 800;">##tenantName##</h3>  </div>  </div>  </td>  </tr>  <!-- Product Information Start -->  <tr>  <td style="text-align: left; padding: 20px 10px 15px;">  <h4 style="font-size: 22px; ma





  
  
  
  
  
  
  
rgin: 0 0 5px; font-weight: 400;">Hello <span style="font-weight: bold;"> ##customerName##! </span></h4>  <p style="margin: 0; font-size: 16px;">Thank you for purchasing our products.</p>  </td>  </tr>  <tr>  <td>  <table style="width: 100%; background: #







  
  
  
  
  
f3f4f5;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td style="padding: 5px 10px;">  <table style="width: 100%; background: #ffffff; padding: 10px; border-radius: 10px;" cellspacing="0" cellpadding="0">  <tbody>  <tr>  <td>  <p style="font-size: 14p







  
  
  
  
  
x; margin: 0; color: #000000; font-weight: 600;">Your Inquiry ID: <span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;"> ##orderNo## </span></p>  </td>  <td>  <p style="font-size: 14px; margin







  
  
  
  
  
: 0; color: #000000; font-weight: 600;">Inquiry Date: <span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;"> ##orderDate## </span></p>  </td>  <td style="width: 40%;">  <p style="font-size: 14







  
  
  
  
  
px; margin: 0; color: #000000; font-weight: 600;">Salesman: <span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;"> ##salesmanName## - ##salesmanPhone## </span></p>  </td>  </tr>  </tbody>  </t







  
  
  
  
  
able>  </td>  </tr>  <!-- Single Set Start --> <!-- Address Start --> <!-- Price Breakup Start -->  <tr>  <td style="padding: 5px 10px;">  <table style="width: 100%; background: #ffffff; border-radius: 10px;" cellspacing="0" cellpadding="0">  <tbody>  <tr







  
  
  
  
  
>  <td>  <p>Please reach out to our team or interact directly with&nbsp;<span style="display: block; font-size: 14px; color: #5e5e5e; font-weight: 600; line-height: 100%; margin: 4px 0 0;">##salesmanName## at&nbsp;##salesmanPhone##</span></p>  <p><span st







  
  
  
  
  
yle="display: block; font-size: 14px; color: #5e5e5e; line-height: 100%; margin: 4px 0px 0px;">Please find attached order pdf.</span></p>  </td>  </tr>  <tr>  <td>&nbsp;</td>  </tr>  </tbody>  </table>  </td>  </tr>  <!-- Price Breakup End --></tbody>  </







  
  
  
  
  
table>  </td>  </tr>  <!-- Product Information End --> <!-- footer Start -->  <tr>  <td style="text-align: center; padding: 5px 10px 10px; font-weight: 500; font-size: 12px;">Powered by: <a style="display: inlne-block; text-decoration: none; color: #00000







  
  
  
  
  
0; font-weight: bold;" href="https://magnusminds.net/" target="_blank" rel="noopener"> TANYO </a></td>  </tr>  <!-- footer End --></tbody>  </table>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Order PDF V2'
						AND ec1.TenantID = @TenantId
					)
				,'Order PDF'
				,
				'<div style="width: 1200px; margin: auto; border: 1px solid #3e3e3e; background: #ebebeb; box-sizing: border-box;">  
<div class="step1" style="box-sizing: border-box; border-bottom: 1px solid #b5b5b5;">  
<div style="width: 85%; display: inline-block; float: left; box-sizing: border-box; height: 112px; border-right: 1px solid #b5b5b5; text-align: center;">  
<div>  
<h3 dir="ltr" style="margin: 0; font-size: 22px; color: #3e3e3e; text-transform: uppercase; padding: 8px 0; border-bottom: 1px solid #b5b5b5;">##tenantName##</h3>  
<p style="margin: 0; padding: 8px 0; border-bottom: 1px solid #b5b5b5;">##tenantAddress##</p>  
<p style="margin: 0; padding: 8px 0;"><strong>Phone:</strong> ##phoneNumber## | <strong>Email:</strong> ##emailId## | <span style="display: ##gstisvisibleflag##;"><strong>GST:</strong> ##GSTNo##</span></p>  
</div>  
</div>  
<div style="height: 112px; width: 15%; display: inline-block; padding: 15px 0 0; box-sizing: border-box; font-size: 0; text-align: center;"><a style="width: 80px; height: 80px; margin: auto; display: inline-block; vertical-align: middle; background: #3e3e





3e; padding: 5px; border-radius: 10px; box-sizing: border-box;" href="" target="_blank" rel="noopener"> <img style="width: 100%; height: 100%;" src="##tenantLogoPath##" alt="##tenantName##" /> </a></div>  
</div>  
<div class="step2" style="margin: 10px; background: #ffffff; overflow: hidden;"><span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; di





splay: block;">Your Order ID:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##orderNo##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <sp





an style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Order Status:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##orderStatus##</span> </span> <span style=





"width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Order Date:</span> <span style="font-size: 14px; color: #191919; font-weight:





 bold; line-height: 100%; margin: 0;">##orderDate##</span> </span> <span style="width: 300px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;





">Salesman:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##salesmanNameAndPhoneNumber##</span> </span></div>  
<div class="step2" style="margin: 10px; background: #ffffff; overflow: hidden;"><span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px; vertical-align: top;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 50





0; color: #3e3e3e; display: block;">Customer Name</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##customerName##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff;





 padding: 5px 10px; vertical-align: top;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Phone Number:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0





;">##customerPhone##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px; vertical-align: top;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Email Ad





dress:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##customerEmail##</span> </span> <span style="width: 300px; display: inline-block; background: #ffffff; padding: 5px 10px; vertical-align: top;">





 <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Inquiry Last Updated Date:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##inquiryDate##</span></sp





an> <span style="width: 250px; display: ##AltPhoneDisplay##; background: #ffffff; padding: 5px 10px; vertical-align: top;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Alt Phone No:</span> <span style=





"font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##AltPhoneNumber##</span> </span> <span style="width: 250px; display: ##ReferredbyDisplay##; background: #ffffff; padding: 5px 10px; vertical-align: top;"> <span style="fo





nt-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Referred By:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##referredby##</span> </span> <span style="width: 250px;





 display: ##companyDisplay##; background: #ffffff; padding: 5px 10px; vertical-align: top;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Company Name:</span> <span style="font-size: 14px; color: #19191





9; font-weight: bold; line-height: 100%; margin: 0;">##companyname##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px; vertical-align: top;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight





: 500; color: #3e3e3e; display: block;">Tentative Delivery Date:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##deliveryDate##</span> </span></div>  
<div class="step4" style="letter-spacing: 0; font-size: 0; margin: 10px 10px 0; overflow: hidden; min-height: 106px;"><span style="display: inline-block; width: 584px; overflow: hidden; background: #ffffff; border: 1px solid #e3e3e3;"> <span style="color:





 #191919; margin: 0; font-size: 14px; border-bottom: 1px solid #f1f2f3; padding: 8px 10px; display: block;">Shipping Address</span> <span style="margin: 0; font-size: 12px; line-height: 150%; padding: 5px 10px 8px; display: block;">##orderShippingAddress#





#</span> </span> <span style="display: inline-block; width: 586px; overflow: hidden; background: #ffffff; border: 1px solid #e3e3e3; margin-left: 3px;"> <span style="color: #191919; margin: 0; font-size: 14px; border-bottom: 1px solid #f1f2f3; padding: 8p





x 10px; display: block;">Billing Address</span> <span style="margin: 0; font-size: 12px; line-height: 150%; padding: 5px 10px 8px; display: block;">##orderBillingAddress##</span> </span></div>  
##orderSetAndProductDetails##  
<div style="box-sizing: border-box; width: 100%; margin: auto; clear: both;">  
<div class="step6" style="padding: 0 8px 0 10px; box-sizing: border-box; margin: 10px 0; clear: both;">  
<div style="font-size: 0; overflow: hidden; color: #191919; box-sizing: border-box; border-bottom: 0;">  
<div style="box-sizing: border-box; border-bottom: 0;">  
<table style="width: 100%; background: #ffffff; overflow: hidden; color: #191919; border: 1px solid #e3e3e3; margin: 10px 0 0;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="margin: 0 0 5px; padding: 8px 10px; border-bottom: 1px solid #b5b5b5;">  
<h3 style="margin: 0; font-size: 14px; color: #191919; text-align: center;">Price Details</h3>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px;">Gross Total Amount</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 120px; width: 170px;">  
<p style="margin: 8px 0; text-align: right; font-weight: 100; font-size: 14px;">##grossTotalAmount##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr style="display: ##lineitemdiscountrow##;">  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px;">Total line item discount</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 120px; width: 170px;">  
<p style="margin: 8px 0; text-align: right; color: #008000; font-size: 14px;">##discountAmount##</p> 
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px; font-weight: bold;">Order Amount</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 120px; width: 170px;">  
<p style="margin: 8px 0; text-align: right; fw-bold;font-size: 14px; font-weight: bold;">##orderamount##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%; display: ##gstisvisibleflag##;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: -20px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px;">Product Amount</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 10px; width: 10%;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px;">##productAmount##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%; display: ##gstisvisibleflag##;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; text-align: right; width: 87.3515%;">  
<p style="margin: 8px 0; font-size: 14px;">CGST</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 10px; width: 10%;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px;">##cgst##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%; display: ##gstisvisibleflag##;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right; width: 87.3514%;">  
<p style="margin: 8px 0; font-size: 14px;">SGST</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 10px; width: 10%;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px;">##sgst##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%; display: ##gstisvisibleflag##;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px;">Round Off</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 10px; width: 10%;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px;">##roundOff##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%; display: ##DisplayTotalAmountOnTop##;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-weight: 600; font-size: 14px;">Total Amount</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 115px; width: 170px;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px; font-weight: 600;">##finalTotal##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px;">Delivery ##amountcharge##</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 115px; width: 170px;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px;">##amountwithdeliveryCharges##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px; font-weight: 600;">Total Order Amount</p>  
</td>  
<td style="border-bottom: 2px dashed #f1f2f3; padding-right: 115px; width: 170px;">  
<p style="margin: 8px 0; text-align: right; font-size: 14px; font-weight: 600;">##TotalOrderValue##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr> 
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="padding-left: 10px; text-align: right;">  
<p style="margin: 8px 0; font-size: 14px;">Advance Amount</p>  
</td>  
<td style="padding-right: 115px; width: 170px;">  
<p style="font-size: 14px; margin: 8px 0; text-align: right;">##advanceAmount##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
<tr>  
<td>  
<table style="width: 100%;" cellspacing="0" cellpadding="0">  
<tbody>  
<tr>  
<td style="border-top: 1px solid #c5c5c5;">  
<p><span style="text-align: left; font-size: 12px; margin-left: 10px; display: ##displayNote##;"><span style="font-weight: bold;"> Note:</span>When delivery is in cash, then it is not included in the Total Order Amount.</span></p>  
</td>  
<td style="border-top: 1px solid #c5c5c5;">  
<p style="font-size: 16px; margin: 10px 8px; text-align: right; font-weight: bold;">Remaining Amount</p>  
</td>  
<td style="border-top: 1px solid #c5c5c5; width: 170px; padding-right: 105px;">  
<p style="font-size: 16px; margin: 10px 0; text-align: right; font-weight: bold;">##remainingAmount##</p>  
</td>  
</tr>  
</tbody>  
</table>  
</td>  
</tr>  
</tbody>  
</table>  
</div>  
</div>  
</div>  
<div class="remarks" style="padding: 0 10px; display: ##displayRemarkSection##;">  
<div style="margin: 15px 0 0; font-size: 0; width: 100%; background: #ffffff; overflow: hidden; color: #191919; border: 1px solid #e3e3e3; box-sizing: border-box;">  
<div style="box-sizing: border-box; font-size: 0;">  
<div style="padding: 8px 10px; border-bottom: 1px solid #b5b5b5;">  
<h3 style="margin: 0; font-size: 14px; color: #191919;">Customer Remarks</h3>  
</div>  
<div>##orderRemark##</div>  
</div>  
</div>  
</div>  
</div>  
<div class="step7" style="padding: 0 10px;">  
<div style="margin: 15px 0 0; font-size: 0; width: 100%; background: #ffffff; overflow: hidden; color: #191919; border: 1px solid #e3e3e3; box-sizing: border-box;">  
<div style="box-sizing: border-box; font-size: 0;">  
<div style="padding: 8px 10px; border-bottom: 1px solid #b5b5b5;">  
<h3 style="margin: 0; font-size: 14px; color: #191919;">Bank Details</h3>  
</div>  
<div style="display: inline-block; width: 25%; text-align: center; border-left: 1px solid #f1f2f3; box-sizing: border-box;">  
<div style="border-bottom: 1px solid #f1f2f3;">  
<p style="margin: 8px 0;">Bank Name</p>  
</div>  
<div>  
<p style="margin: 8px 0; font-weight: 600;">##bankName##</p>  
</div>  
</div>  
<div style="display: inline-block; width: 25%; text-align: center; border-left: 1px solid #f1f2f3; box-sizing: border-box;">  
<div style="border-bottom: 1px solid #f1f2f3;">  
<p style="margin: 8px 0;">Account No</p>  
</div>  
<div>  
<p style="margin: 8px 0; font-weight: 600;">##accountNo##</p>  
</div>  
</div>  
<div style="display: inline-block; width: 25%; text-align: center; border-left: 1px solid #f1f2f3; box-sizing: border-box;">  
<div style="border-bottom: 1px solid #f1f2f3;">  
<p style="margin: 8px 0;">IFSC CODE</p>  
</div>  
<div>  
<p style="margin: 8px 0; font-weight: 600;">##ifsc##</p>  
</div>  
</div>  
<div style="display: inline-block; width: 25%; text-align: center; border-left: 1px solid #f1f2f3; box-sizing: border-box;">  
<div style="border-bottom: 1px solid #f1f2f3;">  
<p style="margin: 8px 0;">Branch Name</p>  
</div>  
<div>  
<p style="margin: 8px 0; font-weight: 600;">##branchName##</p>  
</div>  
</div>  
</div>  
</div>  
</div>  
</div>  
<div style="box-sizing: border-box; width: 100%; margin: auto; overflow: hidden; color: #191919; background: #ebebeb; border-top: 0; border-bottom: 0; padding: 10px 0 0; clear: both;">  
<div style="text-align: center; width: 280px; height: auto; overflow: hidden; margin: auto; page-break-inside: always;"><img style="width: 280px; height: auto; object-fit: contain;" src="##QRcode##" alt="QR Code" /></div>  
</div>  
<div style="width: 100%; margin: auto; font-family: ''Lato'', sans-serif; font-size: 14px; overflow: hidden; color: #191919; background: #ebebeb; border-top: 0; padding: 10px 0 0; box-sizing: border-box;">  
<div class="step9" style="padding: 0 10px;">  
<div style="background: #ffffff;">  
<div style="margin: 0; padding: 8px 10px; border-bottom: 1px solid #f1f2f3;">  
<h3 style="margin: 0; font-size: 11px; color: #191919;">TERMS &amp; CONDITIONS</h3>  
</div>  
<div style="color: #191919; border-bottom: 2px solid #f1f2f3;">  
<p style="font-size: 11px; margin: 0; padding: 3px 10px; font-weight: 600; background: #d9534f; color: #ffffff; border-bottom: 2px solid #f1f2f3;">1. Teams and Conditions comes here.. [Important]</p>  
<p style="font-size: 11px; margin: 0; padding: 3px 10px; font-weight: 600; border-bottom: 2px solid #f1f2f3;">2. Teams and Conditions comes here..</p>  
<p style="font-size: 11px; margin: 0; padding: 3px 10px; font-weight: 600; border-bottom: 2px solid #f1f2f3;">3. Teams and Conditions comes here..</p>
</div>  
</div>  
</div>  
<div class="step10" style="padding: 0 10px; border-top: 1px solid #d5d5d5;">  
<div style="text-align: center; padding: 10px; font-weight: 500; font-size: 12px; color: #191919; letter-spacing: 0;">Powered by: <a style="white-space: nowrap; display: inline-block; text-decoration: none; color: #191919; font-weight: bold;" href="https











://tanyo.in/" target="_blank" rel="noopener"> TANYO </a></div>  
</div>  
</div>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'OrderDispatch PDF'
						AND ec1.TenantID = @TenantId
					)
				,'OrderDispatch PDF'
				,
				'<div style="width: 1200px; margin: auto; border: 1px solid #3e3e3e; background: #ebebeb; box-sizing: border-box;">
				<div class="step1" style="box-sizing: border-box; border-bottom: 1px solid #b5b5b5;">
				<div style="width: 85%; display: inline-block; float: left; box-sizing: border-box; height: 112px; border-right: 1px solid #b5b5b5; text-align: center;">
				<div>
				<h3 style="margin: 0; font-size: 22px; color: #3e3e3e; text-transform: uppercase; padding: 8px 0; border-bottom: 1px solid #b5b5b5;">##tenantName##</h3>
				<p style="margin: 0; padding: 8px 0; border-bottom: 1px solid #b5b5b5;">##tenantAddress##</p>
				<p style="margin: 0; padding: 8px 0;"><strong>Phone:</strong> ##phoneNumber## | <strong>Email:</strong> ##emailId## | <strong>GST:</strong> ##GSTNo##</p>
				</div>
				</div>
				<div style="height: 112px; width: 15%; display: inline-block; padding: 15px 0 0; box-sizing: border-box; font-size: 0; text-align: center;"><a style="width: 80px; height: 80px; margin: auto; display: inline-block; vertical-align: middle; background: #3e3e3e; padding: 5px; border-radius: 10px; box-sizing: border-box;" href="#" target="_blank" rel="noopener"> <img style="width: 100%; height: 100%;" src="##tenantLogoPath##" alt="##tenantName##" /> </a></div>
				</div>
				<div class="step2" style="margin: 10px; background: #ffffff; overflow: hidden; height: 43px;"><span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Your Order ID:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##orderNo##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Order Status:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##orderStatus##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Order Date:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##orderDate##</span> </span> <span style="width: 300px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Salesman:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##salesmanNameAndPhoneNumber##</span> </span></div>
				<div class="step3" style="margin: 10px 10px 0; background: #ffffff; overflow: hidden; height: 43px;"><span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Customer Name</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##customerName##</span> </span> <span style="width: 250px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Mobile Number:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##customerPhone##</span> </span> <span style="width: 500px; display: inline-block; background: #ffffff; padding: 5px 10px;"> <span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Email Address:</span> <span style="font-size: 14px; color: #191919; font-weight: bold; line-height: 100%; margin: 0;">##customerEmail##</span> </span></div>
				<div class="step4" style="letter-spacing: 0px; font-size: 0px; margin: 10px 10px 0px; overflow: hidden;"><span style="display: inline-block; width: 49%; overflow: hidden; background: #ffffff; border: 1px solid #e3e3e3; vertical-align: top; min-height: 106px;"> <span style="color: #191919; margin: 0; font-size: 14px; border-bottom: 1px solid #f1f2f3; padding: 8px 10px; display: block;"> Shipping Address </span> <span style="margin: 0; font-size: 12px; line-height: 150%; padding: 10px 10px 10px; height: 60px; display: block;"> ##orderShippingAddress## </span> </span> <span style="display: inline-block; width: 49%; margin-left: 19px; overflow: hidden; background: #ffffff; border: 1px solid #e3e3e3; vertical-align: top; height: 106px;"> <span style="color: #191919; font-size: 14px; border-bottom: 1px solid #f1f2f3; padding: 8px 10px; display: block; text-align: center;"><strong> DELIVERY CHALLAN </strong></span> <span style="margin: 0; font-size: 12px; line-height: 150%; padding: 40px 10px 10px; display: block;"> <a style="margin-right: 25px;">Challan Number:____________________</a> <a>Challan Date:____________________</a> </span> </span></div>
				&nbsp; &nbsp; ##orderSetAndProductDetails##
				<div style="box-sizing: border-box; width: 100%; margin: auto; clear: both;">
				<div class="step6" style="padding: 0 8px 0 10px; box-sizing: border-box; margin: 10px 0; clear: both;">
				<div style="font-size: 0; overflow: hidden; color: #191919; box-sizing: border-box; border-bottom: 0;">
				<div style="box-sizing: border-box; border-bottom: 0;">&nbsp;</div>
				</div>
				</div>
				<div class="step7" style="padding: 0 10px;">
				<div style="margin: 15px 0 0; font-size: 0; width: 100%; background: #ffffff; overflow: hidden; color: #191919; border: 1px solid #e3e3e3; box-sizing: border-box;">
				<div style="box-sizing: border-box; font-size: 0;">&nbsp;</div>
				</div>
				</div>
				</div>
				<div style="box-sizing: border-box; width: 100%; margin: auto; overflow: hidden; color: #191919; background: #ebebeb; border-top: 0; border-bottom: 0; padding: 10px 0 0; clear: both;">
				<div style="text-align: center; width: 280px; height: auto; overflow: hidden; margin: auto; page-break-inside: always;">&nbsp;</div>
				</div>
				<div style="padding: 10px; font-weight: 500; font-size: 12px; color: #191919; letter-spacing: 0;"><a>Supervisor Signature: ________________________</a><a style="margin-left: 80px;">Gatekeeper Signature: _______________________</a><a style="margin-left: 80px;">Customer Signature:___________________</a></div>
				<div style="width: 100%; margin: auto; font-family: ''Lato'', sans-serif; font-size: 14px; overflow: hidden; color: #191919; background: #ebebeb; border-top: 0; padding: 10px 0 0; box-sizing: border-box;">
				<div class="step10" style="padding: 0 10px; border-top: 1px solid #d5d5d5;">
				<div style="text-align: center; padding: 10px; font-weight: 500; font-size: 12px; color: #191919; letter-spacing: 0;">Powered by: <a style="white-space: nowrap; display: inline-block; text-decoration: none; color: #191919; font-weight: bold;" href="https://tanyo.in/" target="_blank" rel="noopener"> TANYO ERP </a></div>
				</div>
				</div>
				</div>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Product Cost Analyzer'
						AND ec1.TenantID = @TenantId
					)
				,'Product Cost Analyzer'
				,
				'<table          style="width: 1000px;margin: auto;font-size: 14px;color: #212529;background: #ebebeb;padding: 10px 10px 0;border: 1px solid #3e3e3e;font-family: ''Lato'', sans-serif;"           cellspacing="0" cellpadding="0">           
     <tr>                
      <td style="text-align: center;padding: 10px 20px 20px;">                    
       <div style="width: 90%;margin: auto;">                       
        <a href="" target="_blank" style="width: 50px;height: 50px;margin: auto;display: inline-block;vertical-align: middle;background: #3e3e3e;                      padding: 5px;border-radius: 10px;box-sizing: border-box;"

>                     
        <img src="##TenantLogo##"                              alt="" style="width: 100%;height: 100%;">             
        </a>              
        <div style="display: inline-block;vertical-align: middle;margin-left: 8px;">                           
        <h3 style="margin: 0;font-size: 18px;color: #3e3e3e;text-transform: uppercase;">                              ##TenantName##                          </h3>                        
        </div>              
        </div>              
        </td>         
        </tr>         
        <tr>            
        <td>               
        <table style="width: 100%;margin-bottom: 20px;" cellspacing="0" cellpadding="0">         
        <tr>                      
        <td style="vertical-align: top;">             
        <div style="border: 1px solid #b5b5b5;display: table;clear: both;background: #ffffff;">          
        <div style="float: left;width: 170px;height: 170px;">             
        <img src="##ProductCoverImage##" alt="chair" style="width: 100%; height: 100%;object-fit: cover;">      
        </div>              
        <div style="float: left;width: 365px;vertical-align: top;">                
        <div style="font-size: 17px;padding-left: 10px;padding-bottom: 8px;padding-top: 8px;font-weight: 600;background-color: #dfdfdf;">                                          ##ProductTitle##                                    
        </div>           
        <div  style="padding-top: 10px;padding-bottom: 10px;padding-right: 10px;font-size: 14px; font-weight: 600;   padding-left: 10px;">      
        Category : <span style="font-weight: 500;">##CategoryName##</span>     
        </div>                   
        <div     style="padding-top: 10px;padding-bottom: 10px;padding-right: 10px;font-size: 14px; padding-left: 10px;font-weight: 600;">      
        Model : <span style="font-weight: 500;">##ModelNo##</span>     
        </div>       
        <div  style="padding-top: 10px;padding-bottom: 10px;padding-right: 10px;font-size: 14px;    padding-left: 10px;font-weight: 600;display:##displayHWD##">          ##Width##  &times;  ##Height##  &times; ##Depth##<span style="font-size: 12px;font-w















eight: 500;">  
        (inches )</span></div>                  
        </div>                     
        </div>                      
        </td>                      
        <td style="width: 40%;border: 1px solid #b5b5b5;background: #ffffff;vertical-align: top;">      
        <table style="width: 100%;" cellspacing="0" cellpadding="0">     
        <tr>               
        <td style="font-size: 17px;padding-left: 10px;padding-bottom: 8px;padding-top: 8px;font-weight: 600;background-color: #dfdfdf;">                                          Total Price                         
        </td>                       
        </tr>                    
        <tr>                          
        <td>                             
        <table style="width: 100%;border-top: 1px solid #b5b5b5;text-align: right;" cellspacing="0" cellpadding="0">       
        <tr>           
        <td  style="border-bottom: 2px dashed #d0d0d0;padding-top: 12px;padding-bottom: 13px;width: 60%;padding-right: 10px;font-size: 14px;text-align: right;">   
        CostPrice                       
        </td>              
        <td   style="border-bottom: 2px dashed #d0d0d0;padding-top: 5px;padding-bottom: 5px;padding-right: 10px;width: 40%;font-weight: 600;">         
        &#8377 ##CostPrice##                       
        </td>     
        </tr>             
        <tr>             
        <td                        
        style="border-bottom: 2px dashed #d0d0d0;padding-top: 13px;padding-bottom: 13px;width: 60%;padding-right: 10px;font-size: 14px;">                                             
        Retailers Price        
        </td>                                  
        <td     
        style="border-bottom: 2px dashed #d0d0d0;padding-top: 5px;padding-bottom: 5px;padding-right: 10px;width: 40%;font-weight: 600;">                                                      &#8377 ##RetailerPrice##                                        









         </td>                                              </tr>                                      
        <tr>                          
        <td   style="padding-top: 13px;padding-bottom: 13px;width: 60%;padding-right: 10px;font-size: 14px;">                                                      Wholesalers Price    
        </td>         
        <td  style="padding-top: 5px;padding-bottom: 5px;padding-right: 10px;width: 40%;font-weight: 600;">                                                      &#8377 ##WholesalerPrice##     
        </td>                    
        </tr>                  
        </table>     
        </td>            
        </tr>             
        </table>             
        </td>          
        </tr>        
        </table>      
        </td>      
        </tr>        
        <tr>      
        <td style="text-align: start;font-weight: 600;font-size: 16px;color: #191919; display: ##rawMaterialDisplay##">        
        Cost Of Raw Materials        
        </td>         
        </tr>     
        <tr>         
        <td>        
        <table style="width: 100%;margin-top: 10px;" cellspacing="0" cellpadding="0">         
        <tr>                   
        <td style="vertical-align: top;">             
        <table style="width: 100%;" cellspacing="0" cellpadding="0">  
        <tr>                                    
        <td>                  
        <table style="width: 100%;background: #ffffff;border-right: 1px solid #b5b5b5;border-left: 1px solid #b5b5b5; display: ##rawMaterialDisplay##"                                              cellspacing="0" cellpadding="0">        
        <tr>                                      
        <td  style="width:40%;   padding-top: 5px;padding-left: 10px;padding-bottom: 5px;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; font-size: 12px; background-color: #dfdfdf;">                 
        Raw Materials          
        </td>            
        <td      style="width:15%;   text-align: center;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf;">           





                                     Unit                                  
        </td>             
        <td   style="width:15%;   text-align: center;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf;">             











                                        Unit Price          
        </td>       
        <td  style="width:15%;   text-align: center;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf;">              



 

                                       Quantity                               
        </td>                    
        <td   style="width:15%;   text-align: right;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; font-size: 12px; background-color: #dfdfdf;padding-right: 10px;">      





                                                Cost Price                                
        </td>       
          
        </tr>        
        ##RawMaterialTable##               
        </table>                      
        <h3 style="margin: 5px 0 0; padding: 10px 0; display: ##polishDisplay##;">                                              Cost of Polish</h3>                                   
        <table style="width: 100%;background: #ffffff; display: ##polishDisplay##;border-right: 1px solid #b5b5b5;border-left: 1px solid #b5b5b5;"                                              cellspacing="0" cellpadding="0">                               





               <tr>                                   
        <td  style="width: 40%; padding-top: 5px;padding-left: 10px;padding-bottom: 5px;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; font-size: 12px; background-color: #dfdfdf;">                                                      Poli





sh                                                  </td>                                               
        <td   style="width: 15%; text-align: center;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf;">               





                                       Unit                                                  </td>        
          
        <td  style="width: 15%; text-align: center;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf;">                





                                      Unit Price                                                  </td>                                                  <td                                                      style="width: 15%; text-align: center;padding





-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf;">                                                      Quantity            





                                      </td>                                     
        <td  style="width: 15%; text-align: right;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; width: 15%;font-size: 12px; background-color: #dfdfdf; padding-right: 10p





x;">                                                      Cost Price                                             
        </td>                              
        </tr> ##polishTable##        
        </table>            
        <h3 style="margin: 5px 0 0; padding: 10px 0;display: ##labourMaterials##;">     
        Labour Charges</h3>           
        <table     style="width: 100%;background: #ffffff;border-right: 1px solid #b5b5b5;border-left: 1px solid #b5b5b5; display: ##labourMaterials##;"                                              cellspacing="0" cellpadding="0">                         





                     <tr>                                    
        <td  style="width: 70%; padding-top: 5px;padding-left: 10px;padding-bottom: 5px;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5; font-size: 12px;background-color: #dfdfdf;">         
        Labour Charges  </td>       
        <td    style="width: 30%;text-align: right;padding-top: 5px;padding-bottom: 5px;border-left: 1px solid #b5b5b5;border-bottom: 1px solid #b5b5b5;border-top: 1px solid #b5b5b5;font-size: 12px;background-color: #dfdfdf;padding-right: 10px;">        



 

                                             Amount                                         
        </td>   
        </tr>  ##labourMaterialsTable##                   
        </table>                      
        </td>          
        </tr>             
        </table>          
        </td>             
        </tr>                
        </table>          
        </td>         
        </tr>          
        <tr>        
        <td style="text-align: center;padding: 10px;font-weight: 500;font-size: 12px;color: #191919;">         
        Powered by:                
        <a href="https://tanyo.in/" target="_blank"  style="display: inline-block;text-decoration: none;color: #191919;font-weight: bold;">                      TANYO            
        </a>            
        </td>           
        </tr>       
        </table>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE Upper(ec1.KeyName) = 'WELCOME EMAIL'
						AND ec1.TenantID = @TenantId
					)
				,'Welcome to Tanyo'
				,
				'<html><head><title>Welcome to Tanyo</title></head><body style="font-family:poppins,sans-serif;background-color:#f4f4f4;margin:0;padding:0"><div style="background-color:#fff;max-width:600px;margin:10px auto;border-radius:8px;box-shadow:0 0 10px rgba(0





,0,0,.1);overflow:hidden"><div style="text-align:center;padding:20px;width:auto;height:60px"><img src="https://tanyo.in/images/logo_tanyo_crm.png" alt="Tanyo Logo" style="margin-bottom:10px;height:100%;width:100%;object-fit:contain"></div><div style="padd





ing:20px;text-align:center"><p style="margin:0;color:#333">Dear {{UserName}},</p><p style="color:#333">We are excited to welcome you to the Tanyo family! We believe you''ll have a great time working with us.</p><div style="background-color:#f4f4f4;border-





radius:8px;padding:15px;margin:20px 0;text-align:left"><p style="margin:0 0 10px;font-size:13px;font-weight:600">Your Role & Details:</p><p style="margin:5px 0"><span style="width:120px;display:inline-block;font-size:13px;font-weight:600">Position/Role</s





pan>: {{Position}}</p><p style="margin:5px 0"><span style="width:120px;display:inline-block;font-size:13px;font-weight:600">Email</span>: {{UserEmail}}</p></div><div style="background-color:#f4f4f4;border-radius:8px;padding:15px;margin:20px 0;text-align:l





eft"><p style="margin:0 0 10px;font-size:13px;font-weight:600">Welcome Message:</p><p style="margin:5px 0;font-size:13px">{{WelcomeMessage}}</p></div><p style="color:#333">We are looking forward to accomplishing great things together. If you have any ques





tions or need assistance, don''t hesitate to reach out to us at <b>support@tanyo.in</b>.</p></div><div style="padding:20px;text-align:center;color:#888;font-size:12px"><p style="margin:0">Best Regards,</p><p style="font-weight:600;font-size:16px;color:#00





0;margin:5px 0 0">Tanyo Team</p></div></div></body></html>'
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT (
					SELECT TOP 1 ec1.EmailCMSID
					FROM EmailCMS ec1
					WHERE ec1.KeyName = 'Stock Transfer PDF'
						AND ec1.TenantID = @TenantId
					)
				,'Stock Transfer PDF'
				,
				'<div style="width: 1200px; margin: auto; border: 1px solid #3e3e3e; background: #ebebeb; box-sizing: border-box;">  <div style="box-sizing: border-box; border-bottom: 1px solid #b5b5b5; overflow: hidden;">  <div style="width: 85%; float: left; box-sizing: border-box; height: 112px; border-right: 1px solid #b5b5b5; text-align: center;">  <h3 style="margin: 0; font-size: 22px; color: #3e3e3e; text-transform: uppercase; padding: 8px 0; border-bottom: 1px solid #b5b5b5;">##tenantName##</h3>  <p style="margin: 0; padding: 8px 0; border-bottom: 1px solid #b5b5b5;">##tenantAddress##</p>  <p style="margin: 0; padding: 8px 0;"><strong>Phone:</strong> ##tenantPhone## | <strong>Email:</strong> ##tenantEmail## | <strong>GST:</strong> ##tenantGSTNo##</p>  </div>  <div style="width: 15%; float: left; height: 112px; padding: 15px 0 0; box-sizing: border-box; text-align: center;">##tenantLogoHtml##</div>  </div>  <div style="margin: 10px; overflow: hidden; border: 1px solid #b5b5b5; box-sizing: border-box;">  <div style="background: #ffffff; box-sizing: border-box; overflow: hidden; font-size: 0;"><span style="width: 25%; display: inline-block; background: #ffffff; padding: 8px 14px; border-right: 1px solid #b5b5b5; vertical-align: top; box-sizing: border-box;"><span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Transfer Date:</span><span style="font-size: 14px; color: #191919; font-weight: bold; display: block;">##transferDate##</span></span> <span style="width: 25%; display: inline-block; background: #ffffff; padding: 8px 14px; border-right: 1px solid #b5b5b5; vertical-align: top; box-sizing: border-box;"><span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">Transferred By:</span><span style="font-size: 14px; color: #191919; font-weight: bold; display: block;">##transferredBy##</span></span> <span style="width: 25%; display: inline-block; background: #ffffff; padding: 8px 14px; border-right: 1px solid #b5b5b5; vertical-align: top; box-sizing: border-box;"><span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">From Warehouse:</span><span style="font-size: 14px; color: #191919; font-weight: bold; display: block;">##fromWarehouse##</span></span> <span style="width: 25%; display: inline-block; background: #ffffff; padding: 8px 14px; vertical-align: top; box-sizing: border-box;"><span style="font-size: 12px; margin: 0 0 4px; font-weight: 500; color: #3e3e3e; display: block;">To Warehouse:</span><span style="font-size: 14px; color: #191919; font-weight: bold; display: block;">##toWarehouse##</span></span></div>  </div>  <div style="margin: 0 10px 10px; overflow: hidden;">  <table style="width: 100%; background: #ffffff; border: 1px solid #b5b5b5; border-collapse: collapse; box-sizing: border-box;">  <tbody>  <tr>  <td style="padding: 8px 12px; font-size: 14px; color: #191919; font-weight: bold; letter-spacing: 2px; text-transform: uppercase; width: 35%; text-align: left; vertical-align: middle;">Stock Transfer Challan</td>  <td style="padding: 8px 12px; font-size: 14px; color: #191919; font-weight: bold; letter-spacing: 2px; text-transform: uppercase; width: 35%; text-align: center; vertical-align: middle;">Stock Transfer No: ##stockTransferNo##</td>  <td style="padding: 8px 12px; width: 30%;">&nbsp;</td>  </tr>  </tbody>  </table>  </div>  ##productTable##  <div style="clear: both; margin: 10px 10px 0; overflow: hidden;">  <div style="background: #ffffff; border: 1px solid #b5b5b5; box-sizing: border-box; min-height: 80px;">  <div style="font-size: 13px; color: #191919; font-weight: 500; padding: 8px 12px; border-bottom: 1px solid #e3e3e3;">Remarks / Notes</div>  <div style="font-size: 13px; color: #191919; line-height: 170%; padding: 10px 12px; min-height: 50px;">##remarks##</div>  </div>  </div>  <div style="clear: both; margin: 8px 10px 0; overflow: hidden; text-align: right;"><span style="display: inline-block; font-size: 12px; font-weight: 500; color: #191919; letter-spacing: 0; padding: 6px 0;">Authorized Signature: ________________________</span></div>  <div style="clear: both; height: 6px;">&nbsp;</div>  <div style="border-top: 1px solid #d5d5d5; clear: both;">  <div style="text-align: center; padding: 10px; font-weight: 500; font-size: 12px; color: #191919; letter-spacing: 0;">Powered by: <a style="white-space: nowrap; display: inline-block; text-decoration: none; color: #191919; font-weight: bold;" href="https://tanyo.in/" target="_blank" rel="noopener">TANYO ERP</a></div>  </div>  </div>  <p>```</p>'
				,@TenantId
				,@UserId

			PRINT 'Email CMS Details Created Successfully'

			INSERT INTO TenantReminderSettings (
				TenantID
				,ReminderType
				,ReminderDays
				,Position
				,CreatedBy
				)
			SELECT @TenantId
				,'Customer Order Inquiry'
				,3
				,1
				,@UserId
			
			UNION ALL
			
			SELECT @TenantId
				,'Customer Order Inquiry'
				,5
				,2
				,@UserId
			
			UNION ALL
			
			SELECT @TenantId
				,'Customer Order Inquiry'
				,7
				,3
				,@UserId
			
			UNION ALL
			
			SELECT @TenantId
				,'Salesman Order Delivery'
				,3
				,1
				,@UserId
			
			UNION ALL
			
			SELECT @TenantId
				,'Salesman Order Delivery'
				,5
				,2
				,@UserId
			
			UNION ALL
			
			SELECT @TenantId
				,'Salesman Order Delivery'
				,7
				,3
				,@UserId

			PRINT 'Reminder Details Created Successfully'

			INSERT INTO TenantWhatsAppDetails (
				TenantID
				,BaseURL
				,APIVersion
				,PhoneNumberID
				,AccessToken
				,BusinessAccountID
				,AppID
				,CreatedBy
				)
			SELECT @TenantId
				,''
				,''
				,''
				,''
				,''
				,''
				,@UserId

			PRINT 'WhatsApp Details Created Successfully'

			INSERT INTO TenantSMTPDetails (
				TenantID
				,FromEmail
				,Username
				,Password
				,SMTPServer
				,SMTPPort
				,EnableSSL
				,TargetName
				,CreatedBy
				)
			SELECT @TenantId
				,''
				,''
				,''
				,''
				,''
				,''
				,NULL
				,@UserId

			--SELECT @TenantId  
			-- ,'no-reply@tanyo.in'  
			-- ,'magnusminds-smtp'  
			-- ,'vE2sV1lJ8oY4fS2jE7vW1uT8gF5l'  
			-- ,'mail.smtp2go.com'  
			-- ,'587'  
			-- ,'1'  
			-- ,'STARTTLS/mail.smtp2go.com'  
			-- ,@UserId  
			PRINT 'SMTP Details Created Successfully'

			INSERT INTO ManufacturingWorkflows (
				WorkflowName
				,TenantId
				,IsDeleted
				,CreatedBy
				,SendPushNotification
				)
			SELECT 'Framing' AS WorkflowName
				,@TenantId AS TenantId
				,0 AS IsDeleted
				,1 AS CreatedBy
				,1 AS SendPushNotification
			
			UNION ALL
			
			SELECT 'Cushioning'
				,@TenantId
				,0
				,1
				,1
			
			UNION ALL
			
			SELECT 'Polishing'
				,@TenantId
				,0
				,1
				,1
			
			UNION ALL
			
			SELECT 'Packaging'
				,@TenantId
				,0
				,1
				,1
			
			UNION ALL
			
			SELECT 'Dispatch'
				,@TenantId
				,0
				,1
				,1

			PRINT 'Workflows Created Successfully'

			INSERT INTO Categories (
				CategoryTypeId
				,CategoryName
				,IsFixedPrice
				,RSPPercentage
				,WSPPercentage
				,TenantId
				,IsDeleted
				,CreatedBy
				,IsManufacturing
				,IsVisibleInAddOn
				,GST
				,MaxDiscount
				)
			SELECT 1
				,'Sofa'
				,1
				,100
				,50
				,@TenantId
				,0
				,1
				,0
				,0
				,18
				,25
			
			UNION ALL
			
			SELECT 1
				,'Center Table'
				,0
				,100
				,50
				,@TenantId
				,0
				,1
				,1
				,0
				,18
				,25
			
			UNION ALL
			
			SELECT 1
				,'Dining Table'
				,1
				,100
				,50
				,@TenantId
				,0
				,1
				,0
				,0
				,18
				,25

			PRINT 'Categories Created Successfully'

			DECLARE @LookupId BIGINT

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'Unit'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,IsDeleted
				,CreatedBy
				)
			SELECT @LookupId
				,'inch'
				,0
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'feet'
				,0
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'meter'
				,0
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'centimeter'
				,0
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'liter'
				,0
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'kg'
				,0
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'InquiryClosingReasons'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Buy From Other Shop'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Not Interested'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Not Required'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Price is too high'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Quality not good'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Inquiry has been created'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'BackInquiryClosingReasons'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Buy from other vendor'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Client cancelled order'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Product discontinued'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Price is too high as compare another vendor'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Product quality not good'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Switched to another product'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Other'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'Profession'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Job'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Entrepreneur'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Doctor'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Engineer'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Architect'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Teacher'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Student'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Homemaker'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Business Owner'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Government Employee'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Retired'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'LeadSources'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Facebook'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'WhatsApp'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Twitter'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Instagram'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Friends & Family'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'SpecializedIn'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Resident'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Office'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Factory'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'PurchaseUrgency'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Today'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'This Week'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'This Month'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Just Checking'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'CustomerBehavior'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'In a hurry'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Time-pass'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Serious buyer'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Needs family approval'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Needs Architect approval'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Confused but trying'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Revisit planned'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'BuyingRange'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Below ₹10,000'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'₹10,000 – ₹50,000'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'₹50,000 – ₹1,00,000'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'₹1,00,000 – ₹5,00,000'
				,1
			
			UNION ALL
			
			SELECT @LookupId
				,'Above ₹5,00,000'
				,1

			SELECT @LookupId = 0

			SELECT @LookupId = LookupId
			FROM Lookups
			WHERE TenantId = @TenantId
				AND LookupName = 'ProductCustomLabel'

			INSERT INTO LookupValues (
				LookupId
				,LookupValueName
				,CreatedBy
				)
			SELECT @LookupId
				,'Warranty'
				,1

			PRINT 'LookupValues Created Successfully'

			INSERT INTO Companies (
				CompanyName
				,RSPPercentage
				,WSPPercentage
				,MaxDiscount
				,TenantId
				,IsDeleted
				,CreatedBy
				)
			SELECT 'Green Ply'
				,100
				,50
				,10
				,@TenantId
				,0
				,1
			
			UNION ALL
			
			SELECT 'Asian Paint'
				,100
				,50
				,10
				,@TenantId
				,0
				,1
			
			UNION ALL
			
			SELECT 'PROCUST'
				,0
				,0
				,0
				,@TenantId
				,0
				,1

			PRINT 'Companies Created Successfully'

			INSERT INTO Fabrics (
				Title
				,ModelNo
				,CompanyId
				,UnitId
				,UnitPrice
				,TenantId
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,GST
				)
			SELECT 'PROCUST'
				,'PROCUST'
				,(
					SELECT CompanyId
					FROM Companies
					WHERE CompanyName = 'PROCUST'
						AND TenantId = @TenantId
					)
				,(
					SELECT LookupValueId
					FROM LookupValues
					WHERE LookupValueName = 'meter'
						AND LookupId = (
							SELECT LookupId
							FROM Lookups
							WHERE TenantId = @TenantId
								AND LookupName = 'Unit'
							)
					)
				,0
				,@TenantId
				,1
				,@Date
				,@DateUTC
				,0

			PRINT 'Fabrics Created Successfully'

			INSERT INTO Polish (
				Title
				,ModelNo
				,CompanyId
				,UnitId
				,UnitPrice
				,TenantId
				,CreatedBy
				)
			SELECT 'PU Matt with Mixing'
				,'PUMMAX'
				,(
					SELECT CompanyId
					FROM Companies
					WHERE TenantId = @TenantId
						AND CompanyName = 'Asian Paint'
					)
				,(
					SELECT LookupValueId
					FROM LookupValues lv
					INNER JOIN Lookups l ON l.LookupId = lv.LookupId
					WHERE l.TenantId = @TenantId
						AND lv.LookupValueName = 'liter'
					)
				,250
				,@TenantId
				,1
			
			UNION ALL
			
			SELECT 'PU Sealer Mixing'
				,'PUSMIX'
				,(
					SELECT CompanyId
					FROM Companies
					WHERE TenantId = @TenantId
						AND CompanyName = 'Asian Paint'
					)
				,(
					SELECT LookupValueId
					FROM LookupValues lv
					INNER JOIN Lookups l ON l.LookupId = lv.LookupId
					WHERE l.TenantId = @TenantId
						AND lv.LookupValueName = 'liter'
					)
				,250
				,@TenantId
				,1

			PRINT 'Polish Created Successfully'

			INSERT INTO RawMaterials (
				Title
				,UnitId
				,UnitPrice
				,TenantId
				,CreatedBy
				)
			SELECT 'ASH WOOD'
				,(
					SELECT LookupValueId
					FROM LookupValues lv
					INNER JOIN Lookups l ON l.LookupId = lv.LookupId
					WHERE l.TenantId = @TenantId
						AND lv.LookupValueName = 'feet'
					)
				,3500
				,@TenantId
				,@UserId
			
			UNION ALL
			
			SELECT 'TEAK WOOD'
				,(
					SELECT LookupValueId
					FROM LookupValues lv
					INNER JOIN Lookups l ON l.LookupId = lv.LookupId
					WHERE l.TenantId = @TenantId
						AND lv.LookupValueName = 'feet'
					)
				,2500
				,@TenantId
				,@UserId

			PRINT 'Raw Materials Created Successfully'

			INSERT INTO RawMaterialInventory (
				RawMaterialId
				,InventoryDate
				,Inventory
				,MinimumLimit
				,LastModifiedBy
				,LastModifiedDate
				,LastModifiedUTCDate
				)
			SELECT RawMaterialId
				,CONVERT(DATE, @Date)
				,0
				,0
				,@UserId
				,SYSDATETIMEOFFSET()
				,@Date
			FROM RawMaterials
			WHERE Title IN (
					'ASH WOOD'
					,'TEAK WOOD'
					)
				AND TenantId = @TenantId

			--INSERT Product  
			INSERT INTO [dbo].[Products] (
				[CategoryId]
				,[ProductTitle]
				,[ModelNo]
				,[Width]
				,[Height]
				,[Depth]
				,[IsVisibleToWholesalers]
				,[CostPrice]
				,[RetailerPrice]
				,[WholesalerPrice]
				,[TenantId]
				,[Status]
				,[CreatedBy]
				,[CreatedDate]
				,[CreatedUTCDate]
				)
			SELECT CategoryId
				,'Sample Product with Cost Analyzer'
				,'LSC01'
				,1
				,1
				,1
				,0
				,1000
				,(1000 + (1000 * RSPPercentage / 100))
				,(1000 + (1000 * WSPPercentage / 100))
				,@TenantId
				,1
				,@UserId
				,SYSDATETIMEOFFSET()
				,@DateUTC
			FROM Categories
			WHERE CategoryName IN ('Center Table')
				AND TenantId = @TenantId
			
			UNION ALL
			
			SELECT CategoryId
				,'Sample Product with Fixed Price'
				,'SDT001'
				,1
				,1
				,1
				,0
				,17500
				,(17500 + (17500 * RSPPercentage / 100))
				,(17500 + (17500 * WSPPercentage / 100))
				,@TenantId
				,1
				,@UserId
				,SYSDATETIMEOFFSET()
				,@DateUTC
			FROM Categories
			WHERE CategoryName IN ('SOFA')
				AND TenantId = @TenantId

			--INSERT Product Quantities  
			INSERT INTO ProductQuantities (
				ProductId
				,QuantityDate
				,Quantity
				,LastModifiedBy
				,LastModifiedDate
				,LastModifiedUTCDate
				,MinimumLimit
				)
			SELECT ProductId
				,SYSDATETIMEOFFSET()
				,0
				,@UserId
				,SYSDATETIMEOFFSET()
				,@DateUTC
				,0
			FROM Products
			WHERE ModelNo IN (
					'LSC01'
					,'SDT001'
					)
				AND TenantId = @TenantId

			DECLARE @WarehouseID BIGINT

			INSERT INTO Warehouse (
				Name
				,TenantId
				,CreatedBy
				,QRCode
				,IsDefault
				)
			SELECT 'Other'
				,@TenantId
				,1
				,''
				,1

			SELECT @WarehouseID = SCOPE_IDENTITY()

			INSERT INTO ProductQuantitiesByWarehouse (
				ProductId
				,WarehouseId
				,Quantity
				,QuantityDate
				,LastModifiedBy
				)
			SELECT ProductId
				,@WarehouseID
				,0
				,CAST(GETDATE() AS DATE)
				,@UserId
			FROM Products
			WHERE ModelNo IN (
					'LSC01'
					,'SDT001'
					)
				AND TenantId = @TenantId

			--INSERT Product Materials   
			INSERT INTO ProductMaterials (
				ProductId
				,SubjectTypeId
				,SubjectId
				,Qty
				,CreatedBy
				,CreatedUTCDate
				)
			SELECT (
					SELECT TOP 1 ProductId
					FROM Products
					WHERE ModelNo IN ('SDT001')
						AND TenantId = @TenantId
					)
				,(
					SELECT TOP 1 SubjectTypeId
					FROM SubjectTypes
					WHERE SubjectTypeName = 'RawMaterials'
						AND TenantId = @TenantId
					)
				,(
					SELECT TOP 1 RawMaterialId
					FROM RawMaterials
					WHERE Title = 'ASH WOOD'
						AND TenantId = @TenantId
					)
				,5
				,@UserId
				,@DateUTC

			INSERT INTO OrderStatus
			VALUES (
				0
				,@TenantId
				,'Inquiry'
				,'Inquiry'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				1
				,@TenantId
				,'PendingForApproval'
				,'Pending For Approval'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				2
				,@TenantId
				,'Approved'
				,'Approved'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				3
				,@TenantId
				,'InProgress'
				,'InProgress'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				4
				,@TenantId
				,'Completed'
				,'Completed'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				5
				,@TenantId
				,'Delivered'
				,'Delivered'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				6
				,@TenantId
				,'Canceled'
				,'Canceled'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				7
				,@TenantId
				,'MaterialReceive'
				,'Material Receive'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				8
				,@TenantId
				,'Declined'
				,'Declined'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				9
				,@TenantId
				,'Delete'
				,'Delete'
				,'Order'
				)

			INSERT INTO OrderStatus
			VALUES (
				0
				,@TenantId
				,'ReadyToManufacturing'
				,'Ready To Manufacturing'
				,'OrderSetItem'
				)

			INSERT INTO OrderStatus
			VALUES (
				1
				,@TenantId
				,'Manufacturing'
				,'Manufacturing'
				,'OrderSetItem'
				)

			INSERT INTO OrderStatus
			VALUES (
				2
				,@TenantId
				,'ReadyToDelivered'
				,'Ready To Delivered'
				,'OrderSetItem'
				)

			INSERT INTO OrderStatus
			VALUES (
				3
				,@TenantId
				,'Delivered'
				,'Delivered'
				,'OrderSetItem'
				)

			INSERT INTO OrderStatus
			VALUES (
				0
				,@TenantId
				,'Pending'
				,'Pending'
				,'BackOrder'
				)
				,(
				1
				,@TenantId
				,'Accept'
				,'Accept'
				,'BackOrder'
				)
				,(
				2
				,@TenantId
				,'Rejected'
				,'Rejected'
				,'BackOrder'
				)
				,(
				3
				,@TenantId
				,'InProgress'
				,'InProgress'
				,'BackOrder'
				)
				,(
				4
				,@TenantId
				,'Cancelled'
				,'Cancelled'
				,'BackOrder'
				)
				,(
				5
				,@TenantId
				,'ReadyAtVendor'
				,'ReadyAtVendor'
				,'BackOrder'
				)
				,(
				6
				,@TenantId
				,'DeliveredToShowroom'
				,'DeliveredToShowroom'
				,'BackOrder'
				)
				,(
				7
				,@TenantId
				,'DeliveredToClient'
				,'DeliveredToClient'
				,'BackOrder'
				)
				,(
				9
				,@TenantId
				,'Delete'
				,'Delete'
				,'BackOrder'
				)

			INSERT INTO FeedbackQuestions (
				QuestionTitle
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				'Product Quality'
				,@TenantId
				,0
				,1
				,@Date
				,@DateUTC
				)

			INSERT INTO FeedbackQuestions (
				QuestionTitle
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				'Design Variety'
				,@TenantId
				,0
				,1
				,@Date
				,@DateUTC
				)

			INSERT INTO FeedbackQuestions (
				QuestionTitle
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				'Salesman Interaction'
				,@TenantId
				,0
				,1
				,@Date
				,@DateUTC
				)

			INSERT INTO FeedbackQuestions (
				QuestionTitle
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				'Pricing'
				,@TenantId
				,0
				,1
				,@Date
				,@DateUTC
				)

			INSERT INTO FeedbackQuestions (
				QuestionTitle
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				'Delivery'
				,@TenantId
				,0
				,1
				,@Date
				,@DateUTC
				)

			INSERT INTO TagType (
				TagTypeName
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,TenantId
				)
			VALUES (
				'Order'
				,0
				,@UserId
				,@Date
				,@DateUTC
				,@TenantId
				)

			INSERT INTO TagType (
				TagTypeName
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,TenantId
				)
			VALUES (
				'Customer'
				,0
				,@UserId
				,@Date
				,@DateUTC
				,@TenantId
				)

			INSERT INTO TagType (
				TagTypeName
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,TenantId
				)
			VALUES (
				'Interior'
				,0
				,@UserId
				,@Date
				,@DateUTC
				,@TenantId
				)

			INSERT INTO TagType (
				TagTypeName
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,TenantId
				)
			VALUES (
				'Dealer'
				,0
				,@UserId
				,@Date
				,@DateUTC
				,@TenantId
				)

			DECLARE @LocationID BIGINT

			INSERT INTO Locations (
				LocationName
				,TenantId
				,CreatedBy
				)
			VALUES (
				'Main'
				,@TenantId
				,@UserId
				)

			SELECT @LocationID = SCOPE_IDENTITY()

			INSERT INTO LocationUserMapping (
				LocationID
				,UserID
				,IsDefault
				)
			SELECT @LocationID
				,@UserId
				,1

			INSERT INTO [dbo].[TenantInvoiceFormatMapping] (
				[TenantId]
				,[InvoiceFormatId]
				,[TermsAndConditionsHtml]
				,[CreatedBy]
				,[CreatedDate]
				,[CreatedUTCDate]
				)
			SELECT TOP 1 @TenantId
				,InvoiceFormatId
				,'<p style="font-size: 13px; margin: 0; padding: 3px 10px; font-weight: 600; border-bottom: 2px solid #f1f2f3;">Terms and Conditions comes here..</p>
				 <p style="font-size: 13px; margin: 0; padding: 3px 10px; font-weight: 600; border-bottom: 2px solid #f1f2f3;">Terms and Conditions comes here..</p>
				 <p style="font-size: 13px; margin: 0; padding: 3px 10px; font-weight: 600; border-bottom: 2px solid #f1f2f3;">Terms and Conditions comes here..</p>'
				,@UserId
				,@DateOffset
				,@DateUTC
			FROM InvoiceFormat

			INSERT INTO [dbo].[TenantAppVersion] (
				[TenantId]
				,[DeviceType]
				,[AppVersion]
				,[IsForceUpdate]
				,[IsMaintenance]
				,[LastModifiedBy]
				,[LastModifiedDate]
				,[LastModifiedUTCDate]
				)
			SELECT TOP 1 @TenantId
				,'All'
				,[AppVersion]
				,[IsForceUpdate]
				,[IsMaintenance]
				,@UserId
				,@DateOffset
				,@DateUTC
			FROM TenantAppVersion
			WHERE [DeviceType] = 'All'
			ORDER BY TenantAppVersionId DESC
		END

		--ELSE  
		--BEGIN  
		-- PRINT 'TENANT ALREADY EXISTS.'  
		--END  
		SELECT *
		FROM dbo.Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId

		COMMIT TRAN SaveTenant
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN SaveTenant

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

