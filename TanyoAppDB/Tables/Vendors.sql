CREATE TABLE [dbo].[Vendors] (
    [VendorId]               BIGINT             IDENTITY (1, 1) NOT NULL,
    [VendorName]             VARCHAR (150)      NOT NULL,
    [VendorEmailId]          VARCHAR (50)       NOT NULL,
    [VendorPhone]            VARCHAR (16)       NOT NULL,
    [GST]                    VARCHAR (20)       NULL,
    [ZipCode]                VARCHAR (10)       NULL,
    [City]                   VARCHAR (100)      NULL,
    [State]                  VARCHAR (100)      NULL,
    [Country]                VARCHAR (100)      NULL,
    [TenantId]               INT                NOT NULL,
    [Notes]                  VARCHAR (150)      NULL,
    [ContactPersonName]      VARCHAR (150)      NULL,
    [ContactPersonEmail]     VARCHAR (50)       NULL,
    [ContactPersonPhone]     VARCHAR (16)       NULL,
    [Website]                VARCHAR (50)       NULL,
    [Status]                 BIT                NOT NULL,
    [CreatedBy]              INT                NOT NULL,
    [CreatedDate]            DATETIMEOFFSET (7) NOT NULL,
    [CreatedUTCDate]         DATETIME           NOT NULL,
    [UpdatedBy]              INT                NULL,
    [UpdatedDate]            DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]         DATETIME           NULL,
    [AcceptRejectStatus]     BIT                NULL,
    [VendorTenantID]         INT                NULL,
    [ReferralCode]           VARCHAR (10)       NULL,
    [SalesmanId]             BIGINT             NULL,
    [IsDealer]               BIT                DEFAULT ((1)) NOT NULL,
    [DealerCustomerId]       BIGINT             NULL,
    [PaymentTermsInDays]     INT                DEFAULT ((1)) NOT NULL,
    [IsAutoPoByOrder]        BIT                CONSTRAINT [DF_Vendors_IsAutoPoByOrder] DEFAULT ((0)) NOT NULL,
    [VendorCode]             VARCHAR (6)        NOT NULL,
    [Expense]                INT                CONSTRAINT [DF_Vendors_Expense] DEFAULT ((0)) NOT NULL,
    [FullAddress]            VARCHAR (500)      NULL,
    [GSTType]                BIT                DEFAULT ((1)) NOT NULL,
    [IsEmailNotification]    BIT                DEFAULT ((0)) NOT NULL,
    [IsSMSNotification]      BIT                DEFAULT ((0)) NOT NULL,
    [IsWhatsappNotification] BIT                DEFAULT ((0)) NOT NULL,
    CONSTRAINT [PK_Vendors] PRIMARY KEY CLUSTERED ([VendorId] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [ix_NC_Vendors_Cover]
    ON [dbo].[Vendors]([VendorId] ASC)
    INCLUDE([VendorName]);


GO

