-- =============================================      
--Author  : MagnusMinds -- Create date :  14-07-2025 -    
--Description : Report - Product Attributes -- =============================================      
/*      
  EXEC [dbo].[ReportProductAttribute]    
  @TenantId = 1,    
  @ProductTitle = '',    
  @ModelNo = '',    
  @CategoryId = NULL,    
  @PageIndex = 1,    
  @PageSize = 50,    
  @SortBy = 'Label1',    
  @SortOrder = 'asc';    
    
*/
CREATE PROCEDURE [dbo].[ReportProductAttribute]
(
    @TenantId INT,
    @ProductTitle VARCHAR(100) = '',
    @ModelNo VARCHAR(100) = '',
    @CategoryId BIGINT = NULL,
    @PageIndex INT = 1,
    @PageSize INT = 50,
    @SortBy VARCHAR(50) = 'ProductTitle',
    @SortOrder VARCHAR(4) = 'ASC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @ColumnList NVARCHAR(MAX);
        DECLARE @ColumnListWithIsNull NVARCHAR(MAX);
        DECLARE @DynamicSQL NVARCHAR(MAX);
        DECLARE @OrderByClause NVARCHAR(MAX);
        DECLARE @LookupId INT;

        SELECT TOP 1 @LookupId = LookupId
        FROM Lookups
        WHERE LookupName = 'ProductCustomLabel'
          AND TenantId = @TenantId
          AND IsDeleted = 0;

        SELECT
            @ColumnList = STRING_AGG(QUOTENAME(LV.LookupValueName), ','),
            @ColumnListWithIsNull = STRING_AGG(
                'ISNULL(' + QUOTENAME(LV.LookupValueName) + ', '''') AS ' + QUOTENAME(LV.LookupValueName),
                ', '
            )
        FROM LookupValues LV
        WHERE LV.LookupId = @LookupId AND LV.IsDeleted = 0;

        IF @ColumnList IS NULL SET @ColumnList = '';
        IF @ColumnListWithIsNull IS NULL SET @ColumnListWithIsNull = '';

        DECLARE @AllowedColumns TABLE (Col NVARCHAR(128));
        INSERT INTO @AllowedColumns (Col) VALUES
            ('ProductTitle'), ('ModelNo'), ('CategoryName');

        IF @ColumnList <> ''
        BEGIN
            INSERT INTO @AllowedColumns (Col)
            SELECT TRIM(REPLACE(REPLACE(value, '[', ''), ']', ''))
            FROM STRING_SPLIT(@ColumnList, ',');
        END

        IF NOT EXISTS (SELECT 1 FROM @AllowedColumns WHERE Col = @SortBy)
            SET @SortBy = 'ProductTitle';

        IF UPPER(@SortOrder) NOT IN ('ASC', 'DESC')
            SET @SortOrder = 'ASC';

		SET @OrderByClause = 'LTRIM(RTRIM(' + QUOTENAME(@SortBy) + ')) ' + @SortOrder + ', ProductId ASC';

        IF ISNULL(@ColumnList, '') <> ''
        BEGIN
            SET @DynamicSQL = '
            ;WITH SourceData AS (
                SELECT
                    P.ProductId,
                    P.ProductTitle,
                    P.ModelNo,
                    C.CategoryName,
                    CAST(P.CategoryId AS BIGINT) AS CategoryId,
                    LV.LookupValueName,
                    PCF.CustomValue
                FROM Products P WITH (NOLOCK)
                INNER JOIN Categories C WITH (NOLOCK) ON P.CategoryId = C.CategoryId
                    AND C.IsDeleted = 0
                    AND C.TenantId = @TenantId
                INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
                LEFT JOIN ProductCustomFields PCF WITH (NOLOCK) ON P.ProductId = PCF.ProductId
                    AND PCF.TenantId = @TenantId
                    AND PCF.IsDeleted = 0
                LEFT JOIN LookupValues LV WITH (NOLOCK)
                    ON PCF.LookupValueId = LV.LookupValueId
                WHERE
                    P.TenantId = @TenantId
                    AND P.Status <> 3
				    AND (  
					    ISNULL(@CategoryId, - 1) = - 1  
					    OR p.CategoryId = @CategoryId  
				    )
				    AND (@ProductTitle IS NULL OR P.ProductTitle LIKE ''%'' + @ProductTitle + ''%'')
				    AND (@ModelNo IS NULL OR P.ModelNo LIKE ''%'' + @ModelNo + ''%'')
            ),
            Pivoted AS (
                SELECT *
                FROM SourceData
                PIVOT (
                    MAX(CustomValue)
                    FOR LookupValueName IN (' + @ColumnList + ')
                ) AS PivotResult
            )
            SELECT
                T.ProductId,
                T.ProductTitle,
                T.ModelNo,
                T.CategoryName,
                T.CategoryId,
                COUNT(*) OVER() AS TotalCount,
                (
                    SELECT ' + @ColumnListWithIsNull + '
                    FROM Pivoted AS P
                    WHERE P.ProductId = T.ProductId
                    FOR JSON PATH, WITHOUT_ARRAY_WRAPPER
                ) AS CustomFieldsJson
            FROM Pivoted AS T
            ORDER BY ' + @OrderByClause + '
            OFFSET (@PageIndex - 1) * @PageSize ROWS
            FETCH NEXT @PageSize ROWS ONLY';
        END
        ELSE
        BEGIN
            SET @DynamicSQL = '
            ;WITH SourceData AS (
                SELECT
                    P.ProductId,
                    P.ProductTitle,
                    P.ModelNo,
                    C.CategoryName,
                    CAST(P.CategoryId AS BIGINT) AS CategoryId,
                    LV.LookupValueName,
                    PCF.CustomValue
                FROM Products P WITH (NOLOCK)
                INNER JOIN Categories C WITH (NOLOCK) ON P.CategoryId = C.CategoryId
                    AND C.IsDeleted = 0
                    AND C.TenantId = @TenantId
                INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
                LEFT JOIN ProductCustomFields PCF WITH (NOLOCK) ON P.ProductId = PCF.ProductId
                    AND PCF.TenantId = @TenantId
                    AND PCF.IsDeleted = 0
                LEFT JOIN LookupValues LV WITH (NOLOCK)
                    ON PCF.LookupValueId = LV.LookupValueId
                WHERE
                    P.TenantId = @TenantId
                    AND P.Status <> 3
				    AND (  
					    ISNULL(@CategoryId, - 1) = - 1  
					    OR p.CategoryId = @CategoryId  
				    )
				    AND (@ProductTitle IS NULL OR P.ProductTitle LIKE ''%'' + @ProductTitle + ''%'')
				    AND (@ModelNo IS NULL OR P.ModelNo LIKE ''%'' + @ModelNo + ''%'')
            ),
            Pivoted AS (
                SELECT *
                FROM SourceData
            )
            SELECT
                T.ProductId,
                T.ProductTitle,
                T.ModelNo,
                T.CategoryName,
                T.CategoryId,
                COUNT(*) OVER() AS TotalCount,
                '''' AS CustomFieldsJson
            FROM Pivoted AS T
            ORDER BY ' + @OrderByClause + '
            OFFSET (@PageIndex - 1) * @PageSize ROWS
            FETCH NEXT @PageSize ROWS ONLY';
        END

		PRINT @DynamicSQL

        EXEC sp_executesql @DynamicSQL,
            N'@TenantId INT, @ProductTitle VARCHAR(100), @ModelNo VARCHAR(100), @CategoryId BIGINT, @PageIndex INT, @PageSize INT',
            @TenantId = @TenantId,
            @ProductTitle = @ProductTitle,
            @ModelNo = @ModelNo,
            @CategoryId = @CategoryId,
            @PageIndex = @PageIndex,
            @PageSize = @PageSize;

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

GO

