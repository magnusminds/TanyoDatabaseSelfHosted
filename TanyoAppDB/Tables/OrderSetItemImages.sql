CREATE TABLE [dbo].[OrderSetItemImages] (
    [OrderSetItemImageId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [OrderSetItemId]      BIGINT             NOT NULL,
    [DrawImage]           VARCHAR (MAX)      NULL,
    [CreatedBy]           INT                NOT NULL,
    [CreatedDate]         DATETIMEOFFSET (7) CONSTRAINT [DF__OrderSetI__Creat__0169315C] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]      DATETIME           CONSTRAINT [DF__OrderSetI__Creat__025D5595] DEFAULT (getutcdate()) NOT NULL,
    [FileType]            VARCHAR (10)       NULL,
    [FileURL]             VARCHAR (MAX)      NULL,
    [FileName]            NVARCHAR (500)     NULL,
    CONSTRAINT [PK__OrderSet__DC93CB5FF96A1550] PRIMARY KEY CLUSTERED ([OrderSetItemImageId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_OrderSetItemImages_OrderSetItemId_CreatedDate]
    ON [dbo].[OrderSetItemImages]([OrderSetItemId] ASC, [CreatedDate] ASC)
    INCLUDE([DrawImage], [CreatedBy], [FileURL]) WITH (FILLFACTOR = 70);


GO

