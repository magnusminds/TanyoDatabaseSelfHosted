CREATE TABLE [dbo].[PORawMaterialPayment] (
    [PORawMaterialPaymentId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [PORawMaterialId]        BIGINT             NOT NULL,
    [VendorId]               BIGINT             NOT NULL,
    [TenantId]               INT                NOT NULL,
    [PaymentType]            INT                NOT NULL,
    [PaymentStatus]          INT                NOT NULL,
    [BankName]               VARCHAR (200)      NULL,
    [AccountHolderName]      VARCHAR (200)      NULL,
    [ChequeNo]               NVARCHAR (100)     NULL,
    [ReceivedAmount]         DECIMAL (18, 2)    NULL,
    [PaymentReceivedBy]      INT                NULL,
    [ReceivedDate]           DATETIME           NOT NULL,
    [PaymentApprovedBy]      INT                NULL,
    [ApprovedDate]           DATETIMEOFFSET (7) NULL,
    [Comments]               NVARCHAR (MAX)     NULL,
    [TransactionId]          NVARCHAR (100)     NULL,
    [IsDeleted]              BIT                CONSTRAINT [DF_PORawMaterialPayment_IsDeleted] DEFAULT ((0)) NOT NULL,
    [CreatedBy]              INT                NULL,
    [CreatedDate]            DATETIMEOFFSET (7) CONSTRAINT [DF_PORawMaterialPayment_CreatedDate] DEFAULT (sysutcdatetime()) NOT NULL,
    [CreatedUTCDate]         DATETIME           CONSTRAINT [DF_PORawMaterialPayment_CreatedUTCDate] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]              INT                NULL,
    [UpdatedDate]            DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]         DATETIME           NULL,
    CONSTRAINT [PK_PORawMaterialPayment] PRIMARY KEY CLUSTERED ([PORawMaterialPaymentId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_PORawMaterialPayment_PORawMaterialId]
    ON [dbo].[PORawMaterialPayment]([PORawMaterialId] ASC)
    INCLUDE([ReceivedAmount], [PaymentStatus], [IsDeleted]);


GO

