CREATE TABLE [dbo].[Categories] (
    [CategoryId]                  BIGINT                                              IDENTITY (1, 1) NOT NULL,
    [CategoryTypeId]              BIGINT                                              NOT NULL,
    [CategoryName]                VARCHAR (50)                                        NOT NULL,
    [IsFixedPrice]                BIT                                                 DEFAULT ((0)) NOT NULL,
    [RSPPercentage]               NUMERIC (7, 2) DEFAULT ((0)) NOT NULL,
    [WSPPercentage]               NUMERIC (7, 2) DEFAULT ((0)) NOT NULL,
    [TenantId]                    BIGINT                                              NOT NULL,
    [IsDeleted]                   BIT                                                 DEFAULT ((0)) NOT NULL,
    [CreatedBy]                   BIGINT                                              NOT NULL,
    [CreatedDate]                 DATETIMEOFFSET (7)                                  CONSTRAINT [DF__Categorie__Creat__3B60C8C7] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]              DATETIME                                            DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                   BIGINT                                              NULL,
    [UpdatedDate]                 DATETIMEOFFSET (7)                                  NULL,
    [UpdatedUTCDate]              DATETIME                                            NULL,
    [IsManufacturing]             BIT                                                 DEFAULT ((0)) NOT NULL,
    [IsVisibleInAddOn]            BIT                                                 CONSTRAINT [DF_Categories_IsVisibleInAddOn] DEFAULT ((0)) NOT NULL,
    [GST]                         NUMERIC (18, 2)                                     CONSTRAINT [df_Categories_GST] DEFAULT ((18)) NULL,
    [MaxDiscount]                 NUMERIC (18, 2)                                     CONSTRAINT [df_Categories_MaxDiscount] DEFAULT ((100)) NULL,
    [IsCommissionEnabled]         BIT                                                 DEFAULT ((0)) NULL,
    [FriendlyName]                VARCHAR (50)                                        NULL,
    [IsCommissionEnabledInterior] BIT                                                 DEFAULT ((0)) NULL,
    [IsSellByPerSQFT]             BIT                                                 DEFAULT ((0)) NOT NULL,
    [IsFabric]                    BIT                                                 CONSTRAINT [DF_Categories_IsFabric] DEFAULT ((0)) NOT NULL,
    [ParentCategoryId]            BIGINT                                              NULL,
    [CoverImage]                  VARCHAR (MAX)                                       NULL,
    PRIMARY KEY CLUSTERED ([CategoryId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_Categories_CategoryTypeId_IsManufacturing]
    ON [dbo].[Categories]([IsDeleted] ASC, [TenantId] ASC, [CategoryTypeId] ASC, [IsManufacturing] ASC)
    INCLUDE([CategoryName], [IsSellByPerSQFT]) WITH (FILLFACTOR = 70);


GO

