CREATE TABLE [dbo].[PipelineTest] (
    [OrderTrackId]        BIGINT          IDENTITY (1, 1) NOT NULL,
    [TenantId]            INT             NOT NULL,
    [ProductId]           BIGINT          NULL,
    [Quantity]            NUMERIC (18, 2) CONSTRAINT [DF_PipelineTest_Quantity] DEFAULT ((0)) NOT NULL,
    [OrderId]             BIGINT          NULL,
    [OrderNo]             VARCHAR (20)    NULL,
    [CustomerId]          BIGINT          NULL,
    [CustomerName]        VARCHAR (255)   NULL,
    [LastModifiedBy]      INT             NOT NULL,
    [LastModifiedDate]    DATETIME        CONSTRAINT [DF__PipelineTest__CreatedDate] DEFAULT (sysdatetimeoffset()) NULL,
    [LastModifiedUtcDate] DATETIME        CONSTRAINT [DF__PipelineTest__CreatedUtcDate] DEFAULT (getutcdate()) NULL,
    [IsDeleted]           BIT             CONSTRAINT [DF_PipelineTest_IsDeleted] DEFAULT ((0)) NULL,
    CONSTRAINT [PK__PipelineTest_OrderTrackId] PRIMARY KEY CLUSTERED ([OrderTrackId] ASC) WITH (FILLFACTOR = 80)
);


GO

