/*  
 EXEC dbo.UpdateOrderRefreshInquiry  
  @OrderId = 226605  
  ,@TenantId = 2  
  ,@UserId = 5237  
*/  
CREATE PROC [dbo].[UpdateOrderRefreshInquiry] (  
 @OrderId BIGINT  
 ,@TenantId BIGINT  
 ,@UserId BIGINT  
 ,@debug BIT = 0  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @dt DATE = CAST(GETDATE() AS DATE)  
  DECLARE @RoleId NVARCHAR(450)  
   ,@GSTType BIT  
   ,@OrderType INT  
   ,@AllowDiscount BIT  
   ,@RoundTo INT  
   ,@ProductSubjectTypeId BIGINT  
   ,@SQFTLookupValueId BIGINT  
   ,@HasWholesalerPermission BIT = 0  
   ,@InquiryExpirationDays INT  
  
  SELECT @RoleId = aur.RoleId  
  FROM AspNetUserRoles aur WITH (NOLOCK)  
  INNER JOIN AspNetUsers au WITH (NOLOCK) ON au.Id = aur.UserId  
  WHERE au.UserId = @UserId  
  
  SELECT @GSTType = o.GSTType  
   ,@OrderType = o.OrderType  
   FROM Orders o WITH (NOLOCK)  
   WHERE o.OrderId = @OrderId  
  
  SELECT @AllowDiscount = tc.IsAllowDiscount  
   ,@RoundTo = t.AmountRoundMultiple  
   ,@InquiryExpirationDays = t.InquiryExpirationDays  
  FROM Tenants t WITH (NOLOCK)  
  INNER JOIN TenantConfigurations AS tc WITH (NOLOCK) ON t.tenantId = tc.TenantId  
  WHERE t.TenantId = @TenantId  
  
  SELECT @ProductSubjectTypeId = st.SubjectTypeId  
  FROM SubjectTypes st WITH (NOLOCK)  
  WHERE st.TenantId = @TenantId  
   AND st.SubjectTypeName = 'Products'  
  
  SELECT @SQFTLookupValueId = lv.LookupValueId  
  FROM LookupValues lv WITH (NOLOCK)  
  INNER JOIN Lookups l WITH (NOLOCK) ON l.LookupId = lv.LookupId  
  WHERE lv.IsDeleted = 0  
   AND l.LookupName = 'ProductCustomLabel'  
   AND lv.LookupValueName = 'SQFT in BOX'  
   AND l.TenantId = @TenantId  
  
  DROP TABLE IF EXISTS #ProductsWithSQFT  
  
  DROP TABLE IF EXISTS #ProductsWithoutSQFT  
  
   CREATE TABLE #ProductsWithSQFT (  
    Id INT PRIMARY KEY IDENTITY  
    ,OrderSetItemId BIGINT  
    ,SQFTInBox VARCHAR(50)  
    ,Quantity NUMERIC(18, 2)  
    ,InstantUnitPrice NUMERIC(18, 2)  
    ,InstantCostPrice NUMERIC(18, 2)  
    ,OfferId INT  
    ,UnitPrice NUMERIC(18, 2)  
    ,DiscountPrice NUMERIC(18, 2)  
    ,MRP NUMERIC(18, 2)  
    ,OfferPercentage INT  
    )  
  
  CREATE TABLE #ProductsWithoutSQFT (  
   Id INT PRIMARY KEY IDENTITY  
   ,OrderSetItemId BIGINT  
   ,ProductId BIGINT  
   ,Width NUMERIC(18, 2)  
   ,Height NUMERIC(18, 2)  
   ,Depth NUMERIC(18, 2)  
   ,Quantity NUMERIC(18, 2)  
   ,InstantUnitPrice NUMERIC(18, 2)  
   ,InstantCostPrice NUMERIC(18, 2)  
   ,OfferId INT  
   ,UnitPrice NUMERIC(18, 2)  
   ,DiscountPrice NUMERIC(18, 2)  
   ,TotalAmount NUMERIC(18, 2)  
   ,MRP NUMERIC(18, 2)  
   ,OfferPercentage INT  
   )  
  
  --IF EXISTS (SELECT 1 FROM AspNetRoleClaims WHERE RoleId = @RoleId AND ClaimValue = 'Permissions.App.Order.WholeselerPrice')  
  -- SET @HasWholesalerPermission = 1  
  IF @OrderType = 2 --Wholesaler Order  
   SET @HasWholesalerPermission = 1  
  
  -- Products sell by without SQFT  
  IF @AllowDiscount = 1  
  BEGIN  
   TRUNCATE TABLE #ProductsWithoutSQFT  
  
   INSERT INTO #ProductsWithoutSQFT (  
    OrderSetItemId  
    ,ProductId  
    ,Width  
    ,Height  
    ,Depth  
    ,Quantity  
    ,InstantUnitPrice  
    ,InstantCostPrice  
    ,OfferId  
    ,UnitPrice  
    ,DiscountPrice  
    ,MRP  
    ,OfferPercentage  
    )  
   SELECT osi.OrderSetItemId  
    ,p.ProductId  
    ,osi.Width  
    ,osi.Height  
    ,osi.Depth  
    ,osi.Quantity  
    ,CASE   
     WHEN @HasWholesalerPermission = 1  
      THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.InstantWidth, osi.InstantHeight, osi.InstantDepth, 4, @OrderId)  
     ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.InstantWidth, osi.InstantHeight, osi.InstantDepth, 5, @OrderId)  
     END AS InstantUnitPrice  
    ,CASE   
     WHEN @HasWholesalerPermission = 1  
      THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 4, @OrderId)  
     ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 1, @OrderId)  
     END AS InstantCostPrice  
    ,ofr.OfferId AS OfferId  
    ,CAST(CASE   
      WHEN @HasWholesalerPermission = 1  
       THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 4, @OrderId)  
      WHEN ofr.OfferId IS NOT NULL  
       THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 3, @OrderId)  
      ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 5, @OrderId)  
      END AS NUMERIC(18, 2)) AS UnitPrice  
    ,osi.DiscountPrice  
    ,CASE   
     WHEN ofr.OfferId IS NOT NULL  
      THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 5, @OrderId)  
     ELSE 0  
     END AS MRP  
    ,OFR.OfferPercentage  
   FROM OrderSetItems osi WITH (NOLOCK)  
   INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId  
    AND p.Status <> 3  
   INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId  
    AND c.IsDeleted = 0  
    AND c.IsSellByPerSQFT = 0  
   LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId  
   WHERE osi.OrderId = @OrderId  
    AND osi.IsDeleted = 0  
    AND osi.SubjectTypeId = @ProductSubjectTypeId  
  
   IF @debug = 1  
    SELECT @HasWholesalerPermission AS WholeSalePermission  
     ,@RoleId AS RoleID  
     ,*  
    FROM #ProductsWithoutSQFT  
  
   UPDATE osi  
   SET osi.InstantUnitPrice = ps.InstantUnitPrice  
    ,osi.InstantCostPrice = ps.InstantCostPrice  
    ,osi.InstantWidth = p.Width  
    ,osi.InstantHeight = p.Height  
    ,osi.InstantDepth = p.Depth  
    ,osi.InstantDiameter = p.Diameter  
    ,osi.OfferId = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferId  
     ELSE NULL  
     END  
    ,osi.UnitPrice = ps.UnitPrice  
    ,osi.GrossTotal = ROUND(CAST(ps.UnitPrice * ps.Quantity AS NUMERIC(18, 2)), 0)  
    ,osi.TotalAmount = ROUND(CAST(CAST((ps.UnitPrice - ROUND((ps.UnitPrice * ps.DiscountPrice) / 100, 2)) AS NUMERIC(18, 2)) * ps.Quantity AS NUMERIC(18, 2)), 0)  
    ,osi.Discount = ROUND(CAST(((ps.UnitPrice * ps.DiscountPrice) / 100) * ps.Quantity AS NUMERIC(18, 2)), 0)  
    ,osi.MRP = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.MRP  
     ELSE 0  
     END  
    ,osi.OfferPercentage = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferPercentage  
     ELSE NULL  
     END  
    ,osi.UnitSalePrice = CAST((ps.UnitPrice - ROUND((ps.UnitPrice * ps.DiscountPrice) / 100, 2)) AS NUMERIC(18, 2))  
   FROM #ProductsWithoutSQFT ps  
   INNER JOIN OrderSetItems osi ON osi.OrderSetItemId = ps.OrderSetItemId  
   INNER JOIN Products p ON p.ProductId = osi.SubjectId  
   WHERE osi.OrderId = @OrderId  
  
   -- Products sell by SQFT only  
   TRUNCATE TABLE #ProductsWithSQFT  
  
   INSERT INTO #ProductsWithSQFT (  
    OrderSetItemId  
    ,SQFTInBox  
    ,Quantity  
    ,InstantUnitPrice  
    ,InstantCostPrice  
    ,OfferId  
    ,UnitPrice  
    ,DiscountPrice  
    ,MRP  
    ,OfferPercentage  
    )  
   SELECT osi.OrderSetItemId  
    ,pcf.CustomValue AS SQFTInBox  
    ,osi.Quantity  
    ,CASE   
     WHEN @HasWholesalerPermission = 1  
      THEN p.WholesalerPrice  
     ELSE p.RetailerPrice  
     END AS InstantUnitPrice  
    ,IIF(p.CostPrice = 0, CASE   
      WHEN @HasWholesalerPermission = 1  
       THEN p.WholesalerPrice  
      ELSE p.RetailerPrice  
      END, p.CostPrice) AS InstantCostPrice  
    ,ofr.OfferId AS OfferId  
    ,CAST(CASE   
      WHEN @HasWholesalerPermission = 1  
       THEN p.WholesalerPrice  
      ELSE IIF(ofr.OfferId IS NOT NULL, p.RetailOfferPrice, p.RetailerPrice)  
      END * pcf.CustomValue AS NUMERIC(18, 2)) AS UnitPrice  
    ,osi.DiscountPrice  
    ,CASE   
     WHEN ofr.OfferId IS NOT NULL  
      THEN p.RetailOfferPrice  
     ELSE 0  
     END AS MRP  
    ,OFR.OfferPercentage  
   FROM OrderSetItems osi WITH (NOLOCK)  
   INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId  
    AND p.Status <> 3  
   INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId  
    AND c.IsDeleted = 0  
    AND c.IsSellByPerSQFT = 1  
   INNER JOIN ProductCustomFields pcf WITH (NOLOCK) ON pcf.ProductId = p.ProductId  
    AND pcf.LookupValueId = @SQFTLookupValueId  
   LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId  
   WHERE osi.OrderId = @OrderId  
    AND osi.IsDeleted = 0  
    AND osi.SubjectTypeId = @ProductSubjectTypeId  
  
   UPDATE osi  
   SET osi.InstantUnitPrice = ps.InstantUnitPrice  
    ,osi.InstantCostPrice = ps.InstantCostPrice  
    ,osi.OfferId = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferId  
     ELSE NULL  
     END  
    ,osi.UnitPrice = ps.UnitPrice  
    ,osi.GrossTotal = ROUND(CAST(ps.UnitPrice * ps.Quantity AS NUMERIC(18, 2)), 0)  
    ,osi.TotalAmount = ROUND(CAST(CAST((ps.UnitPrice - ROUND((ps.UnitPrice * ps.DiscountPrice) / 100, 2)) AS NUMERIC(18, 2)) * ps.Quantity AS NUMERIC(18, 2)), 0)  
    ,osi.Discount = ROUND(CAST(((ps.UnitPrice * ps.DiscountPrice) / 100) * ps.Quantity AS NUMERIC(18, 2)), 0)  
    ,osi.MRP = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.MRP  
     ELSE 0  
     END  
    ,osi.OfferPercentage = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferPercentage  
     ELSE NULL  
     END  
    ,osi.UnitSalePrice = CAST((ps.UnitPrice - ROUND((ps.UnitPrice * ps.DiscountPrice) / 100, 2)) AS NUMERIC(18, 2))  
   FROM #ProductsWithSQFT ps  
   INNER JOIN OrderSetItems osi ON osi.OrderSetItemId = ps.OrderSetItemId  
   WHERE osi.OrderId = @OrderId  
  END  
  ELSE  
  BEGIN  
   PRINT 'IN'  
  
   TRUNCATE TABLE #ProductsWithoutSQFT  
  
   INSERT INTO #ProductsWithoutSQFT (  
    OrderSetItemId  
    ,Quantity  
    ,InstantUnitPrice  
    ,InstantCostPrice  
    ,OfferId  
    ,UnitPrice  
    ,TotalAmount  
    )  
   SELECT osi.OrderSetItemId  
    ,osi.Quantity  
    ,CASE   
     WHEN @HasWholesalerPermission = 1  
      THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.InstantWidth, osi.InstantHeight, osi.InstantDepth, 4, @OrderId)  
     ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.InstantWidth, osi.InstantHeight, osi.InstantDepth, 5, @OrderId)  
     END AS InstantUnitPrice  
    ,CASE   
     WHEN @HasWholesalerPermission = 1  
      THEN [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 4, @OrderId)  
     ELSE [dbo].[GetProductPriceByDimension](@RoleId, @TenantId, p.ProductId, osi.Width, osi.Height, osi.Depth, 1, @OrderId)  
     END AS InstantCostPrice  
    ,NULL AS OfferId  
    ,osi.UnitPrice AS UnitPrice  
    ,osi.UnitPrice * osi.Quantity AS TotalAmount  
   FROM OrderSetItems osi WITH (NOLOCK)  
   INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId  
    AND p.Status <> 3  
   INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId  
    AND c.IsDeleted = 0  
    AND c.IsSellByPerSQFT = 0  
   WHERE osi.OrderId = @OrderId  
    AND osi.IsDeleted = 0  
    AND osi.SubjectTypeId = @ProductSubjectTypeId  
  
   UPDATE osi  
   SET osi.InstantUnitPrice = ps.InstantUnitPrice  
    ,osi.InstantCostPrice = ps.InstantCostPrice  
    ,osi.InstantWidth = p.Width  
    ,osi.InstantHeight = p.Height  
    ,osi.InstantDepth = p.Depth  
    ,osi.InstantDiameter = p.Diameter  
    ,osi.OfferId = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferId  
     ELSE NULL  
     END  
    ,osi.UnitPrice = ps.UnitPrice  
    ,osi.GrossTotal = CAST(ps.UnitPrice * ps.Quantity AS NUMERIC(18, 2))  
    ,osi.TotalAmount = CAST(ps.UnitPrice * ps.Quantity AS NUMERIC(18, 2))  
    ,osi.Discount = 0  
   FROM #ProductsWithoutSQFT ps  
   INNER JOIN OrderSetItems osi ON osi.OrderSetItemId = ps.OrderSetItemId  
   INNER JOIN Products p ON p.ProductId = osi.SubjectId  
   WHERE osi.OrderId = @OrderId  
  
   -- Products sell by SQFT only  
   TRUNCATE TABLE #ProductsWithSQFT  
  
   INSERT INTO #ProductsWithSQFT (  
    OrderSetItemId  
    ,SQFTInBox  
    ,Quantity  
    ,InstantUnitPrice  
    ,InstantCostPrice  
    ,OfferId  
    ,UnitPrice  
    ,DiscountPrice  
    ,OfferPercentage  
    )  
   SELECT osi.OrderSetItemId  
    ,pcf.CustomValue AS SQFTInBox  
    ,osi.Quantity  
    ,CASE   
     WHEN @HasWholesalerPermission = 1  
      THEN p.WholesalerPrice  
     ELSE p.RetailerPrice  
     END AS InstantUnitPrice  
    ,IIF(p.CostPrice = 0, CASE   
      WHEN @HasWholesalerPermission = 1  
       THEN p.WholesalerPrice  
      ELSE p.RetailerPrice  
      END, p.CostPrice) AS InstantCostPrice  
    ,ofr.OfferId AS OfferId  
    ,osi.UnitPrice AS UnitPrice  
    ,osi.DiscountPrice  
    ,OFR.OfferPercentage  
   FROM OrderSetItems osi WITH (NOLOCK)  
   INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId  
    AND p.Status <> 3  
   INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId  
    AND c.IsDeleted = 0  
    AND c.IsSellByPerSQFT = 1  
   INNER JOIN ProductCustomFields pcf WITH (NOLOCK) ON pcf.ProductId = p.ProductId  
    AND pcf.LookupValueId = @SQFTLookupValueId  
   LEFT JOIN ProductOffers ofr ON ofr.ProductId = p.ProductId  
   WHERE osi.OrderId = @OrderId  
    AND osi.IsDeleted = 0  
    AND osi.SubjectTypeId = @ProductSubjectTypeId  
  
   UPDATE osi  
   SET osi.InstantUnitPrice = ps.InstantUnitPrice  
    ,osi.InstantCostPrice = ps.InstantCostPrice  
    ,osi.OfferId = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferId  
     ELSE NULL  
     END  
    ,osi.UnitPrice = ps.UnitPrice  
    ,osi.GrossTotal = CAST(ps.UnitPrice * ps.Quantity AS NUMERIC(18, 2))  
    ,osi.TotalAmount = CAST(ps.UnitPrice * ps.Quantity AS NUMERIC(18, 2))  
    ,osi.Discount = 0  
    ,osi.OfferPercentage = CASE   
     WHEN @HasWholesalerPermission = 0  
      THEN ps.OfferPercentage  
     ELSE NULL  
     END  
   FROM #ProductsWithSQFT ps  
   INNER JOIN OrderSetItems osi ON osi.OrderSetItemId = ps.OrderSetItemId  
   WHERE osi.OrderId = @OrderId  
  END  
  
  EXEC dbo.UpdateOrderGST @OrderID = @OrderId  
   ,@GSTType = @GSTType  
   ,@UserID = @UserId  
   ,@TenantID = @TenantId  
  
  UPDATE o  
  SET o.InquiryExpirationDate = DATEADD(DAY, @InquiryExpirationDays, SYSDATETIMEOFFSET())  
   ,o.InquiryLastUpdatedDate = SYSDATETIMEOFFSET()  
   ,o.UpdatedBy = @UserId  
   ,o.UpdatedDate = SYSDATETIMEOFFSET()  
   ,o.UpdatedUTCDate = GETUTCDATE()  
  FROM Orders o  
  WHERE o.OrderId = @OrderId  
   AND o.TenantId = @TenantId  
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

