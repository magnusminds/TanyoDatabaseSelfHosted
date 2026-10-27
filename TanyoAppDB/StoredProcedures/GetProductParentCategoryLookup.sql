/*
 EXEC [dbo].[GetProductParentCategoryLookup]
  @TenantId = 1207
*/
CREATE   PROCEDURE [dbo].[GetProductParentCategoryLookup]
(
    @TenantId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            c.CategoryId,
            c.CategoryName,
            CAST (CASE WHEN EXISTS (
                SELECT 1
                FROM Categories sub WITH (NOLOCK)
                WHERE sub.ParentCategoryId = c.CategoryId
                  AND sub.IsDeleted = 0
            ) THEN 1 ELSE 0 END AS BIT) AS HasSubCategory,
            c.CoverImage
        FROM Categories c WITH (NOLOCK)
        WHERE c.ParentCategoryId IS NULL
          AND c.CategoryTypeId = 1
          AND c.IsDeleted = 0
          AND c.TenantId = @TenantId
        ORDER BY c.CategoryName;
    END TRY

    BEGIN CATCH

        DECLARE @ObjectName VARCHAR(500),
                @ErrorMsg VARCHAR(MAX);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
            @ObjectName = @ObjectName,
            @ErrorMsg = @ErrorMsg;
    END CATCH
END

GO

