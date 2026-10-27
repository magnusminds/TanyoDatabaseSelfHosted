-- =============================================
-- Author      : MagnusMinds
-- Create date : 05-10-2026
-- Description : Report - Products without Cost Price
-- =============================================

/*
EXEC [dbo].[ReportProductsWithoutCostPrice]
    @TenantId = 1206,
    @CategoryId = NULL,
    @ModelNumber = NULL,
    @ProductTitle = NULL,
    @PageIndex = 1,
    @PageSize = 1000,
    @SortBy = 'CategoryName',
    @SortOrder = 'ASC'
*/

CREATE PROCEDURE [dbo].[ReportProductsWithoutCostPrice]
(
    @TenantId INT,
    @CategoryId BIGINT = NULL,
    @ModelNumber VARCHAR(50) = NULL,
    @ProductTitle VARCHAR(50) = NULL,
    @PageIndex INT = 1,
    @PageSize INT = 25,
    @SortBy VARCHAR(50) = 'CategoryName',
    @SortOrder VARCHAR(50) = 'ASC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Normalize empty or whitespace strings to NULL
        SET @ModelNumber = NULLIF(LTRIM(RTRIM(@ModelNumber)), '');
        SET @ProductTitle = NULLIF(LTRIM(RTRIM(@ProductTitle)), '');

        IF @CategoryId <= 0
            SET @CategoryId = NULL;

        SELECT
            p.ProductId,
            cat.CategoryName AS Category,
            p.ProductTitle,
            p.ModelNo AS ModelNumber,
            ISNULL(p.CostPrice, 0.0) AS CostPrice,
            ISNULL(p.RetailerPrice, 0.0) AS RetailPrice,
            ISNULL(p.WholesalerPrice, 0.0) AS WholesalePrice,
            COUNT(*) OVER () AS TotalCount
        FROM dbo.Products AS p WITH (NOLOCK)
        INNER JOIN dbo.Categories AS cat WITH (NOLOCK)
            ON p.CategoryId = cat.CategoryId
            AND cat.IsDeleted = 0
        WHERE
            p.TenantId = @TenantId
            AND p.Status != 3
            AND (p.CostPrice = 0 OR p.CostPrice IS NULL)
            AND (@CategoryId IS NULL OR p.CategoryId = @CategoryId)
            AND (@ModelNumber IS NULL OR p.ModelNo LIKE '%' + @ModelNumber + '%')
            AND (@ProductTitle IS NULL OR p.ProductTitle LIKE '%' + @ProductTitle + '%')
        ORDER BY
            CASE
                WHEN @SortBy IN ('Category', 'CategoryName')
                     AND @SortOrder = 'ASC'
                THEN cat.CategoryName
            END ASC,

            CASE
                WHEN @SortBy IN ('Category', 'CategoryName')
                     AND @SortOrder = 'DESC'
                THEN cat.CategoryName
            END DESC,

            CASE
                WHEN @SortBy = 'ProductTitle'
                     AND @SortOrder = 'ASC'
                THEN p.ProductTitle
            END ASC,

            CASE
                WHEN @SortBy = 'ProductTitle'
                     AND @SortOrder = 'DESC'
                THEN p.ProductTitle
            END DESC,

            CASE
                WHEN @SortBy IN ('ModelNumber', 'ModelNo')
                     AND @SortOrder = 'ASC'
                THEN p.ModelNo
            END ASC,

            CASE
                WHEN @SortBy IN ('ModelNumber', 'ModelNo')
                     AND @SortOrder = 'DESC'
                THEN p.ModelNo
            END DESC,

            CASE
                WHEN @SortBy = 'CostPrice'
                     AND @SortOrder = 'ASC'
                THEN p.CostPrice
            END ASC,

            CASE
                WHEN @SortBy = 'CostPrice'
                     AND @SortOrder = 'DESC'
                THEN p.CostPrice
            END DESC,

            CASE
                WHEN @SortBy IN ('RetailPrice', 'RetailerPrice')
                     AND @SortOrder = 'ASC'
                THEN p.RetailerPrice
            END ASC,

            CASE
                WHEN @SortBy IN ('RetailPrice', 'RetailerPrice')
                     AND @SortOrder = 'DESC'
                THEN p.RetailerPrice
            END DESC,

            CASE
                WHEN @SortBy IN ('WholesalePrice', 'WholesalerPrice')
                     AND @SortOrder = 'ASC'
                THEN p.WholesalerPrice
            END ASC,

            CASE
                WHEN @SortBy IN ('WholesalePrice', 'WholesalerPrice')
                     AND @SortOrder = 'DESC'
                THEN p.WholesalerPrice
            END DESC,

            p.ProductId DESC

        OFFSET (@PageIndex - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;

    END TRY
    BEGIN CATCH

        DECLARE
            @ErrorMessage NVARCHAR(4000),
            @ObjectName VARCHAR(500);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMessage = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
            @ObjectName = @ObjectName,
            @ErrorMsg = @ErrorMessage;

    END CATCH
END

GO

