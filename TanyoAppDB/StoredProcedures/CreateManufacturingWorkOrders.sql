/*
EXEC CreateManufacturingWorkOrders
    @OrderId = 42671
    ,@TenantId = 2
    ,@UserId = 4279
*/
CREATE PROCEDURE [dbo].[CreateManufacturingWorkOrders]
(
    @OrderId BIGINT,
    @TenantId BIGINT,
    @UserId INT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        
        Declare @SubjectTypeId INT;

        Select @SubjectTypeId = SubjectTypeId
            FROM SubjectTypes WITH(NOLOCK)
            WHERE SubjectTypeName = 'RawMaterials'
            AND TenantId = @TenantId
        ---------------------------------------------------------
        -- 1️. TEMP: Manufacturing Items WITH BOM ONLY
        ---------------------------------------------------------
        IF OBJECT_ID('tempdb..#MFGItems') IS NOT NULL 
            DROP TABLE #MFGItems;

        SELECT 
            OSI.OrderSetItemId,
            OSI.OrderId,
            OSI.SubjectId AS ProductId,
            OSI.Quantity
        INTO #MFGItems
        FROM OrderSetItems OSI WITH (NOLOCK)
        INNER JOIN Products P WITH (NOLOCK)
            ON P.ProductId = OSI.SubjectId
        INNER JOIN Categories C WITH (NOLOCK)
            ON C.CategoryId = P.CategoryId
        WHERE 
            OSI.OrderId = @OrderId
            AND OSI.IsDeleted = 0
            AND OSI.ParentOrderSetItemId IS NULL
            -- TAN-4714: work orders only for in-house manufacturing
			AND C.IsManufacturing = 1
			AND C.IsInHouseManufacturing = 1
            AND EXISTS (
                SELECT 1 
                FROM ProductMaterials PM WITH (NOLOCK)
                WHERE PM.ProductId = OSI.SubjectId
            )
            AND NOT EXISTS (
                SELECT 1 
                FROM ManufacturingWorkOrders MWO WITH (NOLOCK)
                WHERE MWO.OrderSetItemId = OSI.OrderSetItemId
                  AND MWO.IsDeleted = 0
            );

        ---------------------------------------------------------
        -- 2️. Capture inserted IDs ONLY
        ---------------------------------------------------------
        IF OBJECT_ID('tempdb..#InsertedWorkOrders') IS NOT NULL 
            DROP TABLE #InsertedWorkOrders;

        CREATE TABLE #InsertedWorkOrders
        (
            ManufacturingWorkOrderId BIGINT,
            OrderSetItemId BIGINT
        );

        ---------------------------------------------------------
        -- 3️. Insert WorkOrders
        ---------------------------------------------------------
        INSERT INTO ManufacturingWorkOrders
        (
            OrderSetItemId,
            OrderId,
            CreatedBy
        )
        OUTPUT 
            INSERTED.ManufacturingWorkOrderId,
            INSERTED.OrderSetItemId
        INTO #InsertedWorkOrders
        SELECT
            I.OrderSetItemId,
            I.OrderId,
            @UserId
        FROM #MFGItems I;

        ---------------------------------------------------------
        -- 4️. Insert WorkOrderDetails (BOM)
        ---------------------------------------------------------
        INSERT INTO ManufacturingWorkOrderDetails
        (
            ManufacturingWorkOrderId,
            RawMaterialId,
            RequiredQty,
            ProvidedQty,
            CreatedBy
        )
        SELECT 
            WO.ManufacturingWorkOrderId,
            PM.SubjectId AS RawMaterialId,
            -- Required Qty = OrderQty × BOM Qty
            CAST((MI.Quantity * PM.Qty) AS DECIMAL(18,2)),
            0,
            @UserId
        FROM #InsertedWorkOrders WO
        INNER JOIN #MFGItems MI 
            ON MI.OrderSetItemId = WO.OrderSetItemId
        INNER JOIN ProductMaterials PM WITH (NOLOCK)
            ON PM.ProductId = MI.ProductId AND PM.SubjectTypeId = @SubjectTypeId
        WHERE ISNULL(PM.Qty,0) > 0;

    END TRY

    BEGIN CATCH
        THROW;
    END CATCH
END

GO

