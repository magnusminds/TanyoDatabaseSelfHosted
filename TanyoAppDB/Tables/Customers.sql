CREATE TABLE [dbo].[Customers] (
    [CustomerId]            BIGINT                                                            IDENTITY (1, 1) NOT NULL,
    [CustomerTypeId]        INT                                                               NOT NULL,
    [FirstName]             VARCHAR (150)                                                     NOT NULL,
    [LastName]              VARCHAR (50)                                                      NULL,
    [EmailId]               VARCHAR (100) NULL,
    [PhoneNumber]           VARCHAR (16)                                                      NOT NULL,
    [AltPhoneNumber]        VARCHAR (16)                                                      NULL,
    [GSTNo]                 VARCHAR (15)                                                      NULL,
    [RefferedBy]            BIGINT                                                            NULL,
    [Discount]              NUMERIC (5, 2)                                                    CONSTRAINT [DF_Customers_Discount] DEFAULT ((0)) NOT NULL,
    [TenantId]              INT                                                               NOT NULL,
    [IsDeleted]             BIT                                                               CONSTRAINT [DF__Customers__IsDel__4E1E9780] DEFAULT ((0)) NOT NULL,
    [CreatedBy]             INT                                                               NOT NULL,
    [CreatedDate]           DATETIMEOFFSET (7)                                                CONSTRAINT [DF__Customers__Creat__4F12BBB9] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]        DATETIME                                                          CONSTRAINT [DF__Customers__Creat__5006DFF2] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]             INT                                                               NULL,
    [UpdatedDate]           DATETIMEOFFSET (7)                                                CONSTRAINT [df_Customers_UpdatedDate] DEFAULT (sysdatetimeoffset()) NULL,
    [UpdatedUTCDate]        DATETIME                                                          NULL,
    [IsSubscribe]           BIT                                                               CONSTRAINT [DF__Customers__IsSub__2D12A970] DEFAULT ((0)) NULL,
    [IsVerified]            BIT                                                               CONSTRAINT [DF__Customers__IsVer__52AE4273] DEFAULT ((0)) NULL,
    [Birthday]              DATETIME                                                          NULL,
    [Anniversary]           DATETIME                                                          NULL,
    [Profession]            VARCHAR (50)                                                      NULL,
    [CompanyName]           VARCHAR (100)                                                     NULL,
    [LabelId]               BIGINT                                                            NULL,
    [AltName]               VARCHAR (50)                                                      NULL,
    [LocationID]            BIGINT                                                            NOT NULL,
    [InteriorCommissionPer] NUMERIC (5, 2)                                                    CONSTRAINT [DF__Customers__Inter__03275C9C] DEFAULT ((0)) NULL,
    [CustomerTenantID]      INT                                                               NULL,
    [PANNo]                 VARCHAR (15)                                                      NULL,
    [ProfessionId]          INT                                                               NULL,
    [SpecializedInId]       BIGINT                                                            NULL,
    [ArchitectCategoryId]   INT                                                               NULL,
    [ArchitectTypeId]       INT                                                               NULL,
    [EventId]               INT                                                               NULL,
    [SocialMediaUrl]        VARCHAR (500)                                                     NULL,
    [EventText]             VARCHAR (500)                                                     NULL,
    [MonthlyTarget]         DECIMAL (18, 2)                                                   NULL,
    [CustomerInteriorTypeId] INT NULL,
    CONSTRAINT [PK__Customer__A4AE64B881128DE3] PRIMARY KEY CLUSTERED ([CustomerId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_Customers_CustomerTypeId_TenantId_IsDeleted]
    ON [dbo].[Customers]([TenantId] ASC, [CustomerTypeId] ASC, [IsDeleted] ASC)
    INCLUDE([CreatedDate], [FirstName], [LastName], [PhoneNumber]) WITH (FILLFACTOR = 80);


GO

