CREATE TABLE [dbo].[Products] (
    [ProductId]              BIGINT                                               IDENTITY (1, 1) NOT NULL,
    [CategoryId]             INT                                                  NOT NULL,
    [TenantId]               INT                                                  NOT NULL,
    [ProductTitle]           VARCHAR (150)                                        NOT NULL,
    [ModelNo]                VARCHAR (100)                                        NOT NULL,
    [RetailerPrice]          NUMERIC (18, 2) CONSTRAINT [DF__Products__Retail__0ECE1972] DEFAULT ((0.00)) NOT NULL,
    [WholesalerPrice]        NUMERIC (18, 2) CONSTRAINT [DF__Products__Wholes__0FC23DAB] DEFAULT ((0.00)) NOT NULL,
    [RetailOfferPrice]       NUMERIC (18, 2) NULL,
    [Width]                  NUMERIC (18, 2)                                      NULL,
    [Height]                 NUMERIC (18, 2)                                      NULL,
    [Depth]                  NUMERIC (18, 2)                                      NULL,
    [FabricNeeded]           NUMERIC (5, 2)                                       NULL,
    [IsVisibleToWholesalers] BIT                                                  CONSTRAINT [DF__Products__IsVisi__6CD828CA] DEFAULT ((0)) NOT NULL,
    [TotalDaysToPrepare]     NUMERIC (5, 2)                                       CONSTRAINT [DF__Products__TotalD__6DCC4D03] DEFAULT ((0)) NOT NULL,
    [Features]               VARCHAR (MAX)                                        NULL,
    [Comments]               VARCHAR (MAX)                                        NULL,
    [CostPrice]              NUMERIC (18, 2) CONSTRAINT [DF__Products__CostPr__6EC0713C] DEFAULT ((0)) NOT NULL,
    [QRImage]                VARCHAR (MAX)                                        NULL,
    [Status]                 INT                                                  CONSTRAINT [DF__Products__Status__51BA1E3A] DEFAULT ((2)) NOT NULL,
    [CreatedBy]              INT                                                  NOT NULL,
    [CreatedDate]            DATETIMEOFFSET (7)                                   CONSTRAINT [DF__Products__Create__52AE4273] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]         DATETIME                                             CONSTRAINT [DF__Products__Create__73852659] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]              INT                                                  NULL,
    [UpdatedDate]            DATETIMEOFFSET (7)                                   NULL,
    [UpdatedUTCDate]         DATETIME                                             NULL,
    [Diameter]               NUMERIC (18, 2)                                      NULL,
    [DimensionUnitId]        INT                                                  NULL,
    [VendorId]               BIGINT                                               NULL,
    [ProductVariantId]       BIGINT                                               NULL,
    [IsPriceAutoCalculated]  BIT                                                  CONSTRAINT [DF__Products__IsPric__1269A02C] DEFAULT ((1)) NOT NULL,
    [VendorProductPrice]     NUMERIC (18, 2) NULL,
    [CoverImage]             VARCHAR (1000)                                       NULL,
    [WholesalerOfferPrice]   NUMERIC (18, 2) NULL,
    [VendorNames]            VARCHAR (1000)                                       NULL,
    [HSNNo]                  VARCHAR (50)                                         NULL,
    [ProductMaterialId]      BIGINT                                               NULL,
    [ProductColourId]        BIGINT                                               NULL,
    [ProductBrandId]         BIGINT                                               NULL,
    [PackingBox]             NUMERIC (18, 2)                                      NULL,
    [ProductCostImage]       VARCHAR (MAX)                                        NULL,
    CONSTRAINT [PK_Products] PRIMARY KEY CLUSTERED ([ProductId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_Products_CategoryId_TenantId_Status]
    ON [dbo].[Products]([TenantId] ASC, [CategoryId] ASC, [Status] ASC)
    INCLUDE([ProductTitle], [ModelNo], [RetailerPrice], [WholesalerPrice]) WITH (FILLFACTOR = 70);


GO

CREATE NONCLUSTERED INDEX [ix_nc_Products_Status_Price]
    ON [dbo].[Products]([TenantId] ASC, [Status] ASC, [RetailerPrice] ASC)
    INCLUDE([ProductId], [CategoryId], [ProductTitle], [ModelNo]) WITH (FILLFACTOR = 70);


GO

