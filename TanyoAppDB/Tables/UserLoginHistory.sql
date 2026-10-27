CREATE TABLE [dbo].[UserLoginHistory] (
    [LoginHistoryID] BIGINT        IDENTITY (1, 1) NOT NULL,
    [UserID]         BIGINT        NOT NULL,
    [LoginDateTime]  DATETIME      DEFAULT (getdate()) NOT NULL,
    [IPAddress]      VARCHAR (50)  NOT NULL,
    [UserAgent]      VARCHAR (500) NOT NULL,
    [Source]         VARCHAR (20)  CONSTRAINT [DF_UserLoginHistory_Source] DEFAULT ('APP') NOT NULL,
    PRIMARY KEY CLUSTERED ([LoginHistoryID] ASC)
);


GO

