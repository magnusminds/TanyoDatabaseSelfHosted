CREATE TABLE [dbo].[OrderCommentsTest] (
    [OrderCommentId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [OrderId]        BIGINT             NOT NULL,
    [Status]         INT                NOT NULL,
    [Comments]       NVARCHAR (MAX)     NOT NULL,
    [CreatedBy]      INT                NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) CONSTRAINT [DF_OrderCommentstest_CreatedDate] DEFAULT (sysdatetimeoffset()) NULL,
    [CreatedUTCDate] DATETIME           NOT NULL,
    [Remarks]        NVARCHAR (MAX)     NULL,
    CONSTRAINT [PK_OrderComments_Test] PRIMARY KEY CLUSTERED ([OrderCommentId] ASC) WITH (FILLFACTOR = 80)
);

