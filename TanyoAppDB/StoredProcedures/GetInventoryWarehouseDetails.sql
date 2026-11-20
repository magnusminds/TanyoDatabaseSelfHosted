/*
    EXEC [dbo].[GetInventoryWarehouseDetails] 
	    @ProductId = 406
	    ,@WarehouseId = NULL
*/
CREATE   PROCEDURE [dbo].[GetInventoryWarehouseDetails]
    @ProductId BIGINT
    ,@WarehouseId BIGINT = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
       EXEC [GetInventoryWarehouseDetailsV2]
         @ProductId = @ProductId
    ,@WarehouseId = @WarehouseId

       RETURN

    DECLARE @TotalQuantity NUMERIC(18,2) = 0
            ,@ReadyToDeliver NUMERIC(18,2) = 0
            ,@WarehouseTotal NUMERIC(18,2) = 0
            ,@ProductSubjectTypeId INT = 0

    SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
	AND TenantId = (SELECT TenantId FROM Products WITH (NOLOCK) WHERE ProductId = @ProductId)
	AND IsDeleted = 0

    SELECT @TotalQuantity = ISNULL(Quantity, 0)
    FROM ProductQuantities WITH (NOLOCK)
    WHERE ProductId = @ProductId

	DROP TABLE IF EXISTS #Result
	
    CREATE TABLE #Result (
        ID INT IDENTITY
        ,WarehouseId BIGINT
        ,WarehouseName NVARCHAR(255)
        ,Quantity NUMERIC(18,2)
    )

    INSERT INTO #Result (WarehouseId, WarehouseName, Quantity)
    SELECT 
        w.Id
        ,W.Name AS WarehouseName
        ,PW.Quantity
    FROM ProductQuantitiesByWarehouse PW WITH (NOLOCK)
    INNER JOIN Warehouse W WITH (NOLOCK) ON PW.WarehouseId = W.Id
    WHERE PW.ProductId = @ProductId
    AND (@WarehouseId IS NULL OR @WarehouseId = -1 OR PW.WarehouseId = @WarehouseId)
    ORDER BY W.Name

    SELECT @WarehouseTotal = SUM(Quantity)
    FROM ProductQuantitiesByWarehouse WITH (NOLOCK)
    WHERE ProductId = @ProductId
    AND (@WarehouseId IS NULL OR @WarehouseId = -1 OR WarehouseId = @WarehouseId)

    --SELECT @ReadyToDeliver = ISNULL(SUM(OSI.Quantity), 0)
    --FROM Orders O WITH (NOLOCK)
    --INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON O.OrderId = OSI.OrderId
    --    AND osi.IsDeleted = 0
    --WHERE OSI.SubjectId = @ProductId
    --AND O.Status IN (2, 3)  -- Approved, InProgress

    SELECT @ReadyToDeliver = ISNULL(SUM(vi.Quantity),0)
    FROM vw_ReadyToDeliveredItems vi WITH (NOLOCK)
    WHERE vi.SubjectId = @ProductId
    AND vi.SubjectTypeId = @ProductSubjectTypeId

    INSERT INTO #Result (WarehouseId, WarehouseName, Quantity)
    VALUES (-2, 'Ready To Deliver', @ReadyToDeliver)

    DECLARE @FinalTotal INT
    SET @FinalTotal = ISNULL(@WarehouseTotal, 0) + (ISNULL(@TotalQuantity, 0) - ISNULL(@WarehouseTotal, 0))

    SET @FinalTotal = ISNULL(@FinalTotal, 0)

    INSERT INTO #Result (WarehouseId, WarehouseName, Quantity)
    VALUES (-3, 'Total', @FinalTotal)

    SELECT r.WarehouseId
        ,r.WarehouseName
        ,r.Quantity
    FROM #Result r
    ORDER BY 
        CASE 
            WHEN r.WarehouseName = 'Other' THEN 3
            WHEN r.WarehouseId = -2 THEN 4
            WHEN r.WarehouseId = -3 THEN 5
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

