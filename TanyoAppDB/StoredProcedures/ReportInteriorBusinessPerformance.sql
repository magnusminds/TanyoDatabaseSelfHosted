-- =====================================================================  
-- Report   : Interior Business Performance (TAN-4616)  
-- Purpose  : Per interior, show inquiries received and how many converted  
--            into approved orders. Owner tracks interior referral volume  
--            and conversion.  
-- Location : Reports > Sales > Interior Business Performance Report  
-- Grain    : One row per Interior (Customers.CustomerTypeId = 2) reached  
--            through Orders.RefferedBy. Interiors with no live order in  
--            the window do not appear.  
-- Columns  : Interior Name, Inquiry Amount (count), Converted Amount (count).  
--            Amount shown as SUM(TotalAmount); count shown in brackets.  
-- Statuses : Inquiry Count  = all stages EXCEPT Canceled(6) & Delete(9)  
--                              => {0,1,2,3,4,5,7,8}  (received / denominator)  
--            Converted Count = Status >= 2 EXCLUDING Canceled(6), Declined(8),  
--                              Delete(9) => {2,3,4,5,7} Approved..MaterialReceive  
-- Base WHERE already drops {6,9}, so Converted = CASE Status >= 2 AND Status <> 8.  
-- Filters  : From/To Date (order creation date, inclusive), Interior Name.  
--            @ReferredBy NULL  => all interiors.  
-- Notes    : No IsDeleted predicate on Orders - an order's deleted state IS Status = 9.  
--            Customers c.IsDeleted = 0 is applied: this is an interior-centric report,  
--            so orders referred by a since-deleted interior are intentionally excluded  
--            (the interior no longer exists to have "performance"). Confirmed for TAN-4616.  
--            OFFSET/FETCH is made deterministic with a unique InteriorId tiebreaker, so  
--            tied aggregates (e.g. ConvertedAmount = 0) page stably.  
-- =====================================================================  
CREATE   PROCEDURE [dbo].[ReportInteriorBusinessPerformance]  
        @TenantId  INT  
        ,@ReferredBy BIGINT = NULL  
        ,@FromDate  DATE = NULL  
        ,@ToDate    DATE = NULL  
        ,@PageIndex INT = 1  
        ,@PageSize  INT = 10  
        ,@SortBy    VARCHAR(50) = 'ConvertedAmount'  
        ,@SortOrder VARCHAR(4)  = 'desc'  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
    BEGIN TRY  
        SELECT x.*  
              ,COUNT(1) OVER () AS TotalCount  
        FROM (  
            SELECT c.CustomerId                                                       AS InteriorId  
                  ,COALESCE(NULLIF(LTRIM(RTRIM(c.CompanyName)), ''), LTRIM(RTRIM(c.FirstName + ' ' + ISNULL(c.LastName, '')))) AS InteriorName  
                  ,CAST(SUM(o.TotalAmount) AS DECIMAL(18, 2))                         AS InquiryAmount  
                  ,COUNT(1)                                                           AS InquiryCount  
                  ,CAST(SUM(CASE WHEN o.Status >= 2 AND o.Status <> 8 THEN o.TotalAmount ELSE 0 END) AS DECIMAL(18, 2)) AS ConvertedAmount  
                  ,SUM(CASE WHEN o.Status >= 2 AND o.Status <> 8 THEN 1 ELSE 0 END)  AS ConvertedCount  
            FROM Orders o WITH (NOLOCK)  
            INNER JOIN Customers c WITH (NOLOCK)  
                    ON c.CustomerId = o.RefferedBy  
                   AND c.TenantId   = @TenantId  
                   AND c.CustomerTypeId = 2                     -- Interior  
                   AND c.IsDeleted  = 0  
            WHERE o.TenantId = @TenantId  
              AND o.Status NOT IN (6, 9)                          -- live inquiries only (drop Canceled, Delete)  
              AND (@ReferredBy IS NULL OR o.RefferedBy = @ReferredBy)  
              AND (@FromDate IS NULL OR o.CreatedDate >= @FromDate)  
              AND (@ToDate   IS NULL OR o.CreatedDate <  DATEADD(DAY, 1, CAST(@ToDate AS DATETIME)))  
            GROUP BY c.CustomerId  
                  ,COALESCE(NULLIF(LTRIM(RTRIM(c.CompanyName)), ''), LTRIM(RTRIM(c.FirstName + ' ' + ISNULL(c.LastName, ''))))  
        ) x  
        ORDER BY  
            CASE WHEN @SortBy = 'InteriorName'     AND @SortOrder = 'asc' THEN x.InteriorName END ASC,  
            CASE WHEN @SortBy = 'InteriorName'     AND @SortOrder = 'desc' THEN x.InteriorName END DESC,  
            CASE WHEN @SortBy = 'InquiryAmount'    AND @SortOrder = 'asc'  THEN x.InquiryAmount END ASC,  
            CASE WHEN @SortBy = 'InquiryAmount'    AND @SortOrder = 'desc' THEN x.InquiryAmount END DESC,  
            CASE WHEN @SortBy = 'InquiryCount'     AND @SortOrder = 'asc'  THEN x.InquiryCount END ASC,  
            CASE WHEN @SortBy = 'InquiryCount'     AND @SortOrder = 'desc' THEN x.InquiryCount END DESC,  
            CASE WHEN @SortBy = 'ConvertedAmount'  AND @SortOrder = 'asc'  THEN x.ConvertedAmount END ASC,  
            CASE WHEN @SortBy = 'ConvertedAmount'  AND @SortOrder = 'desc' THEN x.ConvertedAmount END DESC,  
            CASE WHEN @SortBy = 'ConvertedCount'   AND @SortOrder = 'asc'  THEN x.ConvertedCount END ASC,  
            CASE WHEN @SortBy = 'ConvertedCount'   AND @SortOrder = 'desc' THEN x.ConvertedCount END DESC,  
            x.ConvertedAmount DESC,  
            x.InteriorId ASC  
        OFFSET (@PageIndex - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;  
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