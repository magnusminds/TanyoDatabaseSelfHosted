CREATE TABLE [dbo].[OrderSetItems] (
    [OrderSetItemId]         BIGINT                                               IDENTITY (1, 1) NOT NULL,
    [ParentOrderSetItemId]   BIGINT                                               NULL,
    [OrderId]                BIGINT                                               NOT NULL,
    [OrderSetId]             BIGINT                                               NOT NULL,
    [SubjectTypeId]          INT                                                  NOT NULL,
    [SubjectId]              BIGINT                                               NOT NULL,
    [ItemStatus]             INT                                                  NOT NULL,
    [Quantity]               NUMERIC (18, 2)                                      NOT NULL,
    [StockQty]               DECIMAL (18, 2)                                      CONSTRAINT [DF__OrderSetI__Stock__72F0F4D3] DEFAULT ((0)) NOT NULL,
    [CostPrice]              NUMERIC (18, 2) CONSTRAINT [DF__OrderSetI__CostP__3BEAD8AC] DEFAULT ((0)) NOT NULL,
    [UnitPrice]              NUMERIC (18, 2) NOT NULL,
    [DiscountPrice]          NUMERIC (18, 2) NOT NULL,
    [UnitSalePrice]          NUMERIC (18, 2) CONSTRAINT [DF_OrderSetItems_UnitSalePrice] DEFAULT ((0.00)) NULL,
    [Discount]               NUMERIC (18, 2) CONSTRAINT [DF_OrderSetItems_Discount] DEFAULT ((0)) NOT NULL,
    [AmountBeforeGST]        DECIMAL (18, 2) CONSTRAINT [df_OrderSetItems_AmountBeforeGST] DEFAULT ((0)) NULL,
    [CGSTAmount]             DECIMAL (18, 2) CONSTRAINT [df_OrderSetItems_CGSTAmount] DEFAULT ((0)) NULL,
    [SGSTAmount]             DECIMAL (18, 2) CONSTRAINT [df_OrderSetItems_SGSTAmount] DEFAULT ((0)) NULL,
    [GST]                    NUMERIC (18, 2)                                      CONSTRAINT [DF__OrderSetIte__GST__3AF6B473] DEFAULT ((18)) NOT NULL,
    [TotalAmount]            NUMERIC (18, 2) NOT NULL,
    [GrossTotal]             NUMERIC (18, 2) CONSTRAINT [DF_OrderSetItems_GrossTotal] DEFAULT ((0)) NOT NULL,
    [MRP]                    NUMERIC (18, 2)                                      CONSTRAINT [DF__OrderSetIte__MRP__1570F560] DEFAULT ((0)) NOT NULL,
    [InteriorCommission]     NUMERIC (18, 2)                                      CONSTRAINT [DF__OrderSetI__Inter__041B80D5] DEFAULT ((0)) NULL,
    [SalesmanCommission]     NUMERIC (18, 2)                                      CONSTRAINT [DF__OrderSetI__Sales__050FA50E] DEFAULT ((0)) NULL,
    [OfferPercentage]        INT                                                  NULL,
    [Width]                  NUMERIC (18, 2)                                      NULL,
    [Height]                 NUMERIC (18, 2)                                      NULL,
    [Depth]                  NUMERIC (18, 2)                                      NULL,
    [Diameter]               NUMERIC (18, 2)                                      NULL,
    [InstantCostPrice]       NUMERIC (18, 2) NULL,
    [InstantUnitPrice]       NUMERIC (18, 2) NULL,
    [InstantWidth]           NUMERIC (18, 2)                                      NULL,
    [InstantHeight]          NUMERIC (18, 2)                                      NULL,
    [InstantDepth]           NUMERIC (18, 2)                                      NULL,
    [InstantDiameter]        NUMERIC (18, 2)                                      NULL,
    [ProductImage]           VARCHAR (MAX)                                        NULL,
    [QRImage]                VARCHAR (MAX)                                        NULL,
    [Comment]                NVARCHAR (MAX)                                       NULL,
    [DeliveryComment]        NVARCHAR (MAX)                                       NULL,
    [DeliveryNo]             VARCHAR (50)                                         NULL,
    [DeliveryDate]           DATE                                                 NULL,
    [ReceiveDate]            DATETIMEOFFSET (7)                                   NULL,
    [ReadyToDeliveredDate]   DATETIME                                             NULL,
    [DefaultProductVendorId] BIGINT                                               NULL,
    [IsQuantityOnHold]       BIT                                                  CONSTRAINT [DF__OrderSetI__IsQua__7CAF6937] DEFAULT ((0)) NOT NULL,
    [OfferId]                INT                                                  NULL,
    [ProvidedMaterial]       NUMERIC (7, 2)                                       NULL,
    [CreatedBy]              INT                                                  NOT NULL,
    [CreatedDate]            DATETIMEOFFSET (7)                                   NOT NULL,
    [CreatedUTCDate]         DATETIME                                             NOT NULL,
    [UpdatedBy]              INT                                                  NULL,
    [UpdatedDate]            DATETIMEOFFSET (7)                                   NULL,
    [UpdatedUTCDate]         DATETIME                                             NULL,
    [IsDeleted]              BIT                                                  CONSTRAINT [DF__OrderSetI__IsDel__40AF8DC9] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_OrderSetItems] PRIMARY KEY CLUSTERED ([OrderSetItemId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_OrderSetItems_SubjectId]
    ON [dbo].[OrderSetItems]([SubjectId] ASC, [IsDeleted] ASC, [ItemStatus] ASC)
    INCLUDE([Quantity]) WITH (FILLFACTOR = 80);


GO

CREATE NONCLUSTERED INDEX [IX_OrderSetItems_OrderId_IsDeleted_ItemStatus_SubjectTypeId_SubjectId]
    ON [dbo].[OrderSetItems]([OrderId] ASC, [IsDeleted] ASC, [ItemStatus] ASC, [SubjectTypeId] ASC, [SubjectId] ASC)
    INCLUDE([ParentOrderSetItemId]) WITH (FILLFACTOR = 80);


GO

CREATE TRIGGER [dbo].[trg_OrderSetItems_Insert] ON dbo.OrderSetItems
AFTER INSERT
AS
BEGIN
	SET NOCOUNT ON;

	IF EXISTS (
			SELECT 1
			FROM Inserted
			WHERE SubjectId = 0
				OR SubjectTypeId = 0
			)
	BEGIN
		RAISERROR ('SubjectId and SubjectTypeId are not valid', 16, 1)
		
		IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;
	END
END

GO

