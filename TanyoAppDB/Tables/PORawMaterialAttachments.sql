CREATE TABLE [dbo].[PORawMaterialAttachments] (
    [PORawMaterialAttachmentId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [PORawMaterialId]           BIGINT             NOT NULL,
    [FileURL]                   NVARCHAR (MAX)     NOT NULL,
    [IsImage]                   BIT                NOT NULL,
    [Status]                    INT                NULL,
    [LastModifiedBy]            BIGINT             NOT NULL,
    [LastModifiedDate]          DATETIMEOFFSET (7) NOT NULL,
    [LastModifiedUTCDate]       DATETIME           NOT NULL,
    CONSTRAINT [PK_PORawMaterialAttachments] PRIMARY KEY CLUSTERED ([PORawMaterialAttachmentId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_PORawMaterialAttachments_PORawMaterialId]
    ON [dbo].[PORawMaterialAttachments]([PORawMaterialId] ASC);


GO

