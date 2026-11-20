-- =============================================
-- Author:  MagnusMinds
-- Create date: 22-Jul-2025
-- Description: Get count of Orders which are in StockOnHold status
-- =============================================
/*
EXEC Dashboard_GetStockOnHoldCount
 @TenantId = 2
*/
CREATE PROCEDURE [dbo].[Dashboard_GetStockOnHoldCount]
    @TenantId INT
    ,@UserId INT = NULL
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    DECLARE @dt DATE = CAST(GETDATE() AS DATE)

    SELECT COUNT(DISTINCT soh.OrderSetItemId) AS StatusCount
    FROM StockOnHold soh
    INNER JOIN Orders o ON soh.OrderId = o.OrderId 
		AND o.TenantId = @TenantId
    INNER JOIN OrderSetItems osi ON soh.OrderSetItemId = osi.OrderSetItemId
    WHERE soh.IsStockOnHold = 1
      AND o.Status in (0,1) -- Inquiry
      AND o.IsArchive = 0
      AND DATEADD(DAY, TRY_CAST(soh.TimePeriod AS INT), soh.CreatedDate) > @dt

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

