CREATE TABLE [dbo].[OrganizationOwnerDetails] (
    [OwnerId]        BIGINT             IDENTITY (1, 1) NOT NULL,
    [OwnerFullName]  VARCHAR (200)      NOT NULL,
    [PhoneNumber]    VARCHAR (16)       NOT NULL,
    [EmailId]        VARCHAR (255)      NOT NULL,
    [TenantId]       INT                NOT NULL,
    [IsDeleted]      BIT                CONSTRAINT [DF_OrganizationOwnerDetails_IsDeleted] DEFAULT ((0)) NOT NULL,
    [CreatedBy]      INT                NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) CONSTRAINT [DF_OrganizationOwnerDetails_CreatedDate] DEFAULT (sysdatetime()) NOT NULL,
    [CreatedUTCDate] DATETIME           CONSTRAINT [DF_OrganizationOwnerDetails_CreatedUTCDate] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]      INT                NULL,
    [UpdatedDate]    DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate] DATETIME           NULL,
    CONSTRAINT [PK_OrganizationOwnerDetails] PRIMARY KEY CLUSTERED ([OwnerId] ASC)
);


GO

