CREATE TABLE [dbo].[WhatsAppTemplateMappings] (
    [MappingId]       BIGINT             IDENTITY (1, 1) NOT NULL,
    [TemplateId]      BIGINT             NOT NULL,
    [TenantId]        BIGINT             NOT NULL,
    [VariableType]    VARCHAR (50)       NOT NULL,
    [Variable]        VARCHAR (50)       NOT NULL,
    [VariableMapping] VARCHAR (100)      NOT NULL,
    [PhoneNumber]     VARCHAR (16)       NULL,
    [IsDeleted]       BIT                NOT NULL,
    [CreatedBy]       BIGINT             NOT NULL,
    [CreatedDate]     DATETIMEOFFSET (7) NOT NULL,
    [CreatedUTCDate]  DATETIME           NOT NULL,
    [UpdatedBy]       BIGINT             NULL,
    [UpdatedDate]     DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]  DATETIME           NULL,
    PRIMARY KEY CLUSTERED ([MappingId] ASC)
);


GO

