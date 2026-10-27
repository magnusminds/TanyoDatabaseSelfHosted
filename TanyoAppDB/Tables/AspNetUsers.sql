CREATE TABLE [dbo].[AspNetUsers] (
    [Id]                      NVARCHAR (450)     NOT NULL,
    [FirstName]               NVARCHAR (MAX)     NOT NULL,
    [LastName]                NVARCHAR (MAX)     NOT NULL,
    [IsActive]                BIT                NOT NULL,
    [IsDeleted]               BIT                NOT NULL,
    [UserName]                NVARCHAR (256)     NULL,
    [NormalizedUserName]      NVARCHAR (256)     NULL,
    [Email]                   NVARCHAR (256)     NULL,
    [NormalizedEmail]         NVARCHAR (256)     NULL,
    [EmailConfirmed]          BIT                NOT NULL,
    [PasswordHash]            NVARCHAR (MAX)     NULL,
    [SecurityStamp]           NVARCHAR (MAX)     NULL,
    [ConcurrencyStamp]        NVARCHAR (MAX)     NULL,
    [PhoneNumber]             NVARCHAR (MAX)     NULL,
    [PhoneNumberConfirmed]    BIT                NOT NULL,
    [TwoFactorEnabled]        BIT                NOT NULL,
    [LockoutEnd]              DATETIMEOFFSET (7) NULL,
    [LockoutEnabled]          BIT                NOT NULL,
    [AccessFailedCount]       INT                NOT NULL,
    [UserId]                  INT                IDENTITY (1, 1) NOT NULL,
    [MobileDeviceId]          VARCHAR (100)      NULL,
    [RegisteredFCMToken]      VARCHAR (250)      NULL,
    [MacAddress]              VARCHAR (50)       NULL,
    [CommissionPer]           NUMERIC (5, 2)     DEFAULT ((0)) NULL,
    [IsNewUser]               BIT                DEFAULT ((1)) NOT NULL,
    [HasMasterOtpChanged]     BIT                DEFAULT ((0)) NOT NULL,
    [IsRetailerUser]          BIT                DEFAULT ((1)) NOT NULL,
    [IsManager]               BIT                DEFAULT ((0)) NOT NULL,
    [FieldStoreOperationType] INT                NULL,
    [IsAppCatalogueNewView]   BIT                CONSTRAINT [DF_AspNetUsers_IsAppCatalogueNewView] DEFAULT ((0)) NOT NULL,
    [SalesTarget]             NUMERIC (18, 2)    CONSTRAINT [DF_AspNetUsers_SalesTarget] DEFAULT ((0)) NOT NULL,
    [Salary]                  NUMERIC (18, 2)    CONSTRAINT [DF_AspNetUsers_Salary] DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_AspNetUsers] PRIMARY KEY CLUSTERED ([Id] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE UNIQUE NONCLUSTERED INDEX [UserNameIndex]
    ON [dbo].[AspNetUsers]([NormalizedUserName] ASC, [IsActive] ASC, [IsDeleted] ASC, [NormalizedEmail] ASC) WHERE ([NormalizedUserName] IS NOT NULL) WITH (FILLFACTOR = 70);


GO

CREATE NONCLUSTERED INDEX [IX_NC_UserId]
    ON [dbo].[AspNetUsers]([UserId] ASC);


GO

