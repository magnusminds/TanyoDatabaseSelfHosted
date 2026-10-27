CREATE TABLE [dbo].[InwardDetailsEntry] (
    [InwardDetailsId]       BIGINT             IDENTITY (1, 1) NOT NULL,
    [InwardId]              BIGINT             NOT NULL,
    [ProductId]             INT                NOT NULL,
    [Quantity]              NUMERIC (18, 2)    NOT NULL,
    [Amount]                DECIMAL (18, 2)    NULL,
    [IsDeleted]             BIT                NOT NULL,
    [CreatedBy]             INT                NOT NULL,
    [CreatedDate]           DATETIMEOFFSET (7) NOT NULL,
    [CreatedUTCDate]        DATETIME           NOT NULL,
    [UpdatedBy]             INT                NULL,
    [UpdatedDate]           DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]        DATETIME           NULL,
    [Remark]                VARCHAR (250)      NULL,
    [ImagePath]             VARCHAR (MAX)      NULL,
    [WarehouseId]           BIGINT             NULL,
    [OrderSetItemId]        BIGINT             NULL,
    [AudioURL]              VARCHAR (MAX)      NULL,
    [STOCKTRANSFERDETAILID] INT                NULL,
    [POProductItemId]       BIGINT             NULL,
    CONSTRAINT [PK_InwardDetailsEntry] PRIMARY KEY CLUSTERED ([InwardDetailsId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [ix_NC_InwardDetailsEntry_cover]
    ON [dbo].[InwardDetailsEntry]([InwardId] ASC, [ProductId] ASC, [IsDeleted] ASC)
    INCLUDE([Quantity], [Amount]) WITH (FILLFACTOR = 70);


GO

