/*  
  
EXEC [dbo].[SaveInward]  
    @TenantId = 2,  
    @UserId = 4509,  
    @InwardId = 30713,  
    @VendorId = 8,  
    @PoNumber = NULL,  
    @POProductId = NULL,  
    @InwardType = 4,  
    @CustomerId = NULL,  
    @OrderId = NULL,  
    @StockTransferId = 118,  
    @InwardDetailsEntriesJSON = N'[  
  {  
    "InwardDetailsID": 42631,  
    "ProductId": 107716,  
    "Quantity": 4,  
    "Amount": null,  
    "Remark": "Test remark",  
    "WarehouseId": 102,  
    "ImagePath": null,  
    "AudioURL": null,  
    "OrderSetItemId": null,  
    "StockTransferDetailId": 210  
  }  
]';  
  
  
*/  
  
CREATE   PROCEDURE [dbo].[SaveInward]  
    @TenantId INT,  
    @UserId INT,  
    @InwardId BIGINT = NULL,  
    @VendorId INT = NULL,  
    @PoNumber VARCHAR(255) = NULL,  
    @POProductId BIGINT = NULL,  
    @InwardType INT,  
    @CustomerId BIGINT = NULL,  
    @OrderId BIGINT = NULL,  
    @StockTransferId BIGINT = NULL,  
    @InwardDetailsEntriesJSON NVARCHAR(MAX),  
    @ReturnMessage NVARCHAR(255) = '' OUTPUT,  
    @ReturnInwardId BIGINT = NULL OUTPUT,  
    @Status BIT = 0 OUTPUT,  
 @SendPOEmail BIT = 0 OUTPUT  
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  
    DECLARE @IsNewInward BIT,  
            @InwardEntryNumber VARCHAR(50),  
            @Dt DATETIMEOFFSET,  
            @DtUtc DATETIME,  
            @Result INT,  
            @InwardDetailsId INT,  
            @CreatedBy INT,  
            @NewInwardId INT,  
            @FullName NVARCHAR(255),  
            @OrderNo VARCHAR(255),  
            @StockTransferNo VARCHAR(255),  
            @TypeSuffix VARCHAR(500),  
            @PoValRow INT,  
            @PoValTotal INT,  
            @PoProdId INT,   
            @PoReqQty DECIMAL(18,4),   
            @PoCurrentDetailId INT,  
            @POMatchedQty DECIMAL(18,4),   
            @MatchedTitle NVARCHAR(255),  
            @POAlreadyInwardedQty DECIMAL(18,4),   
            @POAvailableQty DECIMAL(18,4),  
            @ProdTitle NVARCHAR(255),   
            @PoErrMsg VARCHAR(500),  
            @ValRow INT,  
            @ValTotal INT,  
            @OrderSetItemId BIGINT,   
            @RequestedQty DECIMAL(18,4),   
            @CurrentDetailId INT,  
            @OriginalQty DECIMAL(18,4),   
            @AlreadyReturnedQty DECIMAL(18,4),   
            @AvailableQty DECIMAL(18,4),  
            @ErrMsg VARCHAR(500),  
            @STValRow INT,  
            @STValTotal INT,  
            @STProdId INT,   
            @STReqQty DECIMAL(18,4),  
            @STAvailableQty DECIMAL(18,4),   
            @STMatchedTitle NVARCHAR(255),  
            @STProdTitle NVARCHAR(255),   
            @STErrMsg VARCHAR(500),  
            @STCurrentDetailId INT,           
            @STOldQuantity DECIMAL(18,4),  
            @OtherWarehouseId BIGINT,  
            @TotalRows INT,  
            @CurrentRow INT,  
            @ProductId INT,   
            @Quantity DECIMAL(18,4),   
            @Amount DECIMAL(18,4),   
            @Remark VARCHAR(500),  
            @WarehouseId BIGINT,   
            @ImagePath NVARCHAR(MAX),   
            @AudioURL NVARCHAR(MAX),  
            @StockTransferDetailId INT,  
            @FinalWarehouseId BIGINT,  
            @POProductItemId BIGINT,  
            @OldQuantity DECIMAL(18,4),  
            @OldWarehouseId BIGINT,  
            @DeltaQuantity DECIMAL(18,4),   
            @SellableOldQuantity DECIMAL(18,4),   
            @SellableNewQuantity DECIMAL(18,4),  
            @Sign VARCHAR(1),   
            @OldQtyStr VARCHAR(50),   
            @NewQtyStr VARCHAR(50),   
            @UpdateQtyStr VARCHAR(50),  
            @Description VARCHAR(MAX),   
            @WarehouseName NVARCHAR(255),  
            @WhOldQuantity DECIMAL(18,4),   
            @WhNewQuantity DECIMAL(18,4),  
            @WhOldQtyStr VARCHAR(50),   
            @WhNewQtyStr VARCHAR(50),  
            @WarehouseDescription VARCHAR(MAX),   
            @WhQtyToUpdate DECIMAL(18,4),  
            @OldWareHouseName VARCHAR(50),  
            @ErrorMessage NVARCHAR(4000),  
            @ErrorSeverity INT,  
         @ErrorState INT,  
            @ObjectName VARCHAR(500);  
  
    DECLARE @InwardDetails TABLE (  
        RowID INT IDENTITY(1,1),  
        InwardDetailsId INT,   
        ProductId INT,  
        Quantity DECIMAL(18,4),  
        Amount DECIMAL(18,4),  
        Remark NVARCHAR(MAX),  
        WarehouseId BIGINT,  
        ImagePath NVARCHAR(MAX),  
        AudioURL NVARCHAR(MAX),  
        OrderSetItemId BIGINT,  
        StockTrasferDetailId BIGINT,  
        POProductItemId BIGINT  
    );  
  
    DECLARE @POCompletionTable TABLE (  
        POProductItemId BIGINT,  
        ProductId INT,  
        POQty INT,   
        TotalInwardQty INT,  
        IsCompleted BIT   
    );  
    SET @IsNewInward = CASE WHEN @InwardId IS NULL OR @InwardId <= 0 THEN 1 ELSE 0 END;  
    SET @Dt = SYSDATETIMEOFFSET();  
    SET @DtUtc = GETUTCDATE();  
    SET @OrderNo = NULL;  
    SET @StockTransferNo = NULL;  
  
    BEGIN TRY  
  
        IF @InwardId IS NOT NULL AND @InwardId > 0   
        BEGIN  
            SELECT @CreatedBy = CreatedBy FROM dbo.InwardEntry WHERE InwardId = @InwardId AND IsDeleted = 0;  
  
            IF @CreatedBy IS NOT NULL AND @CreatedBy <> @UserId  
            BEGIN  
                SELECT @FullName = CONCAT(FirstName, ' ', LastName)   
                FROM dbo.AspNetUsers WITH (NOLOCK)  
                WHERE UserId = @CreatedBy;  
  
                SET @ReturnInwardId = @InwardId;  
                SET @Status = 0;  
                SET @ReturnMessage = 'This Inward is managed by ' + ISNULL(@FullName, 'another user') + '. You cannot update it.';  
    SET @SendPOEmail = @SendPOEmail;  
  
                RETURN;  
            END  
        END  
                  
        INSERT INTO @InwardDetails (InwardDetailsId, ProductId, Quantity, Amount, Remark, WarehouseId, ImagePath, AudioURL, OrderSetItemId, StockTrasferDetailId, POProductItemId)  
        SELECT   
            InwardDetailsId, ProductId, Quantity, Amount, Remark, WarehouseId, ImagePath, AudioURL, OrderSetItemId, StockTrasferDetailId, POProductItemId  
        FROM OPENJSON(@InwardDetailsEntriesJSON)  
        WITH (  
            InwardDetailsId INT '$.InwardDetailsID',  
            ProductId INT '$.ProductId',  
            Quantity DECIMAL(18,4) '$.Quantity',  
            Amount DECIMAL(18,4) '$.Amount',  
            Remark NVARCHAR(MAX) '$.Remark',  
            WarehouseId BIGINT '$.WarehouseId',  
            ImagePath NVARCHAR(MAX) '$.ImagePath',  
            AudioURL NVARCHAR(MAX) '$.AudioURL',  
            OrderSetItemId BIGINT '$.OrderSetItemId',  
            StockTrasferDetailId BIGINT '$.StockTrasferDetailId',  
            POProductItemId BIGINT '$.POProductItemId'  
        );  
  
        IF NOT EXISTS (SELECT 1 FROM @InwardDetails)  
        BEGIN  
            SET @ReturnInwardId = @InwardId;  
            SET @Status = 0;  
            SET @ReturnMessage = 'Inward details are required.';  
   SET @SendPOEmail = @SendPOEmail;  
  
            RETURN;  
        END  
  
        IF @InwardType = 2  
        BEGIN  
            IF @POProductId IS NULL OR @POProductId <= 0  
            BEGIN  
                SET @ReturnInwardId = @InwardId;  
                SET @Status = 0;  
                SET @ReturnMessage = 'PoNumberId is required for Purchase Order Inward Type.';  
    SET @SendPOEmail = @SendPOEmail;  
   
                RETURN;  
            END  
              
            IF @PoNumber IS NULL OR LTRIM(RTRIM(@PoNumber)) = ''  
            BEGIN  
                SET @ReturnInwardId = @InwardId;  
                SET @Status = 0;  
                SET @ReturnMessage = 'PoNumber is required for Purchase Order Inward Type.';  
    SET @SendPOEmail = @SendPOEmail;  
  
                RETURN;  
            END  
  
            SET @PoValRow = 1;  
            SET @PoValTotal = (SELECT COUNT(1) FROM @InwardDetails);  
  
            WHILE @PoValRow <= @PoValTotal  
            BEGIN  
                SELECT @PoProdId = ProductId, @PoReqQty = Quantity, @PoCurrentDetailId = ISNULL(InwardDetailsId, 0)  
FROM @InwardDetails WHERE RowID = @PoValRow;  
  
                SELECT @ProdTitle = ProductTitle FROM Products WHERE ProductId = @PoProdId;  
  
                IF @PoReqQty <= 0  
                BEGIN  
                    SET @ReturnInwardId = @InwardId;  
                    SET @Status = 0;  
                    SET @ReturnMessage = CONCAT('Invalid quantity (', FORMAT(@PoReqQty, '0.00'), ') entered for Product ', @ProdTitle, '. Quantity must be greater than zero.');  
     SET @SendPOEmail = @SendPOEmail;  
  
                    RETURN;  
                END  
  
                -- Product-level: SUM across ALL duplicate PO lines for this product
                -- (no rows -> SUM/MAX are NULL, so the @MatchedTitle IS NULL guard below still fires).
                SELECT   
                    @POMatchedQty = SUM(poi.Quantity),   
                    @MatchedTitle = MAX(p.ProductTitle)   
                FROM POProductItems poi WITH (NOLOCK)  
                INNER JOIN Products p WITH (NOLOCK) ON poi.ProductId = p.ProductId  
                WHERE poi.POProductId = @POProductId AND poi.ProductId = @PoProdId;  
  
                IF @MatchedTitle IS NULL  
                BEGIN  
                    SET @ReturnInwardId = @InwardId;  
                    SET @Status = 0;  
                    SET @ReturnMessage = CONCAT('Product - ', @ProdTitle, ' not found in PO.');  
     SET @SendPOEmail = @SendPOEmail;  
  
                    RETURN;  
                END  
  
                SELECT @POAlreadyInwardedQty = ISNULL(SUM(ide.Quantity), 0)  
                FROM InwardDetailsEntry ide WITH (NOLOCK)  
                INNER JOIN InwardEntry ie WITH (NOLOCK) ON ide.InwardId = ie.InwardId  
                WHERE ie.POProductId = @POProductId   
                  AND ide.ProductId = @PoProdId  
                  AND ide.InwardDetailsId <> @PoCurrentDetailId;  
  
                SET @POAvailableQty = ISNULL(@POMatchedQty, 0) - @POAlreadyInwardedQty;  
                IF @POAvailableQty < 0 SET @POAvailableQty = 0;  
  
                IF @PoReqQty > @POAvailableQty  
                BEGIN  
                    SET @ReturnInwardId = @InwardId;  
                    SET @Status = 0;  
                    SET @ReturnMessage = CONCAT('Requested quantity (', FORMAT(@PoReqQty, '0.00'), ') for ''', @MatchedTitle,  
                    ''' exceeds, available quantity (', FORMAT(@POAvailableQty, '0.00'), ').');  
     SET @SendPOEmail = @SendPOEmail;  
  
                    RETURN;  
                END  
  
                SET @PoValRow = @PoValRow + 1;  
            END  
        END  
  
        IF @InwardType = 3  
        BEGIN  
            IF @CustomerId IS NULL OR @CustomerId <= 0  
            BEGIN  
                SET @ReturnInwardId = @InwardId;  
                SET @Status = 0;  
                SET @ReturnMessage = 'Customer ID is required for Sales Return Inward Type.';  
    SET @SendPOEmail = @SendPOEmail;  
  
                RETURN;  
            END  
  
            SET @VendorId = 0;  
  
            IF @OrderId IS NOT NULL AND @OrderId > 0  
            BEGIN  
                SET @ValRow = 1;  
                SET @ValTotal = (SELECT COUNT(1) FROM @InwardDetails);  
  
                WHILE @ValRow <= @ValTotal  
                BEGIN  
                    SELECT @OrderSetItemId = OrderSetItemId, @RequestedQty = Quantity, @CurrentDetailId = ISNULL(InwardDetailsId, 0)  
                    FROM @InwardDetails WHERE RowID = @ValRow;  
  
                    IF @OrderSetItemId IS NOT NULL AND @OrderSetItemId > 0  
                    BEGIN  
                        SELECT @OriginalQty = ISNULL(Quantity, 0)   
                        FROM OrderSetItems   
                        WHERE OrderSetItemId = @OrderSetItemId;  
  
                        SELECT @AlreadyReturnedQty = ISNULL(SUM(ide.Quantity), 0)  
                        FROM InwardDetailsEntry ide WITH (NOLOCK)   
                        INNER JOIN InwardEntry ie WITH (NOLOCK) ON ide.InwardId = ie.InwardId  
                        WHERE ie.OrderId = @OrderId   
                          AND ide.OrderSetItemId = @OrderSetItemId  
                          AND ide.InwardDetailsId <> @CurrentDetailId;  
  
                        SET @AvailableQty = ISNULL(@OriginalQty, 0) - @AlreadyReturnedQty;  
  
                        IF @AvailableQty <= 0  
                        BEGIN  
                            SET @ReturnInwardId = @InwardId;  
                            SET @Status = 0;  
                            SET @ReturnMessage = 'Return quantity must not exceed delivered quantity.';  
       SET @SendPOEmail = @SendPOEmail;  
  
                            RETURN;  
                        END  
  
                        IF @RequestedQty > @AvailableQty  
                        BEGIN  
                            SET @ReturnInwardId = @InwardId;  
                            SET @Status = 0;  
                            SET @ReturnMessage = CONCAT('Entered quantity ', FORMAT(@RequestedQty, '0.00'), ' is incorrect. The correct value is ',   
                         FORMAT(@AvailableQty, '0.00'), '.');  
       SET @SendPOEmail = @SendPOEmail;  
  
                            RETURN;  
                        END  
                    END  
                    SET @ValRow = @ValRow + 1;  
                END  
            END  
        END  
  
        IF @InwardType = 4  
        BEGIN  
            IF @StockTransferId IS NULL OR @StockTransferId <= 0  
            BEGIN  
                SET @ReturnInwardId = @InwardId;  
                SET @Status = 0;  
                SET @ReturnMessage = 'Stock Transfer ID is required for Stock Transfer Inward Type.';  
    SET @SendPOEmail = @SendPOEmail;  
  
                RETURN;  
            END  
  
            SET @STValRow = 1;  
            SET @STValTotal = (SELECT COUNT(1) FROM @InwardDetails);  
  
            WHILE @STValRow <= @STValTotal  
            BEGIN  
                SET @STOldQuantity = 0;  
                SELECT @STProdId = ProductId, @STReqQty = Quantity, @STCurrentDetailId = ISNULL(InwardDetailsId, 0)  
                FROM @InwardDetails WHERE RowID = @STValRow;  
  
                IF @STCurrentDetailId > 0  
                BEGIN  
                    SELECT @STOldQuantity = ISNULL(Quantity, 0)  
                    FROM InwardDetailsEntry WITH (NOLOCK)  
                    WHERE InwardDetailsId = @STCurrentDetailId;  
                END  
  
                SELECT @STProdTitle = ProductTitle FROM Products WITH (NOLOCK) WHERE ProductId = @STProdId;  
  
                IF @STReqQty <= 0  
                BEGIN  
                    SET @ReturnInwardId = @InwardId;  
                    SET @Status = 0;  
                    SET @ReturnMessage = CONCAT('Invalid quantity (', FORMAT(@STReqQty, '0.00'), ') entered for Product ', @STProdTitle, '. Quantity must be greater than zero.');  
     SET @SendPOEmail = @SendPOEmail;  
  
                    RETURN;  
                END  
  
                SELECT TOP 1   
                    @STAvailableQty = ISNULL(std.TransferQuantity, 0) - ISNULL(std.ReceivedQuantity, 0) + @STOldQuantity,   
                    @STMatchedTitle = p.ProductTitle   
                FROM StockTransferDetail std WITH (NOLOCK)  
                INNER JOIN Products p WITH (NOLOCK) ON std.ProductId = p.ProductId  
                WHERE std.StockTransferId = @StockTransferId AND std.ProductId = @STProdId AND std.IsDeleted = 0;  
  
                IF @STMatchedTitle IS NULL  
                BEGIN  
                    SET @ReturnInwardId = @InwardId;  
                    SET @Status = 0;  
                    SET @ReturnMessage = CONCAT('Product - ', @STProdTitle, ' not found in Stock Transfer.');  
     SET @SendPOEmail = @SendPOEmail;  
  
                    RETURN;  
                END  
  
                IF @STReqQty > @STAvailableQty  
                BEGIN  
                    SET @ReturnInwardId = @InwardId;  
                    SET @Status = 0;  
                    SET @ReturnMessage = CONCAT('Requested quantity (', FORMAT(@STReqQty, '0.00'), ') for ''', @STMatchedTitle, ''' exceeds pending transfer quantity (', FORMAT(@STAvailableQty, '0.00'), ').');  
     SET @SendPOEmail = @SendPOEmail;  
  
                    RETURN;  
      END  
  
                SET @STValRow = @STValRow + 1;  
            END  
        END  
  
        IF @OrderId IS NOT NULL AND @OrderId > 0  
            SELECT @OrderNo = OrderNo FROM [Orders] WITH (NOLOCK) WHERE OrderId = @OrderId;  
  
        IF @StockTransferId IS NOT NULL AND @StockTransferId > 0  
            SELECT @StockTransferNo = StockTransferNo FROM [StockTransfer] WITH (NOLOCK) WHERE StockTransferId = @StockTransferId;  
  
        SET @TypeSuffix = CASE @InwardType  
            WHEN 1 THEN ' for Manual Inward.'  
            WHEN 2 THEN ' for PO ' + ISNULL(@PoNumber, '') + '.'  
            WHEN 3 THEN ' for Sales Return ' + ISNULL(@OrderNo, '') + '.'  
            WHEN 4 THEN ' for Stock Transfer ' + ISNULL(@StockTransferNo, '') + '.'  
            ELSE '.'  
        END;  
  
        BEGIN TRANSACTION;  
        IF @InwardId IS NULL OR @InwardId <= 0  
        BEGIN  
            SELECT @InwardEntryNumber = [dbo].[GetInwardEntryNumber](@TenantId);  
  
            UPDATE TenantConfigurations  
            SET InwardEntryNumberCounter = InwardEntryNumberCounter + 1  
            WHERE TenantId = @TenantId;  
  
            INSERT INTO InwardEntry (  
                VendorId, PoNumber, POProductId, InwardType, CustomerId, OrderId, StockTransferId,  
                InwardEntryNumber, TenantId, CreatedBy, CreatedDate, CreatedUTCDate, IsDeleted  
            )  
            VALUES (  
                @VendorId, @PoNumber, @POProductId, @InwardType, @CustomerId, @OrderId, @StockTransferId,  
                @InwardEntryNumber, @TenantId, @UserId, @Dt, @DtUtc, 0  
            );  
  
            SET @InwardId = SCOPE_IDENTITY();  
        END  
        ELSE  
        BEGIN  
            UPDATE InwardEntry  
            SET VendorId = @VendorId,  
                PoNumber = @PoNumber,  
                POProductId = @POProductId,  
                InwardType = @InwardType,  
                CustomerId = @CustomerId,  
                OrderId = @OrderId,  
                StockTransferId = @StockTransferId,  
                UpdatedBy = @UserId,  
                UpdatedDate = @Dt,  
                UpdatedUTCDate = @DtUtc  
            WHERE InwardId = @InwardId;  
  
            SELECT @InwardEntryNumber = InwardEntryNumber FROM InwardEntry WITH (NOLOCK) WHERE InwardId = @InwardId;  
        END  
  
        IF @InwardId IS NOT NULL AND @InwardId > 0  
        BEGIN  
            UPDATE InwardDetailsEntry  
            SET IsDeleted = 1  
            WHERE InwardId = @InwardId  
              AND InwardDetailsId NOT IN (SELECT InwardDetailsId FROM @InwardDetails WHERE InwardDetailsId IS NOT NULL) AND IsDeleted = 0;  
        END  
  
        SELECT TOP 1 @OtherWarehouseId = Id FROM Warehouse WHERE Name = 'Other';  
  
        SET @TotalRows = (SELECT COUNT(1) FROM @InwardDetails);  
        SET @CurrentRow = 1;  
  
        WHILE @CurrentRow <= @TotalRows  
        BEGIN  
            SELECT   
                @InwardDetailsId = ISNULL(InwardDetailsId, 0),   
                @ProductId = ProductId,   
                @Quantity = Quantity,   
                @Amount = Amount,   
                @Remark = Remark,   
                @WarehouseId = WarehouseId,   
                @ImagePath = ImagePath,   
                @AudioURL = AudioURL,  
                @StockTransferDetailId = StockTrasferDetailId,  
                @OrderSetItemId = OrderSetItemId,  
                @POProductItemId = POProductItemId  
            FROM @InwardDetails  
            WHERE RowID = @CurrentRow;  
  
            IF @Amount IS NULL  
                SELECT @Amount = CostPrice FROM Products WHERE ProductId = @ProductId;  
  
            SET @FinalWarehouseId = CASE WHEN @WarehouseId IS NULL OR @WarehouseId <= 0 THEN @OtherWarehouseId ELSE @WarehouseId END;  
            SET @OldQuantity = 0;  
            SET @OldWarehouseId = NULL;  
  
            IF @InwardDetailsId > 0  
            BEGIN  
                SELECT @OldQuantity = Quantity, @OldWarehouseId = WarehouseId, @OldWareHouseName = Name  
                FROM InwardDetailsEntry IDE WITH (NOLOCK)  
                INNER JOIN Warehouse W WITH (NOLOCK) ON W.Id = IDE.WarehouseId  
                WHERE InwardDetailsId = @InwardDetailsId;  
  
                UPDATE InwardDetailsEntry  
                SET ProductId = @ProductId,  
                    Quantity = @Quantity,  
                    Amount = @Amount,  
                    Remark = @Remark,  
                    ImagePath = @ImagePath,   
                    AudioURL = @AudioURL,   
                    WarehouseId = @FinalWarehouseId,  
                    UpdatedBy = @UserId,  
                    UpdatedDate = @Dt,  
                    UpdatedUTCDate = @DtUtc,  
                    StockTransferDetailId = @StockTransferDetailId,  
                    OrderSetItemId = @OrderSetItemId,  
                    POProductItemId = @POProductItemId  
                WHERE InwardDetailsId = @InwardDetailsId;  
  
                SET @NewInwardId = @InwardId;  
  
                INSERT INTO InwardDetailsEntry (InwardId, ProductId, Quantity, Amount, Remark, ImagePath, AudioURL,   
                    WarehouseId, CreatedBy, CreatedDate, CreatedUTCDate, IsDeleted, StockTransferDetailId, OrderSetItemId, POProductItemId)  
                SELECT @InwardId, @ProductId, @Quantity, @Amount, @Remark, @ImagePath, @AudioURL,  
                    @FinalWarehouseId, @UserId, @Dt, @DtUtc, 0, @StockTransferDetailId, @OrderSetItemId, @POProductItemId  
                WHERE EXISTS (  
                    SELECT 1 FROM InwardDetailsEntry IDE   
                    WHERE IDE.InwardId = @InwardId AND IDE.ProductId = @ProductId AND IDE.IsDeleted = 1  
                    AND IDE.InwardDetailsId = @InwardDetailsId  
                );  
            END  
            ELSE  
            BEGIN  
                INSERT INTO InwardDetailsEntry (  
                    InwardId, ProductId, Quantity, Amount, Remark, ImagePath, AudioURL,   
                    WarehouseId, CreatedBy, CreatedDate, CreatedUTCDate, IsDeleted, StockTransferDetailId, OrderSetItemId,POProductItemId   
                )  
                VALUES (  
                    @InwardId, @ProductId, @Quantity, @Amount, @Remark, @ImagePath, @AudioURL,  
                    @FinalWarehouseId, @UserId, @Dt, @DtUtc, 0, @StockTransferDetailId, @OrderSetItemId, @POProductItemId  
                );  
            END  
  
            SET @DeltaQuantity = @Quantity - @OldQuantity;  
  
            IF @DeltaQuantity <> 0 OR (@OldWarehouseId IS NOT NULL AND @OldWarehouseId <> @FinalWarehouseId)  
            BEGIN  
                SELECT TOP 1 @SellableOldQuantity = ISNULL(Quantity, 0) FROM ProductQuantities WHERE ProductId = @ProductId;  
                SET @SellableNewQuantity = ISNULL(@SellableOldQuantity, 0) + @DeltaQuantity;  
  
                SET @Sign = CASE WHEN @DeltaQuantity > 0 THEN '+' ELSE '' END;  
                  
                SET @OldQtyStr = FORMAT(ISNULL(@SellableOldQuantity, 0), '0.00');  
                SET @NewQtyStr = FORMAT(ISNULL(@SellableNewQuantity, 0), '0.00');  
                SET @UpdateQtyStr = FORMAT(ISNULL(@DeltaQuantity, 0), '0.00');  
  
                SET @Description = 'Inventory has been updated from ' + @OldQtyStr + ' to ' + @NewQtyStr + ' (' + @Sign + @UpdateQtyStr + ')' + @TypeSuffix;  
  
                EXEC dbo.AddProductSaleableQuantity   
                    @TenantId = @TenantId,  
                    @UserId = @UserId,  
                    @ProductId = @ProductId,  
                    @Quantity = @DeltaQuantity,  
                    @Description = @Description,  
                    @OrderNo = @OrderNo,  
                    @PurchaseOrderNo = @PoNumber,  
                    @InwardNo = @InwardEntryNumber,  
                    @StockTransferNo = @StockTransferNo;  
  
                IF @SellableOldQuantity < 0 AND (@InwardType = 1 OR @InwardType = 2)   
                BEGIN  
                    INSERT INTO FollowUpOrders (OrderId, FollowUpComment, FollowUpDate, CreatedBy, CreatedDate)  
                    SELECT DISTINCT   
                        o.OrderId,   
                        CONCAT('Product ', p.ProductTitle, ' - (', p.ModelNo, ') has been added to the inventory.'),  
                        DATEADD(HOUR, 11, CAST(CAST(DATEADD(DAY, 1, @Dt) AS DATE) AS DATETIME)),   
                        @UserId,   
                        @Dt  
                    FROM OrderSetItems osi WITH (NOLOCK)  
                    INNER JOIN [Orders] o WITH (NOLOCK) ON osi.OrderId = o.OrderId  
                    INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = @ProductId  
                    WHERE osi.SubjectId = @ProductId AND osi.IsDeleted = 0 AND o.TenantId = @TenantId AND o.Status IN (2,3) AND o.IsArchive = 0;  
                END  
  
                SELECT TOP 1 @WarehouseName = ISNULL(Name, '') FROM Warehouse WHERE Id = @FinalWarehouseId;  
  
                SELECT TOP 1 @WhOldQuantity = ISNULL(Quantity, 0)   
                FROM ProductQuantitiesByWarehouse WITH (NOLOCK)  
                WHERE ProductId = @ProductId AND WarehouseId = @FinalWarehouseId;  
  
                SET @WhOldQtyStr = FORMAT(ISNULL(@WhOldQuantity, 0), '0.00');  
                SET @WhNewQuantity = ISNULL(@WhOldQuantity, 0) + @DeltaQuantity;  
                SET @WhNewQtyStr = FORMAT(ISNULL(@WhNewQuantity, 0), '0.00');  
  
                SET @WhQtyToUpdate = CASE   
                    WHEN @InwardDetailsId > 0 AND @OldWarehouseId IS NOT NULL AND @OldWarehouseId <> @FinalWarehouseId   
                    THEN @Quantity   
                    ELSE @DeltaQuantity   
                END;  
  
                IF EXISTS (  
                    SELECT 1   
                    FROM dbo.ProductQuantitiesByWarehouse WITH (UPDLOCK)  
                    WHERE ProductId = @ProductId   
                      AND WarehouseId = @FinalWarehouseId  
                )  
                BEGIN  
                    SET @WarehouseDescription = 'Inventory has been updated from ' + @WhOldQtyStr + ' to ' + @WhNewQtyStr + ' (' + @Sign + @UpdateQtyStr + ') in the ' + ISNULL(@WarehouseName, '') + ' warehouse' + @TypeSuffix;  
  
                    EXEC dbo.AddProductWarehouseQuantity   
                        @TenantId = @TenantId,   
                        @UserId = @UserId,   
                        @ProductId = @ProductId,   
                        @WarehouseId = @FinalWarehouseId,  
                        @Quantity = @WhQtyToUpdate,  
                        @Description = @WarehouseDescription,  
                        @OrderNo = @OrderNo,  
                        @InwardNo = @InwardEntryNumber,  
                        @PurchaseOrderNo = @PoNumber,  
                        @StockTransferNo = @StockTransferNo;  
                END  
                ELSE  
                BEGIN  
                    SET @WarehouseDescription = 'Inventory record created with an initial quantity of ' + ISNULL(@WhNewQtyStr, '0.00') + ' in the ' + ISNULL(@WarehouseName, '') + ' warehouse.';  
  
                    EXEC dbo.PopulateProductWarehouseQuantity    
                        @TenantId = @TenantId,    
                        @UserId = @UserId,    
                        @ProductId = @ProductId,    
                        @WarehouseId = @FinalWarehouseId,    
                        @Quantity = @WhQtyToUpdate,    
                        @Description = @WarehouseDescription;  
                END  
  
                IF @OldWarehouseId IS NOT NULL AND @OldWarehouseId <> @FinalWarehouseId  
                BEGIN  
                    SET @Description = 'Inventory transferred out due to warehouse change from ' + ISNULL(@OldWareHouseName, '') + ' to ' + ISNULL(@WarehouseName, '') + @TypeSuffix;  
                      
                    EXEC dbo.DeductProductWarehouseQuantity   
                        @TenantId = @TenantId,  
                        @UserId = @UserId,  
                        @ProductId = @ProductId,  
                        @WarehouseId = @OldWarehouseId,  
                        @OrderNo = @OrderNo,  
          @Quantity = @OldQuantity,   
                        @Description = @Description,  
                        @InwardNo = @InwardEntryNumber,  
                        @StockTransferNo = @StockTransferNo,  
                        @PurchaseOrderNo = @PoNumber,  
                        @Result = @Result OUTPUT;  
                END  
            END  
  
            IF @InwardType = 4 AND @StockTransferId IS NOT NULL AND @StockTransferId > 0 AND @DeltaQuantity <> 0  
            BEGIN  
                UPDATE StockTransferDetail  
                SET ReceivedQuantity = ISNULL(ReceivedQuantity, 0) + @DeltaQuantity,  
                    UpdatedBy = @UserId,  
                    UpdatedDate = @Dt  
                WHERE StockTransferId = @StockTransferId AND ProductId = @ProductId AND IsDeleted = 0;  
            END  
  
            SET @CurrentRow = @CurrentRow + 1;  
        END  
  
        IF @InwardType = 2 AND @POProductId IS NOT NULL AND @POProductId > 0  
        BEGIN  
            DELETE FROM @POCompletionTable;  
  
            INSERT INTO @POCompletionTable (POProductItemId, ProductId, POQty, TotalInwardQty, IsCompleted)  
            EXEC [dbo].[GetPOInwardCompletionStatus] @TenantId = @TenantId, @POProductId = @POProductId;  
              
            IF EXISTS(SELECT 1 FROM @POCompletionTable)  
            BEGIN  
                UPDATE POProductItems   
                SET Status = 4   
                WHERE POProductItemId IN (SELECT POProductItemId FROM @POCompletionTable WHERE IsCompleted = 1);  
                  
                IF NOT EXISTS (SELECT 1 FROM @POCompletionTable WHERE IsCompleted = 0)  
                BEGIN  
                    UPDATE POProducts SET Status = 4 WHERE POProductId = @POProductId;  
                    SET @SendPOEmail = 1;   
                END  
            END  
        END  
  
        IF @InwardType = 4 AND @StockTransferId IS NOT NULL AND @StockTransferId > 0  
        BEGIN  
            IF EXISTS (  
                SELECT 1 FROM StockTransferDetail WITH (NOLOCK)  
                WHERE StockTransferId = @StockTransferId   
                  AND IsDeleted = 0  
                  AND ISNULL(TransferQuantity, 0) > 0 AND ISNULL(ReceivedQuantity, 0) > 0  
            )  
            BEGIN  
                UPDATE StockTransfer   
                SET StockTransferStatus = 2,   
                    ReceivedBy = @UserId,   
                    ReceivedDate = @Dt,  
                    UpdatedBy = @UserId,  
                    UpdatedDate = @Dt  
                WHERE StockTransferId = @StockTransferId;  
            END  
        END  
  
        COMMIT TRANSACTION;  
  
        SET @ReturnMessage = 'Inward No ' + ISNULL(@InwardEntryNumber, '') + CASE   
                    WHEN @IsNewInward = 1  
                        THEN ' Created successfully'  
                    ELSE ' Updated successfully'  
                    END;  
           
        SET @ReturnInwardId = @InwardId;  
        SET @Status = 1;  
        SET @SendPOEmail = @SendPOEmail;  
  
    END TRY  
    BEGIN CATCH  
        IF @@TRANCOUNT > 0  
            ROLLBACK TRANSACTION;  
  
        SET @ErrorMessage = ERROR_MESSAGE();  
        SET @ErrorSeverity = ERROR_SEVERITY();  
        SET @ErrorState = ERROR_STATE();  
        SET @ObjectName = OBJECT_NAME(@@PROCID);  
  
        SET @ReturnInwardId = NULL;  
        SET @Status = 0;  
        SET @ReturnMessage = @ErrorMessage;  
  
        EXEC dbo.SaveDBErrorLog  
            @ObjectName = @ObjectName,  
            @ErrorMsg = @ErrorMessage;  
  
  SET @ReturnMessage = @ErrMsg  
        SET @ReturnInwardId = @InwardId;  
        SET @Status = 0;  
        SET @SendPOEmail = @SendPOEmail;  
  
        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState);  
    END CATCH  
END;

GO

