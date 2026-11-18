CREATE PROC [dbo].[zReport_ListShareProduct]      
(      
    @TenantId INT,      
    @BatchId INT = NULL,      
    @PageIndex INT = 1,      
    @PageSize INT = 50,      
    @SharedBy INT = NULL,      
    @FromDate DATE = NULL,      
    @ToDate DATE = NULL,      
 @CustomerId INT = NULL,      
    @CustomerTypeId INT = NULL,      
 @TagId INT = NULL,    
 @SortBy VARCHAR(100) = NULL,    
    @SortOrder VARCHAR(4) = 'DESC'    
)      
WITH ENCRYPTION
AS
BEGIN      
    SET NOCOUNT ON;      
      
    SELECT       
        bd.Id AS BatchDetailId,      
        ca.CategoryName AS CategoryName,      
  p.ProductTitle AS ProductTitle,      
        p.ModelNo,      
        bd.WholesalerPrice AS WholesalerPrice,      
        c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName,      
        c.CustomerTypeId,      
        l.LabelName AS TagName,      
        P.CoverImage AS ProductImage,      
        au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SharedBy,      
        bd.CreatedDate AS SharedDate,      
        COUNT(1) OVER() AS TotalCount      
      
    FROM dbo.ProductShareBatchDetail bd WITH (NOLOCK)      
    LEFT JOIN dbo.ProductShareBatch b WITH (NOLOCK) ON bd.BatchId = b.Id      
    INNER JOIN dbo.Products p WITH (NOLOCK) ON p.ProductId = bd.ProductId AND p.Status <> 3      
    INNER JOIN dbo.Categories ca WITH (NOLOCK) ON ca.CategoryId = p.CategoryId AND ca.IsDeleted = 0      
    INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = bd.CustomerId AND c.IsDeleted = 0      
    LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = bd.TagId AND l.IsDeleted = 0      
    LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = bd.CreatedBy      
    WHERE bd.TenantId = @TenantId      
        AND (@BatchId IS NULL OR bd.BatchId = @BatchId)      
        AND (@SharedBy IS NULL OR bd.CreatedBy = @SharedBy)      
        AND (@CustomerTypeId IS NULL OR c.CustomerTypeId = @CustomerTypeId)      
  AND (@CustomerId IS NULL OR c.CustomerId = @CustomerId)      
  AND (@TagId IS NULL OR bd.TagId = @TagId)      
        AND (@FromDate IS NULL OR CAST(bd.CreatedDate AS DATE) >= @FromDate)      
        AND (@ToDate IS NULL OR CAST(bd.CreatedDate AS DATE) <= @ToDate)      
     ORDER BY     
        CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN c.FirstName + ' ' + ISNULL(c.LastName, '') END ASC,    
        CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN c.FirstName + ' ' + ISNULL(c.LastName, '') END DESC,    
  CASE WHEN @SortBy = 'SharedBy' AND @SortOrder = 'ASC' THEN au.FirstName + ' ' + ISNULL(au.LastName, '') END ASC,    
  CASE WHEN @SortBy = 'SharedBy' AND @SortOrder = 'DESC' THEN au.FirstName + ' ' + ISNULL(au.LastName, '') END DESC,  
    CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN ca.CategoryName END ASC,  
  CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN ca.CategoryName END DESC,  
        CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle END ASC,    
        CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC,    
        CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN p.ModelNo END ASC,    
        CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN p.ModelNo END DESC,    
        CASE WHEN @SortBy = 'WholesalerPrice' AND @SortOrder = 'ASC' THEN bd.WholesalerPrice END ASC,    
        CASE WHEN @SortBy = 'WholesalerPrice' AND @SortOrder = 'DESC' THEN bd.WholesalerPrice END DESC,    
        CASE WHEN @SortBy = 'SharedDate' AND @SortOrder = 'ASC' THEN bd.CreatedDate END ASC,    
        CASE WHEN @SortBy = 'SharedDate' AND @SortOrder = 'DESC' THEN bd.CreatedDate END DESC,    
        bd.CreatedDate DESC    
      
    OFFSET (@PageIndex - 1) * @PageSize ROWS      
    FETCH NEXT @PageSize ROWS ONLY;      
END

GO

