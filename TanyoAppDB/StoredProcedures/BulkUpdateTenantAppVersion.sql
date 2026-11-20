-- =============================================
-- Author       : MagnusMinds
-- Create date  : 07-Aug-2026
-- Description  : Bulk Update Tenant App Version
-- =============================================
/*
    -- Update all tenants
    EXEC [dbo].[BulkUpdateTenantAppVersion]
         @UpdateType = 'AllTenants'
        ,@BundleId = NULL
        ,@DeviceType = 'Android'
        ,@AppVersion = '2.5.0'
        ,@IsForceUpdate = 1
        ,@IsMaintenance = 0
        ,@LastModifiedBy = 1;


    -- Update Tanyo App based on AppBundleId
    EXEC [dbo].[BulkUpdateTenantAppVersion]
         @UpdateType = 'TanyoApp'
        ,@BundleId = 'com.tanyo.app'
        ,@DeviceType = 'Android'
        ,@AppVersion = '2.5.0'
        ,@IsForceUpdate = 1
        ,@IsMaintenance = 0
        ,@LastModifiedBy = 1;
*/
CREATE PROCEDURE [dbo].[BulkUpdateTenantAppVersion] (
	@UpdateType VARCHAR(50)
	,@BundleId VARCHAR(500) = NULL
	,@DeviceType VARCHAR(50)
	,@AppVersion VARCHAR(100)
	,@IsForceUpdate BIT
	,@IsMaintenance BIT
	,@LastModifiedBy BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		-- =============================================
		-- Validate Update Type
		-- =============================================
		IF ISNULL(LTRIM(RTRIM(@UpdateType)), '') NOT IN (
				'AllTenants'
				,'TanyoApp'
				)
		BEGIN
			SELECT CAST(0 AS BIT) AS STATUS
				,'Invalid update type. Allowed values are AllTenants or TanyoApp.' AS Message;

			RETURN;
		END;

		-- =============================================
		-- Validate Device Type
		-- =============================================
		IF NULLIF(LTRIM(RTRIM(@DeviceType)), '') IS NULL
		BEGIN
			SELECT CAST(0 AS BIT) AS STATUS
				,'Device Type is required.' AS Message;

			RETURN;
		END;

		-- =============================================
		-- Validate App Version
		-- =============================================
		IF NULLIF(LTRIM(RTRIM(@AppVersion)), '') IS NULL
		BEGIN
			SELECT CAST(0 AS BIT) AS STATUS
				,'App Version is required.' AS Message;

			RETURN;
		END;

		-- =============================================
		-- Bundle Id is required for Tanyo App
		-- =============================================
		IF @UpdateType = 'TanyoApp'
			AND NULLIF(LTRIM(RTRIM(@BundleId)), '') IS NULL
		BEGIN
			SELECT CAST(0 AS BIT) AS STATUS
				,'App Bundle Id is required for Tanyo App update.' AS Message;

			RETURN;
		END;

		-- =============================================
		-- Validate Bundle Id
		-- =============================================
		IF @UpdateType = 'TanyoApp'
			AND NOT EXISTS (
				SELECT 1
				FROM [dbo].[Tenants] t WITH (NOLOCK)
				WHERE t.AppBundleId = LTRIM(RTRIM(@BundleId))
				)
		BEGIN
			SELECT CAST(0 AS BIT) AS STATUS
				,'App Bundle Id not found.' AS Message;

			RETURN;
		END;

		-- =============================================
		-- Update All Tenants
		-- =============================================
		IF @UpdateType = 'AllTenants'
		BEGIN
			UPDATE tav
			SET tav.DeviceType = LTRIM(RTRIM(@DeviceType))
				,tav.AppVersion = LTRIM(RTRIM(@AppVersion))
				,tav.IsForceUpdate = ISNULL(@IsForceUpdate, 0)
				,tav.IsMaintenance = ISNULL(@IsMaintenance, 0)
				,tav.LastModifiedBy = @LastModifiedBy
				,tav.LastModifiedDate = SYSDATETIMEOFFSET()
				,tav.LastModifiedUTCDate = GETUTCDATE()
			FROM [dbo].[TenantAppVersion] tav;
		END
				-- =============================================
				-- Update Tanyo App
				-- =============================================
		ELSE IF @UpdateType = 'TanyoApp'
		BEGIN
			UPDATE tav
			SET tav.DeviceType = LTRIM(RTRIM(@DeviceType))
				,tav.AppVersion = LTRIM(RTRIM(@AppVersion))
				,tav.IsForceUpdate = ISNULL(@IsForceUpdate, 0)
				,tav.IsMaintenance = ISNULL(@IsMaintenance, 0)
				,tav.LastModifiedBy = @LastModifiedBy
				,tav.LastModifiedDate = SYSDATETIMEOFFSET()
				,tav.LastModifiedUTCDate = GETUTCDATE()
			FROM [dbo].[TenantAppVersion] tav
			INNER JOIN [dbo].[Tenants] t ON t.TenantId = tav.TenantId
			WHERE t.AppBundleId = LTRIM(RTRIM(@BundleId));
		END;

		-- =============================================
		-- Response
		-- =============================================
		SELECT CAST(1 AS BIT) AS STATUS
			,'Tenant app versions updated successfully.' AS Message;
	END TRY

BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

