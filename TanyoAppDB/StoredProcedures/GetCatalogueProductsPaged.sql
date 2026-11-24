/*
EXEC [dbo].[GetCatalogueProductsPaged]
    @TenantId = 2,
    @CategoryId = 1,
    @Search = '',
    @Page = 1,
    @PageSize = 50
*/
CREATE PROCEDURE [dbo].[GetCatalogueProductsPaged] (
    @TenantId INT,
    @CategoryId INT = NULL,
    @Search VARCHAR(200) = NULL,
    @Page INT = 1,
    @PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SET @Search = LTRIM(RTRIM(@Search));
        IF @Search = '' SET @Search = NULL;
        IF @CategoryId <= 0 SET @CategoryId = NULL;
        IF @Page < 1 SET @Page = 1;
        IF @PageSize <= 0 SET @PageSize = 50;
        IF @PageSize > 200 SET @PageSize = 200;

        SELECT
            p.ProductId,
            p.ProductTitle,
            p.ModelNo,
            p.CoverImage AS ProductImage,
            c.CategoryName,
            COUNT(1) OVER () AS TotalCount
        FROM dbo.Products p WITH (NOLOCK)
        LEFT JOIN dbo.Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
        WHERE p.TenantId = @TenantId
          AND p.[Status] = 1 -- Published
          AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
          AND (
              @Search IS NULL
              OR p.ProductTitle LIKE '%' + @Search + '%'
              OR p.ModelNo LIKE '%' + @Search + '%'
          )
        ORDER BY p.ProductId ASC
        OFFSET (@Page - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        DECLARE @ObjectName VARCHAR(500), @ErrorMsg NVARCHAR(4000);
        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();
        EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName, @ErrorMsg = @ErrorMsg;
        THROW;
    END CATCH
END
GO
