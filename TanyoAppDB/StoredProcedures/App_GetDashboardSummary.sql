
/*  
-- Admin  
EXEC dbo.App_GetDashboardSummary  
    @TenantId = 2,  
    @UserId = 4328,  
    @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'  
*/  
/*  
Dashboard Tiles Mapped:  
  InquiryCount                           -> Leads  
  OrderInquiryCount                      -> Inquiry  
  StockOnHoldCount                       -> Stock Hold  
  OrderPendingApprovalCount              -> Pending For Approval  
  ApprovedOrderCount                     -> Approved  
  InProgressOrderCount                   -> InProgress  
  OrderInProgressProductsPendingCount    -> Inprogress Products > Pending  
  OrderInProgressProductsReadyToDeliverCount -> Inprogress Products > Ready To Deliver  
  DeliveredOrderCount                    -> Delivered  
  TotalComplainCount                     -> Complaint  
  InwardCount                            -> Inward  
  RawMaterialInwardCount                 -> Raw Material Inward  
  ShareProductCount                      -> Share Product  
  ImportProductCount                     -> Import Product  
  ArchivedOrderCount                     -> Archived Orders  
  POProductsCount                        -> Purchase Order  
  StockTransferCount                     -> Stock Transfer  
*/  
CREATE PROCEDURE [dbo].[App_GetDashboardSummary]   
  @TenantId INT  
 ,@UserId BIGINT  
 ,@RoleId NVARCHAR(100)  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  ---------------------------------------------------------  
  -- 1. All variables declared at the top  
  ---------------------------------------------------------  
  DECLARE  
   -- Order permissions  
   @IsAdmin BIT = 0  
   ,@HasSuperAccess BIT = 0  
   ,@IsWholesaler BIT = 0  
   ,@ExpectedOrderType INT  
   ,  
   -- Lead permissions  
   @IsLeadAdmin BIT = 0  
   ,@HasLeadSuperAccess BIT = 0  
   ,  
   -- Order statuses  
   @OrderInquiryStatus INT = 0  
   ,@OrderPendingApprovalStatus INT = 1  
   ,  
   -- Stock On Hold  
   @StockOnHoldUserId BIGINT  
   ,@StockOnHoldDate DATE  
   ,  
   -- Complaint permissions  
   @IsComplainAdmin BIT = 0  
   ,@CanListAllOrders BIT = 0  
   ,  
  
   -- Customers dashboard card permission    
            @HasCustomersCardView BIT = 0  
   ,  
   -- Error handling  
   @ObjectName VARCHAR(500)  
   ,@ErrorMsg VARCHAR(MAX);  
  
  ---------------------------------------------------------  
  -- 2. Set common Order permissions (single-pass)  
  ---------------------------------------------------------  
  SELECT @IsAdmin = MAX(CASE   
     WHEN ClaimValue IN (  
       'Permissions.App.Order.Approve'  
       ,'Permissions.General.Order.Approve'  
       )  
      THEN 1  
     ELSE 0  
     END)  
   ,@HasSuperAccess = MAX(CASE   
     WHEN ClaimValue IN (  
       'Permissions.App.Order.SuperAccess'  
       ,'Permissions.General.Order.SuperAccess'  
       )  
      THEN 1  
     ELSE 0  
     END)  
   ,@IsWholesaler = MAX(CASE   
     WHEN ClaimValue IN (  
       'Permissions.App.Order.WholeselerPrice'  
       ,'Permissions.General.Order.WholeselerPrice'  
       )  
      THEN 1  
     ELSE 0  
     END)  
  FROM AspNetRoleClaims WITH (NOLOCK)  
  WHERE RoleId = @RoleId  
   AND ClaimValue IN (  
    'Permissions.App.Order.Approve'  
    ,'Permissions.App.Order.SuperAccess'  
    ,'Permissions.App.Order.WholeselerPrice'  
    );  
  
  SET @IsAdmin = ISNULL(@IsAdmin, 0);  
  SET @HasSuperAccess = ISNULL(@HasSuperAccess, 0);  
  SET @IsWholesaler = ISNULL(@IsWholesaler, 0);  
  ---------------------------------------------------------  
  -- 3. Set Expected Order Type  
  --    Retailer = 1, Wholesaler = 2  
  ---------------------------------------------------------  
  SET @ExpectedOrderType = CASE   
    WHEN @IsWholesaler = 1  
     THEN 2  
    ELSE 1  
    END;  
  ---------------------------------------------------------  
  -- 4. Set other variable values  
  ---------------------------------------------------------  
  SET @StockOnHoldUserId = @UserId;  
  SET @StockOnHoldDate = CAST(GETDATE() AS DATE);  
  
  ---------------------------------------------------------  
  -- 5. Temporary table for final dashboard result  
  ---------------------------------------------------------  
  CREATE TABLE #DashboardSummary (  
   DashboardName VARCHAR(100)  
   ,DashboardCount INT  
   );  
  
  ---------------------------------------------------------  
  -- 6. Order Counts — single-pass UNPIVOT  
  --    Tiles: Inquiry | Pending For Approval | Approved |  
  --           InProgress | Delivered | Archived Orders  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT DashboardName  
   ,DashboardCount  
  FROM (  
   SELECT  
    -- Tile: Inquiry (Status = 0)  
    ISNULL(SUM(CASE   
       WHEN o.IsArchive = 0  
        AND o.Status = @OrderInquiryStatus  
        THEN 1  
       ELSE 0  
       END), 0) AS OrderInquiryCount  
    -- Tile: Pending For Approval (Status = 1)  
    ,ISNULL(SUM(CASE   
       WHEN o.IsArchive = 0  
        AND o.Status = @OrderPendingApprovalStatus  
        THEN 1  
       ELSE 0  
       END), 0) AS OrderPendingApprovalCount  
    -- Tile: Approved (Status = 2)  
    ,ISNULL(SUM(CASE   
       WHEN o.IsArchive = 0  
        AND o.Status = 2  
        THEN 1  
       ELSE 0  
       END), 0) AS ApprovedOrderCount  
    -- Tile: InProgress (Status = 3)  
    ,ISNULL(SUM(CASE   
       WHEN o.IsArchive = 0  
        AND o.Status = 3  
        THEN 1  
       ELSE 0  
       END), 0) AS InProgressOrderCount  
    -- Tile: Delivered (Status = 5)  
    ,ISNULL(SUM(CASE   
       WHEN o.IsArchive = 0  
        AND o.Status = 5  
        THEN 1  
       ELSE 0  
       END), 0) AS DeliveredOrderCount  
    -- Tile: Archived Orders  
    ,ISNULL(SUM(CASE   
       WHEN o.IsArchive = 1  
        AND o.Status <> 9  
        THEN 1  
       ELSE 0  
       END), 0) AS ArchivedOrderCount  
   FROM Orders o WITH (NOLOCK)  
   WHERE o.TenantId = @TenantId  
    AND (  
     @IsAdmin = 1  
     OR (  
      @HasSuperAccess = 1  
      AND o.OrderType = @ExpectedOrderType  
      )  
     OR (  
      o.SalesmanId = @UserId  
      AND o.OrderType = @ExpectedOrderType  
      )  
     )  
   ) Src  
  UNPIVOT(DashboardCount FOR DashboardName IN (  
     OrderInquiryCount  
     ,OrderPendingApprovalCount  
     ,ApprovedOrderCount  
     ,InProgressOrderCount  
     ,DeliveredOrderCount  
     ,ArchivedOrderCount  
     )) Unpvt;  
  
  ---------------------------------------------------------  
  -- 7. Lead Permissions  
  ---------------------------------------------------------  
  SET @IsLeadAdmin = CASE   
    WHEN EXISTS (  
      SELECT 1  
      FROM AspNetRoles WITH (NOLOCK)  
      WHERE Id = @RoleId  
       AND [Name] = 'Administrator_' + CAST(@TenantId AS VARCHAR(5))  
      )  
     THEN 1  
    ELSE 0  
    END;  
  SET @HasLeadSuperAccess = CASE   
    WHEN EXISTS (  
      SELECT 1  
      FROM AspNetRoleClaims WITH (NOLOCK)  
      WHERE RoleId = @RoleId  
       AND ClaimValue = 'Permissions.App.Lead.SuperAccess'  
      )  
     THEN 1  
    ELSE 0  
    END;  
  
  ---------------------------------------------------------  
  -- 8. User Locations (for Lead/Inquiry count)  
  ---------------------------------------------------------  
  CREATE TABLE #UserLocations (LocationID INT PRIMARY KEY);  
  
  INSERT INTO #UserLocations (LocationID)  
  SELECT DISTINCT LocationID  
  FROM LocationUserMapping WITH (NOLOCK)  
  WHERE UserId = @UserId;  
  
  ---------------------------------------------------------  
  -- 9. Leads Count  
  --    Tile: Leads  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'InquiryCount'  
   ,COUNT(*)  
  FROM Leads l WITH (NOLOCK)  
  INNER JOIN #UserLocations ul ON l.LocationID = ul.LocationID  
  WHERE l.Status NOT IN (  
    5  
    ,6  
    ) -- 5 = Closed, 6 = Deleted  
   AND l.TenantId = @TenantId  
   AND (  
    @IsLeadAdmin = 1  
    OR @HasLeadSuperAccess = 1  
    OR l.SalesmanId = @UserId  
    );  
  
  DROP TABLE #UserLocations;  
  
  ---------------------------------------------------------  
  -- 10. Inward Count  
  --     Tile: Inward  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'InwardCount'  
   ,COUNT(*)  
  FROM InwardEntry i WITH (NOLOCK)  
  INNER JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = i.CreatedBy  
  LEFT JOIN Vendors v WITH (NOLOCK) ON i.VendorId = v.VendorId  
   AND v.TenantId = @TenantId  
  WHERE i.TenantId = @TenantId  
   AND i.IsDeleted = 0;  
  
  ---------------------------------------------------------  
  -- 11. Inprogress Products Counts — single-pass   
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT DashboardName  
   ,DashboardCount  
  FROM (  
   SELECT  
    -- Sub-tile: Pending (ItemStatus = 4)  
    ISNULL(SUM(CASE   
       WHEN osi.ItemStatus = 4  
        THEN 1  
       ELSE 0  
       END), 0) AS OrderInProgressProductsPendingCount  
    -- Sub-tile: Ready To Deliver (ItemStatus = 2)  
    ,ISNULL(SUM(CASE   
       WHEN osi.ItemStatus = 2  
        THEN 1  
       ELSE 0  
       END), 0) AS OrderInProgressProductsReadyToDeliverCount  
   FROM OrderSetItems osi WITH (NOLOCK)  
   INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId  
    AND o.TenantId = @TenantId  
   WHERE osi.ParentOrderSetItemId IS NULL  
    AND o.IsArchive = 0  
    AND osi.IsDeleted = 0  
    AND osi.ItemStatus IN (  
     2  
     ,4  
     )  
    AND (  
     @IsAdmin = 1  
     OR (  
      @HasSuperAccess = 1  
      AND o.OrderType = @ExpectedOrderType  
      )  
     OR (  
      o.CreatedBy = @UserId  
      AND o.OrderType = @ExpectedOrderType  
      )  
     )  
   ) Src  
  UNPIVOT(DashboardCount FOR DashboardName IN (  
     OrderInProgressProductsPendingCount  
     ,OrderInProgressProductsReadyToDeliverCount  
     )) Unpvt;  
  
  ---------------------------------------------------------  
  -- 12. Purchase Order Count  
  --     Tile: Purchase Order  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'POProductsCount'  
   ,COUNT(1)  
  FROM POProducts WITH (NOLOCK)  
  WHERE TenantId = @TenantId  
   AND IsDeleted = 0  
   AND Status IN (  
    1  
    ,2  
    ,5  
    );-- 1=Pending, 2=Approved, 5=Material Ready  
  
  ---------------------------------------------------------  
  -- 13. Raw Material Inward Count  
  --     Tile: Raw Material Inward  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'RawMaterialInwardCount'  
   ,COUNT(*)  
  FROM RawMaterialInwardEntry i WITH (NOLOCK)  
  LEFT JOIN Vendors v WITH (NOLOCK) ON i.VendorId = v.VendorId  
   AND v.TenantId = @TenantId  
  WHERE i.TenantId = @TenantId  
   AND i.IsDeleted = 0;  
  
  ---------------------------------------------------------  
  -- 15. Stock On Hold Count  
  --     Tile: Stock Hold  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'StockOnHoldCount'  
   ,COUNT(DISTINCT soh.OrderSetItemId)  
  FROM StockOnHold soh WITH (NOLOCK)  
  INNER JOIN Orders o WITH (NOLOCK) ON soh.OrderId = o.OrderId  
   AND o.TenantId = @TenantId  
  INNER JOIN OrderSetItems osi WITH (NOLOCK) ON soh.OrderSetItemId = osi.OrderSetItemId  
  WHERE soh.IsStockOnHold = 1  
   AND o.Status IN (  
    0  
    ,1  
    ) -- Inquiry, Pending For Approval  
   AND o.IsArchive = 0  
   AND DATEADD(DAY, TRY_CAST(soh.TimePeriod AS INT), soh.CreatedDate) > @StockOnHoldDate
  
  ---------------------------------------------------------  
  -- 16. Stock Transfer Count  
  --     Tile: Stock Transfer  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'StockTransferCount'  
   ,COUNT(*)  
  FROM StockTransfer i  
  WHERE i.TenantId = @TenantId  
   AND i.IsDeleted = 0;  
  
  ---------------------------------------------------------  
  -- 17. Share Product Count  
  --     Tile: Share Product  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'ShareProductCount'  
   ,COUNT(DISTINCT b.Id)  
  FROM dbo.ProductShareBatch b WITH (NOLOCK)  
  INNER JOIN dbo.ProductShareBatchDetail bd WITH (NOLOCK) ON bd.BatchId = b.Id  
  INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = b.CreatedBy  
  WHERE b.TenantId = @TenantId;  
  
  ---------------------------------------------------------  
  -- 18. Import Product Count  
  --     Tile: Import Product  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'ImportProductCount'  
   ,COUNT(*)  
  FROM dbo.ProductShareBatchDetail bd WITH (NOLOCK)  
  INNER JOIN dbo.ProductShareBatch b WITH (NOLOCK) ON b.Id = bd.BatchId  
  INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = bd.ProductId  
   AND p.Status <> 3  
  INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = bd.CustomerId  
   AND c.IsDeleted = 0  
  WHERE bd.ToTenantId = @TenantId  
   AND bd.Status = 0;  
  
  ---------------------------------------------------------  
  -- 19. Complaint Permissions  
  --     @IsComplainAdmin mirrors @IsLeadAdmin (same Administrator_TenantId check)  
  ---------------------------------------------------------  
  SET @IsComplainAdmin = @IsLeadAdmin;  
  SET @CanListAllOrders = CASE   
    WHEN EXISTS (  
      SELECT 1  
      FROM AspNetRoleClaims WITH (NOLOCK)  
      WHERE RoleId = @RoleId  
       AND ClaimValue = 'Permissions.App.Complain.ListAllOrders'  
      )  
     THEN 1  
    ELSE 0  
    END;  
  
  ---------------------------------------------------------  
  -- 20. Total Complaint Count  
  --     Tile: Complaint  
  ---------------------------------------------------------  
  INSERT INTO #DashboardSummary (  
   DashboardName  
   ,DashboardCount  
   )  
  SELECT 'TotalComplainCount'  
   ,COUNT(*)  
  FROM Complains c WITH (NOLOCK)  
  LEFT JOIN Orders o WITH (NOLOCK) ON c.OrderId = o.OrderId  
   AND o.TenantId = @TenantId  
   AND o.IsArchive = 0  
  WHERE c.TenantId = @TenantId  
   AND c.Status <> 4 -- not include delete complain  
   AND (  
    @IsComplainAdmin = 1  
    OR @CanListAllOrders = 1  
    OR (  
     @IsComplainAdmin = 0  
     AND @CanListAllOrders = 0  
     AND c.CreatedBy = @UserId  
     AND ISNULL(o.OrderType, 1) = @ExpectedOrderType  
     )  
    );  
    
  ---------------------------------------------------------    
  -- 21. Customers Count    
  --     Tile: Customers — gated by its own App.Dashboard.CustomersView claim    
  --     (CustomerTypeId 1=Customer, 2=Interior; never Wholesaler)    
  ---------------------------------------------------------    
  SET @HasCustomersCardView = CASE     
    WHEN EXISTS (    
      SELECT 1    
      FROM AspNetRoleClaims    
      WHERE RoleId = @RoleId    
       AND ClaimValue = 'Permissions.App.Dashboard.CustomersView'    
      )    
     THEN 1    
    ELSE 0    
    END;    
    
  INSERT INTO #DashboardSummary (    
   DashboardName    
   ,DashboardCount    
   )    
  SELECT 'Customers'    
   ,CASE     
     WHEN @HasCustomersCardView = 1    
      THEN COUNT(*)    
     ELSE 0    
     END    
  FROM Customers c    
  WHERE c.TenantId = @TenantId    
   AND c.IsDeleted = 0    
   AND c.CustomerTypeId IN (    
    1    
    ,2    
    );    
  ---------------------------------------------------------  
  -- 22. Final Dashboard Result  
  ---------------------------------------------------------  
  SELECT DashboardName  
   ,DashboardCount  
  FROM #DashboardSummary  
  ORDER BY DashboardName;  
  
  DROP TABLE #DashboardSummary;  
 END TRY  
  
 BEGIN CATCH  
  IF OBJECT_ID('tempdb..#DashboardSummary') IS NOT NULL  
   DROP TABLE #DashboardSummary;  
  
  IF OBJECT_ID('tempdb..#UserLocations') IS NOT NULL  
   DROP TABLE #UserLocations;  
  
  SET @ObjectName = OBJECT_NAME(@@PROCID);  
  SET @ErrorMsg = ERROR_MESSAGE();  
  
  EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
   ,@ErrorMsg = @ErrorMsg;  
 END CATCH  
END

GO

