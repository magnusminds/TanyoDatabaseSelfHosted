CREATE  PROCEDURE [dbo].[zGetStockTransferHistory]
    (
        @TenantId BIGINT,
        @ProductId BIGINT = NULL
    )
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SELECT
        ST.StockTransferId
        ,ST.ProductId
        ,ST.FromWarehouseId
        ,ST.ToWarehouseId
        ,ST.Quantity
        ,ST.Status
        ,ST.TenantId
        ,ST.CreatedBy
        ,ST.CreatedDate
        ,ST.CreatedUTCDate
        ,FW.Name As FromWarehouseName
        ,TW.Name As ToWarehouseName
        ,P.ProductTitle
        ,ModelNo
        ,CONCAT(AU.FirstName, ' ', AU.LastName) AS TransferredByName
        ,ISNULL(P.CoverImage, '') AS CoverImage
    FROM dbo.StockTransferLog ST WITH (NOLOCK)
    INNER JOIN dbo.Products P ON ST.ProductId = P.ProductId
    INNER JOIN dbo.Warehouse FW ON ST.FromWarehouseId = FW.Id
    INNER JOIN dbo.Warehouse TW ON ST.ToWarehouseId = TW.Id
    INNER JOIN dbo.AspNetUsers AU ON ST.CreatedBy = AU.UserId
    WHERE ST.TenantId = @TenantId
      AND ST.ProductId = @ProductId
    ORDER BY ST.CreatedDate DESC;
END

GO

