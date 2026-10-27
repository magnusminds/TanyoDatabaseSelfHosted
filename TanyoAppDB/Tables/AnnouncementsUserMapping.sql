CREATE TABLE [dbo].[AnnouncementsUserMapping] (
    [AnnouncementMappingId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [AnnouncementId]        BIGINT             NOT NULL,
    [NotificationType]      VARCHAR (50)       NOT NULL,
    [IsRead]                BIT                NOT NULL,
    [SentTo]                BIGINT             NOT NULL,
    [SentBy]                BIGINT             NOT NULL,
    [ApplicationType]       INT                NOT NULL,
    [TenantId]              BIGINT             NOT NULL,
    [CreatedBy]             BIGINT             NOT NULL,
    [CreatedDate]           DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]        DATETIME           DEFAULT (getutcdate()) NOT NULL
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_AnnouncementsUserMapping_cover]
    ON [dbo].[AnnouncementsUserMapping]([TenantId] ASC, [AnnouncementId] ASC, [NotificationType] ASC, [IsRead] ASC) WITH (FILLFACTOR = 70);


GO

CREATE CLUSTERED INDEX [ix_C_AnnouncementsUserMapping_ID]
    ON [dbo].[AnnouncementsUserMapping]([AnnouncementId] ASC) WITH (FILLFACTOR = 70);


GO

