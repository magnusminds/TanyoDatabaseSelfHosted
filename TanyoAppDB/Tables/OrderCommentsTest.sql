CREATE TABLE [dbo].[OrderCommentsTest] (
    [OrderCommentId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [OrderId]        BIGINT             NOT NULL,
    [Status]         INT                NOT NULL,
    [Comments]       NVARCHAR (MAX)     NOT NULL,
    [CreatedBy]      INT                NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) CONSTRAINT [DF_OrderComments_CreatedDate] DEFAULT (sysdatetimeoffset()) NULL,
    [CreatedUTCDate] DATETIME           NOT NULL,
    [Remarks]        NVARCHAR (MAX)     NULL,
    CONSTRAINT [PK_OrderComments] PRIMARY KEY CLUSTERED ([OrderCommentId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_OrderComments_OrderId]
    ON [dbo].[OrderComments]([OrderId] ASC)
    INCLUDE([Comments]) WITH (FILLFACTOR = 80);


GO

