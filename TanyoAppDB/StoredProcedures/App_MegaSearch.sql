
/*  
--Admin  
EXEC App_MegaSearch  
 @TenantId = 2  
 ,@SearchText = 'bhagat'  
 ,@CurrentUserId = 4279  
 ,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'  
  
--SalesRepresentative  
EXEC App_MegaSearch  
 @TenantId = 2  
 ,@SearchText = 'bar'  
 ,@CurrentUserId = 2131  
 ,@RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'  
  
*/  
 CREATE PROCEDURE [dbo].[App_MegaSearch] (  
 @TenantId INT  
 ,@SearchText NVARCHAR(100)  
 ,@CurrentUserId BIGINT  
 ,@RoleId NVARCHAR(100)  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @IsAdmin BIT = 0  
   ,@HasSuperAccess BIT = 0  
   ,@HasWholesalerPermission BIT = 0  
   ,@HasCustomerView BIT = 0  
   ,@HasInteriorView BIT = 0  
   ,@HasOrderApprove BIT = 0  
   ,@HasComplainPermission BIT = 0;  
  
  IF EXISTS (  
    SELECT 1  
    FROM TenantModulePermissions WITH (NOLOCK)  
    WHERE TenantId = @TenantId  
     AND ClaimValue = 'Permissions.Complain'  
    )  
   SET @HasComplainPermission = 1;  
  
  IF EXISTS (  
    SELECT 1  
    FROM AspNetRoles WITH (NOLOCK)  
    WHERE Id = @RoleId  
     AND Name LIKE 'Administrator_%'  
    )  
   SET @IsAdmin = 1;  
  
  IF EXISTS (  
    SELECT 1  
    FROM AspNetRoleClaims WITH (NOLOCK)  
    WHERE RoleId = @RoleId  
     AND ClaimValue IN (  
      'Permissions.App.Order.SuperAccess'  
      ,'Permissions.General.Order.SuperAccess'  
      )  
    )  
   SET @HasSuperAccess = 1;  
  
  IF EXISTS (  
    SELECT 1  
    FROM AspNetRoleClaims WITH (NOLOCK)  
    WHERE RoleId = @RoleId  
     AND ClaimValue IN (  
      'Permissions.App.Order.WholeselerPrice'  
      ,'Permissions.General.Order.WholeselerPrice'  
      )  
    )  
   SET @HasWholesalerPermission = 1;  
  
  IF EXISTS (  
    SELECT 1  
    FROM AspNetRoleClaims WITH (NOLOCK)  
    WHERE RoleId = @RoleId  
     AND ClaimValue IN ('Permissions.App.Customer.View', 'Permissions.App.Customer.Create')
    )  
   SET @HasCustomerView = 1;  
  
  IF EXISTS (  
    SELECT 1  
    FROM AspNetRoleClaims WITH (NOLOCK)  
    WHERE RoleId = @RoleId  
     AND ClaimValue = 'Permissions.App.Interior.View'  
    )  
   SET @HasInteriorView = 1;  
  
  IF EXISTS (  
    SELECT 1  
    FROM AspNetRoleClaims WITH (NOLOCK)  
    WHERE RoleId = @RoleId  
     AND ClaimValue IN (  
      'Permissions.App.Order.Approve'  
      ,'Permissions.General.Order.Approve'  
      )  
    )  
   SET @HasOrderApprove = 1;  
  
  CREATE TABLE #MegaSearchResults (  
   Id BIGINT  
   ,Title VARCHAR(255)  
   ,Number VARCHAR(255)  
   ,DefaultImage VARCHAR(40)  
   ,[Type] VARCHAR(50)  
   );  
     
   ;WITH cteProducts  
  AS (  
   SELECT TOP 10 p.ProductId AS Id  
    ,p.ProductTitle AS Title  
    ,p.ModelNo AS Number  
    ,'' AS DefaultImage  
    ,'Product' AS Type  
   FROM Products p WITH (NOLOCK)  
   WHERE p.TenantId = @TenantId  
    AND p.Status = 1  
    AND (  
     p.ModelNo LIKE '%' + @SearchText + '%'  
     OR p.ProductTitle LIKE '%' + @SearchText + '%'  
     )  
    AND (  
     (  
      p.IsVisibleToWholesalers = 1  
      AND @HasWholesalerPermission = 1  
      )  
     OR p.IsVisibleToWholesalers = 0  
     )  
   )  
  INSERT INTO #MegaSearchResults (  
   Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
   )  
  SELECT Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
  FROM cteProducts;  
    
  ;WITH cteCustomers  
  AS (  
   SELECT TOP 10 c.CustomerId AS Id  
    ,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS Title  
    ,c.PhoneNumber AS Number  
    ,NULL AS DefaultImage  
    ,CASE   
     WHEN c.CustomerTypeId = 2  
      THEN 'Interior'  
     ELSE 'Customer'  
     END AS Type  
   FROM Customers c WITH (NOLOCK)  
   WHERE c.TenantId = @TenantId  
    AND c.IsDeleted = 0  
    AND c.CustomerTypeId IN (  
     1  
     ,2  
     )  
    AND (  
     (  
      @HasInteriorView = 1  
      AND @HasCustomerView = 1  
      AND (  
       c.PhoneNumber LIKE @SearchText + '%'  
       OR ISNULL(c.FirstName, '') LIKE '%' + @SearchText + '%'  
       OR ISNULL(c.LastName, '') LIKE '%' + @SearchText + '%'  
       OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @SearchText + '%'  
       )  
      )  
     OR (        @HasInteriorView = 1  
      AND @HasCustomerView = 0  
      AND c.CustomerTypeId = 2  
      AND (  
       c.PhoneNumber LIKE @SearchText + '%'  
       OR ISNULL(c.FirstName, '') LIKE '%' + @SearchText + '%'  
       OR ISNULL(c.LastName, '') LIKE '%' + @SearchText + '%'  
       OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @SearchText + '%'  
       )  
      )  
     OR (  
      @HasInteriorView = 0  
      AND @HasCustomerView = 1  
      AND c.CustomerTypeId = 1  
      AND (  
       c.PhoneNumber LIKE @SearchText + '%'  
       OR ISNULL(c.FirstName, '') LIKE '%' + @SearchText + '%'  
       OR ISNULL(c.LastName, '') LIKE '%' + @SearchText + '%'  
       OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @SearchText + '%'  
       )  
      )  
     )  
   )  
  INSERT INTO #MegaSearchResults (  
   Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
   )  
  SELECT Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
  FROM cteCustomers;  
     
 ;WITH cteCategories  
  AS (  
   SELECT TOP 10 cat.CategoryId AS Id  
    ,cat.CategoryName AS Title  
    ,NULL AS Number  
    ,NULL AS DefaultImage  
    ,'Category' AS Type  
   FROM Categories cat WITH (NOLOCK)  
   WHERE cat.TenantId = @TenantId  
    AND cat.IsDeleted = 0  
    AND cat.CategoryName LIKE @SearchText + '%'  
   )  
  INSERT INTO #MegaSearchResults (  
   Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
   )  
  SELECT Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
  FROM cteCategories;  
  
  ;WITH cteOrders  
  AS (  
   SELECT TOP 10 o.OrderId AS Id  
    ,o.OrderNo AS Title  
    ,NULL AS Number  
    ,NULL AS DefaultImage  
    ,'Order' AS Type  
   FROM Orders o WITH (NOLOCK)  
   WHERE o.TenantId = @TenantId  
    AND o.Status <> 9  
    AND o.OrderNo LIKE @SearchText + '%'  
    AND (  
     @IsAdmin = 1  
     OR (o.SalesmanId = @CurrentUserId)  
     OR (  
      (  
       @HasOrderApprove = 1  
       OR @HasSuperAccess = 1  
       )  
      AND (  
       o.OrderType = CASE   
        WHEN @HasWholesalerPermission = 1  
         THEN 2  
        ELSE 1  
        END  
       )  
      )  
     )  
   ORDER BY o.CreatedDate DESC  
   )  
  INSERT INTO #MegaSearchResults (  
   Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
   )  
  SELECT Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
  FROM cteOrders;  
  
  SELECT Id  
   ,Title  
   ,Number  
   ,DefaultImage  
   ,[Type]  
  FROM #MegaSearchResults;  
  
  DROP TABLE #MegaSearchResults;  
 END TRY  
  
 BEGIN CATCH  
  DECLARE @ObjectName VARCHAR(500)  
   ,@ErrorMsg NVARCHAR(MAX);  
  
  SET @ObjectName = -1  
  SET @ErrorMsg = ERROR_MESSAGE();  
  
  IF OBJECT_ID('tempdb..#MegaSearchResults') IS NOT NULL  
   DROP TABLE #MegaSearchResults;  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
 END CATCH  
END

GO

