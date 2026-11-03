CREATE TABLE [dbo].[Archive_OrderSetItems] (
    [Archive_OrderSetItemId]     INT                IDENTITY (1106248, 1) NOT NULL,
    [VersionId]                  BIGINT             NOT NULL,
    [Archive_OrderVersionId]     BIGINT             NOT NULL,
    [Archive_OrderSetsVersionId] BIGINT             NOT NULL,
    [OrderSetItemId]             BIGINT             NOT NULL,
    [ParentOrderSetItemId]       BIGINT             NULL,
    [OrderId]                    BIGINT             NOT NULL,
    [OrderSetId]                 BIGINT             NOT NULL,
    [DeliveryNo]                 VARCHAR (50)       NULL,
    [SubjectTypeId]              INT                NOT NULL,
    [SubjectId]                  BIGINT             NOT NULL,
    [DeliveryDate]               DATE               NULL,
    [UnitPrice]                  NUMERIC (18, 2)    NOT NULL,
    [DiscountPrice]              NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_DiscountPrice] DEFAULT ((0)) NOT NULL,
    [GrossTotal]                 NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_GrossTotal] DEFAULT ((0)) NOT NULL,
    [Discount]                   NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_Discount] DEFAULT ((0)) NOT NULL,
    [TotalAmount]                NUMERIC (18, 2)    NOT NULL,
    [AmountBeforeGST]            NUMERIC (18, 2)    NOT NULL,
    [CGSTAmount]                 NUMERIC (18, 2)    NOT NULL,
    [SGSTAmount]                 NUMERIC (18, 2)    NOT NULL,
    [ProductImage]               VARCHAR (MAX)      NULL,
    [Width]                      NUMERIC (18, 2)    NULL,
    [Height]                     NUMERIC (18, 2)    NULL,
    [Depth]                      NUMERIC (18, 2)    NULL,
    [DimensionUnitId]            INT                NULL,
    [Diameter]                   NUMERIC (18, 2)    NULL,
    [Quantity]                   NUMERIC (18, 2)    NOT NULL,
    [Comment]                    NVARCHAR (MAX)     NULL,
    [ItemStatus]                 INT                NOT NULL,
    [ReceiveDate]                DATETIMEOFFSET (7) NULL,
    [ProvidedMaterial]           NUMERIC (5, 2)     NULL,
    [CreatedBy]                  INT                NOT NULL,
    [CreatedDate]                DATETIMEOFFSET (7) CONSTRAINT [DF_Archive_OrderSetItems_CreatedDate] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]             DATETIME           CONSTRAINT [DF_Archive_OrderSetItems_CreatedUTCDate] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                  INT                NULL,
    [UpdatedDate]                DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]             DATETIME           NULL,
    [DeliveryComment]            NVARCHAR (MAX)     NULL,
    [GST]                        NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_GST] DEFAULT ((18)) NOT NULL,
    [CostPrice]                  NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_CostPrice] DEFAULT ((0)) NOT NULL,
    [IsDeleted]                  BIT                CONSTRAINT [DF_Archive_OrderSetItems_IsDeleted] DEFAULT ((0)) NOT NULL,
    [OfferId]                    INT                NULL,
    [InstantUnitPrice]           NUMERIC (18, 2)    NULL,
    [InstantWidth]               NUMERIC (18, 2)    NULL,
    [InstantHeight]              NUMERIC (18, 2)    NULL,
    [InstantDepth]               NUMERIC (18, 2)    NULL,
    [InstantDiameter]            NUMERIC (18, 2)    NULL,
    [InstantCostPrice]           NUMERIC (18, 2)    NULL,
    [ReadyToDeliveredDate]       DATE               NULL,
    [DefaultProductVendorId]     BIGINT             NULL,
    [SalesmanCommission]         NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_SalesmanCommission] DEFAULT ((0)) NULL,
    [InteriorCommission]         NUMERIC (18, 2)    CONSTRAINT [DF_Archive_OrderSetItems_InteriorCommission] DEFAULT ((0)) NULL,
    [MRP]                        NUMERIC (18, 2)    DEFAULT ((0)) NOT NULL,
    [OfferPercentage]            INT                NULL,
    CONSTRAINT [PK_Archive_OrderSetItems] PRIMARY KEY CLUSTERED ([Archive_OrderSetItemId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [ix_NC_Archive_OrderSetItems_cover]
    ON [dbo].[Archive_OrderSetItems]([OrderId] ASC)
    INCLUDE([VersionId]) WITH (FILLFACTOR = 70);


GO

