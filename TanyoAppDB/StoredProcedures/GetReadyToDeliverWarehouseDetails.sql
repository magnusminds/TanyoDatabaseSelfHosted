/*
    EXEC [dbo].[GetReadyToDeliverWarehouseDetails]
	    @TenantId   = 1206
        ,@ProductId = 403144
        
*/
CREATE  PROCEDURE [dbo].[GetReadyToDeliverWarehouseDetails]
     @TenantId INT  
     ,@ProductId BIGINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DROP TABLE IF EXISTS #WarehouseDetails;

        CREATE TABLE #WarehouseDetails
        (
             WarehouseId BIGINT
            ,WarehouseName NVARCHAR(255)
            ,Quantity NUMERIC(18,2) NULL
            ,IsDefault BIT NULL
        );


        INSERT INTO #WarehouseDetails
        (
             WarehouseId
            ,WarehouseName
            ,Quantity
            ,IsDefault
        )
        SELECT
             W.Id
            ,W.Name
            ,ISNULL(PQW.Quantity,0)
            ,ISNULL(W.IsDefault, 0)
        FROM dbo.Warehouse W WITH (NOLOCK)
        LEFT JOIN dbo.ProductQuantitiesByWarehouse PQW WITH (NOLOCK)
            ON PQW.WarehouseId = W.Id
              AND PQW.ProductId = @ProductId
        WHERE W.IsDeleted = 0
          AND W.TenantId = @TenantId;

        -- If no default warehouse exists,
        -- mark 'Other' warehouse as default
        IF NOT EXISTS
        (
            SELECT 1
            FROM #WarehouseDetails
            WHERE IsDefault = 1
        )
        BEGIN
            UPDATE #WarehouseDetails
            SET IsDefault = 1
            WHERE WarehouseName = 'Other';
        END;

        SELECT
             WarehouseId
            ,WarehouseName
            ,Quantity
            ,IsDefault
        FROM #WarehouseDetails
        ORDER BY
            CASE
                WHEN IsDefault = 1 THEN 0
                ELSE 1
            END,
            WarehouseName;

        DROP TABLE #WarehouseDetails;

    END TRY

    BEGIN CATCH

        IF OBJECT_ID('tempdb..#WarehouseDetails') IS NOT NULL
            DROP TABLE #WarehouseDetails;

        DECLARE
             @ObjectName VARCHAR(400)
            ,@ErrorMsg VARCHAR(MAX);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
             @ObjectName = @ObjectName
            ,@ErrorMsg = @ErrorMsg;

    END CATCH
END

GO

