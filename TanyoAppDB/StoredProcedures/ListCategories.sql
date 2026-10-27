
/*  
 EXEC [dbo].[ListCategories]   
  @TenantId = 2  
  ,@CategoryName = NULL  
  ,@FriendlyName = NULL  
  ,@IsFixedPrice = NULL  
  ,@IsManufacturing = NULL  
  ,@PageIndex = 1  
  ,@PageSize = 50  
  ,@SortBy = 'CategoryName'  
  ,@SortOrder = 'ASC'  
  ,@CategoryTypeId = 1  
  ,@CategoryId = NULL  
*/  
CREATE PROCEDURE [dbo].[ListCategories] (  
 @TenantId INT  
 ,@CategoryName VARCHAR(50) = NULL  
 ,@FriendlyName VARCHAR(50) = NULL  
 ,@IsFixedPrice INT = NULL  
 ,@IsManufacturing INT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 100  
 ,@SortBy VARCHAR(50) = '10'  
 ,@SortOrder VARCHAR(50) = 'DESC'  
 ,@CategoryTypeId BIGINT = 1   
 ,@CategoryId BIGINT = NULL  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 DROP TABLE IF EXISTS #ProductCount  
  
 DROP TABLE IF EXISTS #ChildCategories  
  
 DROP TABLE IF EXISTS #ParentCategories  
  
 SELECT p.CategoryId  
  ,COUNT(1) AS ProductCount  
 INTO #ProductCount  
 FROM Products p WITH (NOLOCK)  
 WHERE p.STATUS <> 3  
 and p.TenantId = @TenantId  
 GROUP BY p.CategoryId  
  
  
 SELECT *  
 INTO #ChildCategories  
 FROM Categories WITH (NOLOCK)  
 WHERE ParentCategoryId IS NOT NULL  
 AND TenantId = @TenantId  
 AND IsDeleted = 0  
 AND (  
  @IsFixedPrice IS NULL  
  OR IsFixedPrice = @IsFixedPrice  
  )  
 AND (  
  @IsManufacturing IS NULL  
  OR IsManufacturing = @IsManufacturing  
  )  
 AND (  
  @CategoryTypeId IS NULL  
  OR CategoryTypeId = @CategoryTypeId  
  )  
  
  
 SELECT CategoryId  
  ,CategoryName AS ParentCategoryName  
 INTO #ParentCategories  
 FROM Categories WITH (NOLOCK)  
 WHERE ParentCategoryId IS NULL  
 AND TenantId = @TenantId  
 AND IsDeleted = 0  
  
  
 SELECT c.CategoryId  
  ,c.CategoryName  
  ,pct.ParentCategoryName  
  ,c.FriendlyName  
  ,c.RSPPercentage  
  ,c.WSPPercentage  
  ,c.IsFixedPrice  
  ,c.IsManufacturing AS Manufacturing  
  ,c.IsVisibleInAddOn AS VisibleInAddOn  
  ,c.IsCommissionEnabled  
  ,c.IsCommissionEnabledInterior  
  ,c.IsSellByPerSQFT  
  --,c.IsFabric  
  ,c.GST  
  ,c.MaxDiscount  
  ,ISNULL(pc.ProductCount, 0) AS ProductCount  
  ,ISNULL(vc.ViewCount, 0) AS ViewCount  
  ,ISNULL(sc.SharedCount, 0) AS SharedCount  
  ,CAST(  
      CASE   
          WHEN ISNULL(pc.ProductCount, 0) > 0   
               OR cp.HasChildProducts = 1  
          THEN 1  
          ELSE 0  
      END AS BIT  
  ) AS CategoryHasProducts  
  ,c.CoverImage
  --,CAST(CASE   
  -- WHEN ISNULL(pc.ProductCount, 0) > 0  
  --  OR EXISTS (  
  --   SELECT 1  
  --   FROM #ChildCategories child WITH (NOLOCK)  
  --   INNER JOIN Products p WITH (NOLOCK) ON p.CategoryId = child.CategoryId  
  --   WHERE child.ParentCategoryId = c.CategoryId  
  --    AND p.STATUS <> 3  
  --   )  
  --  THEN 1  
  -- ELSE 0  
  -- END AS bit) AS CategoryHasProducts  
  ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
 FROM Categories c WITH (NOLOCK)  
 LEFT JOIN #ParentCategories pct ON c.ParentCategoryId = pct.CategoryId  
 LEFT JOIN #ProductCount pc ON c.CategoryId = pc.CategoryId  
 LEFT JOIN (  
  SELECT cav.CategoriesId  
   ,COUNT(1) AS ViewCount  
  FROM CategoriesAnonymousViews cav WITH (NOLOCK)  
  GROUP BY cav.CategoriesId  
  ) vc ON c.CategoryId = vc.CategoriesId  
 LEFT JOIN (  
  SELECT sal.SubjectId  
   ,COUNT(1) AS SharedCount  
  FROM SharingActivityLog sal WITH (NOLOCK)  
  GROUP BY sal.SubjectId  
  ) sc ON c.CategoryId = sc.SubjectId  
 LEFT JOIN (  
     SELECT child.ParentCategoryId, 1 AS HasChildProducts  
     FROM #ChildCategories child WITH (NOLOCK)  
     INNER JOIN Products p WITH (NOLOCK)  
         ON p.CategoryId = child.CategoryId  
         AND p.STATUS <> 3  
     GROUP BY child.ParentCategoryId  
 ) cp ON c.CategoryId = cp.ParentCategoryId  
  
 WHERE c.TenantId = @TenantId  
  AND c.IsDeleted = 0  
  AND (  
   @CategoryName IS NULL  
   OR c.CategoryName LIKE '%' + @CategoryName + '%'  
   )  
  AND (  
   @FriendlyName IS NULL  
   OR c.FriendlyName LIKE '%' + @FriendlyName + '%'  
   )  
  AND (  
   @CategoryId IS NULL  
   OR (c.CategoryId = @CategoryId OR c.ParentCategoryId = @CategoryId)  
   )  
  AND (  
   @IsFixedPrice IS NULL  
   OR c.IsFixedPrice = @IsFixedPrice  
   )  
  AND (  
   @IsManufacturing IS NULL  
   OR c.IsManufacturing = @IsManufacturing  
   )  
  AND (  
   @CategoryTypeId IS NULL  
   OR C.CategoryTypeId = @CategoryTypeId  
   )  
 ORDER BY CASE   
   WHEN @SortBy = 'CategoryName'  
    AND @SortOrder = 'ASC'  
    THEN c.CategoryName  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'CategoryName'  
    AND @SortOrder = 'DESC'  
    THEN c.CategoryName  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'ParentCategoryName'  
    AND @SortOrder = 'ASC'  
    THEN pct.ParentCategoryName  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'ParentCategoryName'  
    AND @SortOrder = 'DESC'  
    THEN pct.ParentCategoryName  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'FriendlyName'  
    AND @SortOrder = 'ASC'  
    THEN c.FriendlyName  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'FriendlyName'  
    AND @SortOrder = 'DESC'  
    THEN c.FriendlyName  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'IsFixedPrice'  
    AND @SortOrder = 'ASC'  
    THEN c.IsFixedPrice  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'IsFixedPrice'  
    AND @SortOrder = 'DESC'  
    THEN c.IsFixedPrice  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'IsManufacturing'  
    AND @SortOrder = 'ASC'  
    THEN c.IsManufacturing  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'IsManufacturing'  
    AND @SortOrder = 'DESC'  
    THEN c.IsManufacturing  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'IsVisibleInAddOn'  
    AND @SortOrder = 'ASC'  
    THEN c.IsVisibleInAddOn  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'IsVisibleInAddOn'  
    AND @SortOrder = 'DESC'  
    THEN c.IsVisibleInAddOn  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'IsCommissionEnabled'  
    AND @SortOrder = 'ASC'  
    THEN c.IsCommissionEnabled  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'IsCommissionEnabled'  
    AND @SortOrder = 'DESC'  
    THEN c.IsCommissionEnabled  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'IsCommissionEnabledInterior'  
    AND @SortOrder = 'ASC'  
    THEN c.IsCommissionEnabledInterior  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'IsCommissionEnabledInterior'  
    AND @SortOrder = 'DESC'  
    THEN c.IsCommissionEnabledInterior  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'GST'  
    AND @SortOrder = 'ASC'  
    THEN c.GST  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'GST'  
    AND @SortOrder = 'DESC'  
    THEN c.GST  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'MaxDiscount'  
    AND @SortOrder = 'ASC'  
    THEN c.MaxDiscount  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'MaxDiscount'  
    AND @SortOrder = 'DESC'  
    THEN c.MaxDiscount  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'ProductCount'  
    AND @SortOrder = 'ASC'  
    THEN ISNULL(pc.ProductCount, 0)  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'ProductCount'  
    AND @SortOrder = 'DESC'  
    THEN ISNULL(pc.ProductCount, 0)  
   END DESC  
  ,CASE   
   WHEN @SortBy = 'IsSellByPerSQFT'  
    AND @SortOrder = 'ASC'  
    THEN c.IsSellByPerSQFT  
   END ASC  
  ,CASE   
   WHEN @SortBy = 'IsSellByPerSQFT'  
    AND @SortOrder = 'DESC'  
    THEN c.IsSellByPerSQFT  
   END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS  
  
 FETCH NEXT @PageSize ROWS ONLY  
END

GO

