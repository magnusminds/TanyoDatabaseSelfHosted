/* 
EXEC  [GetInwardById]
    @InwardId = 62535   
*/
CREATE PROCEDURE [dbo].[GetInwardById] 
(
@InwardId INT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @SalesReturnType INT = 3;-- InwardTypeEnum.SalesReturn — adjust to your actual enum value

		------------------------------------------------------------------
		-- Result set 1: header
		------------------------------------------------------------------
		SELECT
			-- InwardEntry fields
			x.CustomerId
			,CustomerName = CASE 
				WHEN x.InwardType = @SalesReturnType
					AND x.CustomerId > 0
					THEN cust.FirstName + N' ' + ISNULL(cust.LastName, N'')
				ELSE NULL
				END
			,x.InwardEntryNumber
			,x.InwardId
			,x.InwardType
			,OrderId = CASE 
				WHEN x.OrderId > 0
					THEN ord.OrderId
				ELSE NULL
				END
			,OrderNo = CASE 
				WHEN x.OrderId > 0
					THEN ord.OrderNo
				ELSE NULL
				END
			,x.POProductId
			,x.PoNumber
			,x.VendorId
			,VendorName = CASE 
				WHEN vend.VendorId IS NOT NULL
					AND x.InwardType <> @SalesReturnType
					THEN vend.VendorName
				ELSE N''
				END
			,ReceivedBy = usr.FirstName + N' ' + usr.LastName
			,X.StockTransferId
			,ST.StockTransferNo
			,ST.TransferDate
			,FW.Name AS FromWarehouseName
			,TW.Name AS ToWarehouseName
			-- InwardDetailsEntry fields
			,d.Amount
			,AudioURL = ISNULL(d.AudioURL, N'')
			,c.CategoryId
			,c.CategoryName
			,ImagePath = ISNULL(d.ImagePath, N'')
			,d.InwardDetailsId
			,IsFabric = CASE 
				WHEN c.CategoryTypeId = 2
					THEN CAST(1 AS BIT)
				ELSE CAST(0 AS BIT)
				END
			,p.ModelNo
			,d.OrderSetItemId
			,d.ProductId
			,p.ProductTitle
			,d.Quantity
			,d.Remark
			,d.WarehouseId
			,IDEW.Name AS WarehouseName
			,STD.StockTransferDetailId
			,d.POProductItemId
		FROM dbo.InwardEntry x
		LEFT JOIN InwardDetailsEntry d ON x.InwardId = d.InwardId
			AND d.IsDeleted = 0
			AND EXISTS (
				SELECT 1
				FROM dbo.Products p2
				WHERE p2.ProductId = d.ProductId
					AND p2.Status = 1
				)
		LEFT JOIN dbo.Products p ON p.ProductId = d.ProductId
			AND p.Status = 1
		LEFT JOIN dbo.Categories c ON c.CategoryId = p.CategoryId
		LEFT JOIN Warehouse IDEW ON d.WarehouseId = IDEW.Id
		LEFT JOIN dbo.Vendors vend ON vend.VendorId = x.VendorId
		LEFT JOIN dbo.Customers cust ON cust.CustomerId = x.CustomerId
			AND x.InwardType = @SalesReturnType
			AND x.CustomerId > 0
		LEFT JOIN dbo.[Orders] ord ON ord.OrderId = x.OrderId
			AND x.OrderId > 0
		--LEFT JOIN StockTransfer ST ON ST.StockTransferId = X.StockTransferId AND X.StockTransferId > 0
		--LEFT JOIN StockTransferDetail STD ON STD.StockTransferId = ST.StockTransferId
		LEFT JOIN StockTransfer ST ON ST.StockTransferId = X.StockTransferId
			AND X.StockTransferId > 0
		LEFT JOIN StockTransferDetail STD ON STD.StockTransferDetailId = d.StockTransferDetailId
		LEFT JOIN POProducts PO ON PO.POProductId = X.POProductId
		LEFT JOIN Warehouse FW ON ST.FromWarehouseId = FW.Id
		LEFT JOIN Warehouse TW ON ST.ToWarehouseId = TW.Id
		OUTER APPLY (
			SELECT TOP 1 *
			FROM dbo.[AspNetUsers]
			WHERE UserId = COALESCE(x.UpdatedBy, x.CreatedBy)
			) usr
		WHERE x.InwardId = @InwardId
			AND x.IsDeleted = 0
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage VARCHAR(MAX)
			,@ObjectName VARCHAR(500);

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ObjectName = OBJECT_NAME(@@PROCID);

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage
	END CATCH
END

GO

