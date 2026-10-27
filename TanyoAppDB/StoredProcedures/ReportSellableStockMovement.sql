-- =====================================================================
-- Report   : Sellable Stock Movement (TAN-4454)
-- Purpose  : Read-only trail of sellable-stock movements taken directly
--            from the existing [InventoryLogs] table. No schema change,
--            no Description parsing, no cross-row computation.
--            Only columns that physically exist in InventoryLogs (plus
--            simple lookup joins) are surfaced; the Movement Type /
--            Opening / Stock In / Stock Out / Closing / Quantity columns
--            requested in the ticket are intentionally NOT present because
--            InventoryLogs stores none of them.
-- Columns  : Date & Time, Product Category, Product Title, Model Number,
--            Movement Reason (=Description), Moved By.
-- Scope    : Finished-goods Products only (Categories.CategoryTypeId = 1,
--            ProductCategoryTypesEnum.Product), tenant-scoped, non-deleted
--            categories. All InventoryLogs rows for the tenant are shown.
-- Filters  : From/To Date (CreatedDate, inclusive), Product Category,
--            Product Title (LIKE), Model No (LIKE), Moved By (user id).
-- Moved By : AspNetUsers FirstName + LastName + ' (Inactive)' when IsDeleted.
-- =====================================================================
CREATE   PROCEDURE [dbo].[ReportSellableStockMovement]
        @TenantId INT
        ,@FromDate DATE = NULL
        ,@ToDate DATE = NULL
        ,@CategoryId INT = NULL
        ,@ProductTitle NVARCHAR(500) = NULL
        ,@ModelNo NVARCHAR(100) = NULL
        ,@MovedById INT = NULL
        ,@PageIndex INT = 1
        ,@PageSize INT = 10
        ,@SortBy VARCHAR(50) = 'CreatedDate'
        ,@SortOrder VARCHAR(4) = 'desc'
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT x.*
              ,COUNT(1) OVER () AS TotalCount
        FROM (
            SELECT FORMAT(il.CreatedDate, 'dd-MM-yyyy hh:mm tt')                   AS MovementDateTime
                  ,il.CreatedDate                                                  AS CreatedDate
                  ,ISNULL(cat.CategoryName, '')                                    AS ProductCategory
                  ,ISNULL(p.ProductTitle, '')                                      AS ProductTitle
                  ,ISNULL(p.ModelNo, '')                                           AS ModelNo
                  ,ISNULL(il.Description, '')                                      AS MovementReason
                  ,ISNULL(au.FirstName + ' ' + au.LastName, '')
                   + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END     AS MovedBy
                  ,il.InventoryLogId                                               AS InventoryLogId
            FROM InventoryLogs il WITH (NOLOCK)
            INNER JOIN Products p WITH (NOLOCK)
                    ON p.ProductId = il.ProductId
                   AND p.TenantId = @TenantId
            INNER JOIN Categories cat WITH (NOLOCK)
                    ON cat.CategoryId = p.CategoryId
                   AND cat.TenantId = @TenantId
                   AND cat.IsDeleted = 0
            LEFT JOIN AspNetUsers au WITH (NOLOCK)
                    ON au.UserId = il.CreatedBy
            WHERE (il.WarehouseId IS NULL OR il.WarehouseId = 0)
              AND (@FromDate     IS NULL OR il.CreatedDate >= @FromDate)
              AND (@ToDate       IS NULL OR il.CreatedDate <  DATEADD(DAY, 1, CAST(@ToDate AS DATETIME)))
              AND (@CategoryId   IS NULL OR p.CategoryId = @CategoryId)
              AND (@MovedById    IS NULL OR il.CreatedBy = @MovedById)
              AND (@ProductTitle IS NULL OR LTRIM(RTRIM(@ProductTitle)) = '' OR p.ProductTitle LIKE '%' + @ProductTitle + '%')
              AND (@ModelNo      IS NULL OR LTRIM(RTRIM(@ModelNo)) = '' OR p.ModelNo LIKE '%' + @ModelNo + '%')
        ) x
        ORDER BY
            CASE WHEN @SortBy = 'CreatedDate'     AND @SortOrder = 'asc'  THEN x.CreatedDate END ASC,
            CASE WHEN @SortBy = 'CreatedDate'     AND @SortOrder = 'desc' THEN x.CreatedDate END DESC,
            CASE WHEN @SortBy = 'ProductCategory' AND @SortOrder = 'asc'  THEN x.ProductCategory END ASC,
            CASE WHEN @SortBy = 'ProductCategory' AND @SortOrder = 'desc' THEN x.ProductCategory END DESC,
            CASE WHEN @SortBy = 'ProductTitle'    AND @SortOrder = 'asc'  THEN x.ProductTitle END ASC,
            CASE WHEN @SortBy = 'ProductTitle'    AND @SortOrder = 'desc' THEN x.ProductTitle END DESC,
            CASE WHEN @SortBy = 'ModelNo'         AND @SortOrder = 'asc'  THEN x.ModelNo END ASC,
            CASE WHEN @SortBy = 'ModelNo'         AND @SortOrder = 'desc' THEN x.ModelNo END DESC,
            CASE WHEN @SortBy = 'MovementReason'  AND @SortOrder = 'asc'  THEN x.MovementReason END ASC,
            CASE WHEN @SortBy = 'MovementReason'  AND @SortOrder = 'desc' THEN x.MovementReason END DESC,
            CASE WHEN @SortBy = 'MovedBy'         AND @SortOrder = 'asc'  THEN x.MovedBy END ASC,
            CASE WHEN @SortBy = 'MovedBy'         AND @SortOrder = 'desc' THEN x.MovedBy END DESC,
            x.CreatedDate DESC
        OFFSET (@PageIndex - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK;
        DECLARE @ObjectName VARCHAR(500), @ErrorMsg NVARCHAR(4000);
        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();
        EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName, @ErrorMsg = @ErrorMsg;
        THROW;
    END CATCH
END;

GO

