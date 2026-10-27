CREATE TABLE [dbo].[POProducts] (
    [POProductId]           BIGINT                                               IDENTITY (1, 1) NOT NULL,
    [TenantId]              BIGINT                                               NOT NULL,
    [VendorId]              BIGINT                                               NOT NULL,
    [PONumber]              VARCHAR (20)                                         NOT NULL,
    [OrderDate]             DATETIME                                             DEFAULT (getdate()) NOT NULL,
    [TotalAmount]           DECIMAL (18, 2) NULL,
    [Status]                INT                                                  DEFAULT ((0)) NOT NULL,
    [IsDeleted]             BIT                                                  DEFAULT ((0)) NOT NULL,
    [CreatedBy]             INT                                                  NOT NULL,
    [CreatedDate]           DATETIMEOFFSET (7)                                   DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]        DATETIME                                             DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]             INT                                                  NULL,
    [UpdatedDate]           DATETIMEOFFSET (7)                                   NULL,
    [UpdatedUTCDate]        DATETIME                                             NULL,
    [IsSyncWithTally]       BIT                                                  CONSTRAINT [DF_POProduct_IsSyncWithTally] DEFAULT ((0)) NOT NULL,
    [ExpectedDeliveryDate]  DATE                                                 NULL,
    [OrderId]               BIGINT                                               NULL,
    [TentativePOPickupDate] DATETIME                                             NULL,
    [VendorOrderId]         BIGINT                                               NULL,
    [POMaterialReadyDate]   DATETIME                                             NULL,
    [AmountBeforeGST]       NUMERIC (18, 2) NULL,
    [CGSTAmount]            NUMERIC (18, 2) NULL,
    [SGSTAmount]            NUMERIC (18, 2) NULL,
    [GSTType]               BIT                                                  CONSTRAINT [DF_POProducts_GSTType] DEFAULT ((1)) NOT NULL,
    [IsInterState]          BIT                                                  DEFAULT ((0)) NOT NULL,
    [IGSTAmount]            NUMERIC (18, 2) NULL,
    [LabelId]               BIGINT                                               NULL,
    PRIMARY KEY CLUSTERED ([POProductId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_POProductsCover]
    ON [dbo].[POProducts]([TenantId] ASC, [VendorId] ASC)
    INCLUDE([PONumber], [OrderDate], [TotalAmount], [Status], [ExpectedDeliveryDate]) WITH (FILLFACTOR = 70);


GO

