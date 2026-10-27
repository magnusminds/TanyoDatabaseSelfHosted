CREATE TABLE [dbo].[POProductItems] (
    [POProductItemId]           BIGINT                                               IDENTITY (1, 1) NOT NULL,
    [POProductId]               BIGINT                                               NOT NULL,
    [ProductId]                 BIGINT                                               NOT NULL,
    [VendorModelNo]             VARCHAR (50)                                         NOT NULL,
    [Quantity]                  DECIMAL (18, 2)                                      NOT NULL,
    [UnitPrice]                 DECIMAL (18, 2) NOT NULL,
    [ExpectedDeliveryDate]      DATE                                                 NULL,
    [Status]                    INT                                                  CONSTRAINT [DF__POProduct__Statu__2DD28ED6] DEFAULT ((0)) NOT NULL,
    [Remarks]                   NVARCHAR (500)                                       NULL,
    [CreatedBy]                 INT                                                  NOT NULL,
    [CreatedDate]               DATETIMEOFFSET (7)                                   CONSTRAINT [DF__POProduct__Creat__60DD3190] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]            DATETIME                                             CONSTRAINT [DF__POProduct__Creat__61D155C9] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                 INT                                                  NULL,
    [UpdatedDate]               DATETIMEOFFSET (7)                                   NULL,
    [UpdatedUTCDate]            DATETIME                                             NULL,
    [OrderSetItemId]            BIGINT                                               NULL,
    [Width]                     NUMERIC (18, 2)                                      CONSTRAINT [DF_POProductItems_Width] DEFAULT ((1)) NOT NULL,
    [Height]                    NUMERIC (18, 2)                                      CONSTRAINT [DF_POProductItems_Height] DEFAULT ((1)) NOT NULL,
    [Depth]                     NUMERIC (18, 2)                                      CONSTRAINT [DF_POProductItems_Depth] DEFAULT ((1)) NOT NULL,
    [Diameter]                  NUMERIC (18, 2)                                      CONSTRAINT [DF_POProductItems_Diameter] DEFAULT ((1)) NOT NULL,
    [TentativePOItemPickupDate] DATETIME                                             NULL,
    [VendorOrderSetItemId]      BIGINT                                               NULL,
    [POItemMaterialReadyDate]   DATETIME                                             NULL,
    [CGSTAmount]                NUMERIC (18, 2) NULL,
    [SGSTAmount]                NUMERIC (18, 2) NULL,
    [GSTType]                   BIT                                                  CONSTRAINT [DF_POProductItems_GSTType] DEFAULT ((1)) NOT NULL,
    [GST]                       NUMERIC (18, 2)                                      CONSTRAINT [DF_POProductItems_GST] DEFAULT ((18)) NOT NULL,
    [IsInterState]              BIT                                                  CONSTRAINT [DF__POProduct__IsInt__5927012F] DEFAULT ((0)) NOT NULL,
    [IGSTAmount]                NUMERIC (18, 2) NULL,
    [TotalPrice]                AS                                                   (CONVERT([numeric](18,2),round([UnitPrice]*[Quantity],(0)))),
    [AmountBeforeGST]           AS                                                   (CONVERT([numeric](18,2),round(case when [GSTType]=(0) then (([UnitPrice]*[Quantity])*(100))/nullif((100)+[GST],(0)) else [UnitPrice]*[Quantity] end,(0)))),
    [TotalAmount_Old]           NUMERIC (18, 2)                                      NULL,
    [TotalAmount]               AS                                                   (CONVERT([numeric](18,2),round(case when [GSTType]=(0) then [UnitPrice]*[Quantity] else [UnitPrice]*[Quantity]+case when [IsInterState]=(1) then isnull([IGSTAmount],(0)) else isnull([CGSTAmount],(0))+isnull([SGSTAmount],(0)) end end,(0)))),
    [ParentPOProductItemId]     BIGINT                                               NULL,
    [IsAddOn]                   BIT                                                  CONSTRAINT [DF_POProductItems_IsAddOn] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK__POProduc__818EDC75F1D0A8B7] PRIMARY KEY CLUSTERED ([POProductItemId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_POProductItems_Cover]
    ON [dbo].[POProductItems]([POProductId] ASC, [ProductId] ASC)
    INCLUDE([VendorModelNo], [Quantity], [UnitPrice], [ExpectedDeliveryDate], [Status]);


GO

