CREATE TABLE [dbo].[LicenseKeys](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[KeyString] [nvarchar](100) NOT NULL,
	[TenantLimit] [int] NOT NULL,
	[ExpiryDate] [datetime2](7) NOT NULL,
	[StorageProvider] [nvarchar](50) NOT NULL,
	[QueueProvider] [nvarchar](50) NOT NULL,
	[Features] [nvarchar](max) NULL,
	[IsActive] [bit] NOT NULL,
	[CreatedAt] [datetime2](7) NOT NULL,
	[UpdatedAt] [datetime2](7) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
),
UNIQUE NONCLUSTERED 
(
	[KeyString] ASC
)
)
GO

ALTER TABLE [dbo].[LicenseKeys] ADD  DEFAULT ((1)) FOR [TenantLimit]
GO

ALTER TABLE [dbo].[LicenseKeys] ADD  DEFAULT ('Azure') FOR [StorageProvider]
GO

ALTER TABLE [dbo].[LicenseKeys] ADD  DEFAULT ('Azure') FOR [QueueProvider]
GO

ALTER TABLE [dbo].[LicenseKeys] ADD  DEFAULT ((1)) FOR [IsActive]
GO

ALTER TABLE [dbo].[LicenseKeys] ADD  DEFAULT (getutcdate()) FOR [CreatedAt]
GO

ALTER TABLE [dbo].[LicenseKeys] ADD  DEFAULT (getutcdate()) FOR [UpdatedAt]
GO


