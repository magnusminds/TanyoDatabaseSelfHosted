CREATE   PROCEDURE [dbo].[ReportPaymentCollection]  
(  
 @TenantId INT  
,@FromDate DATE  
,@Todate DATE  
,@OrderNo VARCHAR(20) = NULL  
,@PaymentType INT = NULL  
,@PageIndex INT = 1  
,@PageSize INT = 50  
,@SortBy VARCHAR(50) = '1'  
,@SortOrder VARCHAR(50) = 'DESC'
,@IsDownloadAll BIT = 0
,@LocationId BIGINT = NULL
,@CustomerId BIGINT = NULL
,@ReceivedBy BIGINT = NULL
)  
WITH ENCRYPTION
AS
BEGIN  
SET NOCOUNT ON;  

BEGIN TRY  
    IF(@IsDownloadAll = 0)
    begin
        ;WITH CTE
        AS 
        (
        SELECT   
           o.OrderId  
           ,o.OrderNo  
           ,c.FirstName + ' ' + ISNULL(c.LastName,'') AS CustomerName  
           ,c.PhoneNumber  
           ,p.ReceivedAmount AS ReceivedAmount  
           ,p.TransactionId  
           ,au.Firstname + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName  
           ,CAST(p.ApprovedDate AS DATE) AS ApprovedDate  
           ,p.PaymentApprovedBy AS ApprovedBy  
           ,p.PaymentType  
           ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
           ,ISNULL(approvedBy.FirstName + ' ' + approvedBy.LastName, '') + CASE WHEN approvedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS PaymentApprovedByName  
           ,ISNULL(receivedBy.FirstName + ' ' + receivedBy.LastName, '') + CASE WHEN receivedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS PaymentReceivedByName
           ,p.ReceivedDate
           ,ISNULL(l.LocationName, '') AS LocationName
           ,SUM(p.ReceivedAmount) OVER() AS GrandTotalReceivedAmount
          FROM Orders AS o WITH (NOLOCK)  
          INNER JOIN Customers AS c WITH (NOLOCK) ON c.CustomerId = o.CustomerID  
          INNER JOIN Payments AS p WITH (NOLOCK) ON p.OrderId = o.OrderId  
           AND p.PaymentStatus = 1  
           AND p.IsDeleted = 0  
          INNER JOIN AspNetUsers AS au WITH (NOLOCK) ON au.UserId = o.SalesmanId  
          LEFT JOIN AspNetUsers AS approvedBy WITH (NOLOCK) ON approvedBy.UserId = p.PaymentApprovedBy  
          LEFT JOIN AspNetUsers AS receivedBy WITH (NOLOCK) ON receivedBy.UserId = p.PaymentReceivedBy
          LEFT JOIN Locations AS l WITH (NOLOCK) ON l.LocationID = o.LocationId
          WHERE o.TenantId = @TenantId  
          AND o.Status <> 9  
          AND CONVERT(date, p.ApprovedDate) BETWEEN @FromDate AND @ToDate  
          AND (ISNULL(@OrderNo, '') = '' OR o.OrderNo LIKE '%' + @OrderNo + '%')  
          AND (@PaymentType IS NULL OR p.PaymentType = @PaymentType)
          AND (@LocationId IS NULL OR o.LocationId = @LocationId)
          AND (@CustomerId IS NULL OR o.CustomerId = @CustomerId)
          AND (@ReceivedBy IS NULL OR p.PaymentReceivedBy = @ReceivedBy)
          ORDER BY CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'asc' THEN o.OrderNo END  
           ,CASE WHEN @SortBy = 'OrderNo'AND @SortOrder = 'desc' THEN o.OrderNo END DESC  
           ,CASE WHEN @SortBy = 'CustomerName'AND @SortOrder = 'asc' THEN c.FirstName + ' ' + ISNULL(c.LastName,'') END  
           ,CASE WHEN @SortBy = 'CustomerName'AND @SortOrder = 'desc' THEN c.FirstName + ' ' + ISNULL(c.LastName,'') END DESC  
           ,CASE WHEN @SortBy = 'PhoneNumber'AND @SortOrder = 'asc' THEN c.PhoneNumber END  
           ,CASE WHEN @SortBy = 'PhoneNumber'AND @SortOrder = 'desc' THEN c.PhoneNumber END DESC  
           ,CASE WHEN @SortBy = 'ReceivedAmount'AND @SortOrder = 'asc' THEN p.ReceivedAmount END  
           ,CASE WHEN @SortBy = 'ReceivedAmount'AND @SortOrder = 'desc' THEN p.ReceivedAmount END DESC  
           ,CASE WHEN @SortBy = 'SalesmanName'AND @SortOrder = 'asc' THEN au.Firstname + ' ' + au.LastName END  
           ,CASE WHEN @SortBy = 'SalesmanName'AND @SortOrder = 'desc' THEN au.Firstname + ' ' + au.LastName END DESC  
           ,CASE WHEN @SortBy = 'ApprovedDate'AND @SortOrder = 'asc' THEN p.ApprovedDate END  
           ,CASE WHEN @SortBy = 'ApprovedDate'AND @SortOrder = 'desc' THEN p.ApprovedDate END DESC  
           ,CASE WHEN @SortBy = 'ApprovedBy'AND @SortOrder = 'asc' THEN p.PaymentApprovedBy END  
           ,CASE WHEN @SortBy = 'ApprovedBy'AND @SortOrder = 'desc' THEN p.PaymentApprovedBy END DESC  
           ,CASE WHEN @SortBy = 'PaymentType'AND @SortOrder = 'asc' THEN p.PaymentType END  
           ,CASE WHEN @SortBy = 'PaymentType'AND @SortOrder = 'desc' THEN p.PaymentType END DESC
           ,CASE WHEN @SortBy = 'TransactionId'AND @SortOrder = 'desc' THEN p.TransactionId END DESC
           ,CASE WHEN @SortBy = 'TransactionId'AND @SortOrder = 'asc' THEN p.TransactionId END  
           ,CASE WHEN @SortBy = 'ReceivedDate'AND @SortOrder = 'asc' THEN p.ReceivedDate END  
           ,CASE WHEN @SortBy = 'ReceivedDate'AND @SortOrder = 'desc' THEN p.ReceivedDate END DESC
           ,CASE WHEN @SortBy = 'ReceivedBy'AND @SortOrder = 'asc' THEN ISNULL(receivedBy.FirstName + ' ' + receivedBy.LastName, '') + CASE WHEN receivedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END END  
           ,CASE WHEN @SortBy = 'ReceivedBy'AND @SortOrder = 'desc' THEN ISNULL(receivedBy.FirstName + ' ' + receivedBy.LastName, '') + CASE WHEN receivedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END END DESC
           ,CASE WHEN @SortBy = 'LocationName' AND @SortOrder = 'asc' THEN l.LocationName END
           ,CASE WHEN @SortBy = 'LocationName' AND @SortOrder = 'desc' THEN l.LocationName END DESC
          OFFSET(@PageIndex - 1) * @PageSize ROWS  
        FETCH NEXT @PageSize ROWS ONLY
        )
        SELECT *
        ,SUM(ReceivedAmount) OVER() AS TotalReceivedAmount
        FROM CTE
    END
    ELSE
  BEGIN
        SELECT   
           o.OrderId  
           ,o.OrderNo  
           ,c.FirstName + ' ' + ISNULL(c.LastName,'') AS CustomerName  
           ,c.PhoneNumber  
           ,p.ReceivedAmount AS ReceivedAmount  
           ,p.TransactionId  
           ,au.Firstname + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName  
           ,CAST(p.ApprovedDate AS DATE) AS ApprovedDate  
           ,p.PaymentApprovedBy AS ApprovedBy  
           ,p.PaymentType  
           ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
           ,ISNULL(approvedBy.FirstName + ' ' + approvedBy.LastName, '') + CASE WHEN approvedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS PaymentApprovedByName 
           ,ISNULL(receivedBy.FirstName + ' ' + receivedBy.LastName, '') + CASE WHEN receivedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS PaymentReceivedByName
           ,p.ReceivedDate
           ,ISNULL(l.LocationName, '') AS LocationName
           ,SUM(p.ReceivedAmount) OVER() AS GrandTotalReceivedAmount
           ,SUM(ReceivedAmount) OVER() AS TotalReceivedAmount    
          FROM Orders AS o WITH (NOLOCK)  
          INNER JOIN Customers AS c WITH (NOLOCK) ON c.CustomerId = o.CustomerID  
          INNER JOIN Payments AS p WITH (NOLOCK) ON p.OrderId = o.OrderId  
           AND p.PaymentStatus = 1  
           AND p.IsDeleted = 0  
          INNER JOIN AspNetUsers AS au WITH (NOLOCK) ON au.UserId = o.SalesmanId  
          LEFT JOIN AspNetUsers AS approvedBy WITH (NOLOCK) ON approvedBy.UserId = p.PaymentApprovedBy  
          LEFT JOIN AspNetUsers AS receivedBy WITH (NOLOCK) ON receivedBy.UserId = p.PaymentReceivedBy
          LEFT JOIN Locations AS l WITH (NOLOCK) ON l.LocationID = o.LocationId
          WHERE o.TenantId = @TenantId  
          AND o.Status <> 9  
          AND CONVERT(date, p.ApprovedDate) BETWEEN @FromDate AND @ToDate  
          AND (ISNULL(@OrderNo, '') = '' OR o.OrderNo LIKE '%' + @OrderNo + '%')  
          AND (@PaymentType IS NULL OR p.PaymentType = @PaymentType)
          AND (@LocationId IS NULL OR o.LocationId = @LocationId)
          AND (@CustomerId IS NULL OR o.CustomerId = @CustomerId)
          AND (@ReceivedBy IS NULL OR p.PaymentReceivedBy = @ReceivedBy)
          ORDER BY CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'asc' THEN o.OrderNo END  
            ,CASE WHEN @SortBy = 'OrderNo'AND @SortOrder = 'desc' THEN o.OrderNo END DESC  
            ,CASE WHEN @SortBy = 'CustomerName'AND @SortOrder = 'asc' THEN c.FirstName + ' ' + ISNULL(c.LastName,'') END  
            ,CASE WHEN @SortBy = 'CustomerName'AND @SortOrder = 'desc' THEN c.FirstName + ' ' + ISNULL(c.LastName,'') END DESC  
            ,CASE WHEN @SortBy = 'PhoneNumber'AND @SortOrder = 'asc' THEN c.PhoneNumber END  
            ,CASE WHEN @SortBy = 'PhoneNumber'AND @SortOrder = 'desc' THEN c.PhoneNumber END DESC  
            ,CASE WHEN @SortBy = 'ReceivedAmount'AND @SortOrder = 'asc' THEN p.ReceivedAmount END  
            ,CASE WHEN @SortBy = 'ReceivedAmount'AND @SortOrder = 'desc' THEN p.ReceivedAmount END DESC  
            ,CASE WHEN @SortBy = 'SalesmanName'AND @SortOrder = 'asc' THEN au.Firstname + ' ' + au.LastName END  
            ,CASE WHEN @SortBy = 'SalesmanName'AND @SortOrder = 'desc' THEN au.Firstname + ' ' + au.LastName END DESC  
            ,CASE WHEN @SortBy = 'ApprovedDate'AND @SortOrder = 'asc' THEN p.ApprovedDate END  
            ,CASE WHEN @SortBy = 'ApprovedDate'AND @SortOrder = 'desc' THEN p.ApprovedDate END DESC  
            ,CASE WHEN @SortBy = 'ApprovedBy'AND @SortOrder = 'asc' THEN p.PaymentApprovedBy END  
            ,CASE WHEN @SortBy = 'ApprovedBy'AND @SortOrder = 'desc' THEN p.PaymentApprovedBy END DESC  
            ,CASE WHEN @SortBy = 'PaymentType'AND @SortOrder = 'asc' THEN p.PaymentType END  
            ,CASE WHEN @SortBy = 'PaymentType'AND @SortOrder = 'desc' THEN p.PaymentType END DESC
            ,CASE WHEN @SortBy = 'TransactionId'AND @SortOrder = 'asc' THEN p.TransactionId END  
            ,CASE WHEN @SortBy = 'TransactionId'AND @SortOrder = 'desc' THEN p.TransactionId END DESC
            ,CASE WHEN @SortBy = 'ReceivedDate'AND @SortOrder = 'asc' THEN p.ReceivedDate END  
            ,CASE WHEN @SortBy = 'ReceivedDate'AND @SortOrder = 'desc' THEN p.ReceivedDate END DESC
            ,CASE WHEN @SortBy = 'ReceivedBy'AND @SortOrder = 'asc' THEN ISNULL(receivedBy.FirstName + ' ' + receivedBy.LastName, '') + CASE WHEN receivedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END END  
            ,CASE WHEN @SortBy = 'ReceivedBy'AND @SortOrder = 'desc' THEN ISNULL(receivedBy.FirstName + ' ' + receivedBy.LastName, '') + CASE WHEN receivedBy.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END END DESC
            ,CASE WHEN @SortBy = 'LocationName' AND @SortOrder = 'asc' THEN l.LocationName END
            ,CASE WHEN @SortBy = 'LocationName' AND @SortOrder = 'desc' THEN l.LocationName END DESC

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
END

GO

