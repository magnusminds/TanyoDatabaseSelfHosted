CREATE TABLE [dbo].[WrkProducts] (
    [WrkProductID]    BIGINT                                             IDENTITY (1, 1) NOT NULL,
    [WrkImportFileID] BIGINT                                             NOT NULL,
    [CategoryName]    VARCHAR (MAX)                                      NULL,
    [ProductTitle]    VARCHAR (MAX)                                      NULL,
    [ModelNo]         VARCHAR (MAX)                                      NULL,
    [Width]           VARCHAR (MAX)                                      NULL,
    [Height]          VARCHAR (MAX)                                      NULL,
    [Depth]           VARCHAR (MAX)                                      NULL,
    [Diameter]        VARCHAR (MAX)                                      NULL,
    [Unit]            VARCHAR (250)                                      NULL,
    [Status]          INT                                                DEFAULT ((0)) NOT NULL,
    [ErrorMessage]    VARCHAR (MAX)                                      NULL,
    [CreatedBy]       BIGINT                                             NOT NULL,
    [CreatedDate]     DATETIMEOFFSET (7)                                 DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]  DATETIME                                           DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]       BIGINT                                             NULL,
    [UpdatedDate]     DATETIMEOFFSET (7)                                 NULL,
    [UpdatedUTCDate]  DATETIME                                           NULL,
    [CostPrice]       VARCHAR (MAX) NULL,
    [StockQty]        VARCHAR (MAX)                                      NULL,
    [VendorName]      VARCHAR (MAX)                                      NULL,
    [RetailerPrice]   VARCHAR (MAX) NULL,
    [WholesalerPrice] VARCHAR (MAX) NULL,
    [WarehouseName]   VARCHAR (MAX)                                      NULL,
    PRIMARY KEY CLUSTERED ([WrkProductID] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_WrkProducts_WrkImportFileID]
    ON [dbo].[WrkProducts]([WrkImportFileID] ASC)
    INCLUDE([CategoryName], [ProductTitle], [ModelNo], [Status], [CreatedDate]) WITH (FILLFACTOR = 80);


GO

