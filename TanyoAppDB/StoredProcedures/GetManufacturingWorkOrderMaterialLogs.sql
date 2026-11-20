/*
EXEC GetManufacturingWorkOrderMaterialLogs
    @TenantId = 2,
    @UserId = 4279,
    @ManufacturingWorkOrderDetailId = 3,
    @RawMaterialId = 783
*/
CREATE PROCEDURE [dbo].[GetManufacturingWorkOrderMaterialLogs]
(
    @TenantId BIGINT,
    @UserId BIGINT,
    @ManufacturingWorkOrderDetailId BIGINT,
    @RawMaterialId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    SELECT
        MWODL.Description,
        MWODL.ProvidedQty,
        CONCAT(ISNULL(RU.FirstName,''), ' ', ISNULL(RU.LastName,'')) AS ReceivedByUser,
        CONCAT(ISNULL(PU.FirstName,''), ' ', ISNULL(PU.LastName,'')) AS ProvidedByUser,
        FORMAT(MWODL.CreatedDate, 'dd/MM/yy hh:mm tt') AS CreatedDate

    FROM ManufacturingWorkOrderDetailsLog MWODL WITH (NOLOCK)
    LEFT JOIN AspNetUsers RU WITH (NOLOCK)
        ON MWODL.MaterialReceiveId = RU.UserId
    LEFT JOIN AspNetUsers PU WITH (NOLOCK)
        ON MWODL.MaterialProviderId = PU.UserId
    WHERE
        MWODL.ManufacturingWorkOrderDetailId = @ManufacturingWorkOrderDetailId
        AND MWODL.RawMaterialId = @RawMaterialId
    ORDER BY
        MWODL.CreatedDate DESC;


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

