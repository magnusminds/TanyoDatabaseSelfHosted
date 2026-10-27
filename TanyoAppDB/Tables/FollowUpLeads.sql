CREATE TABLE [dbo].[FollowUpLeads] (
    [FollowUpLeadId]  BIGINT             IDENTITY (1, 1) NOT NULL,
    [LeadId]          BIGINT             NOT NULL,
    [FollowUpDate]    DATETIME           NULL,
    [FollowUpComment] NVARCHAR (MAX)     NULL,
    [CreatedBy]       INT                NOT NULL,
    [CreatedDate]     DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]  DATETIME           DEFAULT (getutcdate()) NULL,
    CONSTRAINT [PK__FollowUpLeads] PRIMARY KEY CLUSTERED ([FollowUpLeadId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [ix_nc_FollowUpLeads_cover]
    ON [dbo].[FollowUpLeads]([LeadId] ASC)
    INCLUDE([FollowUpDate], [FollowUpComment]) WITH (FILLFACTOR = 70);


GO

CREATE NONCLUSTERED INDEX [IX_NC_FollowUpLeads_LeadId_FollowUpDate]
    ON [dbo].[FollowUpLeads]([LeadId] ASC, [FollowUpDate] DESC)
    INCLUDE([FollowUpComment]);


GO

