CREATE TABLE [dbo].[OrderQuotationResets]
(
    [OrderQuotationResetId] BIGINT IDENTITY(1, 1) NOT NULL,
    [OrderId]               BIGINT                NOT NULL ,
    [OrderNo]               VARCHAR(100)         NULL,
    [TenantId]              INT                   NOT NULL,
    [ArchiveVersionId]      BIGINT                NULL,
    [OldTotalAmount]        DECIMAL(18, 2)        NOT NULL CONSTRAINT [DF_OrderQuotationResets_OldTotalAmount] DEFAULT (0),
    [NewTotalAmount]        DECIMAL(18, 2)        NULL,
    [CreatedBy]             INT                   NOT NULL CONSTRAINT [DF_OrderQuotationResets_CreatedBy] DEFAULT (0),
    [ResetByName]           VARCHAR(256)         NULL,
    [CreatedDate]           DATETIMEOFFSET(7)     NOT NULL,
    [CreatedUTCDate]        DATETIME              NOT NULL,
    CONSTRAINT [PK_OrderQuotationResets] PRIMARY KEY CLUSTERED ([OrderQuotationResetId]),
    CONSTRAINT [UQ_OrderQuotationResets_OrderId] UNIQUE ([OrderId]),
    INDEX [IX_OrderQuotationResets_TenantId_CreatedDate] NONCLUSTERED ([TenantId], [CreatedDate])
);

GO
