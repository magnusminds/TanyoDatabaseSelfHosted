/*
 EXEC [dbo].[GetOrdersByStatusForApp]
  @StatusValue = 2,
  @IsArchiveOrders = 0,
  @TenantID = 1207,
  @IsAdmin = 1,
  @SuperAccess = 0,
  @WholesalerFlag = 0,
  @UserId = 1,
  @CustomerId = NULL,
  @SalesmanId = NULL,
  @PriorityId = NULL,
  @FilterBy = NULL,
  @OrderNo = NULL,
  @CustomerName = NULL,
  @SalesmanName = NULL,
  @OrderFromDate = NULL,
  @OrderToDate = NULL,
  @TentativeDeliveryFromDate = NULL,
  @TentativeDeliveryToDate = NULL
*/
CREATE PROCEDURE [dbo].[GetOrdersByStatusForApp]
(
    @StatusValue INT = NULL,
    @IsArchiveOrders BIT,
    @TenantID INT,
    @IsAdmin BIT,
    @SuperAccess BIT,
    @WholesalerFlag BIT,
    @UserId INT,
    @CustomerId BIGINT = NULL,
    @SalesmanId INT = NULL,
    @PriorityId BIGINT = NULL,
    @FilterBy INT = NULL,
    @OrderNo VARCHAR(50) = NULL,
    @CustomerName VARCHAR(200) = NULL,
    @SalesmanName VARCHAR(200) = NULL,
    @OrderFromDate DATE = NULL,
    @OrderToDate DATE = NULL,
    @TentativeDeliveryFromDate DATE = NULL,
    @TentativeDeliveryToDate DATE = NULL
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @OrderType SMALLINT = CASE WHEN @WholesalerFlag = 1 THEN 2 ELSE 1 END;      

        ;WITH LatestFollowUp AS (
            SELECT fo.OrderId, fo.FollowUpDate, fo.FollowUpComment,
                   ROW_NUMBER() OVER (PARTITION BY fo.OrderId ORDER BY fo.CreatedDate DESC) AS rn
            FROM FollowUpOrders fo WITH (NOLOCK)
            INNER JOIN Orders o WITH (NOLOCK) ON fo.OrderId = o.OrderId
            WHERE o.TenantId = @TenantID
        )
        SELECT
            o.OrderId,
            o.CustomerID AS CustomerId,
            o.OrderNo,
            TRIM(CONCAT(c.FirstName, ' ', c.LastName)) AS CustomerName,
            ROUND(o.AmountBeforeGST + o.CGSTAmount + o.SGSTAmount
                + ISNULL(o.DeliveryCharges, 0)
                + CASE
                    WHEN o.DeliveryAmount IS NOT NULL
                         AND o.DeliveryAmountCollectionType IS NOT NULL
                         AND o.DeliveryAmountCollectionType = 1
                    THEN ISNULL(o.DeliveryAmount, 0)
                    ELSE 0
                  END
                - ISNULL(o.LumpsumDiscount, 0), 0) AS TotalAmount,
            CASE
                WHEN @IsArchiveOrders = 1 THEN CAST(o.Status AS VARCHAR(50))
                WHEN @CustomerId IS NOT NULL THEN CAST(o.Status AS VARCHAR(50))
                ELSE ISNULL(CAST(@StatusValue AS VARCHAR(50)), CAST(o.Status AS VARCHAR(50)))
            END AS OrderStatus,
            o.CreatedDate AS OrderDate,
            o.ApprovedDate,
            u.FirstName + ' ' + u.LastName AS SalesmanName,
            u.FirstName,
            u.LastName,
            o.LumpsumDiscount,
            o.DeliveryAmountCollectionType,
            o.CreatedBy,
            o.DeliveryAmount,
            ISNULL(l.ColorCode, '') AS PriorityColorCode,
            ISNULL(l.LabelName, '') AS PriorityLabel,
            o.LabelId AS PriorityId,
            lf.FollowUpDate,
            lf.FollowUpComment AS FollowUpLastComment,
            lf.FollowUpComment,
            o.IsFlagged,
            o.IsPinned,
            o.DeliveryDate,
            o.TentativeDeliveryDate,
            o.IsArchive,
            CASE WHEN o.IsArchive = 1 THEN o.ArchiveOrderDate ELSE NULL END AS ArchiveOrderDate,
            ISNULL(o.CustomerVisitCount, 0) AS CustomerVisitCount,
            u.IsDeleted AS IsSalesmanDeleted,
            o.SalesmanId,
            o.UpdatedDate,
            o.OrderType
        FROM Orders o WITH (NOLOCK)
        INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
        INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.SalesmanId = u.UserId
        LEFT JOIN Labels l WITH (NOLOCK) ON o.LabelId = l.LabelId
        LEFT JOIN LatestFollowUp lf WITH (NOLOCK) ON o.OrderId = lf.OrderId AND lf.rn = 1
        WHERE o.TenantId = @TenantID
          AND o.Status <> 9
          AND ( o.IsArchive = @IsArchiveOrders )
          --AND (@CustomerId IS NOT NULL OR @StatusValue IS NULL OR o.Status = @StatusValue)
          AND (
              (@CustomerId IS NOT NULL AND @StatusValue IS NULL AND o.Status <> 9)
              OR (@StatusValue IS NOT NULL AND o.Status = @StatusValue)
              OR (@CustomerId IS NULL AND @StatusValue IS NULL)
          )
          AND (
              @IsAdmin = 1
              OR (@SuperAccess = 1 AND o.OrderType = @OrderType)
              OR (@CustomerId IS NOT NULL 
                    --AND o.CreatedBy = @UserId AND o.OrderType = @OrderType
                 )
              OR (@CustomerId IS NULL AND o.SalesmanId = @UserId AND o.OrderType = @OrderType)
          )
          AND (@CustomerId IS NULL OR o.CustomerID = @CustomerId)
          AND (@SalesmanId IS NULL OR o.SalesmanId = @SalesmanId)
          AND (@PriorityId IS NULL OR o.LabelId = @PriorityId)
          AND (@FilterBy IS NULL
               OR (@FilterBy = 1 AND o.IsPinned = 1)
               OR (@FilterBy = 2 AND o.IsFlagged = 1))
          AND (@OrderNo IS NULL OR o.OrderNo LIKE '%' + @OrderNo + '%')
          AND (@CustomerName IS NULL OR (c.FirstName + ' ' + c.LastName) LIKE '%' + @CustomerName + '%')
          AND (@SalesmanName IS NULL OR (u.FirstName + ' ' + u.LastName) LIKE '%' + @SalesmanName + '%')
          AND (@OrderFromDate IS NULL OR (o.ApprovedDate IS NOT NULL AND CAST(o.ApprovedDate AS DATE) >= @OrderFromDate))
          AND (@OrderToDate IS NULL OR (o.ApprovedDate IS NOT NULL AND CAST(o.ApprovedDate AS DATE) <= @OrderToDate))
          AND (@TentativeDeliveryFromDate IS NULL OR (o.TentativeDeliveryDate IS NOT NULL AND o.TentativeDeliveryDate >= @TentativeDeliveryFromDate))
          AND (@TentativeDeliveryToDate IS NULL OR (o.TentativeDeliveryDate IS NOT NULL AND o.TentativeDeliveryDate <= @TentativeDeliveryToDate))
        ORDER BY o.IsPinned DESC, o.OrderId DESC;

    END TRY

    BEGIN CATCH

        DECLARE @ObjectName VARCHAR(500),
                @ErrorMsg NVARCHAR(4000);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
            @ObjectName = @ObjectName,
            @ErrorMsg = @ErrorMsg;
    END CATCH
END

GO

