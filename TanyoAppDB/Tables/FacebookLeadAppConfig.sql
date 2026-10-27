CREATE TABLE [dbo].[FacebookLeadAppConfig] (
    [FacebookLeadAppConfigId] BIGINT         IDENTITY (1, 1) NOT NULL,
    [TenantId]                INT            NOT NULL,
    [AppId]                   VARCHAR (30)   NOT NULL,
    [AppSecret]               VARCHAR (500)  NOT NULL,
    [VerifyToken]             NVARCHAR (255) NOT NULL,
    [GraphVersion]            VARCHAR (20)   NULL,
    [IsEnabled]               BIT            DEFAULT ((1)) NOT NULL,
    [CreatedBy]               INT            NULL,
    [CreatedDate]             DATETIME2 (7)  DEFAULT (sysdatetime()) NOT NULL,
    [CreatedUTCDate]          DATETIME       DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]               INT            NULL,
    [UpdatedDate]             DATETIME2 (7)  NULL,
    [UpdatedUTCDate]          DATETIME2 (7)  NULL,
    CONSTRAINT [PK_FacebookLeadAppConfig] PRIMARY KEY CLUSTERED ([FacebookLeadAppConfigId] ASC),
    CONSTRAINT [UQ_FacebookLeadAppConfig_Tenant] UNIQUE NONCLUSTERED ([TenantId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_FacebookLeadAppConfig_VerifyToken]
    ON [dbo].[FacebookLeadAppConfig]([VerifyToken] ASC)
    INCLUDE([TenantId], [AppId], [AppSecret], [GraphVersion], [IsEnabled]);


GO

