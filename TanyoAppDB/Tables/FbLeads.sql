CREATE TABLE [dbo].[FbLeads] (
    [FbLeadId]       BIGINT             IDENTITY (1, 1) NOT NULL,
    [TenantId]       INT                NOT NULL,
    [LeadgenId]      VARCHAR (30)       NOT NULL,
    [PageId]         VARCHAR (30)       NOT NULL,
    [FormId]         VARCHAR (30)       NULL,
    [AdId]           VARCHAR (30)       NULL,
    [AdName]         NVARCHAR (300)     NULL,
    [AdsetId]        VARCHAR (30)       NULL,
    [AdsetName]      VARCHAR (300)      NULL,
    [CampaignId]     VARCHAR (30)       NULL,
    [CampaignName]   VARCHAR (300)      NULL,
    [Platform]       VARCHAR (20)       NULL,
    [IsOrganic]      BIT                NULL,
    [FbCreatedTime]  DATETIME2 (7)      NULL,
    [FullName]       VARCHAR (200)      NULL,
    [Email]          NVARCHAR (256)     NULL,
    [PhoneNumber]    VARCHAR (50)       NULL,
    [City]           VARCHAR (100)      NULL,
    [RawFieldData]   NVARCHAR (MAX)     NULL,
    [IsTestLead]     BIT                DEFAULT ((0)) NOT NULL,
    [CrmLeadId]      BIGINT             NULL,
    [Status]         VARCHAR (20)       DEFAULT ('Pending') NOT NULL,
    [LastError]      VARCHAR (2000)     NULL,
    [ReceivedAt]     DATETIME2 (7)      DEFAULT (sysdatetime()) NOT NULL,
    [ProcessedAt]    DATETIME2 (7)      NULL,
    [CreatedDate]    DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate] DATETIME           DEFAULT (getutcdate()) NOT NULL,
    CONSTRAINT [PK_FbLeads] PRIMARY KEY CLUSTERED ([FbLeadId] ASC),
    CONSTRAINT [CK_FbLeads_Status] CHECK ([Status]='Skipped' OR [Status]='Failed' OR [Status]='Imported' OR [Status]='Pending'),
    CONSTRAINT [UQ_FbLeads_LeadgenId] UNIQUE NONCLUSTERED ([LeadgenId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_FbLeads_TenantId_FbCreatedTime]
    ON [dbo].[FbLeads]([TenantId] ASC, [FbCreatedTime] DESC)
    INCLUDE([LeadgenId], [PageId], [CrmLeadId], [Status], [FullName], [PhoneNumber]);


GO

CREATE NONCLUSTERED INDEX [IX_FbLeads_Status_ReceivedAt]
    ON [dbo].[FbLeads]([Status] ASC, [ReceivedAt] ASC)
    INCLUDE([TenantId], [LeadgenId], [PageId]);


GO

