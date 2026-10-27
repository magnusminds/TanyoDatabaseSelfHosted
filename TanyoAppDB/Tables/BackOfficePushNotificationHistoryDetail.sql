CREATE TABLE [dbo].[BackOfficePushNotificationHistoryDetail] (
    [HistoryDetailId] BIGINT          IDENTITY (1, 1) NOT NULL,
    [HistoryId]       BIGINT          NOT NULL,
    [UserId]          INT             NOT NULL,
    [FullName]        VARCHAR (256)   NULL,
    [Status]          TINYINT         NOT NULL,
    [FailureReason]   NVARCHAR (1000) NULL,
    [SentDate]        DATETIME2 (7)   CONSTRAINT [DF_BackOfficePushNotificationHistoryDetail_SentDate] DEFAULT (sysutcdatetime()) NOT NULL,
    PRIMARY KEY CLUSTERED ([HistoryDetailId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_BackOfficePushNotificationHistoryDetail_HistoryId]
    ON [dbo].[BackOfficePushNotificationHistoryDetail]([HistoryId] ASC);


GO

