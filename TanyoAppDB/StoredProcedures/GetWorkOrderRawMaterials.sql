/*
EXEC GetWorkOrderRawMaterials
    @TenantId = 2
    ,@UserId = 4279
    ,@ManufacturingWorkOrderId = 2
*/
CREATE   PROCEDURE [dbo].[GetWorkOrderRawMaterials]
(
    @TenantId BIGINT,
    @UserId BIGINT,
    @ManufacturingWorkOrderId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    SELECT
        MWOD.ManufacturingWorkOrderDetailId,
        MWOD.RawMaterialId,

        -- Raw Material Name (handle missing case)
        ISNULL(RM.Title, 'N/A') AS RawMaterialName,

        -- Available Qty
        CAST(ISNULL(RMI.Inventory, 0) AS DECIMAL(18, 2)) AS AvailableQty,

        -- Required Qty (NULL for additionally added materials)
        CAST(MWOD.RequiredQty AS DECIMAL(18, 2)) AS RequiredQty,

        -- Provided Qty (default = Required when not yet issued)
        --CAST(
        --    CASE
        --        WHEN ISNULL(MWOD.IsNotNeeded, 0) = 1 THEN 0
        --        WHEN MWOD.ProvidedQty IS NOT NULL AND MWOD.ProvidedQty > 0 THEN MWOD.ProvidedQty
        --        ELSE ISNULL(MWOD.RequiredQty, 0)
        --    END AS DECIMAL(18, 2)
        --) AS ProvidedQty,
        CAST(ISNULL(MWOD.RequiredQty, 0) AS DECIMAL(18,2)) AS ProvidedQty,

        ISNULL(MWOD.IsNotNeeded, 0) AS IsNotNeeded,

        CAST(CASE
            WHEN ISNULL(MWOD.IsFromBom, 1) = 0 THEN 1
            ELSE 0
        END AS BIT) AS IsAdditional

    FROM ManufacturingWorkOrderDetails MWOD WITH (NOLOCK)
    INNER JOIN ManufacturingWorkOrders MWO WITH (NOLOCK)
        ON MWOD.ManufacturingWorkOrderId = MWO.ManufacturingWorkOrderId
    LEFT JOIN RawMaterials RM WITH (NOLOCK)
        ON MWOD.RawMaterialId = RM.RawMaterialId
    LEFT JOIN RawMaterialInventory RMI WITH (NOLOCK)
        ON RMI.RawMaterialId = MWOD.RawMaterialId
    WHERE
        MWO.ManufacturingWorkOrderId = @ManufacturingWorkOrderId
        AND ISNULL(MWO.IsDeleted, 0) = 0
    ORDER BY
        ISNULL(MWOD.IsFromBom, 1) DESC,
        CAST(ISNULL(RMI.Inventory, 0) AS DECIMAL(18, 2)) ASC,
        RM.Title ASC;

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

