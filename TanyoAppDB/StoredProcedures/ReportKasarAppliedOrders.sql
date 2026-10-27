-- =====================================================================  
-- Report   : Kasar Applied Orders Report  
-- Author   : Krish Rana  
-- Purpose  : Retrieves orders from Orders table where KasarAmount > 0,  
--            including order amount before Kasar, Kasar amount, and net  
--            order amount after Kasar.  
-- =====================================================================  
/* EXEC [dbo].[ReportKasarAppliedOrders]    
  @TenantId = 1206    
  ,@FromDate = '2026-10-01'    
  ,@ToDate = '2026-10-15'    
  ,@CustomerId = -1    
  ,@SalesmanId = -1    
  ,@OrderStatus = -1    
  ,@PageIndex = 1    
  ,@PageSize = 10    
  ,@SortBy = 'OrderDate'    
  ,@SortOrder = 'DESC'    
  ,@IsDownloadAll = 0  
 */  
CREATE PROCEDURE [dbo].[ReportKasarAppliedOrders] (  
    @TenantId INT,  
    @FromDate DATE = NULL,  
    @ToDate DATE = NULL,  
    @CustomerId BIGINT = NULL,  
    @SalesmanId BIGINT = NULL,  
    @OrderStatus INT = NULL,  
    @PageIndex INT = 1,  
    @PageSize INT = 10,  
    @SortBy VARCHAR(50) = 'OrderDate',  
    @SortOrder VARCHAR(50) = 'DESC',  
    @IsDownloadAll BIT = 0  
)  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
        SET @CustomerId = NULLIF(@CustomerId, 0);  
        SET @CustomerId = CASE WHEN @CustomerId < 0 THEN NULL ELSE @CustomerId END;  
          
        SET @SalesmanId = NULLIF(@SalesmanId, 0);  
        SET @SalesmanId = CASE WHEN @SalesmanId < 0 THEN NULL ELSE @SalesmanId END;  
          
        SET @OrderStatus = CASE WHEN @OrderStatus = -1 THEN NULL ELSE @OrderStatus END;  
        SET @PageIndex = ISNULL(NULLIF(@PageIndex, 0), 1);  
        SET @PageSize = ISNULL(NULLIF(@PageSize, 0), 10);  
        SET @SortBy = ISNULL(@SortBy, 'OrderDate');  
        SET @SortOrder = UPPER(ISNULL(@SortOrder, 'DESC'));  
  
        DECLARE   
            @FromDateTime DATETIMEOFFSET = NULL,  
            @ToDateTime DATETIMEOFFSET = NULL;  
  
        SELECT   
            @FromDateTime = CAST(@FromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30',  
            @ToDateTime = CAST(@ToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30';  
  
        SELECT  
            o.OrderId,  
            CONVERT(VARCHAR(10), COALESCE(o.ApprovedDate, o.CreatedDate), 103) AS OrderDate,  
            ISNULL(o.OrderNo, '') AS OrderNo,  
            LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))) AS CustomerName,  
            ISNULL(c.PhoneNumber, '') AS MobileNumber,  
            LTRIM(RTRIM(ISNULL(u.FirstName, '') + ' ' + ISNULL(u.LastName, ''))) AS SalesmanName,  
            os.StatusLabel AS OrderStatus,  
            ROUND(ISNULL(o.TotalAmt, 0) + o.KasarAmount, 0) AS OrderAmountBeforeKasar,  
            ROUND(o.KasarAmount, 0) AS KasarAmount,  
            ROUND(ISNULL(o.TotalAmt, 0), 0) AS OrderAmountAfterKasar,  
            COUNT_BIG(*) OVER () AS TotalCount  
        FROM dbo.Orders o WITH (NOLOCK)  
        LEFT JOIN dbo.Customers c WITH (NOLOCK)  
            ON c.CustomerId = o.CustomerID AND c.TenantId = @TenantId  
        LEFT JOIN dbo.AspNetUsers u WITH (NOLOCK)  
            ON u.UserId = o.SalesmanId  
        LEFT JOIN dbo.OrderStatus os WITH (NOLOCK)  
            ON os.StatusEnumId = o.Status AND os.TenantId = @TenantId AND os.Type = 'Order'  
        WHERE o.TenantId = @TenantId  
          AND o.IsArchive = 0  
          AND o.KasarAmount > 0  
          AND (@FromDateTime IS NULL OR COALESCE(o.ApprovedDate, o.CreatedDate) >= @FromDateTime)  
          AND (@ToDateTime IS NULL OR COALESCE(o.ApprovedDate, o.CreatedDate) <= @ToDateTime)  
          AND (@CustomerId IS NULL OR o.CustomerID = @CustomerId)  
          AND (@SalesmanId IS NULL OR o.SalesmanId = @SalesmanId)  
          AND (@OrderStatus IS NULL OR o.Status = @OrderStatus)  
        ORDER BY  
            CASE WHEN @SortBy = 'OrderDate' AND @SortOrder = 'ASC' THEN COALESCE(o.ApprovedDate, o.CreatedDate) END ASC,  
            CASE WHEN @SortBy = 'OrderDate' AND @SortOrder = 'DESC' THEN COALESCE(o.ApprovedDate, o.CreatedDate) END DESC,  
              
            CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'ASC' THEN o.OrderNo END ASC,  
            CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'DESC' THEN o.OrderNo END DESC,  
              
            CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))) END ASC,  
            CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))) END DESC,  
              
            CASE WHEN @SortBy = 'MobileNumber' AND @SortOrder = 'ASC' THEN c.PhoneNumber END ASC,  
            CASE WHEN @SortBy = 'MobileNumber' AND @SortOrder = 'DESC' THEN c.PhoneNumber END DESC,  
              
            CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'ASC' THEN LTRIM(RTRIM(ISNULL(u.FirstName, '') + ' ' + ISNULL(u.LastName, ''))) END ASC,  
            CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'DESC' THEN LTRIM(RTRIM(ISNULL(u.FirstName, '') + ' ' + ISNULL(u.LastName, ''))) END DESC,  
              
            CASE WHEN @SortBy = 'OrderStatus' AND @SortOrder = 'ASC' THEN os.StatusLabel END ASC,  
            CASE WHEN @SortBy = 'OrderStatus' AND @SortOrder = 'DESC' THEN os.StatusLabel END DESC,  
              
            CASE WHEN @SortBy = 'OrderAmountBeforeKasar' AND @SortOrder = 'ASC' THEN ROUND(ISNULL(o.TotalAmt, 0) + o.KasarAmount, 0) END ASC,  
            CASE WHEN @SortBy = 'OrderAmountBeforeKasar' AND @SortOrder = 'DESC' THEN ROUND(ISNULL(o.TotalAmt, 0) + o.KasarAmount, 0) END DESC,  
              
            CASE WHEN @SortBy = 'KasarAmount' AND @SortOrder = 'ASC' THEN ROUND(o.KasarAmount, 0) END ASC,  
            CASE WHEN @SortBy = 'KasarAmount' AND @SortOrder = 'DESC' THEN ROUND(o.KasarAmount, 0) END DESC,  
              
            CASE WHEN @SortBy = 'OrderAmountAfterKasar' AND @SortOrder = 'ASC' THEN ROUND(ISNULL(o.TotalAmt, 0), 0) END ASC,  
            CASE WHEN @SortBy = 'OrderAmountAfterKasar' AND @SortOrder = 'DESC' THEN ROUND(ISNULL(o.TotalAmt, 0), 0) END DESC,  
              
            COALESCE(o.ApprovedDate, o.CreatedDate) DESC,  
            o.OrderId DESC  
        OFFSET CASE WHEN @IsDownloadAll = 1 THEN 0 ELSE (@PageIndex - 1) * @PageSize END ROWS  
        FETCH NEXT CASE WHEN @IsDownloadAll = 1 THEN 2147483647 ELSE @PageSize END ROWS ONLY;  
  
    END TRY  
    BEGIN CATCH  
        IF @@TRANCOUNT > 0  
            ROLLBACK;  
  
        DECLARE  
            @ObjectName VARCHAR(500) = OBJECT_NAME(@@PROCID),  
            @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();  
  
        EXEC dbo.SaveDBErrorLog   
            @ObjectName = @ObjectName,  
            @ErrorMsg = @ErrorMsg;  
  
        THROW;  
    END CATCH  
END

GO

