/*
    EXEC [dbo].[GetRawMaterialInventoryWarehouseDetails] 
	    @RawMaterialId = 715
	    ,@WarehouseId = NULL
*/
CREATE   PROCEDURE [dbo].[GetRawMaterialInventoryWarehouseDetails]
    @RawMaterialId BIGINT
    ,@WarehouseId BIGINT = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    DECLARE @TotalQuantity Numeric(18,2) = 0
            ,@ReadyToDeliver Numeric(18,2) = 0
            ,@WarehouseTotal Numeric(18,2) = 0
            ,@ProductSubjectTypeId INT = 0

    SELECT @TotalQuantity = ISNULL(Inventory, 0)
    FROM RawMaterialInventory WITH (NOLOCK)
    WHERE RawMaterialId = @RawMaterialId

	DROP TABLE IF EXISTS #Result
	
    CREATE TABLE #Result (
        ID INT IDENTITY
        ,WarehouseId BIGINT
        ,WarehouseName NVARCHAR(255)
        ,Quantity Numeric(18,2)
    )

    INSERT INTO #Result (WarehouseId, WarehouseName, Quantity)
    SELECT 
        w.Id
        ,W.Name AS WarehouseName
        ,CAST(RW.Quantity AS Numeric(18,2))
    FROM RawMaterialInventoryByWarehouse RW WITH (NOLOCK)
    INNER JOIN Warehouse W WITH (NOLOCK) ON RW.WarehouseId = W.Id
    WHERE RW.RawMaterialId = @RawMaterialId
    AND (@WarehouseId IS NULL OR @WarehouseId = -1 OR RW.WarehouseId = @WarehouseId)
    ORDER BY W.Name

    SELECT @WarehouseTotal = SUM(Quantity)
    FROM RawMaterialInventoryByWarehouse WITH (NOLOCK)
    WHERE RawMaterialId = @RawMaterialId
    AND (@WarehouseId IS NULL OR @WarehouseId = -1 OR WarehouseId = @WarehouseId)

    DECLARE @FinalTotal Numeric(18,2)
    SET @FinalTotal = ISNULL(@WarehouseTotal, 0) + (ISNULL(@TotalQuantity, 0) - ISNULL(@WarehouseTotal, 0))

    SET @FinalTotal = ISNULL(@FinalTotal, 0)

    INSERT INTO #Result (WarehouseId, WarehouseName, Quantity)
    VALUES (-2, 'Total', @FinalTotal)

    SELECT r.WarehouseId
        ,r.WarehouseName
        ,r.Quantity
    FROM #Result r
    ORDER BY 
        CASE 
            WHEN r.WarehouseName = 'Other' THEN 3
            WHEN r.WarehouseId = -2 THEN 4
            ELSE 1 END
        ,r.ID

    DROP TABLE #Result

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

