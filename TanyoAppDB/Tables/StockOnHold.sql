CREATE TABLE [dbo].[StockOnHold] (
    [StockOnHoldId]  BIGINT             IDENTITY (1, 1) NOT NULL,
    [ProductId]      BIGINT             NOT NULL,
    [Quantity]       NUMERIC (18, 2)    NOT NULL,
    [OrderId]        BIGINT             NOT NULL,
    [OrderSetItemId] BIGINT             NOT NULL,
    [TimePeriod]     VARCHAR (20)       NOT NULL,
    [CreatedBy]      INT                NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) CONSTRAINT [DF__StockOnHo__Creat__733CA444] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate] DATETIME           CONSTRAINT [DF__StockOnHo__Creat__7430C87D] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]      INT                NULL,
    [UpdatedDate]    DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate] DATETIME           NULL,
    [IsStockOnHold]  BIT                NOT NULL,
    [HoldUptoDate]   AS                 (dateadd(day,CONVERT([int],[TimePeriod]),CONVERT([datetimeoffset],[CreatedDate]))),
    PRIMARY KEY CLUSTERED ([StockOnHoldId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_StockOnHold_OrderSetItemId]
    ON [dbo].[StockOnHold]([OrderSetItemId] ASC)
    INCLUDE([ProductId], [IsStockOnHold], [TimePeriod], [CreatedDate], [Quantity], [OrderId]);


GO

CREATE NONCLUSTERED INDEX [IX_NC_StockOnHold_cover]
    ON [dbo].[StockOnHold]([OrderSetItemId] ASC)
    INCLUDE([ProductId], [Quantity], [OrderId]);


GO

