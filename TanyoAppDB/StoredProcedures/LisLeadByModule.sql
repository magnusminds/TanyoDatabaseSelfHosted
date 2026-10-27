/*  
====================================================================  
IMPORTANT: If any changes in Parameters or in WHERE clause, please do update [dbo].[GetLeadCountByModule] SP.  
====================================================================  
EXEC LisLeadByModule  
    @TenantId = 2   
    ,@CurrentUserId = 4279  
    ,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'  
    ,@CustomerName = NULL  
    ,@StatusId = NULL  
    ,@SalesmanId = NULL  
    ,@PhoneNumber = NULL  
    ,@InquiryFromDate = NULL  
    ,@InquiryToDate = NULL  
    ,@FollowUpFromDate = NULL  
    ,@FollowUpToDate = NULL  
    ,@LeadSourceId = NULL  
    ,@CustomerId = NULL  
    ,@LeadNumber = NULL  
    ,@PriorityId = NULL  
    ,@ModuleName = 'Remaining'  
    ,@PageIndex = 1  
    ,@PageSize = 25  
    ,@SortBy = 'UpdatedDate'  
    ,@SortOrder = 'DESC'  
    ,@BuyingRangeValueId = NULL  
====================================================================  
*/
CREATE PROC [dbo].[LisLeadByModule] (
	@TenantId INT
	,@CurrentUserId BIGINT
	,@RoleId NVARCHAR(100)
	,@CustomerName VARCHAR(200) = NULL
	,@StatusId INT = NULL
	,@SalesmanId BIGINT = NULL
	,@PhoneNumber VARCHAR(50) = NULL
	,@InquiryFromDate DATE = NULL
	,@InquiryToDate DATE = NULL
	,@FollowUpFromDate DATE = NULL
	,@FollowUpToDate DATE = NULL
	,@LeadSourceId BIGINT = NULL
	,@CustomerId BIGINT = NULL
	,@LeadNumber VARCHAR(15) = NULL
	,@PriorityId INT = NULL
	,@ModuleName VARCHAR(50) = 'Today'
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'UpdatedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	,@BuyingRangeValueId BIGINT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @dt DATE = GETDATE();
		DECLARE @IsAdmin BIT = 0
			,@HasSuperAccess BIT = 0;

		------------------------------------------  
		-- ROLE CHECK  
		------------------------------------------  
		IF EXISTS (
				SELECT 1
				FROM AspNetRoles WITH (NOLOCK)
				WHERE Id = @RoleId
					AND [Name] = 'Administrator_' + CAST(@TenantId AS VARCHAR(5))
				)
			SET @IsAdmin = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims WITH (NOLOCK)
				WHERE RoleId = @RoleId
					AND ClaimValue = 'Permissions.App.Lead.SuperAccess'
				)
			SET @HasSuperAccess = 1;

		------------------------------------------  
		-- USER LOCATION  
		------------------------------------------  
		CREATE TABLE #UserLocations (LocationID INT);

		INSERT INTO #UserLocations
		SELECT LocationID
		FROM LocationUserMapping WITH (NOLOCK)
		WHERE UserId = @CurrentUserId;

		------------------------------------------  
		-- MAIN QUERY  
		------------------------------------------  
		SELECT l.LeadId
			,l.Notes AS Inquiry
			,l.InquiryAbout
			,l.InquiryFor
			,l.RefferedBy
			,ISNULL(custRef.FirstName, '') + ' ' + ISNULL(custRef.LastName, '') AS RefferedByName
			,ISNULL(cust.FirstName, l.FirstName) AS FirstName
			,ISNULL(cust.LastName, l.LastName) AS LastName
			,ISNULL(NULLIF(CONCAT (
						cust.FirstName
						,' '
						,cust.LastName
						), ''), CONCAT (
					l.FirstName
					,' '
					,l.LastName
					)) AS CustomerName
			,l.Priority
			,lbl.LabelName AS PriorityLabel
			,lbl.ColorCode AS PriorityColorCode
			,l.CreatedDate AS InquiryDate
			,l.LastContactedDate
			,l.CreatedBy
			,l.SalesmanId AS Salesman
			,l.Status
			,l.Other
			,ISNULL(cust.PhoneNumber, l.PhoneNumber) AS PhoneNumber
			,cust.EmailId AS Email
			,u.FirstName + ' ' + u.LastName AS SalesmanName
			,l.LocationID
			,fu.FollowUpDate
			,fu.FollowUpComment AS FollowUpLastComment
			,l.LeadSourceId
			,ISNULL(LKV.LookupValueName, ISNULL(l.Other, 'Other')) AS LeadSourceName
			,l.CustomerId
			,l.LeadNumber
			,u.IsDeleted AS IsSalesmanDeleted
			,BUY.LookupValueName AS BuyingRangeValue
			,l.BuyingRangeValueId
			,l.AlternateMobileNumber
			,l.InquiryAreaRequirement
			,l.AlternateSalesmanId
			,l.ClientMeetingStageId
			,l.ArchitectMeetingStageId
			,l.LeadType
			,CASE 
				WHEN fu.FollowUpDate IS NOT NULL
					AND CAST(fu.FollowUpDate AS DATE) = @dt
					THEN 'Today'
				WHEN fu.FollowUpDate IS NOT NULL
					AND fu.FollowUpDate < @dt
					THEN 'Overdue'
				WHEN fu.FollowUpDate IS NOT NULL
					AND fu.FollowUpDate > @dt
					THEN 'Upcoming'
				ELSE 'Remaining'
				END AS ModuleGroup
			,COUNT(1) OVER () AS TotalCount
		FROM Leads l WITH (NOLOCK)
		LEFT JOIN LookupValues LKV WITH (NOLOCK) ON l.LeadSourceId = LKV.LookupValueId
		LEFT JOIN Labels lbl WITH (NOLOCK) ON l.Priority = lbl.LabelId
			AND lbl.TenantId = @TenantId
		LEFT JOIN AspNetUsers u WITH (NOLOCK) ON l.SalesmanId = u.UserId
		LEFT JOIN Customers cust WITH (NOLOCK) ON l.CustomerId = cust.CustomerId
			AND cust.TenantId = @TenantId
		LEFT JOIN Customers custRef WITH (NOLOCK) ON cust.RefferedBy = custRef.CustomerId
			AND custRef.TenantId = @TenantId
		LEFT JOIN LookupValues BUY WITH (NOLOCK) ON l.BuyingRangeValueId = BUY.LookupValueId
		OUTER APPLY (
			SELECT TOP 1 FollowUpDate
				,FollowUpComment
			FROM FollowUpLeads f WITH (NOLOCK)
			WHERE f.LeadId = l.LeadId
			ORDER BY f.FollowUpDate DESC
			) fu
		WHERE l.TenantId = @TenantId
			--AND l.Status NOT IN (5,6)  
			AND (
				(
					@StatusId IS NULL
					AND l.Status NOT IN (
						5
						,6
						)
					)
				OR (
					@StatusId IS NOT NULL
					AND l.Status = @StatusId
					)
				)
			AND EXISTS (
				SELECT 1
				FROM #UserLocations ul
				WHERE ul.LocationID = l.LocationID
				)
			AND (
				@IsAdmin = 1
				OR @HasSuperAccess = 1
				OR l.SalesmanId = @CurrentUserId
				)
			AND (
				@CustomerName IS NULL
				OR (cust.FirstName + ' ' + ISNULL(cust.LastName, '') LIKE '%' + @CustomerName + '%')
				)
			AND (
				@SalesmanId IS NULL
				OR l.SalesmanId = @SalesmanId
				)
			AND (
				@PhoneNumber IS NULL
				OR ISNULL(cust.PhoneNumber, l.PhoneNumber) LIKE '%' + @PhoneNumber + '%'
				)
			AND (
				@InquiryFromDate IS NULL
				OR l.CreatedDate >= @InquiryFromDate
				)
			AND (
				@InquiryToDate IS NULL
				OR l.CreatedDate <= @InquiryToDate
				)
			AND (
				@FollowUpFromDate IS NULL
				OR fu.FollowUpDate >= @FollowUpFromDate
				)
			AND (
				@FollowUpToDate IS NULL
				OR fu.FollowUpDate <= @FollowUpToDate
				)
			AND (
				@LeadSourceId IS NULL
				OR l.LeadSourceId = @LeadSourceId
				)
			AND (
				@CustomerId IS NULL
				OR l.CustomerId = @CustomerId
				)
			AND (
				@LeadNumber IS NULL
				OR l.LeadNumber LIKE '%' + @LeadNumber + '%'
				)
			AND (
				@PriorityId IS NULL
				OR l.Priority = @PriorityId
				)
			AND (
				@BuyingRangeValueId IS NULL
				OR l.BuyingRangeValueId = @BuyingRangeValueId
				)
			AND (
				@ModuleName = 'All'
				OR CASE 
					WHEN fu.FollowUpDate IS NOT NULL
						AND CAST(fu.FollowUpDate AS DATE) = @dt
						THEN 'Today'
					WHEN fu.FollowUpDate IS NOT NULL
						AND fu.FollowUpDate < @dt
						THEN 'Overdue'
					WHEN fu.FollowUpDate IS NOT NULL
						AND fu.FollowUpDate > @dt
						THEN 'Upcoming'
					ELSE 'Remaining'
					END = @ModuleName
				OR (
					@ModuleName = 'FieldPipeline'
					AND ISNULL(l.LeadType, 0) = 0
					AND u.FieldStoreOperationType = 1
					)
				OR (
					@ModuleName = 'SalesPipeline'
					AND ISNULL(l.LeadType, 0) = 0
					AND u.FieldStoreOperationType IN (
						2
						,3
						)
					)
				OR (
					@ModuleName = 'ArchitectsVisit-Store'
					AND ISNULL(l.LeadType, 0) = 1
					AND u.FieldStoreOperationType IN (
						2
						,3
						)
					)
				OR (
					@ModuleName = 'ArchitectsVisit-Field'
					AND ISNULL(l.LeadType, 0) = 1
					AND u.FieldStoreOperationType = 1
					)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'Priority'
					AND @SortOrder = 'ASC'
					THEN l.Priority
				END ASC
			,CASE 
				WHEN @SortBy = 'Priority'
					AND @SortOrder = 'DESC'
					THEN l.Priority
				END DESC
			,CASE 
				WHEN @SortBy = 'InquiryDate'
					AND @SortOrder = 'ASC'
					THEN l.CreatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'InquiryDate'
					AND @SortOrder = 'DESC'
					THEN l.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'ASC'
					THEN l.Status
				END ASC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'DESC'
					THEN l.Status
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN ISNULL(NULLIF(CONCAT (
									cust.FirstName
									,' '
									,cust.LastName
									), ''), CONCAT (
								l.FirstName
								,' '
								,l.LastName
								))
				END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN ISNULL(NULLIF(CONCAT (
									cust.FirstName
									,' '
									,cust.LastName
									), ''), CONCAT (
								l.FirstName
								,' '
								,l.LastName
								))
				END DESC
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'ASC'
					THEN ISNULL(cust.PhoneNumber, l.PhoneNumber)
				END ASC
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'DESC'
					THEN ISNULL(cust.PhoneNumber, l.PhoneNumber)
				END DESC
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'ASC'
					THEN u.FirstName + ' ' + u.LastName
				END ASC
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'DESC'
					THEN u.FirstName + ' ' + u.LastName
				END DESC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'ASC'
					THEN fu.FollowUpDate
				END ASC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'DESC'
					THEN fu.FollowUpDate
				END DESC
			,CASE 
				WHEN @SortBy = 'LeadSourceName'
					AND @SortOrder = 'ASC'
					THEN ISNULL(LKV.LookupValueName, ISNULL(l.Other, 'Other'))
				END ASC
			,CASE 
				WHEN @SortBy = 'LeadSourceName'
					AND @SortOrder = 'DESC'
					THEN ISNULL(LKV.LookupValueName, ISNULL(l.Other, 'Other'))
				END DESC
			,CASE 
				WHEN @SortBy = 'LeadNumber'
					AND @SortOrder = 'ASC'
					THEN l.LeadNumber
				END ASC
			,CASE 
				WHEN @SortBy = 'LeadNumber'
					AND @SortOrder = 'DESC'
					THEN l.LeadNumber
				END DESC
			,
			------------------------------------------  
			-- DEFAULT SORT (FIXED)  
			------------------------------------------  
			CASE 
				WHEN @SortBy = 'UpdatedDate'
					AND @SortOrder = 'ASC'
					THEN ISNULL(l.UpdatedDate, l.CreatedDate)
				END ASC
			,CASE 
				WHEN @SortBy = 'UpdatedDate'
					AND @SortOrder = 'DESC'
					THEN ISNULL(l.UpdatedDate, l.CreatedDate)
				END DESC
			,l.CreatedDate DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;

		DROP TABLE #UserLocations;
	END TRY

	BEGIN CATCH
		IF OBJECT_ID('tempdb..#UserLocations') IS NOT NULL
			DROP TABLE #UserLocations;

		DECLARE @ObjectName VARCHAR(400)
			,@ERRORMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

