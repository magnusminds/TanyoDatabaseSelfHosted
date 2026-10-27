CREATE TABLE [dbo].[FacebookAPIPageDetails] (
    [FacebookAPIPageDetailsID]  BIGINT         IDENTITY (1, 1) NOT NULL,
    [PageAccessToken]           VARCHAR (400)  NULL,
    [Category]                  VARCHAR (400)  NULL,
    [CategoriesList]            VARCHAR (MAX)  NULL,
    [PageName]                  VARCHAR (400)  NULL,
    [PageID]                    VARCHAR (400)  NULL,
    [Tasks]                     VARCHAR (MAX)  NULL,
    [LongTermPageAccessToken]   VARCHAR (400)  NULL,
    [PageTokenCreatedDate]      DATETIME       NOT NULL,
    [FacebookLoginCredentialID] BIGINT         NOT NULL,
    [TenantId]                  VARCHAR (900)  NOT NULL,
    [CreatedBy]                 VARCHAR (100)  NOT NULL,
    [CreatedDate]               DATETIME       CONSTRAINT [DF_FacebookAPIPageDetails_CreatedDate] DEFAULT (getdate()) NOT NULL,
    [CreatedUTCDate]            DATETIME       CONSTRAINT [DF_FacebookAPIPageDetails_CreatedUTCDate] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                 BIGINT         NULL,
    [UpdatedDate]               DATETIME       NULL,
    [UpdatedUTCDate]            DATETIME       NULL,
    [IGUserID]                  VARCHAR (400)  NULL,
    [IsActive]                  BIT            NULL,
    [IsLeadAdsConnected]        BIT            DEFAULT ((0)) NOT NULL,
    [LeadAdsAppId]              VARCHAR (30)   NULL,
    [LeadAdsPageToken]          VARCHAR (4000) NULL,
    [SubscribedToLeadgen]       BIT            DEFAULT ((0)) NOT NULL,
    [LeadAdsConnectedBy]        INT            NULL,
    [LeadAdsConnectedDate]      DATETIME2 (7)  NULL,
    CONSTRAINT [PK_FacebookAPIPageDetails] PRIMARY KEY CLUSTERED ([FacebookAPIPageDetailsID] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_FacebookAPIPageDetails_LeadAds_Page]
    ON [dbo].[FacebookAPIPageDetails]([PageID] ASC, [TenantId] ASC, [IsLeadAdsConnected] ASC)
    INCLUDE([PageName], [LeadAdsPageToken], [SubscribedToLeadgen], [LeadAdsAppId], [LeadAdsConnectedBy], [IsActive]) WHERE ([IsLeadAdsConnected]=(1));


GO

CREATE UNIQUE NONCLUSTERED INDEX [UQ_FacebookAPIPageDetails_LeadAds_Page]
    ON [dbo].[FacebookAPIPageDetails]([PageID] ASC) WHERE ([IsLeadAdsConnected]=(1));


GO

