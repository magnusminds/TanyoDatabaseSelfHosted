CREATE TABLE [dbo].[Leads] (
    [LeadId]                  BIGINT             IDENTITY (1, 1) NOT NULL,
    [FirstName]               VARCHAR (50)       NOT NULL,
    [LastName]                VARCHAR (50)       NULL,
    [PhoneNumber]             VARCHAR (16)       NULL,
    [Notes]                   NVARCHAR (MAX)     NULL,
    [Source]                  INT                NOT NULL,
    [Email]                   VARCHAR (100)      NULL,
    [Priority]                INT                NULL,
    [Status]                  INT                CONSTRAINT [DF__Leads__Status__4E0988E7] DEFAULT ((0)) NOT NULL,
    [SalesmanId]              BIGINT             NULL,
    [SalesmanAssignDate]      DATE               NULL,
    [LastContactedDate]       DATE               NOT NULL,
    [Other]                   VARCHAR (MAX)      NULL,
    [TenantId]                INT                NOT NULL,
    [CreatedBy]               BIGINT             NOT NULL,
    [CreatedDate]             DATETIMEOFFSET (7) CONSTRAINT [DF__Leads__CreatedDa__4EFDAD20] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]          DATETIME           CONSTRAINT [DF__Leads__CreatedUT__4FF1D159] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]               BIGINT             NULL,
    [UpdatedDate]             DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]          DATETIME           NULL,
    [InquiryAbout]            BIGINT             NULL,
    [LocationID]              BIGINT             NULL,
    [CloseLookupValueId]      INT                NULL,
    [InquiryFor]              VARCHAR (MAX)      NULL,
    [RefferedBy]              BIGINT             NULL,
    [CustomerId]              BIGINT             NULL,
    [LeadSourceId]            BIGINT             NULL,
    [LeadNumber]              VARCHAR (15)       NOT NULL,
    [PurchaseUrgencyId]       BIGINT             NULL,
    [CustomerBehaviorId]      BIGINT             NULL,
    [BuyingRangeValueId]      BIGINT             NULL,
    [LeadType]                INT                CONSTRAINT [DF_Leads_LeadType] DEFAULT ((0)) NULL,
    [AlternateMobileNumber]   VARCHAR (16)       NULL,
    [InquiryAreaRequirement]  DECIMAL (18, 2)    NULL,
    [AlternateSalesmanId]     BIGINT             NULL,
    [ClientMeetingStageId]    INT                NULL,
    [ArchitectMeetingStageId] INT                NULL,
    [ArchitectBehaviorId]     BIGINT             NULL,
    [CompanyName]             VARCHAR (200)      NULL,
    [VisitForId]              BIGINT             NULL,
    CONSTRAINT [PK__Leads__73EF78FA3F0F5F65] PRIMARY KEY CLUSTERED ([LeadId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_Leads_TenantId_Status]
    ON [dbo].[Leads]([TenantId] ASC, [Status] ASC, [CustomerId] ASC, [LocationID] ASC, [LeadSourceId] ASC, [CreatedDate] ASC)
    INCLUDE([Source], [SalesmanId], [CreatedBy], [Priority]) WITH (FILLFACTOR = 80);


GO

