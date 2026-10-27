CREATE TABLE [dbo].[WhatsAppDealerInquiryLogs] (
    [WhatsAppDealerInquiryLogId] BIGINT             IDENTITY (1, 1) NOT NULL,
    [DealerCustomerId]           BIGINT             NOT NULL,
    [DealerPhone]                VARCHAR (20)       NOT NULL,
    [DealerName]                 VARCHAR (200)      NULL,
    [ModelNo]                    VARCHAR (100)      NOT NULL,
    [ProductId]                  BIGINT             NOT NULL,
    [InquiryType]                VARCHAR (20)       NOT NULL,
    [RequestedQty]               DECIMAL (18, 2)    NULL,
    [IsAvailable]                BIT                NULL,
    [ResponseMessage]            NVARCHAR (500)     NULL,
    [TenantId]                   INT                NOT NULL,
    [CreatedDate]                DATETIMEOFFSET (7) CONSTRAINT [DF_WhatsAppDealerInquiryLogs_CreatedDate] DEFAULT (sysdatetimeoffset()) NOT NULL,
    CONSTRAINT [PK_WhatsAppDealerInquiryLogs] PRIMARY KEY CLUSTERED ([WhatsAppDealerInquiryLogId] ASC)
);


GO

CREATE NONCLUSTERED INDEX [IX_WhatsAppDealerInquiryLogs_DealerCustomerId_CreatedDate]
    ON [dbo].[WhatsAppDealerInquiryLogs]([DealerCustomerId] ASC, [CreatedDate] ASC)
    INCLUDE([ModelNo], [InquiryType], [RequestedQty], [IsAvailable]);


GO

CREATE NONCLUSTERED INDEX [IX_WhatsAppDealerInquiryLogs_TenantId_CreatedDate]
    ON [dbo].[WhatsAppDealerInquiryLogs]([TenantId] ASC, [CreatedDate] ASC)
    INCLUDE([DealerCustomerId], [DealerPhone], [DealerName], [ModelNo], [ProductId], [InquiryType], [RequestedQty], [IsAvailable]);


GO

