/*  
EXEC [dbo].[SearchCustomerByData]  
    @Search = 'Krish',  
    @TenantId = 1207,  
    @RoleId = '73e927e8-2e81-4464-a881-ab292c491bca',  
    @HasAnyPermission = @HasAnyPermission OUTPUT,  
    @HiddenMatchType = @HiddenMatchType OUTPUT;  
*/  
  
CREATE PROCEDURE [dbo].[SearchCustomerByData]   
  @Search NVARCHAR(100)  
 ,@TenantId INT  
 ,@RoleId NVARCHAR(450)  
 ,@HasAnyPermission BIT = 0 OUTPUT  
 ,@HiddenMatchType INT = 0 OUTPUT  
WITH ENCRYPTION
AS
BEGIN TRY  
 SET NOCOUNT ON;  
  
 SET @HasAnyPermission = 0;  
 SET @HiddenMatchType = 0;  
  
 ------------------------------------------------------------------  
 -- 1. Permission Check (Consolidated into single SELECT)  
 ------------------------------------------------------------------  
 DECLARE @HasCustomerView BIT = 0  
  ,@HasInteriorView BIT = 0;  
  
 SELECT @HasCustomerView = ISNULL(MAX(CASE   
     WHEN ClaimValue IN ('Permissions.App.Customer.View', 'Permissions.App.Customer.Create')  
      THEN 1  
     ELSE 0  
     END), 0)  
  ,@HasInteriorView = ISNULL(MAX(CASE   
     WHEN ClaimValue = 'Permissions.App.Interior.View'  
      THEN 1  
     ELSE 0  
     END), 0)  
 FROM AspNetRoleClaims  
 WHERE RoleId = @RoleId  
  AND ClaimType = 'permission'  
  AND ClaimValue IN (  
   'Permissions.App.Customer.View'  
   ,'Permissions.App.Customer.Create'  
   ,'Permissions.App.Interior.View'  
   );  
  
 -- NOTE: never RETURN early with a skeleton (or no) SELECT here. EF Core  
 -- (FromSqlRaw) requires every mapped column in the result schema, even  
 -- when zero rows are returned. Permission denial is signalled via  
 -- @HasAnyPermission instead, and the main query below is guarded to  
 -- return zero (fully-shaped) rows in that case.  
 IF @HasCustomerView = 1  
  OR @HasInteriorView = 1  
  SET @HasAnyPermission = 1;  
  
 ;WITH OrderAggregates  
 AS (  
  SELECT o.CustomerID AS CustomerId  
   ,COUNT(*) AS NoOfTotalOrder  
   ,SUM(CASE   
     WHEN o.Status = 0  
      THEN 1  
     ELSE 0  
     END) AS NoOfInquiryOrder  
   ,SUM(CASE   
     WHEN o.Status = 5  
      THEN 1  
     ELSE 0  
     END) AS NoOfDeliveredOrder  
  FROM dbo.Orders o WITH (NOLOCK)  
  WHERE o.TenantId = @TenantId  
   AND o.Status != 9  
  GROUP BY o.CustomerID  
  )  
  ,LatestOrders  
 AS (  
  SELECT CustomerID  
   ,SalesmanId  
   ,ROW_NUMBER() OVER (  
    PARTITION BY CustomerID ORDER BY OrderId DESC  
    ) AS RowNum  
  FROM dbo.Orders WITH (NOLOCK)  
  WHERE TenantId = @TenantId  
   AND Status != 9  
  )  
  ,LatestLeads  
 AS (  
  SELECT CustomerId  
   ,SalesmanId  
   ,ROW_NUMBER() OVER (  
    PARTITION BY CustomerId ORDER BY LeadId DESC  
    ) AS RowNum  
  FROM dbo.Leads WITH (NOLOCK)  
  WHERE TenantId = @TenantId  
   AND Status != 6  
   AND CustomerId IS NOT NULL  
  )  
  ,VisitAggregates  
 AS (  
  SELECT CustomerId  
   ,COUNT(*) AS NoOfVisit  
  FROM dbo.CustomerVisits WITH (NOLOCK)  
  GROUP BY CustomerId  
  )  
 SELECT c.CustomerId  
  ,c.CustomerTypeId  
  ,c.FirstName  
  ,c.LastName  
  ,c.FirstName + ' ' + ISNULL(c.LastName, '') AS FullName  
  ,c.EmailId  
  ,c.PhoneNumber  
  ,c.AltName  
  ,c.AltPhoneNumber  
  ,c.GSTNo  
  ,c.Discount  
  ,c.InteriorCommissionPer  
  ,c.RefferedBy  
  ,c.IsSubscribe  
  ,c.IsVerified  
  ,c.Profession  
  ,c.CompanyName  
  ,c.Birthday  
  ,c.Anniversary  
  ,c.LocationID  
  ,c.CreatedBy  
  ,c.CreatedDate  
  ,c.ProfessionId  
  ,c.ArchitectCategoryId  
  ,c.ArchitectTypeId  
  ,c.EventId  
  ,c.EventText  
  ,c.SocialMediaUrl  
  ,u.FirstName + ' ' + u.LastName AS CreatedByName  
  ,ISNULL(vc.NoOfVisit, 0) AS NoOfVisit  
  ,ISNULL(oa.NoOfInquiryOrder, 0) AS NoOfInquiryOrder  
  ,ISNULL(oa.NoOfDeliveredOrder, 0) AS NoOfDeliveredOrder  
  ,ISNULL(oa.NoOfTotalOrder, 0) AS NoOfTotalOrder  
  ,CAST(COALESCE(so.SalesmanId, sl.SalesmanId) AS BIGINT) AS SalesmanId  
  ,rc.CustomerId AS RefferedCustomerId  
  ,rc.FirstName AS RefferedFirstName  
  ,rc.LastName AS RefferedLastName  
  ,rc.PhoneNumber AS RefferedPhoneNumber  
  ,rc.EmailId AS RefferedEmailId  
  ,rc.CustomerTypeId AS RefferedCustomerTypeId  
  ,rc.InteriorCommissionPer AS RefferedInteriorCommissionPer  
  ,rc.RefferedBy AS RefferedRefferedBy  
  ,rc.IsSubscribe AS RefferedIsSubscribe  
  ,rc.IsVerified AS RefferedIsVerified  
  ,rc.Profession AS RefferedProfession  
  ,rc.CompanyName AS RefferedCompanyName  
  ,rc.Birthday AS RefferedBirthday  
  ,rc.Anniversary AS RefferedAnniversary  
  ,rc.LocationID AS RefferedLocationID  
  ,rc.CreatedBy AS RefferedCreatedBy  
  ,rc.CreatedDate AS RefferedCreatedDate  
  ,rc.ProfessionId AS RefferedProfessionId  
  ,rc.ArchitectCategoryId AS RefferedArchitectCategoryId  
  ,rc.ArchitectTypeId AS RefferedArchitectTypeId  
  ,rc.EventId AS RefferedEventId  
  ,rc.EventText AS RefferedEventText  
  ,rc.SocialMediaUrl AS RefferedSocialMediaUrl  
 FROM dbo.Customers c WITH (NOLOCK)  
 LEFT JOIN dbo.AspNetUsers u WITH (NOLOCK) ON u.UserId = c.CreatedBy  
 LEFT JOIN dbo.Customers rc WITH (NOLOCK) ON rc.CustomerId = c.RefferedBy  
  AND rc.IsDeleted = 0  
 LEFT JOIN VisitAggregates vc WITH (NOLOCK) ON vc.CustomerId = c.CustomerId  
 LEFT JOIN OrderAggregates oa WITH (NOLOCK) ON oa.CustomerId = c.CustomerId  
 LEFT JOIN LatestOrders so WITH (NOLOCK) ON so.CustomerID = c.CustomerId  
  AND so.RowNum = 1  
 LEFT JOIN LatestLeads sl WITH (NOLOCK) ON sl.CustomerId = c.CustomerId  
  AND sl.RowNum = 1  
 WHERE c.IsDeleted = 0  
  AND c.TenantId = @TenantId  
  AND @HasAnyPermission = 1  
  AND (  
   c.PhoneNumber LIKE @Search + '%'  
   OR c.AltPhoneNumber LIKE @Search + '%'  
   OR (c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @Search + '%'  
   )  
  AND (  
   (  
    @HasCustomerView = 1  
    AND @HasInteriorView = 1  
    )  
   OR (  
    @HasCustomerView = 1  
    AND c.CustomerTypeId = 1  
    )  
   OR (  
    @HasInteriorView = 1  
    AND c.CustomerTypeId = 2  
    )  
   );  
  
 ------------------------------------------------------------------  
 -- 2. Hidden-match detection (only when main query found nothing  
 --    and the caller has partial permission).  
 --    @HiddenMatchType: 0 = none, 1 = hidden Interior match,  
 --    2 = hidden Customer match. CustomerTypeId: 1 = Customer,  
 --    2 = Interior.  
 ------------------------------------------------------------------  
 IF @@ROWCOUNT = 0  
  AND @HasAnyPermission = 1  
  AND (  
   @HasCustomerView = 0  
   OR @HasInteriorView = 0  
   )  
 BEGIN  
  IF @HasInteriorView = 0  
   AND EXISTS (  
    SELECT 1  
    FROM dbo.Customers c WITH (NOLOCK)  
    WHERE c.IsDeleted = 0  
     AND c.TenantId = @TenantId  
     AND c.CustomerTypeId = 2  
     AND (  
      c.PhoneNumber LIKE @Search + '%'  
      OR c.AltPhoneNumber LIKE @Search + '%'  
      OR (c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @Search + '%'  
      )  
    )  
   SET @HiddenMatchType = 1;  
  
  IF @HasCustomerView = 0  
   AND EXISTS (  
    SELECT 1  
    FROM dbo.Customers c WITH (NOLOCK)  
    WHERE c.IsDeleted = 0  
     AND c.TenantId = @TenantId  
     AND c.CustomerTypeId = 1  
     AND (  
      c.PhoneNumber LIKE @Search + '%'  
      OR c.AltPhoneNumber LIKE @Search + '%'  
      OR (c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @Search + '%'  
      )  
    )  
   SET @HiddenMatchType = 2;  
 END  
END TRY  
  
BEGIN CATCH  
 DECLARE @ObjectName VARCHAR(500)  
  ,@ErrorMsg VARCHAR(MAX);  
  
 SET @ObjectName = OBJECT_NAME(@@PROCID);  
 SET @ErrorMsg = ERROR_MESSAGE();  
  
 EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
  ,@ErrorMsg = @ErrorMsg;  
END CATCH

GO

