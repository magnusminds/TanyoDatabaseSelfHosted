CREATE TABLE [dbo].[EmployeeDetails] (
    [EmployeeDetailID]          BIGINT             IDENTITY (1, 1) NOT NULL,
    [UserID]                    INT                NULL,
    [DateofBirth]               DATE               NULL,
    [DepartmentID]              INT                NULL,
    [DesignationID]             INT                NULL,
    [Address]                   VARCHAR (250)      NULL,
    [PersonalEmailID]           VARCHAR (50)       NULL,
    [OtherMobile]               VARCHAR (16)       NULL,
    [EmergencyContactName]      VARCHAR (50)       NULL,
    [EmergencyContact]          VARCHAR (16)       NULL,
    [BloodGroup]                VARCHAR (3)        NULL,
    [ProfilePic]                VARCHAR (500)      NULL,
    [Gender]                    VARCHAR (15)       NULL,
    [DateOfJoining]             DATE               NULL,
    [Experience]                DECIMAL (4, 2)     NULL,
    [ReportingTo]               INT                NULL,
    [CreatedBy]                 INT                NOT NULL,
    [CreatedDate]               DATETIMEOFFSET (7) CONSTRAINT [DF__EmployeeD__Creat__1610DF35] DEFAULT (sysdatetimeoffset()) NOT NULL,
    [CreatedUTCDate]            DATETIME           CONSTRAINT [DF__EmployeeD__Creat__1705036E] DEFAULT (getutcdate()) NOT NULL,
    [UpdatedBy]                 INT                NULL,
    [UpdatedDate]               DATETIMEOFFSET (7) NULL,
    [UpdatedUTCDate]            DATETIME           NULL,
    [DateOfAnniversary]         DATE               NULL,
    [JoiningExperienceInMonths] INT                DEFAULT ((0)) NULL,
    CONSTRAINT [PK__Employee__3214EC2791EFF41C] PRIMARY KEY CLUSTERED ([EmployeeDetailID] ASC) WITH (FILLFACTOR = 80)
);


GO

