CREATE TABLE [dbo].[Contractor] (
    [ContractorId]   INT                IDENTITY (1, 1) NOT NULL,
    [ContractorName] VARCHAR (50)       NOT NULL,
    [PhoneNumber]    VARCHAR (16)       NOT NULL,
    [IMEI]           VARCHAR (15)       NOT NULL,
    [EmailId]        VARCHAR (50)       NOT NULL,
    [TenantId]       INT                NULL,
    [IsDeleted]      BIT                DEFAULT ((0)) NOT NULL,
    [CreatedBy]      INT                NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) CONSTRAINT [DF__Contracto__Creat__6CD828CA] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate] DATETIME           DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]      INT                NULL,
    [UpdatedDate]    DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate] DATETIME           NULL,
    PRIMARY KEY CLUSTERED ([ContractorId] ASC)
);


GO

