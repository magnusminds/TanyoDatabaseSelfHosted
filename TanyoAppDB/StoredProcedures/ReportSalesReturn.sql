-- =============================================
-- Author       : MagnusMinds
-- Create date  : 03-07-2026
-- Description  : Report - Sales Return
-- =============================================
/*
EXEC [dbo].[ReportSalesReturn]
     @TenantId = 2
    ,@ReturnFromDate = NULL
    ,@ReturnToDate = NULL
    ,@CustomerId = NULL
    ,@InwardNo = NULL
    ,@OrderNo = NULL
    ,@ProductTitle = NULL
    ,@ModelNo = NULL
    ,@WarehouseId = NULL
    ,@CreatedBy = NULL
    ,@PageIndex = 1
    ,@PageSize = 100
    ,@SortBy = 'ReturnDate'
    ,@SortOrder = 'DESC'
*/
CREATE   PROCEDURE [dbo].[ReportSalesReturn]
(
     @TenantId INT
    ,@ReturnFromDate DATE = NULL
    ,@ReturnToDate DATE = NULL
    ,@CustomerId BIGINT = NULL
    ,@InwardNo VARCHAR(100) = NULL
    ,@OrderNo VARCHAR(100) = NULL
    ,@ProductTitle VARCHAR(500) = NULL
    ,@ModelNo VARCHAR(100) = NULL
    ,@WarehouseId BIGINT = NULL
    ,@CreatedBy INT = NULL
    ,@PageIndex INT = 1
    ,@PageSize INT = 100
    ,@SortBy VARCHAR(50) = 'ReturnDate'
    ,@SortOrder VARCHAR(4) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        DECLARE
             @TotalCount INT = 0
            ,@GrandTotalReturnQty DECIMAL(18,2) = 0
            ,@GrandTotalReturnAmount DECIMAL(18,2) = 0
            ,@SQL NVARCHAR(MAX);

        CREATE TABLE #SalesReturnData
        (
             InwardId BIGINT
            ,InwardDetailsId BIGINT
            ,ReturnDate DATETIME
            ,ReturnDateDisplay VARCHAR(30)
            ,InwardNo VARCHAR(100)
            ,OrderNo VARCHAR(100)
            ,CustomerName VARCHAR(500)
            ,ModelNo VARCHAR(100)
            ,ProductTitle VARCHAR(500)
            ,QuantityReturned DECIMAL(18,2)
            ,ReturnAmount DECIMAL(18,2)
            ,Warehouse VARCHAR(200)
            ,CreatedBy INT
            ,CreatedByName VARCHAR(300)
        );

        INSERT INTO #SalesReturnData
        (
             InwardId
            ,InwardDetailsId
            ,ReturnDate
            ,ReturnDateDisplay
            ,InwardNo
            ,OrderNo
            ,CustomerName
            ,ModelNo
            ,ProductTitle
            ,QuantityReturned
            ,ReturnAmount
            ,Warehouse
            ,CreatedBy
            ,CreatedByName
        )
        SELECT
             ie.InwardId
            ,ide.InwardDetailsId
            ,ie.CreatedDate
            ,FORMAT(ie.CreatedDate,'dd/MM/yyyy hh:mm tt')
            ,ie.InwardEntryNumber
            ,o.OrderNo
            ,LTRIM(RTRIM(ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'')))
            ,ISNULL(p.ModelNo,'')
            ,p.ProductTitle
            ,ide.Quantity
            ,CAST
            (
                ROUND(CASE
                    WHEN osi.OrderSetItemId IS NOT NULL
                         AND osi.Quantity > 0
                         AND (osi.AmountBeforeGST + osi.CGSTAmount + osi.SGSTAmount) > 0
                        THEN (osi.AmountBeforeGST + osi.CGSTAmount + osi.SGSTAmount)
                             * ide.Quantity / osi.Quantity

                    ELSE ide.Quantity * ISNULL(p.RetailerPrice,0)
                END, 0)
                AS DECIMAL(18,2)
            )
            ,ISNULL(w.Name,'-')
            ,ie.CreatedBy
            ,LTRIM(RTRIM(ISNULL(u.FirstName,'') + ' ' + ISNULL(u.LastName,'')))
        FROM dbo.InwardEntry ie
        INNER JOIN dbo.InwardDetailsEntry ide
            ON ie.InwardId = ide.InwardId
           AND ide.IsDeleted = 0
        INNER JOIN dbo.Products p
            ON p.ProductId = ide.ProductId
        LEFT JOIN dbo.Orders o
            ON o.OrderId = ie.OrderId
        LEFT JOIN dbo.Customers c
            ON c.CustomerId = ie.CustomerId
        LEFT JOIN dbo.Warehouse w
            ON w.Id = ide.WarehouseId
        LEFT JOIN dbo.OrderSetItems osi
            ON osi.OrderSetItemId = ide.OrderSetItemId
           AND osi.IsDeleted = 0
        LEFT JOIN dbo.AspNetUsers u
           ON u.UserId = ie.CreatedBy
        WHERE ie.TenantId = @TenantId
          AND ie.IsDeleted = 0
          AND ie.InwardType = 3
          AND
          (
                @ReturnFromDate IS NULL
                OR ie.CreatedDate >= @ReturnFromDate
          )
          AND
          (
                @ReturnToDate IS NULL
                OR ie.CreatedDate < DATEADD(DAY,1,@ReturnToDate)
          )
          AND
          (
                ISNULL(@CustomerId,0)=0
                OR ie.CustomerId=@CustomerId
          )
          AND
          (
                @InwardNo IS NULL
                OR ie.InwardEntryNumber LIKE '%' + @InwardNo + '%'
          )
          AND
          (
                @OrderNo IS NULL
                OR o.OrderNo LIKE '%' + @OrderNo + '%'
          )
          AND
          (
                @ProductTitle IS NULL
                OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
          )
          AND
          (
                @ModelNo IS NULL
                OR p.ModelNo LIKE '%' + @ModelNo + '%'
          )
          AND
          (
                ISNULL(@WarehouseId,0)=0
                OR ide.WarehouseId=@WarehouseId
          )
          AND
          (
                ISNULL(@CreatedBy,0)=0
                OR ie.CreatedBy=@CreatedBy
          );

        SELECT
             @TotalCount = COUNT(*)
            ,@GrandTotalReturnQty = ISNULL(SUM(QuantityReturned),0)
            ,@GrandTotalReturnAmount = ISNULL(SUM(ReturnAmount),0)
        FROM #SalesReturnData;

        CREATE TABLE #PagedData
        (
             InwardId BIGINT
            ,InwardDetailsId BIGINT
            ,ReturnDate DATETIME
            ,ReturnDateDisplay VARCHAR(30)
            ,InwardNo VARCHAR(100)
            ,OrderNo VARCHAR(100)
            ,CustomerName VARCHAR(500)
            ,ModelNo VARCHAR(100)
            ,ProductTitle VARCHAR(500)
            ,QuantityReturned DECIMAL(18,2)
            ,ReturnAmount DECIMAL(18,2)
            ,Warehouse VARCHAR(200)
            ,CreatedBy INT
            ,CreatedByName VARCHAR(300)
        );
        
        SET @SQL = N'

        INSERT INTO #PagedData
        (
             InwardId
            ,InwardDetailsId
            ,ReturnDate
            ,ReturnDateDisplay
            ,InwardNo
            ,OrderNo
            ,CustomerName
            ,ModelNo
            ,ProductTitle
            ,QuantityReturned
            ,ReturnAmount
            ,Warehouse
            ,CreatedBy
            ,CreatedByName
        )

        SELECT
             InwardId
            ,InwardDetailsId
            ,ReturnDate
            ,ReturnDateDisplay
            ,InwardNo
            ,OrderNo
            ,CustomerName
            ,ModelNo
            ,ProductTitle
            ,QuantityReturned
            ,ReturnAmount
            ,Warehouse
            ,CreatedBy
            ,CreatedByName
        FROM #SalesReturnData
        ORDER BY ' +

        CASE @SortBy

            WHEN 'ReturnDate' THEN 'ReturnDate'

            WHEN 'InwardNo' THEN 'InwardNo'

            WHEN 'OrderNo' THEN 'OrderNo'

            WHEN 'CustomerName' THEN 'CustomerName'

            WHEN 'ModelNo' THEN 'ModelNo'

            WHEN 'ProductTitle' THEN 'ProductTitle'

            WHEN 'QuantityReturned' THEN 'QuantityReturned'

            WHEN 'ReturnAmount' THEN 'ReturnAmount'

            WHEN 'Warehouse' THEN 'Warehouse'

            WHEN 'CreatedByName' THEN 'CreatedByName'

            ELSE 'ReturnDate'

        END +

        CASE
            WHEN UPPER(@SortOrder) = 'ASC'
                THEN ' ASC '
            ELSE
                ' DESC '
        END +

        ', InwardDetailsId DESC

        OFFSET ' + CAST(((@PageIndex - 1) * @PageSize) AS VARCHAR(20)) + ' ROWS

        FETCH NEXT ' + CAST(@PageSize AS VARCHAR(20)) + ' ROWS ONLY;';

     EXEC (@SQL);

        DECLARE
             @PageTotalReturnQty DECIMAL(18,2)
            ,@PageTotalReturnAmount DECIMAL(18,2);

        SELECT
             @PageTotalReturnQty = ISNULL(SUM(QuantityReturned),0)
            ,@PageTotalReturnAmount = ISNULL(SUM(ReturnAmount),0)
        FROM #PagedData;

        SELECT
             InwardId
            ,InwardDetailsId
            ,ReturnDateDisplay AS ReturnDate
            ,InwardNo
            ,OrderNo
            ,CustomerName
            ,ModelNo
            ,ProductTitle
            ,QuantityReturned
            ,ReturnAmount
            ,Warehouse
            ,CreatedBy
            ,CreatedByName
            ,@TotalCount AS TotalCount
            ,@PageTotalReturnQty AS PageTotalReturnQty
            ,@PageTotalReturnAmount AS PageTotalReturnAmount
            ,@GrandTotalReturnQty AS GrandTotalReturnQty
            ,@GrandTotalReturnAmount AS GrandTotalReturnAmount
        FROM #PagedData;

        DROP TABLE #PagedData;
        DROP TABLE #SalesReturnData;
    END TRY
    BEGIN CATCH

        IF OBJECT_ID('tempdb..#PagedData') IS NOT NULL
            DROP TABLE #PagedData;

        IF OBJECT_ID('tempdb..#SalesReturnData') IS NOT NULL
            DROP TABLE #SalesReturnData;

        DECLARE
             @ErrorMessage NVARCHAR(MAX)
            ,@ErrorSeverity INT
            ,@ErrorState INT;

        SELECT
             @ErrorMessage = ERROR_MESSAGE()
            ,@ErrorSeverity = ERROR_SEVERITY()
            ,@ErrorState = ERROR_STATE();

        RAISERROR
        (
             @ErrorMessage
            ,@ErrorSeverity
            ,@ErrorState
        );

    END CATCH
END

GO

