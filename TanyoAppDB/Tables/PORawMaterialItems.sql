CREATE TABLE [dbo].[PORawMaterialItems] (
    [PORawMaterialItemId]       BIGINT                                               IDENTITY (1, 1) NOT NULL,
    [PORawMaterialId]           BIGINT                                               NOT NULL,
    [RawMaterialId]             BIGINT                                               NOT NULL,
    [Quantity]                  DECIMAL (18, 2)                                      NOT NULL,
    [UnitPrice]                 DECIMAL (18, 2) NOT NULL,
    [ExpectedDeliveryDate]      DATE                                                 NULL,
    [Status]                    INT                                                  DEFAULT ((0)) NOT NULL,
    [Remarks]                   NVARCHAR (500)                                       NULL,
    [CreatedBy]                 INT                                                  NOT NULL,
    [CreatedDate]               DATETIMEOFFSET (7)                                   DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]            DATETIME                                             DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                 INT                                                  NULL,
    [UpdatedDate]               DATETIMEOFFSET (7)                                   NULL,
    [UpdatedUTCDate]            DATETIME                                             NULL,
    [TotalPrice]                AS                                                   ([Quantity]*[UnitPrice]),
    [TentativePOItemPickupDate] DATE                                                 NULL,
    [POItemMaterialReadyDate]   DATETIME                                             NULL,
    PRIMARY KEY CLUSTERED ([PORawMaterialItemId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_PORawMaterialItemsCover]
    ON [dbo].[PORawMaterialItems]([PORawMaterialId] ASC, [RawMaterialId] ASC, [Status] ASC)
    INCLUDE([Quantity], [UnitPrice], [TotalPrice], [ExpectedDeliveryDate], [Remarks]);


GO

