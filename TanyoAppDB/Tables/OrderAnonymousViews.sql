CREATE TABLE [dbo].[OrderAnonymousViews] (
    [OrderAnonymousViewId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [OrderId]              BIGINT             NOT NULL,
    [CustomerId]           BIGINT             NOT NULL,
    [IPAddress]            VARCHAR (50)       NOT NULL,
    [CreatedDate]          DATETIMEOFFSET (7) CONSTRAINT [DF__OrderAnon__Creat__6DEC4894] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]       DATETIME           DEFAULT (getutcdate()) NULL,
    [BrowserName]          VARCHAR (1000)     DEFAULT (NULL) NULL,
    PRIMARY KEY CLUSTERED ([OrderAnonymousViewId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_OrderAnonymousViews_OrderId_CustomerId]
    ON [dbo].[OrderAnonymousViews]([OrderId] ASC, [CustomerId] ASC) WITH (FILLFACTOR = 80);


GO

