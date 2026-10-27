CREATE TABLE [dbo].[BackOfficePushNotificationHistory] (
    [HistoryId]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [Title]             NVARCHAR (200) NOT NULL,
    [Message]           NVARCHAR (MAX) NOT NULL,
    [TotalTenants]      INT            NOT NULL,
    [TotalRoles]        INT            NOT NULL,
    [TotalUsers]        INT            NOT NULL,
    [TotalSent]         INT            NOT NULL,
    [FailedCount]       INT            NOT NULL,
    [SentByUserId]      VARCHAR (450)  NOT NULL,
    [SentDate]          DATETIME2 (7)  CONSTRAINT [DF__BackOfficePushNotificationHistory__SentDate] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [SelectedTenantIds] NVARCHAR (MAX) NULL,
    [SelectedRoleIds]   NVARCHAR (MAX) NULL,
    PRIMARY KEY CLUSTERED ([HistoryId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_BackOfficePushNotificationHistory_SentDate]
    ON [dbo].[BackOfficePushNotificationHistory]([SentDate] DESC);


GO

