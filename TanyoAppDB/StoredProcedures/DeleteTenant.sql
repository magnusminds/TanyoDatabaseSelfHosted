/*
 EXEC DeleteTenant UserData
  @TenantId = 00000000000000000000000
  ,@Type = 1
*/
CREATE PROC [dbo].[DeleteTenant]
(
 @TenantId BIGINT
 ,@Type INT--2: Delete all, 1: Delete Products,0: delete Masters
)
WITH ENCRYPTION
AS
BEGIN
	-- OTP / Auth Cleanup
	DELETE FROM UserLoginHistory WHERE UserID IN (SELECT UserID FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
	DELETE FROM OTPLogin WHERE PhoneNumber IN (SELECT PhoneNumber FROM Customers WHERE TenantId = @TenantId UNION ALL SELECT PhoneNumber FROM AspNetUsers INNER JOIN UserTenantMapping ON AspNetUsers.UserId = UserTenantMapping.UserId WHERE UserTenantMapping.TenantId = @TenantId)

	-- Activity Logs
	DELETE FROM ActivityLogs WHERE SubjectTypeId IN (SELECT SubjectTypeId FROM SubjectTypes WHERE TenantId = @TenantId)

	-- Complains
	DELETE FROM ComplainAttachments WHERE ComplainId IN (SELECT ComplainId FROM Complains WHERE TenantId = @TenantId)
	DELETE FROM ComplainComments WHERE ComplainId IN (SELECT ComplainId FROM Complains WHERE TenantId = @TenantId)
	DELETE FROM ComplainRemarks WHERE ComplainId IN (SELECT ComplainId FROM Complains WHERE TenantId = @TenantId)
	DELETE FROM Complains WHERE TenantId = @TenantId

	-- Customers
	DELETE FROM CustomerAddresses WHERE CustomerId IN (SELECT CustomerId FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM CustomerVisits WHERE CustomerId IN (SELECT CustomerId FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM CustomerContacts WHERE CustomerId IN (SELECT CustomerId FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM CustomerRemarks WHERE CustomerId IN (SELECT CustomerId FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM CustomerImages WHERE CustomerId IN (SELECT CustomerId FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM CustomerFamily WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
	DELETE FROM CustomerTypes WHERE CustomerTypeId IN (SELECT CustomerTypeId FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM Customers WHERE TenantId = @TenantId

	-- Inquiries
	DELETE FROM InquiryComments WHERE InquiryId IN (SELECT InquiryId FROM Inquiries WHERE TenantId = @TenantId)
	DELETE FROM InquiryLogs WHERE InquiryId IN (SELECT InquiryId FROM Inquiries WHERE TenantId = @TenantId)
	DELETE FROM Inquiries WHERE TenantId = @TenantId
	DELETE FROM BackInquiriesItems WHERE BackInquiryId IN (SELECT BackInquiryId FROM BackInquiries WHERE TenantID = @TenantId)
	DELETE FROM BackInquiriesComments WHERE BackInquiryId IN (SELECT BackInquiryId FROM BackInquiries WHERE TenantID = @TenantId)
	DELETE FROM BackInquiries WHERE TenantID = @TenantId

	-- Manufacturing Workflows
	DELETE FROM ManufacturingActivityLogs WHERE ManufacturingWorkflowId IN (SELECT ManufacturingWorkflowId FROM ManufacturingWorkflows WHERE TenantId = @TenantId)
	DELETE FROM ManufacturingWorkflowMapping WHERE ManufacturingWorkflowId IN (SELECT ManufacturingWorkflowId FROM ManufacturingWorkflows WHERE TenantId = @TenantId)
	DELETE FROM ManufacturingWorkflowStockLog WHERE ManufacturingWorkflowId IN (SELECT ManufacturingWorkflowId FROM ManufacturingWorkflows WHERE TenantId = @TenantId)
	DELETE FROM ManufacturingWorkflowStock WHERE ManufacturingWorkflowId IN (SELECT ManufacturingWorkflowId FROM ManufacturingWorkflows WHERE TenantId = @TenantId)
	DELETE FROM ManufacturingWorkOrderDetailsLog WHERE ManufacturingWorkOrderDetailId IN (SELECT ManufacturingWorkOrderDetailId FROM ManufacturingWorkOrderDetails WHERE ManufacturingWorkOrderId IN (SELECT ManufacturingWorkOrderId FROM ManufacturingWorkOrders WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)));
	DELETE FROM ManufacturingWorkOrderDetails WHERE ManufacturingWorkOrderId IN (SELECT ManufacturingWorkOrderId FROM ManufacturingWorkOrders WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId ));	
	DELETE FROM ManufacturingWorkOrders WHERE OrderId IN (SELECT OrderId FROM Orders WHERE  TenantId = @TenantId )
	DELETE FROM ManufacturingWorkflows WHERE TenantId = @TenantId

	-- Notifications
	DELETE FROM BackOfficeNotificationReads WHERE NotificationId IN (SELECT NotificationId FROM Notifications WHERE TenantId = @TenantId)
	DELETE FROM BackOfficeNotifications WHERE NotificationId IN (SELECT NotificationId FROM Notifications WHERE TenantId = @TenantId)
	DELETE FROM NotificationManagement WHERE TenantId = @TenantId
	DELETE FROM Notifications WHERE TenantId = @TenantId
	DELETE FROM NotificationTemplate WHERE TenantId = @TenantId

	-- Orders
	DELETE FROM Payments WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM PaymentRazorPay WHERE TenantId = @TenantId
	DELETE FROM OrderAddresses WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderAnonymousViews WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderAttachments WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderComments WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderDeliveryDetails WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderArchiveDetails WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM FollowUpOrders WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderDeliveryDateMissing WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderFamily WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	--DELETE FROM OrderPaymentStatus WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderManufacturingWorkflowImages WHERE OrderManufacturingWorkflowId IN (SELECT OrderManufacturingWorkflowId FROM OrderManufacturingWorkflows WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId))
	DELETE FROM OrderManufacturingWorkflows WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderProductCharges WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderSetItemImages WHERE OrderSetItemId IN (SELECT OrderSetItemId FROM OrderSetItems WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId))
	DELETE FROM OrderSetItemReceivables WHERE OrderSetItemId IN (SELECT OrderSetItemId FROM OrderSetItems WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId))
	DELETE FROM OrderSetItems WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderSets WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderShortedURL WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM OrderTrack WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM WhatsAppComplaintLogs WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM WhatsAppComplaintFlows WHERE CustomerId IN (SELECT CustomerID FROM Customers WHERE TenantId = @TenantId)
	DELETE FROM WhatsAppDealerInquiryLogs WHERE TenantId = @TenantId
	DELETE FROM WhatsAppDealerInquiryFlows WHERE TenantId = @TenantId
	DELETE FROM Orders_Trigger_Log WHERE TenantId = @TenantId
	DELETE FROM FeedbackOrders WHERE TenantId = @TenantId
	DELETE FROM OrderStatus WHERE TenantId = @TenantId
	DELETE FROM RecurringPaymentRecords WHERE TenantId = @TenantId
	DELETE FROM TenantRecordPayment WHERE TenantId = @TenantId
	DELETE FROM Orders WHERE TenantId = @TenantId

	-- Purchase Orders
	DELETE FROM POProductItemsAttachments WHERE POProductItemId IN (SELECT POProductItemId FROM POProductItems WHERE POProductId IN (SELECT POProductId FROM POProducts WHERE TenantId = @TenantId))
	DELETE FROM POProductItems WHERE POProductId IN (SELECT POProductId FROM POProducts WHERE TenantId = @TenantId)
	DELETE FROM POProductAttachments WHERE POProductId IN (SELECT POProductId FROM POProducts WHERE TenantId = @TenantId)
	DELETE FROM POProductPayment WHERE TenantId = @TenantId
	DELETE FROM POProducts WHERE TenantId = @TenantId
	DELETE FROM PORawMaterialItems WHERE PORawMaterialId IN (SELECT PORawMaterialId FROM PORawMaterials WHERE TenantId = @TenantId)
	DELETE FROM PORawMaterials WHERE TenantId = @TenantId

	-- Stock / Inward
	DELETE FROM StockTransferDetail WHERE StockTransferId IN (SELECT StockTransferId FROM StockTransfer WHERE TenantId = @TenantId)
	DELETE FROM StockTransferLog WHERE TenantId = @TenantId
	DELETE FROM StockTransfer WHERE TenantId = @TenantId
	DELETE FROM InwardDetailsEntry WHERE InwardId IN (SELECT InwardId FROM InwardEntry WHERE TenantId = @TenantId)
	DELETE FROM InwardEntry WHERE TenantId = @TenantId
	DELETE FROM RawMaterialInwardDetailsEntry WHERE RawMaterialId IN (SELECT RawMaterialId FROM RawMaterialInwardEntry WHERE TenantId = @TenantId)
	DELETE FROM RawMaterialInwardEntry WHERE TenantId = @TenantId
	DELETE FROM Stock_predictions WHERE product_id IN (SELECT product_id FROM Products WHERE TenantId = @TenantId)
	DELETE FROM RawMaterialInventory WHERE RawMaterialId IN (SELECT RawMaterialId FROM RawMaterials WHERE TenantId = @TenantId)
	DELETE FROM RawMaterialInventoryByWarehouse WHERE RawMaterialId IN (SELECT RawMaterialId FROM RawMaterials WHERE TenantId = @TenantId)
	DELETE FROM StockOnHold WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)

	-- Wrk Import
	DELETE FROM WrkImportCustomers WHERE WrkImportFileID IN (SELECT WrkImportFileID FROM WrkImportFiles WHERE TenantId = @TenantId)
	DELETE FROM WrkImportFabrics WHERE WrkImportFileID IN (SELECT WrkImportFileID FROM WrkImportFiles WHERE TenantId = @TenantId)
	DELETE FROM WrkImportVendors WHERE WrkImportFileID IN (SELECT WrkImportFileID FROM WrkImportFiles WHERE TenantId = @TenantId)
	DELETE FROM WrkImportFiles WHERE TenantId = @TenantId
	DELETE FROM WrkProducts WHERE WrkImportFileID IN (SELECT WrkImportFileID FROM WrkImportFiles WHERE TenantId = @TenantId)
	DELETE FROM WrkInwardProducts WHERE WrkImportFileID IN (SELECT WrkImportFileID FROM WrkImportFiles WHERE TenantId = @TenantId)

	-- Leads
	DELETE FROM FollowUpLeads WHERE LeadId IN (SELECT LeadId FROM Leads WHERE TenantId = @TenantId)
	DELETE FROM LeadRemarks WHERE LeadId IN (SELECT LeadId FROM Leads WHERE TenantId = @TenantId)
	DELETE FROM LeadComments WHERE LeadId IN (SELECT LeadId FROM Leads WHERE TenantId = @TenantId)
	DELETE FROM LeadAudios WHERE LeadId IN (SELECT LeadId FROM Leads WHERE TenantId = @TenantId)
	DELETE FROM LeadLogs WHERE LeadId IN (SELECT LeadId FROM Leads WHERE TenantId = @TenantId)
	DELETE FROM FollowUps WHERE SubjectTypeId IN (SELECT SubjectTypeId FROM SubjectTypes WHERE TenantId = @TenantId )
	DELETE FROM Leads WHERE TenantId = @TenantId
	DELETE FROM WrkLead WHERE TenantId = @TenantId

	-- Feedback / Offers
	DELETE FROM FeedbackComments WHERE OrderId IN (SELECT OrderId FROM Orders WHERE TenantId = @TenantId)
	DELETE FROM FeedbackQuestions WHERE TenantId = @TenantId
	DELETE FROM OfferProductMapping WHERE OfferId IN (SELECT OfferId FROM Offers WHERE TenantId = @TenantId)
	DELETE FROM Offers WHERE TenantId = @TenantId

	-- Catalogue & Vendors
	DELETE FROM CatalogueDetails WHERE CatalogueId IN (SELECT CatalogueId FROM Catalogue WHERE TenantId = @TenantId)
	DELETE FROM CatalogueAnonymousViews WHERE CatalogueId IN (SELECT CatalogueId FROM Catalogue WHERE TenantId = @TenantId)
	DELETE FROM CategoriesAnonymousViews WHERE CategoriesId IN (SELECT CategoriesId FROM Categories WHERE TenantId = @TenantId)
	DELETE FROM Catalogue WHERE TenantId = @TenantId
	DELETE FROM ProductVendorMapping WHERE VendorId IN (SELECT VendorId FROM Vendors WHERE TenantId = @TenantId)
	DELETE FROM ProductVendorSharing WHERE ToTenantID = @TenantId
	DELETE FROM VendorAddresses WHERE VendorId IN (SELECT VendorId FROM Vendors WHERE TenantId = @TenantId)
	DELETE FROM Vendors WHERE TenantId = @TenantId

	-- Announcements
	DELETE FROM AnnouncementsUserMapping WHERE TenantId = @TenantId
	DELETE FROM Announcements WHERE TenantId = @TenantId

	-- WhatsApp Templates
	DELETE FROM WhatsAppTemplateMappings WHERE TenantId = @TenantId
	DELETE FROM WhatsAppTemplates WHERE TenantId = @TenantId

	-- Facebook / Social
	DELETE FROM FacebookAPIPageDetails WHERE TenantId = @TenantId
	DELETE FROM FacebookLoginCredentials WHERE TenantId = @TenantId

	-- Sales / Analytics
	DELETE FROM SalesTargets WHERE TenantId = @TenantId
	DELETE FROM SalesAnalysis WHERE TenantID = @TenantId
	--DELETE FROM CombinedSalesAnalysis WHERE TenantId = @TenantId

	-- Training Modules
	DELETE FROM TrainingModuleVideo WHERE TrainingModuleId IN (SELECT TrainingModuleId FROM TrainingModule WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE  TenantId = @TenantId))) -- module id
	DELETE FROM TrainingModule WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE  TenantId = @TenantId))

	-- Misc / Logging
	DELETE FROM BatchUpdateLog WHERE TenantId = @TenantId
	DELETE FROM SharingActivityLog WHERE SubjectTypeId IN (SELECT SubjectTypeId FROM SubjectTypes WHERE TenantId = @TenantId)
	DELETE FROM DeviceLogs WHERE TenantID = @TenantId
	DELETE FROM ErrorLogs WHERE TenantId = @TenantId
	--DELETE FROM DBErrorLogs WHERE TenantId = @TenantId
	--DELETE FROM SQLObjectHistory WHERE TenantId = @TenantId
	--DELETE FROM WebhookResponse WHERE TenantId = @TenantId
	DELETE FROM Comments WHERE SubjectTypeId IN (SELECT SubjectTypeId FROM SubjectTypes WHERE TenantId = @TenantId)
	DELETE FROM KafkaEmailSending WHERE TenantID = @TenantId
	DELETE FROM TaskComments WHERE TaskId IN (SELECT TaskId FROM Tasks WHERE TenantId = @TenantId)
	DELETE FROM TaskAttachments WHERE TaskId IN (SELECT TaskId FROM Tasks WHERE TenantId = @TenantId)
	DELETE FROM TaskActivities WHERE TaskId IN (SELECT TaskId FROM Tasks WHERE TenantId = @TenantId)
	DELETE FROM Tasks WHERE TenantId = @TenantId
	DELETE FROM OwnerActionItems WHERE TenantId = @TenantId
	DELETE FROM TagType WHERE TenantId = @TenantId
	DELETE FROM Warehouse WHERE TenantId = @TenantId
	DELETE FROM Frames WHERE TenantId = @TenantId
	DELETE FROM Accessories WHERE TenantId = @TenantId
	DELETE FROM AccessoriesTypes WHERE TenantId = @TenantId

	IF @Type = 1 --Clean Products and Categories Data
	BEGIN
		DELETE FROM ManufacturingCategories WHERE TenantId = @TenantId
		DELETE FROM Categories WHERE TenantId = @TenantId
		DELETE FROM Companies WHERE TenantId = @TenantId
		DELETE FROM Fabrics WHERE TenantId = @TenantId
		DELETE FROM Polish WHERE TenantId = @TenantId
		DELETE FROM Labours WHERE TenantId = @TenantId
		DELETE FROM RawMaterials WHERE TenantId = @TenantId
		DELETE FROM PriceChangeLogs WHERE EntityID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductImages WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductLabours WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductMaterialsLabours WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductMaterialsTurningLabour WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductMaterials WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductQuantitiesByWarehouse WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductQuantities WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductQuantity_History WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductVariants WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductWorkflows WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductCustomFields WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductOffers WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductPrices WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductSetItems WHERE ProductSetId IN (SELECT ProductSetId FROM ProductSets WHERE TenantId = @TenantId)
		DELETE FROM ProductSetImage WHERE ProductSetId IN (SELECT ProductSetId FROM ProductSets WHERE TenantId = @TenantId)
		DELETE FROM ProductSets WHERE TenantId = @TenantId
		DELETE FROM ProductShareBatchDetail WHERE TenantId = @TenantId
		DELETE FROM ProductShareBatch WHERE TenantId = @TenantId
		DELETE FROM Products WHERE TenantId = @TenantId
	END

	IF @Type = 0 --Clean Master Data
	BEGIN
		DELETE FROM AspNetRoleClaims WHERE RoleId IN (SELECT Id FROM AspNetRoles WHERE TenantId = @TenantId)
		DELETE FROM AspNetRoles WHERE TenantId = @TenantId
		DELETE FROM AspNetUserClaims WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUserLogins WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUserTokens WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUserRoles WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)
		DELETE FROM UsersNotMapped WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)
		DELETE FROM UserFavoriteMenu WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM UserTenantMapping WHERE TenantId = @TenantId
		--DELETE FROM UserData WHERE TenantId = @TenantId
		DELETE FROM EmailCMSDetails WHERE EmailCMSID IN (SELECT EmailCMSID FROM EmailCMS WHERE TenantId = @TenantId)
		DELETE FROM EmailCMS WHERE TenantId = @TenantId
		DELETE FROM Labels WHERE TenantId = @TenantId
		DELETE FROM LookupValues WHERE LookupId IN (SELECT LookupId FROM Lookups WHERE TenantId = @TenantId)
		DELETE FROM Lookups WHERE TenantId = @TenantId
		DELETE FROM SubjectTypes WHERE TenantId = @TenantId
		DELETE FROM Attendance WHERE UserId IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM EmployeeDetails WHERE DepartmentID IN(SELECT DepartmentID FROM Departments WHERE TenantId = @TenantId)
		DELETE FROM LeaveApplicationDetails WHERE LeaveApplicationId IN (SELECT LeaveApplicationId FROM LeaveApplications WHERE LeaveCategoryID IN (SELECT LeaveCategoryID FROM LeaveCategory WHERE TenantId = @TenantId))
		DELETE FROM LeaveApplications WHERE LeaveCategoryID IN (SELECT LeaveCategoryID FROM LeaveCategory WHERE TenantId = @TenantId)
		DELETE FROM LeaveCategory WHERE TenantId = @TenantId
		DELETE FROM Departments WHERE TenantId = @TenantId
		DELETE FROM Designations WHERE TenantId = @TenantId
		DELETE FROM Holidays WHERE TenantId = @TenantId
		DELETE FROM LocationUserMapping WHERE LocationID IN (SELECT LocationID FROM Locations WHERE TenantId = @TenantId)
		DELETE FROM Locations WHERE TenantID = @TenantId
		DELETE FROM AreaByPincode WHERE State IN (SELECT StateName FROM State WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)))
		DELETE FROM Pincodes WHERE CityId IN (SELECT CityId FROM City WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE  TenantId = @TenantId)))
		DELETE FROM Cities WHERE CityID IN (SELECT CityId FROM City WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)))
		DELETE FROM City WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM State WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM States WHERE StateID IN (SELECT StateID FROM State WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)))
		DELETE FROM Contractor WHERE TenantId = @TenantId
		DELETE FROM OrganizationOwnerDetails WHERE TenantId = @TenantId
		DELETE FROM OrganizationTimingUserMapping WHERE UserId IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM OrganizationTimings WHERE TenantId = @TenantId
		DELETE FROM TenantBankDetails WHERE TenantId = @TenantId
		DELETE FROM TenantReminderSettings WHERE TenantId = @TenantId
		DELETE FROM TenantSMTPDetails WHERE TenantId = @TenantId
		DELETE FROM TenantWhatsAppDetails WHERE TenantId = @TenantId
		--DELETE FROM LicenseActivations WHERE TenantId = @TenantId
		--DELETE FROM LicenseAuditLog WHERE TenantId = @TenantId
		--DELETE FROM LicenseKeys WHERE TenantId = @TenantId
		DELETE FROM TenantConfigurations WHERE TenantId = @TenantId
		DELETE FROM TenantContracts WHERE TenantID = @TenantId
		DELETE FROM InvoiceFormat WHERE InvoiceFormatId IN (SELECT InvoiceFormatId FROM TenantInvoiceFormatMapping WHERE TenantId = @TenantId)
		DELETE FROM TenantInvoiceFormatMapping WHERE TenantId = @TenantId
		DELETE FROM TenantIPDomainRequestLog WHERE TenantId = @TenantId
		DELETE FROM TenantIPDomainWhitelist WHERE TenantId = @TenantId
		DELETE FROM TenantModulePermissions WHERE TenantId = @TenantId
		DELETE FROM TenantAPICount WHERE TenantId = @TenantId
		DELETE FROM TenantUsageStatistics WHERE TenantId = @TenantId
		DELETE FROM AzureBlobStorageSize WHERE TenantID = @TenantId
		DELETE FROM TallyConfiguration WHERE TenantId = @TenantId
		DELETE FROM ModuleColumnSequence WHERE UserId IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM TenantAppVersion WHERE TenantId = @TenantId
		DELETE FROM TenantInfo WHERE TenantInfoId IN (SELECT TenantInfoId FROM Tenants WHERE  TenantId = @TenantId)
		DELETE FROM Tenants WHERE TenantId = @TenantId
	END

	IF @Type = 2 --Delete All
	BEGIN
		DELETE FROM ManufacturingCategories WHERE TenantId = @TenantId
		DELETE FROM Categories WHERE TenantId = @TenantId
		DELETE FROM Companies WHERE TenantId = @TenantId
		DELETE FROM Fabrics WHERE TenantId = @TenantId
		DELETE FROM Polish WHERE TenantId = @TenantId
		DELETE FROM Labours WHERE TenantId = @TenantId
		DELETE FROM RawMaterials WHERE TenantId = @TenantId
		DELETE FROM PriceChangeLogs WHERE EntityID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductImages WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductLabours WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductMaterialsLabours WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductMaterialsTurningLabour WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductMaterials WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductQuantitiesByWarehouse WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductQuantities WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductQuantity_History WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductVariants WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductWorkflows WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductCustomFields WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductOffers WHERE ProductID IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductPrices WHERE ProductId IN (SELECT ProductId FROM Products WHERE TenantId = @TenantId)
		DELETE FROM ProductSetItems WHERE ProductSetId IN (SELECT ProductSetId FROM ProductSets WHERE TenantId = @TenantId)
		DELETE FROM ProductSetImage WHERE ProductSetId IN (SELECT ProductSetId FROM ProductSets WHERE TenantId = @TenantId)
		DELETE FROM ProductSets WHERE TenantId = @TenantId
		DELETE FROM ProductShareBatchDetail WHERE TenantId = @TenantId
		DELETE FROM ProductShareBatch WHERE TenantId = @TenantId
		DELETE FROM Products WHERE TenantId = @TenantId

		DELETE FROM AspNetRoleClaims WHERE RoleId IN (SELECT Id FROM AspNetRoles WHERE TenantId = @TenantId)
		DELETE FROM AspNetRoles WHERE TenantId = @TenantId
		DELETE FROM AspNetUserClaims WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUserLogins WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUserTokens WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUserRoles WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)
		DELETE FROM UsersNotMapped WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)
		DELETE FROM UserFavoriteMenu WHERE UserId IN (SELECT Id FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM UserTenantMapping WHERE TenantId = @TenantId
		--DELETE FROM UserData WHERE TenantId = @TenantId
		DELETE FROM EmailCMSDetails WHERE EmailCMSID IN (SELECT EmailCMSID FROM EmailCMS WHERE TenantId = @TenantId)
		DELETE FROM EmailCMS WHERE TenantId = @TenantId
		DELETE FROM Labels WHERE TenantId = @TenantId
		DELETE FROM LookupValues WHERE LookupId IN (SELECT LookupId FROM Lookups WHERE TenantId = @TenantId)
		DELETE FROM Lookups WHERE TenantId = @TenantId
		DELETE FROM SubjectTypes WHERE TenantId = @TenantId
		DELETE FROM Attendance WHERE UserId IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM EmployeeDetails WHERE DepartmentID IN(SELECT DepartmentID FROM Departments WHERE TenantId = @TenantId)
		DELETE FROM LeaveApplicationDetails WHERE LeaveApplicationId IN (SELECT LeaveApplicationId FROM LeaveApplications WHERE LeaveCategoryID IN (SELECT LeaveCategoryID FROM LeaveCategory WHERE TenantId = @TenantId))
		DELETE FROM LeaveApplications WHERE LeaveCategoryID IN (SELECT LeaveCategoryID FROM LeaveCategory WHERE TenantId = @TenantId)
		DELETE FROM LeaveCategory WHERE TenantId = @TenantId
		DELETE FROM Departments WHERE TenantId = @TenantId
		DELETE FROM Designations WHERE TenantId = @TenantId
		DELETE FROM Holidays WHERE TenantId = @TenantId
		DELETE FROM LocationUserMapping WHERE LocationID IN (SELECT LocationID FROM Locations WHERE TenantId = @TenantId)
		DELETE FROM Locations WHERE TenantID = @TenantId
		DELETE FROM AreaByPincode WHERE State IN (SELECT StateName FROM State WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)))
		DELETE FROM Pincodes WHERE CityId IN (SELECT CityId FROM City WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE  TenantId = @TenantId)))
		DELETE FROM Cities WHERE CityID IN (SELECT CityId FROM City WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)))
		DELETE FROM City WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM State WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM States WHERE StateID IN (SELECT StateID FROM State WHERE CreatedBy IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId)))
		DELETE FROM Contractor WHERE TenantId = @TenantId
		DELETE FROM OrganizationOwnerDetails WHERE TenantId = @TenantId
		DELETE FROM OrganizationTimingUserMapping WHERE UserId IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM OrganizationTimings WHERE TenantId = @TenantId
		DELETE FROM TenantBankDetails WHERE TenantId = @TenantId
		DELETE FROM TenantReminderSettings WHERE TenantId = @TenantId
		DELETE FROM TenantSMTPDetails WHERE TenantId = @TenantId
		DELETE FROM TenantWhatsAppDetails WHERE TenantId = @TenantId
		--DELETE FROM LicenseActivations WHERE TenantId = @TenantId
		--DELETE FROM LicenseAuditLog WHERE TenantId = @TenantId
		--DELETE FROM LicenseKeys WHERE TenantId = @TenantId
		DELETE FROM TenantConfigurations WHERE TenantId = @TenantId
		DELETE FROM TenantContracts WHERE TenantID = @TenantId
		DELETE FROM InvoiceFormat WHERE InvoiceFormatId IN (SELECT InvoiceFormatId FROM TenantInvoiceFormatMapping WHERE TenantId = @TenantId)
		DELETE FROM TenantInvoiceFormatMapping WHERE TenantId = @TenantId
		DELETE FROM TenantIPDomainRequestLog WHERE TenantId = @TenantId
		DELETE FROM TenantIPDomainWhitelist WHERE TenantId = @TenantId
		DELETE FROM TenantModulePermissions WHERE TenantId = @TenantId
		DELETE FROM TenantAPICount WHERE TenantId = @TenantId
		DELETE FROM TenantUsageStatistics WHERE TenantId = @TenantId
		DELETE FROM AzureBlobStorageSize WHERE TenantID = @TenantId
		DELETE FROM TallyConfiguration WHERE TenantId = @TenantId
		DELETE FROM ModuleColumnSequence WHERE UserId IN (SELECT UserId FROM AspNetUsers WHERE UserId IN (SELECT UserId FROM UserTenantMapping WHERE TenantId = @TenantId))
		DELETE FROM TenantAppVersion WHERE TenantId = @TenantId
		DELETE FROM TenantInfo WHERE TenantInfoId IN (SELECT TenantInfoId FROM Tenants WHERE  TenantId = @TenantId)
		DELETE FROM Tenants WHERE TenantId = @TenantId
	END

	-- tanyo_user_mcp
	DELETE FROM tanyo_user_mcp WHERE TenantId = @TenantId

	-- BackOfficeNotifications
	DELETE FROM BackOfficeNotificationReads WHERE NotificationId IN (SELECT NotificationId FROM Notifications WHERE TenantId = @TenantId)
	DELETE FROM BackOfficeNotifications WHERE NotificationId IN (SELECT NotificationId FROM Notifications WHERE TenantId = @TenantId)
END

GO

