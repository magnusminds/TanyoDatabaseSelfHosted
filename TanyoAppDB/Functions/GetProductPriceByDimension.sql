/*  
    -- Wholesaler Price Permission is OFF.  
    -- Product without dimension change, it will return actual price. No calculation  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 198329, 1, 1, 1, 1) -- Cost Price  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 198329, 1, 1, 1, 2) -- Retailer Price  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 198329, 1, 1, 1, 3) -- Retailer Offer Price  
  
    -- Product with dimension change, it will return calculated price.  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 198329, 2, 2, 2, 1) -- Cost Price  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 198329, 2, 2, 2, 2) -- Retailer Price  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 198329, 2, 2, 2, 3) -- Retailer Offer Price  
  
    -- Fabric, No calculation  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 278099, 1, 1, 1, 1) -- Cost Price  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 278099, 1, 1, 1, 2) -- Retailer Price  
    SELECT [dbo].[GetProductPriceByDimension] ('17BE52F0-731D-4215-9CA3-021C068A9F6F', 2, 278099, 1, 1, 1, 3) -- Retailer Offer Price  
  
  
    -- Wholesaler Price Permission is ON.  
    -- Product without dimension change, it will return actual price. No calculation  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 198329, 1, 1, 1, 1) -- Cost Price  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 198329, 1, 1, 1, 2) -- Wholesaler Price  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 198329, 1, 1, 1, 3) -- Wholesaler Offer Price  
  
    -- Product with dimension change, it will return calculated price.  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 198329, 2, 2, 2, 1) -- Cost Price  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 198329, 2, 2, 2, 2) -- Wholesaler Price  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 198329, 2, 2, 2, 3) -- Wholesaler Offer Price  
  
    -- Fabric, No calculation  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 278099, 1, 1, 1, 1) -- Cost Price  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 278099, 1, 1, 1, 2) -- Wholesaler Price  
    SELECT [dbo].[GetProductPriceByDimension] ('C5E937AE-1233-47A8-B668-7710141E2C0C', 2, 278099, 1, 1, 1, 3) -- Wholesaler Offer Price  
*/  
CREATE FUNCTION [dbo].[GetProductPriceByDimension]  
(  
    @RoleId NVARCHAR(50)  
    ,@TenantId INT  
    ,@ProductId INT  
    ,@Width DECIMAL(18, 2)  
    ,@Height DECIMAL(18, 2)  
    ,@Depth DECIMAL(18, 2)  
    ,@PriceType INT  
    ,@OrderId BIGINT = NULL  
)  
RETURNS DECIMAL(18, 2)  
WITH ENCRYPTION
AS
BEGIN  
  
    -- 1. Cost | 2. Retailer/Wholesaler | 3. Retailer Offer   
    -- 4. Wholesaler Price ONLY | 5. Retailer Price ONLY | 6. Retailer Offer Price ONLY  
  
    DECLARE @HasWholesalerPrice BIT = 0;  
    DECLARE @ProductPrice DECIMAL(18, 2);  
    DECLARE @TotalAmount DECIMAL(18, 2) = 0;  
    DECLARE @CostPrice DECIMAL(18, 2);  
    DECLARE @RetailerPrice DECIMAL(18, 2);  
    DECLARE @RetailerOfferPrice DECIMAL(18, 2);  
    DECLARE @WholesalerPrice DECIMAL(18, 2);  
    DECLARE @ProductWidth DECIMAL(18, 2);  
    DECLARE @ProductHeight DECIMAL(18, 2);  
    DECLARE @ProductDepth DECIMAL(18, 2);  
    DECLARE @CategoryName NVARCHAR(255);  
    DECLARE @TenantAmountRoundMultiple INT;  
    DECLARE @CostPerCubic DECIMAL(18,6);  
    DECLARE @TotalCubic DECIMAL(18, 6);  
    DECLARE @NewCostPrice DECIMAL(18, 2);  
    DECLARE @IsProduct BIT = 0;  
    DECLARE @IsAllowDimension BIT = 0;  
  
    -- Check Dimension  
    SELECT @IsAllowDimension = ISNULL(tc.IsAllowDimensionsChange, 0)  
    FROM TenantConfigurations tc WITH (NOLOCK)  
    WHERE tc.TenantId = @TenantId;  
  
    -- Check Wholesaler Price Permission  
    IF ISNULL(@OrderId, 0) > 0  
    BEGIN  
        -- Use OrderType from the order when OrderId is passed  
        SELECT @HasWholesalerPrice = CASE  
            WHEN o.OrderType = 2 THEN 1  
            ELSE 0  
        END  
        FROM Orders o WITH (NOLOCK)  
        WHERE o.OrderId = @OrderId;  
    END  
    ELSE IF (@RoleId IS NOT NULL AND @RoleId <> '')  
    BEGIN  
        SELECT @HasWholesalerPrice = CASE WHEN EXISTS (  
            SELECT 1   
            FROM AspNetRoleClaims WITH (NOLOCK)  
            WHERE RoleId = @RoleId  
            AND ClaimValue IN ('Permissions.App.Order.WholeselerPrice', 'Permissions.General.Order.WholeselerPrice')  
        ) THEN 1 ELSE 0 END;  
    END  
  
    -- Fetch product data  
    SELECT @CostPrice = IIF(p.CostPrice = 0, p.RetailerPrice, p.CostPrice)  
        ,@RetailerPrice = ISNULL(p.RetailerPrice, 0)  
        ,@RetailerOfferPrice = ISNULL(p.RetailOfferPrice, 0)  
        ,@WholesalerPrice = ISNULL(p.WholesalerPrice, 0)  
        ,@ProductWidth = p.Width  
        ,@ProductHeight = p.Height  
        ,@ProductDepth = p.Depth  
        ,@CategoryName = (SELECT CategoryName FROM Categories WITH (NOLOCK) WHERE CategoryId = p.CategoryId)  
    FROM Products p WITH (NOLOCK)  
    WHERE p.ProductId = @ProductId  
    AND p.TenantId = @TenantId  
  
    -- Check if the category is a product category  
    IF EXISTS (SELECT TOP 1 1  
            FROM Categories c WITH (NOLOCK)  
            WHERE c.CategoryName = @CategoryName  
            AND c.TenantId = @TenantId  
            AND c.CategoryTypeId = 1)  
    BEGIN  
        SET @IsProduct = 1  
    END  
  
    IF @PriceType = 1 -- Product Cost Price  
    BEGIN  
        SET @ProductPrice = @CostPrice  
    END  
    ELSE IF @PriceType = 2 -- Product Retailer/Wholesaler Price  
    BEGIN  
        IF @HasWholesalerPrice = 1 -- Check Wholesaler Price permission  
        BEGIN  
            SET @ProductPrice = @WholesalerPrice  
        END  
        ELSE  
        BEGIN  
            SET @ProductPrice = @RetailerPrice  
        END  
    END  
    ELSE IF @PriceType = 3 -- Product Retailer Offer Price  
    BEGIN  
        IF @HasWholesalerPrice = 1 -- Check Wholesaler Price permission  
        BEGIN  
            SET @ProductPrice = 0.00 -- No Offer applicable in Wholesaler Price  
        END  
        ELSE  
        BEGIN  
            SET @ProductPrice = @RetailerOfferPrice  
        END  
    END  
    ELSE IF @PriceType = 4 -- Product Wholesaler Price ONLY  
    BEGIN  
        SET @ProductPrice = @WholesalerPrice  
    END  
    ELSE IF @PriceType = 5 -- Product Retailer Price ONLY  
    BEGIN  
        SET @ProductPrice = @RetailerPrice  
    END  
    ELSE IF @PriceType = 6 -- Product Retailer Offer Price ONLY  
    BEGIN  
        SET @ProductPrice = @RetailerOfferPrice  
    END  
  
    -- If not a product category, return price  
    IF @IsProduct = 0 OR @IsAllowDimension = 0  
    BEGIN  
        RETURN @ProductPrice  
    END  
  
    -- Fetch tenant roundoff amount  
    SELECT @TenantAmountRoundMultiple = AmountRoundMultiple  
    FROM Tenants WITH (NOLOCK)  
    WHERE TenantId = @TenantId  
  
    IF NULLIF(@ProductWidth,0) IS NULL  
        SET @ProductWidth = 1;  
    IF NULLIF(@ProductHeight,0) IS NULL  
        SET @ProductHeight = 1;  
    IF NULLIF(@ProductDepth,0) IS NULL  
        SET @ProductDepth = 1;  
  
    IF NULLIF(@Width,0) IS NULL  
        SET @Width = 1;  
    IF NULLIF(@Height,0) IS NULL  
        SET @Height = 1;  
    IF NULLIF(@Depth,0) IS NULL  
        SET @Depth = 1;  
  
    IF @TenantId = 1 -- Shreem Furniture  
    BEGIN  
        -- Perform calculations based on category  
        IF @CategoryName IN ('Sofa / Corner / Lounger', 'office sofa fix price')  
        BEGIN  
            SET @CostPerCubic = @ProductPrice / @ProductWidth;  
            SET @TotalCubic = @Width;  
            SET @NewCostPrice = @TotalCubic * @CostPerCubic;  
        END  
        ELSE IF CHARINDEX('marble', @CategoryName) > 0  
        BEGIN  
            SET @CostPerCubic = @ProductPrice / (@ProductWidth * @ProductDepth);  
            SET @TotalCubic = @Width * @Depth;  
            SET @NewCostPrice = @TotalCubic * @CostPerCubic;  
        ENd  
        ELSE  
        BEGIN  
            SET @NewCostPrice = @ProductPrice  
        END  
    END  
    ELSE IF @TenantId IN (9, 26) --Demo and Reflection  
    BEGIN  
        SET @CostPerCubic = @ProductPrice / @ProductWidth;  
        SET @TotalCubic = @Width;  
        SET @NewCostPrice = @TotalCubic * @CostPerCubic;  
    END  
    ELSE  
    BEGIN  
        SET @CostPerCubic = @ProductPrice / (@ProductWidth * @ProductHeight * @ProductDepth);  
        SET @TotalCubic = @Width * @Height * @Depth;  
        SET @NewCostPrice = @TotalCubic * @CostPerCubic;  
    END  
  
    -- Calculate rounded price  
    RETURN CAST(ROUND(  
        CASE   
            WHEN @TenantAmountRoundMultiple IS NOT NULL AND @TenantAmountRoundMultiple > 0 THEN   
                @TenantAmountRoundMultiple * ROUND(@NewCostPrice / @TenantAmountRoundMultiple, 2)  
            ELSE   
                @NewCostPrice  
        END, 2  
    ) AS NUMERIC(18, 2));  
END

GO

