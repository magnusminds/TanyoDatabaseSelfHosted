/*    
    DECLARE @RESULT INT    
    EXEC [dbo].[UpdateProductOfferPrice] @TenantId = 1, @ProductIds = '97677,97623', @Result = @RESULT OUTPUT    
    SELECT @RESULT    
*/    
-- =============================================     
-- Author      : MagnusMinds    
-- Create date : 28-07-2025    
-- Description : Assign New OfferPrice     
-- =============================================     
CREATE PROCEDURE [dbo].[UpdateProductOfferPrice]    
(    
    @TenantId BIGINT = NULL    
    ,@UserID INT = NULL    
    ,@OfferId BIGINT = NULL    
    ,@CategoryId BIGINT = NULL    
    ,@ProductIds VARCHAR(255) = NULL    
    ,@IsPublished BIT = NULL    
    ,@Result INT OUTPUT    
)    
WITH ENCRYPTION
AS
BEGIN    
    SET NOCOUNT ON;    
    
    DECLARE @ProductTable TABLE (    
        ProductId BIGINT PRIMARY KEY    
    );    
    
    IF ISNULL(@ProductIds, '') <> ''    
    BEGIN    
        INSERT INTO @ProductTable (ProductId)    
        SELECT DISTINCT CAST(TRIM(value) AS BIGINT)    
        FROM STRING_SPLIT(@ProductIds, ',')    
        WHERE TRIM(value) <> '';    
    END    
    
    DECLARE @UpdatedProducts TABLE (    
        ProductId BIGINT    
        ,OldRetailOfferPrice DECIMAL(18, 2)    
        ,NewRetailOfferPrice DECIMAL(18, 2)    
    );    
    
    SET @Result = 0;    
    
    DECLARE @dt DATETIMEOFFSET = SYSDATETIMEOFFSET()    
        ,@dtUTC DATETIME = GETUTCDATE()    
        ,@ProductSubjectTypeId INT;    
    
    SELECT @ProductSubjectTypeId = SubjectTypeId    
 FROM SubjectTypes WITH (NOLOCK)    
 WHERE TenantId = @TenantId    
  AND SubjectTypeName = 'Products';    
    
    BEGIN TRY    
        BEGIN TRANSACTION UpdateProductOfferPrice;    
        IF @IsPublished = 0    
         BEGIN    
            -- If @ProductIds is NULL or empty, set RetailOfferPrice = NULL based on TenantId and OfferId    
            UPDATE p    
            SET p.RetailOfferPrice = NULL    
                ,p.UpdatedBy = @UserID    
                ,p.UpdatedDate = @dt    
                ,p.UpdatedUTCDate = @dtUTC    
            FROM Products p  WITH (NOLOCK)   
            INNER JOIN OfferProductMapping OPM WITH (NOLOCK) ON OPM.ProductId = p.ProductId    
            INNER JOIN Offers O WITH (NOLOCK) ON OPM.OfferId = O.OfferId    
            WHERE (    
                    @TenantId IS NULL OR p.TenantId = @TenantId    
                  )    
                AND (    
                    @OfferId IS NULL OR O.OfferId = @OfferId    
                  )    
                AND p.RetailOfferPrice IS NOT NULL;    
        END    
        ELSE    
        BEGIN     
    
        UPDATE p    
        SET p.RetailOfferPrice = (p.RetailerPrice - ((p.RetailerPrice * po.OfferPercentage) / 100))    
        OUTPUT INSERTED.ProductId    
            ,DELETED.RetailOfferPrice    
            ,INSERTED.RetailOfferPrice    
        INTO @UpdatedProducts(ProductId, OldRetailOfferPrice, NewRetailOfferPrice)    
        FROM Products p  WITH (NOLOCK)   
        INNER JOIN ProductOffers po WITH (NOLOCK) ON po.ProductId = p.ProductId    
        WHERE (    
                @TenantId IS NULL    
                OR po.TenantId = @TenantId    
              )    
            AND (    
                @OfferId IS NULL    
                OR po.OfferId = @OfferId    
              )    
            AND (    
                @CategoryId IS NULL    
                OR p.CategoryId = @CategoryId    
              )    
            AND (    
                ISNULL(@ProductIds, '') = ''    
                OR p.ProductId IN (SELECT ProductId FROM @ProductTable)    
              )    
            AND (ISNULL(p.RetailOfferPrice, 0) <> (p.RetailerPrice - ((p.RetailerPrice * po.OfferPercentage) / 100)));    
        END    
        SET @Result = @@ROWCOUNT;    
    
        COMMIT TRANSACTION UpdateProductOfferPrice;    
    
        IF @Result > 0    
  BEGIN    
   DECLARE @Inc INT = 1    
    ,@Cnt INT    
    ,@SubjectId BIGINT    
    ,@Description VARCHAR(MAX);    
    
   CREATE TABLE #ActivityLogData (    
    RowId INT IDENTITY(1, 1)    
    ,SubjectId BIGINT    
    ,Description VARCHAR(MAX)    
    );    
    
   INSERT INTO #ActivityLogData (    
    SubjectId    
    ,Description    
    )    
   SELECT up.ProductId    
    ,'Offer percentage updated. Retailer offer price changed from ' + CAST(ISNULL(up.OldRetailOfferPrice, 0) AS VARCHAR(100)) + ' to ' + CAST(up.NewRetailOfferPrice AS VARCHAR(100))    
   FROM @UpdatedProducts up;    
    
   SELECT @Cnt = COUNT(1) FROM #ActivityLogData;    
    
   WHILE @Cnt >= @Inc    
   BEGIN    
    SELECT @SubjectId = SubjectId    
     ,@Description = Description    
    FROM #ActivityLogData    
    WHERE RowId = @Inc;    
    
    EXEC dbo.SaveActivityLog @SubjectTypeId = @ProductSubjectTypeId    
     ,@SubjectId = @SubjectId    
     ,@Description = @Description    
     ,@Action = 'UPDATE'    
     ,@CreatedBy = @UserID    
     ,@CreatedDate = @dt    
     ,@CreatedUTCDate = @dtUTC;    
    
    SET @Inc = @Inc + 1;    
   END;    
    
   DROP TABLE #ActivityLogData;    
  END    
    
    
    END TRY    
    
    BEGIN CATCH    
        IF @@TRANCOUNT > 0    
            ROLLBACK TRANSACTION UpdateProductOfferPrice;    
    
        DECLARE @ObjectName VARCHAR(500)    
            ,@ErrorMsg VARCHAR(MAX);    
    
        SET @ObjectName = OBJECT_NAME(@@PROCID);    
        SET @ErrorMsg = ERROR_MESSAGE();    
    
        EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName    
            ,@ErrorMsg = @ErrorMsg;    
    
        SET @Result = -1;    
    END CATCH    
END 