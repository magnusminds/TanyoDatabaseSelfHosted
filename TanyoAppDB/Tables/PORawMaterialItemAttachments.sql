CREATE TABLE [dbo].[PORawMaterialItemAttachments] (
    [PORawMaterialItemAttachmentId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [PORawMaterialItemId]           BIGINT             NOT NULL,
    [FileURL]                       NVARCHAR (MAX)     NOT NULL,
    [IsDeleted]                     BIT                CONSTRAINT [DF_PORawMaterialItemAttachments_IsDeleted] DEFAULT ((0)) NOT NULL,
    [IsImage]                       BIT                NOT NULL,
    [CreatedBy]                     INT                NOT NULL,
    [CreatedDate]                   DATETIMEOFFSET (7) CONSTRAINT [DF_PORawMaterialItemAttachments_CreatedDate] DEFAULT (sysutcdatetime()) NOT NULL,
    [CreatedUTCDate]                DATETIME           CONSTRAINT [DF_PORawMaterialItemAttachments_CreatedUTCDate] DEFAULT (getutcdate()) NOT NULL,
    [LastModifiedBy]                INT                NULL,
    [LastModifiedDate]              DATETIMEOFFSET (7) NULL,
    [LastModifiedUTCDate]           DATETIME           NULL,
    CONSTRAINT [PK_PORawMaterialItemAttachments] PRIMARY KEY CLUSTERED ([PORawMaterialItemAttachmentId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_PORawMaterialItemAttachments_PORawMaterialItemId]
    ON [dbo].[PORawMaterialItemAttachments]([PORawMaterialItemId] ASC);


GO

