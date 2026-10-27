/*  
  Tenant-wide, no filters (Dashboard):  
  EXEC [dbo].[GetLeadPipelineCounts] @TenantId = 192  
  
  Scoped + filtered (Accordion / LeadsData):  
  EXEC [dbo].[GetLeadPipelineCounts] @TenantId = 192, @CurrentUserId = 1, @RoleId = '00000000-0000-0000-0000-000000000000'  
    , @CustomerName = NULL, @StatusId = NULL, @SalesmanId = NULL, @PhoneNumber = NULL  
    , @InquiryFromDate = NULL, @InquiryToDate = NULL, @FollowUpFromDate = NULL, @FollowUpToDate = NULL  
    , @LeadSourceId = NULL, @CustomerId = NULL, @LeadNumber = NULL, @PriorityId = NULL, @BuyingRangeValueId = NULL  
*/  
CREATE PROCEDURE [dbo].[GetLeadPipelineCounts]  
(  
   @TenantId INT  
   ,@CurrentUserId BIGINT = NULL  
   ,@RoleId NVARCHAR(100) = NULL  
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
   ,@BuyingRangeValueId BIGINT = NULL  
)  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
        DECLARE @ApplyUserScope BIT = CASE WHEN @CurrentUserId IS NULL THEN 0 ELSE 1 END;  
        DECLARE @IsAdmin BIT = 0, @HasSuperAccess BIT = 0;  
  
        ------------------------------------------  
        -- ROLE CHECK  
        ------------------------------------------  
        IF EXISTS (  
            SELECT 1 FROM AspNetRoles WITH (NOLOCK)  
            WHERE Id = @RoleId  
            AND [Name] = 'Administrator_' + CAST(@TenantId AS VARCHAR(5))  
        )  
            SET @IsAdmin = 1;  
  
        IF EXISTS (  
            SELECT 1 FROM AspNetRoleClaims WITH (NOLOCK)  
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
        WHERE UserId = ISNULL(@CurrentUserId, -1);  
  
        SELECT  
            COUNT(CASE WHEN ISNULL(l.LeadType, 0) = 0 AND u.FieldStoreOperationType = 1 THEN 1 END) AS FieldPipelineCount,  
            COUNT(CASE WHEN ISNULL(l.LeadType, 0) = 0 AND u.FieldStoreOperationType IN (2, 3) THEN 1 END) AS SalesPipelineCount,  
            COUNT(CASE WHEN ISNULL(l.LeadType, 0) = 1 AND u.FieldStoreOperationType IN (2, 3) THEN 1 END) AS ArchitectsVisitStoreCount,  
            COUNT(CASE WHEN ISNULL(l.LeadType, 0) = 1 AND u.FieldStoreOperationType = 1 THEN 1 END) AS ArchitectsVisitFieldCount  
        FROM dbo.Leads l WITH (NOLOCK)  
        LEFT JOIN dbo.Customers cust WITH (NOLOCK)  
            ON l.CustomerId = cust.CustomerId  
            AND cust.TenantId = @TenantId  
        INNER JOIN dbo.AspNetUsers u WITH (NOLOCK)  
            ON l.SalesmanId = u.UserId  
        OUTER APPLY (  
            SELECT TOP 1 FollowUpDate  
            FROM dbo.FollowUpLeads f WITH (NOLOCK)  
            WHERE f.LeadId = l.LeadId  
            ORDER BY f.FollowUpDate DESC  
        ) fu  
        WHERE l.TenantId = @TenantId  
          AND (  
              -- Dashboard (no user scope): original tenant-wide behaviour  
              (@ApplyUserScope = 0 AND l.Status <> 6)  
              OR  
              -- Accordion / LeadsData: same status rule as [LisLeadByModule]  
              (@ApplyUserScope = 1  
                   AND (  
                       (@StatusId IS NULL AND l.STATUS NOT IN (5,6))  
                       OR  
                       (@StatusId IS NOT NULL AND l.STATUS = @StatusId)))  
          )  
          AND (  
              @ApplyUserScope = 0  
              OR (  
                  EXISTS (  
                      SELECT 1 FROM #UserLocations ul  
                      WHERE ul.LocationID = l.LocationID  
                  )  
                  AND (  
                      @IsAdmin = 1  
                      OR @HasSuperAccess = 1  
                      OR l.SalesmanId = @CurrentUserId  
                  ))  
          )  
          ------------------------------------------  
          -- SAME FILTERS AS [LisLeadByModule] / [GetLeadCountByModule]  
          ------------------------------------------  
          AND (@CustomerName IS NULL OR   
              (cust.FirstName + ' ' + ISNULL(cust.LastName, '') LIKE '%' + @CustomerName + '%'))  
          AND (@SalesmanId IS NULL OR l.SalesmanId = @SalesmanId)  
          AND (@PhoneNumber IS NULL OR   
              ISNULL(cust.PhoneNumber, l.PhoneNumber) LIKE '%' + @PhoneNumber + '%')  
          AND (@InquiryFromDate IS NULL OR l.CreatedDate >= @InquiryFromDate)  
          AND (@InquiryToDate IS NULL OR l.CreatedDate <= @InquiryToDate)  
          AND (@FollowUpFromDate IS NULL OR fu.FollowUpDate >= @FollowUpFromDate)  
          AND (@FollowUpToDate IS NULL OR fu.FollowUpDate <= @FollowUpToDate)  
          AND (@LeadSourceId IS NULL OR l.LeadSourceId = @LeadSourceId)  
          AND (@CustomerId IS NULL OR l.CustomerId = @CustomerId)  
          AND (@LeadNumber IS NULL OR l.LeadNumber LIKE '%' + @LeadNumber + '%')  
          AND (@PriorityId IS NULL OR l.Priority = @PriorityId)  
          AND (@BuyingRangeValueId IS NULL OR l.BuyingRangeValueId = @BuyingRangeValueId);  
  
        DROP TABLE #UserLocations;  
    END TRY  
    BEGIN CATCH  
        IF OBJECT_ID('tempdb..#UserLocations') IS NOT NULL  
            DROP TABLE #UserLocations;  
  
        DECLARE @ObjectName VARCHAR(500),  
                @ErrorMsg VARCHAR(MAX);  
  
        SET @ObjectName = OBJECT_NAME(@@PROCID);  
        SET @ErrorMsg = ERROR_MESSAGE();  
  
        EXEC dbo.SaveDBErrorLog   
            @ObjectName = @ObjectName,  
            @ErrorMsg = @ErrorMsg;  
    END CATCH  
END

GO

