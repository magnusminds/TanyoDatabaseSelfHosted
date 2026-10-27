CREATE TABLE [dbo].[NotificationManagement] (
    [NotificationManagementID] BIGINT             IDENTITY (1, 1) NOT NULL,
    [EntityTypeID]             BIGINT             NOT NULL,
    [EntityID]                 BIGINT             NOT NULL,
    [NotificationType]         VARCHAR (50)       NOT NULL,
    [NotificationMethod]       VARCHAR (50)       NOT NULL,
    [MessageSubject]           NVARCHAR (500)     NULL,
    [MessageBody]              NVARCHAR (MAX)     NULL,
    [ReceiverEmail]            VARCHAR (100)      NULL,
    [ReceiverMobile]           VARCHAR (20)       NULL,
    [Status]                   INT                DEFAULT ((0)) NOT NULL,
    [CreatedBy]                BIGINT             NOT NULL,
    [CreatedDate]              DATETIMEOFFSET (7) CONSTRAINT [DF__Notificat__Creat__1AF3F935] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]           DATETIME           DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                BIGINT             NULL,
    [UpdatedDate]              DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]           DATETIME           NULL,
    [TenantId]                 INT                NOT NULL,
    [Response]                 VARCHAR (MAX)      NULL,
    [WAMessageId]              VARCHAR (80)       NULL,
    PRIMARY KEY CLUSTERED ([NotificationManagementID] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_NotificationManagement_TenantId_CreatedDate_EntityTypeID_ReceiverEmail_ReceiverMobile_Status]
    ON [dbo].[NotificationManagement]([TenantId] ASC, [NotificationMethod] ASC, [CreatedDate] ASC, [EntityTypeID] ASC, [Status] ASC)
    INCLUDE([NotificationType], [ReceiverEmail], [ReceiverMobile]) WITH (FILLFACTOR = 80);


GO

CREATE NONCLUSTERED INDEX [IX_NotificationManagement_WAMessageId]
    ON [dbo].[NotificationManagement]([WAMessageId] ASC);


GO

