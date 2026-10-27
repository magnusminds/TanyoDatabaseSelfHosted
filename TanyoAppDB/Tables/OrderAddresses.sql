CREATE TABLE [dbo].[OrderAddresses] (
    [OrderAddressId]    BIGINT             IDENTITY (1, 1) NOT NULL,
    [OrderId]           BIGINT             NOT NULL,
    [CustomerAddressId] BIGINT             NOT NULL,
    [FirstName]         VARCHAR (50)       NOT NULL,
    [LastName]          VARCHAR (50)       NULL,
    [EmailId]           VARCHAR (100)      NULL,
    [PhoneNumber]       VARCHAR (16)       NOT NULL,
    [AddressType]       VARCHAR (15)       NOT NULL,
    [Street1]           VARCHAR (200)      NOT NULL,
    [Street2]           VARCHAR (200)      NULL,
    [Landmark]          VARCHAR (100)      NULL,
    [Area]              VARCHAR (100)      NOT NULL,
    [City]              VARCHAR (100)      NOT NULL,
    [State]             VARCHAR (100)      NOT NULL,
    [ZipCode]           VARCHAR (6)        NOT NULL,
    [CreatedBy]         INT                NOT NULL,
    [CreatedDate]       DATETIMEOFFSET (7) CONSTRAINT [DF__OrderAddr__Creat__0539C240] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]    DATETIME           CONSTRAINT [DF__OrderAddr__Creat__062DE679] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]         INT                NULL,
    [UpdatedDate]       DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]    DATETIME           NULL,
    [GSTNo]             VARCHAR (15)       NULL,
    [Latitude]          VARCHAR (25)       NULL,
    [Longitude]         VARCHAR (25)       NULL,
    [CompanyName]       VARCHAR (100)      NULL,
    [Country]           VARCHAR (MAX)      NULL,
    [FullAddress]       VARCHAR (MAX)      NULL,
    CONSTRAINT [PK__OrderAdd__34B754E5BD4071ED] PRIMARY KEY CLUSTERED ([OrderAddressId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_OrderAddresses_OrderId]
    ON [dbo].[OrderAddresses]([OrderId] ASC)
    INCLUDE([CustomerAddressId], [EmailId], [PhoneNumber]) WITH (FILLFACTOR = 80);


GO

