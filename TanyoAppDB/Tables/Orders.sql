CREATE TABLE [dbo].[Orders] (
    [OrderId]                      BIGINT                                               IDENTITY (1, 1) NOT NULL,
    [OrderNo]                      VARCHAR (20)                                         NOT NULL,
    [CustomerID]                   BIGINT                                               NOT NULL,
    [RefferedBy]                   BIGINT                                               NULL,
    [GrossTotal]                   NUMERIC (18, 2) NOT NULL,
    [Discount]                     NUMERIC (18, 2)                                      NOT NULL,
    [TotalAmount]                  NUMERIC (18, 2) NOT NULL,
    [AmountBeforeGST]              NUMERIC (18, 2) CONSTRAINT [df_Orders_AmountBeforeGST] DEFAULT ((0)) NULL,
    [CGSTAmount]                   NUMERIC (18, 2) CONSTRAINT [df_Orders_CGSTAmount] DEFAULT ((0)) NULL,
    [SGSTAmount]                   NUMERIC (18, 2) CONSTRAINT [df_Orders_SGSTAmount] DEFAULT ((0)) NULL,
    [GSTTaxAmount]                 NUMERIC (18, 2)                                      NOT NULL,
    [AdvanceAmount]                NUMERIC (18, 2)                                      NOT NULL,
    [DeliveryDate]                 DATE                                                 NULL,
    [Comments]                     NVARCHAR (MAX)                                       NULL,
    [IsFreeDelivery]               BIT                                                  CONSTRAINT [DF_Orders_IsFreeDelivery] DEFAULT ((0)) NOT NULL,
    [Status]                       INT                                                  CONSTRAINT [DF__Orders__Status__30242045] DEFAULT ((1)) NOT NULL,
    [TenantId]                     INT                                                  NOT NULL,
    [InquiryExpirationDate]        DATETIMEOFFSET (7)                                   NULL,
    [DeliveryCharges]              NUMERIC (18, 2)                                      NULL,
    [ApprovedDate]                 DATETIMEOFFSET (7)                                   NULL,
    [TentativeDeliveryDate]        DATE                                                 NULL,
    [OrderType]                    SMALLINT                                             CONSTRAINT [DF__Orders__OrderTyp__5AD97420] DEFAULT ((1)) NOT NULL,
    [OfferDiscount]                NUMERIC (18, 2)                                      CONSTRAINT [df_Orders_OfferAmount] DEFAULT ((0)) NULL,
    [CreatedBy]                    INT                                                  NOT NULL,
    [CreatedDate]                  DATETIMEOFFSET (7)                                   CONSTRAINT [DF__Orders__CreatedD__320C68B7] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]               DATETIME                                             CONSTRAINT [DF__Orders__CreatedU__33008CF0] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                    INT                                                  NULL,
    [UpdatedDate]                  DATETIMEOFFSET (7)                                   NULL,
    [UpdatedUTCDate]               DATETIME                                             NULL,
    [InquiryLastUpdatedDate]       DATETIMEOFFSET (7)                                   NULL,
    [LabelId]                      BIGINT                                               NULL,
    [GSTType]                      BIT                                                  DEFAULT ((0)) NOT NULL,
    [LumpsumDiscount]              NUMERIC (18)                                         NULL,
    [DeliveryAmount]               NUMERIC (9)                                          NULL,
    [DeliveryAmountCollectionType] INT                                                  NULL,
    [DeliveryCharge]               TINYINT                                              NULL,
    [LocationID]                   BIGINT                                               NULL,
    [SalesmanId]                   INT                                                  NOT NULL,
    [InteriorCommissionPer]        NUMERIC (5, 2)                                       DEFAULT ((0)) NULL,
    [IsSyncWithTally]              BIT                                                  DEFAULT ((0)) NOT NULL,
    [IsBackOrder]                  BIT                                                  DEFAULT ((0)) NOT NULL,
    [SalesmanCommissionPer]        NUMERIC (5, 2)  NULL,
    [IsFlagged]                    BIT                                                  DEFAULT ((0)) NULL,
    [IsPinned]                     BIT                                                  DEFAULT ((0)) NULL,
    [ViewInquiryImage]             INT                                                  DEFAULT ((1)) NOT NULL,
    [IsArchive]                    BIT                                                  DEFAULT ((0)) NOT NULL,
    [ArchiveOrderDate]             DATETIMEOFFSET (7)                                   NULL,
    [SpecialDiscount]              NUMERIC (18, 2)                                      CONSTRAINT [DF_Orders_SpecialDiscount] DEFAULT ((0)) NOT NULL,
    [ParentOrderId]                BIGINT                                               NULL,
    [CustomerVisitCount]           INT                                                  CONSTRAINT [DF_Orders_CustomerVisitCount] DEFAULT ((0)) NOT NULL,
    [KasarAmount]                  NUMERIC (18, 2)                                      DEFAULT ((0)) NOT NULL,
    [TotalAmt]                     AS                                                   ((([AmountBeforeGST]+[CGSTAmount])+[SGSTAmount])-[KasarAmount]),
    CONSTRAINT [PK__Orders__C3905BCFA9F235EE] PRIMARY KEY CLUSTERED ([OrderId] ASC) WITH (FILLFACTOR = 80),
    CONSTRAINT [CK_Orders_SalesmanId] CHECK ([SalesmanId]>(0))
);


GO

CREATE   TRIGGER [dbo].[trg_Orders_GSTType_Capture_Insert]
   ON  [dbo].[Orders]
   AFTER UPDATE
AS 
BEGIN
	SET NOCOUNT ON;

    DECLARE @InsertedCount INT
    SELECT @InsertedCount = COUNT(1) FROM inserted
    
    IF (@InsertedCount > 0
        AND EXISTS (
            SELECT TOP 1 1
            FROM inserted i
            INNER JOIN deleted d ON i.OrderId = d.OrderId
            WHERE i.GSTType <> d.GSTType
            AND i.TenantId IN (1) --lets focus on Shreem only
        )
    )
    BEGIN
        INSERT INTO dbo.[Orders_Trigger_Log] (OldGSTType, NewGSTType, [OrderId], [OrderNo], [CustomerID], [RefferedBy], [GrossTotal], [Discount], [TotalAmount], [TotalAmt], [AmountBeforeGST], [CGSTAmount], [SGSTAmount], [GSTTaxAmount], [AdvanceAmount], [DeliveryDate], [Comments], [IsFreeDelivery], [Status], [TenantId], [InquiryExpirationDate], [DeliveryCharges], [ApprovedDate], [TentativeDeliveryDate], [OrderType], [OfferDiscount], [CreatedBy], [CreatedDate], [CreatedUTCDate], [UpdatedBy], [UpdatedDate], [UpdatedUTCDate], [InquiryLastUpdatedDate], [LabelId], [GSTType], [LumpsumDiscount], [DeliveryAmount], [DeliveryAmountCollectionType], [DeliveryCharge], [LocationID], [SalesmanId], [InteriorCommissionPer], [IsSyncWithTally], [IsBackOrder], [SalesmanCommissionPer], [IsFlagged], [IsPinned], [ViewInquiryImage], [IsArchive])
        SELECT d.GSTType, i.GSTType, i.[OrderId], i.[OrderNo], i.[CustomerID], i.[RefferedBy], i.[GrossTotal], i.[Discount], i.[TotalAmount], i.[TotalAmt], i.[AmountBeforeGST], i.[CGSTAmount], i.[SGSTAmount], i.[GSTTaxAmount], i.[AdvanceAmount], i.[DeliveryDate], i.[Comments], i.[IsFreeDelivery], i.[Status], i.[TenantId], i.[InquiryExpirationDate], i.[DeliveryCharges], i.[ApprovedDate], i.[TentativeDeliveryDate], i.[OrderType], i.[OfferDiscount], i.[CreatedBy], i.[CreatedDate], i.[CreatedUTCDate], i.[UpdatedBy], i.[UpdatedDate], i.[UpdatedUTCDate], i.[InquiryLastUpdatedDate], i.[LabelId], i.[GSTType], i.[LumpsumDiscount], i.[DeliveryAmount], i.[DeliveryAmountCollectionType], i.[DeliveryCharge], i.[LocationID], i.[SalesmanId], i.[InteriorCommissionPer], i.[IsSyncWithTally], i.[IsBackOrder], i.[SalesmanCommissionPer], i.[IsFlagged], i.[IsPinned], i.[ViewInquiryImage], i.[IsArchive]
        FROM inserted i
        INNER JOIN deleted d ON i.OrderId = d.OrderId
        WHERE i.GSTType <> d.GSTType

        DECLARE @message VARCHAR(MAX)
        SELECT @message = 'Tenant has restricted to change type to Inclusive for Order - ' + CAST(i.OrderId AS VARCHAR(MAX)) + ' ' + CAST(i.OrderNo AS VARCHAR(MAX))
        FROM inserted i
        RAISERROR (@message, 16, 1);
    END
END

GO

