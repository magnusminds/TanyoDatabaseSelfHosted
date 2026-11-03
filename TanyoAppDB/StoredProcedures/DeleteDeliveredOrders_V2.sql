--This is being used from Portal to DELETE DELIVERED ORDERS ONLY
/*
    EXEC [dbo].[DeleteDeliveredOrders_V2]
        @OrderId = '84',
        @DeletedBy = 1,
        @ResultMessage = '' OUTPUT

    Multiple Orders:
    EXEC [dbo].[DeleteDeliveredOrders_V2]
        @OrderId = '84,85,86',
        @DeletedBy = 1,
        @ResultMessage = '' OUTPUT
*/
CREATE PROCEDURE [dbo].[DeleteDeliveredOrders_V2]
(
    @OrderId VARCHAR(MAX),
    @DeletedBy BIGINT,
    @ResultMessage VARCHAR(MAX) = '' OUTPUT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE
        @ObjectName VARCHAR(500),

        @IncOrderId BIGINT,
        @OrderSetId BIGINT,
        @TenantId INT,

        @OrderIndex INT = 1,
        @OrderCount INT,

        @OrderSetIndex INT,
        @OrderSetCount INT

        ,@dtoffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtutc DATETIME = GETUTCDATE();

 
    BEGIN TRY

        /*==============================================================
            1. Prepare Order List
        ==============================================================*/

        DROP TABLE IF EXISTS #DelOrder;
        DROP TABLE IF EXISTS #OrderList;

        SELECT DISTINCT
            TRY_CAST(TRIM(ORD.value) AS BIGINT) AS OrderId
        INTO #DelOrder
        FROM STRING_SPLIT(TRIM(@OrderId), ',') ORD
        WHERE TRY_CAST(TRIM(ORD.value) AS BIGINT) IS NOT NULL;


        /*==============================================================
            2. Get Orders
        ==============================================================*/

        SELECT
            ROW_NUMBER() OVER (ORDER BY ORD.OrderId) AS ID,
            ORD.OrderId,
            ORD.OrderNo,
            ORD.TenantId,
            ORD.Status
        INTO #OrderList
        FROM dbo.Orders ORD
        INNER JOIN #DelOrder DORD
            ON DORD.OrderId = ORD.OrderId;

        -- 1. Validate Order exists
        IF NOT EXISTS (SELECT 1 FROM #DelOrder)
            OR EXISTS (
                SELECT 1
                FROM #DelOrder DORD
                LEFT JOIN #OrderList OL
                    ON OL.OrderId = DORD.OrderId
                WHERE OL.OrderId IS NULL
            )
        BEGIN
            SET @ResultMessage = 'Order not found.';
            RETURN;
        END

        -- 2. Validate if order is already deleted
        IF EXISTS (
            SELECT 1 
            FROM #OrderList
            WHERE Status = 9 -- Deleted
        )
        BEGIN
            SET @ResultMessage = 'This order has already been deleted.'
            RETURN;
        END

        IF EXISTS(
            SELECT 1 
            FROM #OrderList
            WHERE Status <> 5 --Delivered
        ) BEGIN
            SET @ResultMessage = 'Only Delivered Orders can be deleted.';
            RETURN
        END

        SELECT @OrderCount = COUNT(1)
        FROM #OrderList;

        BEGIN TRANSACTION DeleteDeliveredOrdersV2;
        
        UPDATE al
		SET AL.Description = LEFT(Description, CASE 
					WHEN (CHARINDEX('for order', Description) - 2) >= 0
						THEN (CHARINDEX('for order', Description) - 2)
					ELSE CASE 
							WHEN (CHARINDEX('From', Description) - 2) >= 0
								THEN (CHARINDEX('From', Description) - 2)
							ELSE CASE 
									WHEN (CHARINDEX('For', Description) - 2) >= 0
										THEN (CHARINDEX('For', Description) - 2)
									ELSE (CHARINDEX(ORDL.OrderNo, Description) - 2)
									END
							END
					END)
		FROM InventoryLogs al
		INNER JOIN OrderSetItems osi
            ON osi.SubjectId = al.ProductId
        INNER JOIN Orders o
            ON o.OrderId = osi.OrderId
            AND al.OrderNo = o.OrderNo
        INNER JOIN #OrderList ORDL ON ordl.OrderId = osi.OrderId
        
        DELETE OC
        FROM dbo.OrderComments OC
        INNER JOIN #OrderList ol
            ON ol.OrderId = OC.OrderId
          
        DELETE PTS
        FROM dbo.Payments PTS
        INNER JOIN #OrderList ol
            ON ol.OrderId = PTS.OrderId
        WHERE PTS.OrderId = @IncOrderId;

        DELETE osi
        FROM OrderSetItems osi
        INNER JOIN OrderSets os
            ON os.OrderSetId = osi.OrderSetId
        INNER JOIN #OrderList ol
            ON ol.OrderId = os.OrderId;
        
        DELETE os
        FROM OrderSets os
        INNER JOIN #OrderList ol
            ON ol.OrderId = os.OrderId;
        
        DELETE o
        FROM Orders o
        INNER JOIN #OrderList ol
            ON ol.OrderId = o.OrderId;


        /*==============================================================
            6. Success Response
        ==============================================================*/

        SET @ResultMessage = '';
        
        COMMIT TRANSACTION DeleteDeliveredOrdersV2;
       
    END TRY

    BEGIN CATCH

        IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION DeleteDeliveredOrdersV2

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ResultMessage = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ResultMessage

		RAISERROR('Error in DeleteDeliveredOrders_V2: %s', 16, 1, @ResultMessage)

    END CATCH
END

GO

