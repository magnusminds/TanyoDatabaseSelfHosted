CREATE TABLE [dbo].[Warehouse] (
    [Id]             BIGINT             IDENTITY (1, 1) NOT NULL,
    [Name]           VARCHAR (100)      NOT NULL,
    [Description]    VARCHAR (500)      NULL,
    [QRCode]         VARCHAR (MAX)      NULL,
    [TenantId]       BIGINT             NOT NULL,
    [IsDeleted]      BIT                DEFAULT ((0)) NOT NULL,
    [CreatedBy]      BIGINT             NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate] DATETIME           DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]      BIGINT             NULL,
    [UpdatedDate]    DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate] DATETIME           NULL,
    [IsDefault]      BIT                CONSTRAINT [DF_Warehouse_IsDefault] DEFAULT ((0)) NOT NULL,
    PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO


CREATE NONCLUSTERED INDEX IX_Warehouse_TenantID_IsDeleted
ON dbo.Warehouse (TenantID, IsDeleted);
GO