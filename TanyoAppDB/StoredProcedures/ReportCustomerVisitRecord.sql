-- =============================================
-- Author       : MagnusMinds
-- Create date  : 06-07-2026
-- Description  : Report - Customer Visit Record
-- =============================================
/*
    EXEC [dbo].[ReportCustomerVisitRecord]
        @TenantId = 2,
        @VisitFromDate = '2026-01-01',
        @VisitToDate = '2026-07-06',
        @CustomerName = NULL,
        @CustomerContactNumber = NULL,
        @SalesmanName = NULL,
        @InquiryFor = NULL,
        @PageIndex = 1,
        @PageSize = 50,
        @SortBy = 'VisitDate',
        @SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[ReportCustomerVisitRecord] (
    @TenantId INT,
    @VisitFromDate DATE = NULL,
    @VisitToDate DATE = NULL,
    @CustomerName VARCHAR(500) = NULL,
    @CustomerContactNumber VARCHAR(50) = NULL,
    @SalesmanName VARCHAR(500) = NULL,
    @InquiryFor BIGINT = NULL,
    @PageIndex INT = 1,
    @PageSize INT = 50,
    @SortBy VARCHAR(50) = 'VisitDate',
    @SortOrder VARCHAR(4) = 'DESC'
    )
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            cv.CustomerVisitId,
            LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))) AS CustomerName,
            c.PhoneNumber AS CustomerContactNumber,
            FORMAT(cv.CreatedDate, 'dd/MM/yyyy') AS VisitDate,
            FORMAT(cv.CreatedDate, 'hh:mm tt') AS VisitTime,
            LTRIM(RTRIM(ISNULL(u.FirstName, '') + ' ' + ISNULL(u.LastName, ''))) AS SalesmanName,
            cat.CategoryName AS InquiryFor,
            cv.Comment,
            COUNT(*) OVER() AS TotalCount
        FROM dbo.CustomerVisits cv WITH (NOLOCK)
        INNER JOIN dbo.Customers c WITH (NOLOCK)
            ON cv.CustomerId = c.CustomerId
        INNER JOIN dbo.AspNetUsers u WITH (NOLOCK)
            ON cv.CreatedBy = u.UserId
        LEFT JOIN dbo.Categories cat WITH (NOLOCK)
            ON cv.CategoryId = cat.CategoryId
        WHERE
            c.TenantId = @TenantId
            AND c.IsDeleted = 0
            AND (@VisitFromDate IS NULL OR CONVERT(DATE, cv.CreatedDate) >= @VisitFromDate)
            AND (@VisitToDate IS NULL OR CONVERT(DATE, cv.CreatedDate) <= @VisitToDate)
            AND (
                    ISNULL(@CustomerName,'') = ''
                    OR LTRIM(RTRIM(ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'')))
                        LIKE '%' + @CustomerName + '%'
                )
            AND (
                    ISNULL(@CustomerContactNumber,'') = ''
                    OR c.PhoneNumber LIKE '%' + @CustomerContactNumber + '%'
                    OR ISNULL(c.AltPhoneNumber,'') LIKE '%' + @CustomerContactNumber + '%'
                )
            AND (
                    ISNULL(@SalesmanName,'') = ''
                    OR LTRIM(RTRIM(ISNULL(u.FirstName,'') + ' ' + ISNULL(u.LastName,'')))
                        LIKE '%' + @SalesmanName + '%'
                )
            AND (
                    @InquiryFor IS NULL
                    OR cv.CategoryId = @InquiryFor
                )
        ORDER BY
            CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN LTRIM(RTRIM(ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,''))) END ASC,
            CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN LTRIM(RTRIM(ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,''))) END DESC,

            CASE WHEN @SortBy = 'CustomerContactNumber' AND @SortOrder = 'ASC' THEN c.PhoneNumber END ASC,
            CASE WHEN @SortBy = 'CustomerContactNumber' AND @SortOrder = 'DESC' THEN c.PhoneNumber END DESC,

            CASE WHEN @SortBy = 'VisitDate' AND @SortOrder = 'ASC' THEN cv.CreatedDate END ASC,
            CASE WHEN @SortBy = 'VisitDate' AND @SortOrder = 'DESC' THEN cv.CreatedDate END DESC,

            CASE WHEN @SortBy = 'VisitTime' AND @SortOrder = 'ASC' THEN cv.CreatedDate END ASC,
            CASE WHEN @SortBy = 'VisitTime' AND @SortOrder = 'DESC' THEN cv.CreatedDate END DESC,

            CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'ASC' THEN LTRIM(RTRIM(ISNULL(u.FirstName,'') + ' ' + ISNULL(u.LastName,''))) END ASC,
            CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'DESC' THEN LTRIM(RTRIM(ISNULL(u.FirstName,'') + ' ' + ISNULL(u.LastName,''))) END DESC,

            CASE WHEN @SortBy = 'InquiryFor' AND @SortOrder = 'ASC' THEN cat.CategoryName END ASC,
            CASE WHEN @SortBy = 'InquiryFor' AND @SortOrder = 'DESC' THEN cat.CategoryName END DESC,

            CASE WHEN @SortBy = 'Comment' AND @SortOrder = 'ASC' THEN cv.Comment END ASC,
            CASE WHEN @SortBy = 'Comment' AND @SortOrder = 'DESC' THEN cv.Comment END DESC,

            -- Default sorting
            cv.CreatedDate DESC
        OFFSET (@PageIndex - 1) * @PageSize ROWS
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

