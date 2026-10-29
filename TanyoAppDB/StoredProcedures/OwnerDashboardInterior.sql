-- =============================================================================  
-- SP Name   : OwnerDashboardInterior  
-- Module    : Owner Dashboard - Top Business from Interiors (TAN-4615)  
--             ("Who Is Sending Us Business?") - temporarily occupies the  
--             Profit card slot (section 3) on the dashboard and the PDF digest.  
-- Params    : @TenantId INT, @Month INT, @Year INT  
-- Returns   : One row per interior (CustomerTypeId = 2) that referred at least  
--             one won order in the selected month:  
--               InteriorId, InteriorName, BusinessValue, OrderCount  
--  
-- KPI Logic:  
--   Interior          = dbo.Customers row with CustomerTypeId = 2  
--                       (CustomerTypeEnum.Interior), not deleted.  
--   Referred orders   = Orders.RefferedBy = interior's CustomerId (same link  
--                       the Sales by Interior report and the interior  
--                       commission engine use).  
--   BusinessValue     = SUM(Orders.AmountBeforeGST) of the interior's referred  
--                       orders with Status >= 2 and NOT IN (6 Canceled,  
--                       8 Declined) - the dashboard-standard "won" basis - and  
--                       ApprovedDate inside the selected month.  
--   OrderCount        = COUNT of those orders.  
--   Ordered by BusinessValue DESC (the top-10 display cap is applied in BL).  
--   Interiors with no referred order in the period return no rows (the card  
--   shows its empty state, like Dealer Targets does).  
--  
-- NOTE: Read-only (GET/SELECT-only) SP - it opens no transaction, so there is NO  
--       BEGIN TRAN and NO "IF @@TRANCOUNT > 0 ROLLBACK" here (nothing to roll back).  
--       The TRY/CATCH is kept only to log failures into dbo.SaveDBErrorLog, and THROW  
--       re-raises them so EF/FromSqlRaw gets a real SqlException instead of a  
--       missing result set.  
-- =============================================================================  
  
CREATE   PROCEDURE [dbo].[OwnerDashboardInterior]  
    @TenantId INT,  
    @Month    INT,  
    @Year     INT  
WITH ENCRYPTION
AS
BEGIN  
    BEGIN TRY  
        SET NOCOUNT ON;  
  
        DECLARE @MonthStart DATE = DATEFROMPARTS(@Year, @Month, 1);  
        DECLARE @MonthEnd   DATE = EOMONTH(@MonthStart);  
  
        SELECT  
            c.CustomerId                                                          AS InteriorId,  
            ISNULL(NULLIF(LTRIM(RTRIM(c.FirstName + ISNULL(' ' + c.LastName, ''))), ''), 'Interior') AS InteriorName,  
            ISNULL(o.BusinessValue, 0)                                            AS BusinessValue,  
            ISNULL(o.OrderCount, 0)                                               AS OrderCount  
        FROM dbo.Customers c WITH (NOLOCK)  
        INNER JOIN  
        (  
            SELECT  
                od.RefferedBy,  
                SUM(CAST(od.AmountBeforeGST AS DECIMAL(18, 2)))                   AS BusinessValue,  
                COUNT(od.OrderId)                                                 AS OrderCount  
            FROM dbo.Orders od WITH (NOLOCK)  
            WHERE od.TenantId = @TenantId  
              AND od.IsArchive = 0  
              AND od.RefferedBy IS NOT NULL  
              AND od.Status >= 2  
              AND od.Status NOT IN (6, 8)   -- Won basis: Approved, InProgress, Completed, Delivered, MaterialReceive  
              AND CAST(od.ApprovedDate AS DATE) BETWEEN @MonthStart AND @MonthEnd  
            GROUP BY od.RefferedBy  
        ) o ON o.RefferedBy = c.CustomerId  
        WHERE c.TenantId = @TenantId  
          AND c.IsDeleted = 0  
          AND c.CustomerTypeId = 2          -- CustomerTypeEnum.Interior  
        ORDER BY ISNULL(o.BusinessValue, 0) DESC, InteriorName;  
    END TRY  
  
    BEGIN CATCH  
      DECLARE @ObjectName VARCHAR(500)  
       ,@ErrorMsg VARCHAR(MAX);  
      
      SET @ObjectName = OBJECT_NAME(@@PROCID);  
      SET @ErrorMsg = ERROR_MESSAGE();  
      
      EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName  
       ,@ErrorMsg = @ErrorMsg;  
    END CATCH  
END;  