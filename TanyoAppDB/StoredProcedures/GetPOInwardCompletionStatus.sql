CREATE PROCEDURE [dbo].[GetPOInwardCompletionStatus]  
(  
    @TenantId INT,  
    @POProductId BIGINT  
)  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
  
    BEGIN TRY  
  
        ;WITH InwardBase AS (  
            SELECT ie.InwardId  
            FROM InwardEntry ie  
            WHERE ie.POProductId = @POProductId  
              AND ie.IsDeleted = 0  
              AND ie.TenantId = @TenantId  
        ),  
        InwardedQty AS (  
            SELECT   
                ide.ProductId,  
                SUM(ide.Quantity) AS TotalInwardQty  
            FROM InwardDetailsEntry ide  
            INNER JOIN InwardBase ib ON ide.InwardId = ib.InwardId  
            WHERE ide.IsDeleted = 0  
            GROUP BY ide.ProductId  
        )  
        SELECT   
            pii.POProductItemId,  
            pii.ProductId,  
            pii.Quantity AS POQty,  
            ISNULL(iq.TotalInwardQty, 0) AS TotalInwardQty,  
            CAST(  
                CASE   
                    -- Product-level completion: a line completes only when the product's TOTAL
                    -- PO qty (all duplicate lines summed) has been inwarded — never compare
                    -- product-wide inwarded qty against a single line's qty.
                    WHEN ISNULL(iq.TotalInwardQty, 0) >= SUM(pii.Quantity) OVER (PARTITION BY pii.ProductId)   
                        THEN 1   
                    ELSE 0   
                END  
            AS BIT) AS IsCompleted  
        FROM POProductItems pii  
        LEFT JOIN InwardedQty iq ON iq.ProductId = pii.ProductId  
        WHERE pii.POProductId = @POProductId  
  
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

