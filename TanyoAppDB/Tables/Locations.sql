CREATE TABLE [dbo].[Locations] (
    [LocationID]     BIGINT             IDENTITY (1, 1) NOT NULL,
    [LocationName]   VARCHAR (100)      NOT NULL,
    [Address]        VARCHAR (500)      NULL,
    [PhoneNumber]    VARCHAR (16)       NULL,
    [TenantID]       INT                NOT NULL,
    [IsDeleted]      BIT                DEFAULT ((0)) NOT NULL,
    [CreatedBy]      INT                NOT NULL,
    [CreatedDate]    DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate] DATETIME           DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]      INT                NULL,
    [UpdatedDate]    DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate] DATETIME           NULL,
    [EmailId]        VARCHAR (100)      NULL,
    PRIMARY KEY CLUSTERED ([LocationID] ASC)
);


GO

