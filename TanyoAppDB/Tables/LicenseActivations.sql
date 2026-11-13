CREATE TABLE [dbo].[LicenseActivations](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[LicenseKeyId] [int] NOT NULL,
	[ActivatedDomain] [nvarchar](255) NOT NULL,
	[ActivatedAt] [datetime2](7) NOT NULL,
	[LastValidatedAt] [datetime2](7) NULL,
	[IsActive] [bit] NOT NULL,
	[AdminBaseUrl] [nvarchar](500) NULL,
	[ApiBaseUrl] [nvarchar](500) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
),
UNIQUE NONCLUSTERED 
(
	[LicenseKeyId] ASC,
	[ActivatedDomain] ASC
)
)
GO

ALTER TABLE [dbo].[LicenseActivations] ADD  DEFAULT (getutcdate()) FOR [ActivatedAt]
GO

ALTER TABLE [dbo].[LicenseActivations] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[LicenseActivations]  WITH CHECK ADD FOREIGN KEY([LicenseKeyId])
REFERENCES [dbo].[LicenseKeys] ([Id])
GO


