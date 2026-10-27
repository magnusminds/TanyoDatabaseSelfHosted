/*
EXEC [dbo].[ReportFlaggedInquiries]
     @TenantId = 1207
    ,@InquiryNo    = NULL
    ,@CustomerName = NULL
    ,@PhoneNumber  = NULL
    ,@SalesmanId   = NULL
    ,@SortBy       = 'InquiryDate'
    ,@SortOrder    = 'DESC'
    ,@PageNumber   = 1
    ,@PageSize     = 10;
*/
CREATE PROCEDURE [dbo].[ReportFlaggedInquiries]
     @TenantId BIGINT 
    ,@InquiryNo        VARCHAR(100)    = NULL
    ,@CustomerName     NVARCHAR(100)   = NULL
    ,@PhoneNumber      VARCHAR(16)     = NULL
    ,@SalesmanId       BIGINT          = NULL
    ,@SortBy           VARCHAR(50)     = 'InquiryDate'
    ,@SortOrder        VARCHAR(4)      = 'DESC'
    ,@PageNumber       INT             = 1
    ,@PageSize         INT             = 10
WITH ENCRYPTION
AS
BEGIN
    BEGIN TRY
    SET NOCOUNT ON;

    SELECT 
         O.OrderNo AS InquiryNo
        ,O.OrderId
        ,LTRIM(RTRIM(CONCAT(U.FirstName, ' ', U.LastName))) + CASE WHEN U.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName
        ,LTRIM(RTRIM(CONCAT(C.FirstName, ' ', C.LastName)))  AS CustomerName
        ,O.CustomerID AS CustomerId
        ,C.PhoneNumber
        ,O.AmountBeforeGST AS ProductAmount
        ,ISNULL(O.CGSTAmount, 0) + ISNULL(O.SGSTAmount, 0) AS TaxAmount
        ,O.TotalAmount
        ,O.Status AS OrderStatus
        ,O.CreatedDate AS InquiryDate
        ,L.LocationName
        ,O.IsFlagged
        ,COUNT(1) OVER() AS TotalCount
    FROM Orders O WITH (NOLOCK)
    INNER JOIN Customers C WITH (NOLOCK) ON O.CustomerID = C.CustomerId
    INNER JOIN AspNetUsers U WITH (NOLOCK) ON U.UserId = O.SalesmanId
    INNER JOIN Locations L WITH (NOLOCK) ON O.LocationId = L.LocationID
    WHERE 
        O.IsFlagged = 1
        AND O.TenantId = @TenantId
        AND (@InquiryNo IS NULL OR @InquiryNo = '' OR O.OrderNo LIKE '%' + @InquiryNo + '%')
        AND (@CustomerName IS NULL OR @CustomerName = '' OR CONCAT(C.FirstName, ' ', C.LastName) LIKE '%' + @CustomerName + '%')
        AND (@PhoneNumber IS NULL OR @PhoneNumber = '' OR C.PhoneNumber LIKE '%' + @PhoneNumber + '%')
        AND (@SalesmanId IS NULL OR O.SalesmanId = @SalesmanId)
    ORDER BY
        --Sorting
         CASE WHEN @SortOrder = 'ASC' AND @SortBy = 'OrderNo' THEN O.OrderNo END ASC
        ,CASE WHEN @SortOrder = 'DESC' AND @SortBy = 'OrderNo' THEN O.OrderNo END DESC
        ,CASE WHEN @SortOrder = 'ASC' AND @SortBy = 'SalesmanName' THEN CONCAT(U.FirstName, ' ', U.LastName) END ASC
        ,CASE WHEN @SortOrder = 'DESC' AND @SortBy = 'SalesmanName' THEN CONCAT(U.FirstName, ' ', U.LastName) END DESC
        ,CASE WHEN @SortOrder = 'ASC' AND @SortBy = 'CustomerName' THEN CONCAT(C.FirstName, ' ', C.LastName) END ASC
        ,CASE WHEN @SortOrder = 'DESC' AND @SortBy = 'CustomerName' THEN CONCAT(C.FirstName, ' ', C.LastName) END DESC
        ,CASE WHEN @SortOrder = 'ASC' AND @SortBy = 'PhoneNumber' THEN C.PhoneNumber END ASC
        ,CASE WHEN @SortOrder = 'DESC' AND @SortBy = 'PhoneNumber' THEN C.PhoneNumber END DESC
        ,CASE WHEN @SortOrder = 'ASC' AND @SortBy = 'TotalAmount' THEN O.TotalAmount END ASC
        ,CASE WHEN @SortOrder = 'DESC' AND @SortBy = 'TotalAmount' THEN O.TotalAmount END DESC
        ,CASE WHEN @SortOrder = 'ASC' AND @SortBy = 'InquiryDate' THEN O.CreatedDate END ASC
        ,CASE WHEN @SortOrder = 'DESC' AND @SortBy = 'InquiryDate' THEN O.CreatedDate END DESC
        ,O.OrderId DESC
    OFFSET ((@PageNumber - 1) * @PageSize) ROWS
    FETCH NEXT @PageSize ROWS ONLY;
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

