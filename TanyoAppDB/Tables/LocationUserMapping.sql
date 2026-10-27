CREATE TABLE [dbo].[LocationUserMapping] (
    [LocationUserMappingID] BIGINT IDENTITY (1, 1) NOT NULL,
    [LocationID]            BIGINT NOT NULL,
    [UserID]                BIGINT NOT NULL,
    [IsDefault]             BIT    NOT NULL,
    PRIMARY KEY CLUSTERED ([LocationUserMappingID] ASC) WITH (FILLFACTOR = 80)
);


GO

CREATE NONCLUSTERED INDEX [IX_NC_LocationUserMapping_UserId_LocationId]
    ON [dbo].[LocationUserMapping]([UserID] ASC, [LocationID] ASC);


GO

