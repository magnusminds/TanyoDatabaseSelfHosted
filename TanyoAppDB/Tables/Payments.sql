CREATE TABLE [dbo].[Payments] (
    [PaymentId]         BIGINT             IDENTITY (1, 1) NOT NULL,
    [OrderId]           BIGINT             NULL,
    [TenantId]          INT                NULL,
    [PaymentType]       INT                DEFAULT ((0)) NULL,
    [BankName]          VARCHAR (100)      NULL,
    [AccountHolderName] VARCHAR (100)      NULL,
    [ChequeNo]          VARCHAR (50)       NULL,
    [ReceivedAmount]    NUMERIC (18, 2)    NULL,
    [PaymentReceivedBy] INT                NULL,
    [PaymentApprovedBy] INT                NULL,
    [PaymentStatus]     INT                DEFAULT ((0)) NULL,
    [ApprovedDate]      DATETIMEOFFSET (7) NULL,
    [IsDeleted]         BIT                DEFAULT ((0)) NULL,
    [UpdatedBy]         INT                NULL,
    [UpdatedDate]       DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]    SMALLDATETIME      NULL,
    [CreatedBy]         INT                NULL,
    [CreatedDate]       DATETIMEOFFSET (7) DEFAULT (sysdatetimeoffset()) NULL,
    [CreatedUTCDate]    SMALLDATETIME      DEFAULT (getutcdate()) NULL,
    [ReceivedDate]      DATETIME           DEFAULT (getdate()) NOT NULL,
    [Comments]          VARCHAR (500)      NULL,
    [TransactionId]     VARCHAR (100)      NULL
);


GO

CREATE NONCLUSTERED INDEX [IX_Payments_OrderId_PaymentStatus_IsDeleted_ApprovedDate_PaymentType_PaymentApprovedBy]
    ON [dbo].[Payments]([OrderId] ASC, [PaymentStatus] ASC, [IsDeleted] ASC, [ApprovedDate] ASC, [PaymentType] ASC, [PaymentApprovedBy] ASC) WITH (FILLFACTOR = 80);


GO

CREATE CLUSTERED INDEX [IX_C_Payments_Tenant]
    ON [dbo].[Payments]([OrderId] ASC, [TenantId] ASC);


GO

