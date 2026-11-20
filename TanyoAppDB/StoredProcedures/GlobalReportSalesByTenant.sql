-- =============================================  
-- Author  : MagnusMinds -- Create date : 27-08-2025
-- Description : Global Report - Sales By Tenant
-- =============================================  
/*  
 EXEC GlobalReportSalesByTenant  
	  @UserId = 4279
     ,@TenantId = NULL 
	 ,@FromDate = '2025-08-01'  
	 ,@ToDate = '2025-08-27'
	 ,@PageIndex = 1  
	 ,@PageSize = 50  
	 ,@SortBy = 'TotalGstAmount'
	 ,@SortOrder = 'asc'  
*/  

CREATE   PROCEDURE [dbo].[GlobalReportSalesByTenant](
    @UserId     INT 
    ,@TenantId   INT = NULL
    ,@FromDate   DATE
    ,@ToDate     DATE
    ,@PageIndex  INT = 1
    ,@PageSize   INT = 50
    ,@SortBy     VARCHAR(50) = 'TotalGstAmount'
    ,@SortOrder  VARCHAR(50) = 'desc'
)
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;
    
    BEGIN TRY  

        SELECT 
            COUNT(o.OrderId) AS TotalOrders
            ,ROUND(SUM(o.AmountBeforeGST), 0) AS TotalOrderValue
            ,ROUND(SUM(o.CGSTAmount + o.SGSTAmount), 0) AS TotalGstAmount
            ,o.TenantId
            ,t.TenantName
            ,COUNT(1) OVER () AS TotalCount
        FROM Orders AS o WITH (NOLOCK)
        INNER JOIN Tenants AS t WITH (NOLOCK) ON o.TenantId = t.TenantId
        INNER JOIN UserTenantMapping AS utm WITH (NOLOCK) ON utm.TenantId = o.TenantId AND utm.UserId = @UserId
        WHERE 
            (@TenantId IS NULL OR o.TenantId = @TenantId)
            AND o.STATUS IN (  
                 2  
                 ,3  
                 ,4  
                 ,5  
            ) --Approved & Delivered  
            AND CONVERT(DATE, o.ApprovedDate) BETWEEN @FromDate  
            AND @ToDate 
            --AND (@FromDate IS NULL OR o.ApprovedDate >= @FromDate)
            --AND (@ToDate IS NULL OR o.ApprovedDate <= @ToDate)
        GROUP BY 
            o.TenantId, 
            t.TenantName
        ORDER BY  
            -- Sort by TenantName
            CASE WHEN @SortBy = 'TenantName' AND @SortOrder = 'ASC'  THEN t.TenantName END ASC,
            CASE WHEN @SortBy = 'TenantName' AND @SortOrder = 'DESC' THEN t.TenantName END DESC,

            -- Sort by TotalOrders
            CASE WHEN @SortBy = 'TotalOrders' AND @SortOrder = 'ASC'  THEN COUNT(o.OrderId) END ASC,
            CASE WHEN @SortBy = 'TotalOrders' AND @SortOrder = 'DESC' THEN COUNT(o.OrderId) END DESC,

            -- Sort by TotalOrderValue
            CASE WHEN @SortBy = 'TotalOrderValue' AND @SortOrder = 'ASC'  THEN ROUND(SUM(o.AmountBeforeGST), 0) END ASC,
            CASE WHEN @SortBy = 'TotalOrderValue' AND @SortOrder = 'DESC' THEN ROUND(SUM(o.AmountBeforeGST), 0) END DESC,

            -- Sort by TotalGstAmount
            CASE WHEN @SortBy = 'TotalGstAmount' AND @SortOrder = 'ASC'  THEN ROUND(SUM(o.CGSTAmount + o.SGSTAmount), 0) END ASC,
            CASE WHEN @SortBy = 'TotalGstAmount' AND @SortOrder = 'DESC' THEN ROUND(SUM(o.CGSTAmount + o.SGSTAmount), 0) END DESC

        OFFSET (@PageIndex - 1) * @PageSize ROWS 
        FETCH NEXT @PageSize ROWS ONLY

    END TRY
    
BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH  
END

GO

