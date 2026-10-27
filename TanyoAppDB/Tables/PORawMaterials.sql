CREATE TABLE [dbo].[PORawMaterials] (
    [PORawMaterialId]       BIGINT             IDENTITY (1, 1) NOT NULL,
    [TenantId]              BIGINT             NOT NULL,
    [VendorId]              BIGINT             NOT NULL,
    [PONumber]              VARCHAR (20)       NOT NULL,
    [OrderDate]             DATETIME           DEFAULT (getdate()) NOT NULL,
    [TotalAmount]           DECIMAL (18, 2)    NULL,
    [Status]                INT                DEFAULT ((0)) NOT NULL,
    [IsDeleted]             BIT                DEFAULT ((0)) NOT NULL,
    [CreatedBy]             INT                NOT NULL,
    [CreatedDate]           DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]        DATETIME           DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]             INT                NULL,
    [UpdatedDate]           DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]        DATETIME           NULL,
    [ExpectedDeliveryDate]  DATE               NULL,
    [TentativePOPickupDate] DATETIME           NULL,
    [POMaterialReadyDate]   DATETIME           NULL,
    PRIMARY KEY CLUSTERED ([PORawMaterialId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_PORawMaterialsCover]
    ON [dbo].[PORawMaterials]([TenantId] ASC, [VendorId] ASC, [Status] ASC, [IsDeleted] ASC)
    INCLUDE([PONumber], [OrderDate], [TotalAmount]);


GO

