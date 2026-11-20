CREATE   PROCEDURE [dbo].[HFJob_GetRawMaterialPriceUpdateToSendEmail]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON


	BEGIN TRY
	DECLARE @YesterDayDate DATE = DATEADD(DAY, - 1, GETUTCDATE())
	DECLARE @YesterdayStartTime DATETIME = CAST(@YesterDayDate AS VARCHAR(10)) + ' 00:00:00.002'
		,@YesterdayEndTime DATETIME = CAST(@YesterDayDate AS VARCHAR(10)) + ' 23:59:59.997'

	DROP TABLE

	IF EXISTS #tmp_UniquePriceChange
		DROP TABLE

	IF EXISTS #Tmp_EmailLit;
		WITH UniquePriceChange
		AS (
			SELECT al.OldValue
				,al.TableKey
				,ROW_NUMBER() OVER (
					PARTITION BY TableKey ORDER BY TableKey ASC
					) AS Row_Id
			FROM AuditLogs al
			WHERE al.TableName = 'RawMaterial'
				AND al.FieldName = 'UnitPrice'
				AND al.Actions = 'Update'
				AND al.CreatedUTCDate BETWEEN @YesterdayStartTime
					AND @YesterdayEndTime
			)
		SELECT t.TenantId
			,tsd.FromEmail
			,tsd.Password
			,tsd.SMTPPort
			,tsd.SMTPServer
			,tsd.Username
			,tsd.EnableSSL
			,tsd.TargetName
			,rm.Title AS MaterialName
			,rm.UnitPrice AS NewValue
			,upc.OldValue
			,t.TenantName
		INTO #tmp_UniquePriceChange
		FROM UniquePriceChange upc
		INNER JOIN RawMaterials rm ON rm.RawMaterialId = upc.TableKey
		INNER JOIN Tenants t ON t.TenantId = rm.TenantId
			AND t.EnableEmailNotification = 1
		INNER JOIN TenantSMTPDetails tsd ON tsd.TenantID = t.TenantId
		WHERE Row_Id = 1

	SELECT utm.TenantId
		,STRING_AGG(ISNULL(anu.Email, ''), ',') AS EmailList
	INTO #Tmp_EmailLit
	FROM AspNetUsers anu
	INNER JOIN AspNetUserRoles anur ON anur.UserId = anu.Id
	INNER JOIN AspNetRoles anr ON anr.Id = anur.RoleId
	INNER JOIN UserTenantMapping utm ON utm.UserId = anu.UserId
	WHERE anr.Name LIKE 'Administrator_%'
		AND utm.TenantId IN (
			SELECT TenantId
			FROM #tmp_UniquePriceChange
			)
	GROUP BY utm.TenantId

	SELECT a.TenantId
		,a.FromEmail
		,a.Password
		,a.SMTPPort
		,a.SMTPServer
		,a.Username
		,a.EnableSSL
		,a.TargetName
		,a.MaterialName
		,a.OldValue
		,a.NewValue
		,b.EmailList
		,a.TenantName
	FROM #tmp_UniquePriceChange a
	INNER JOIN #Tmp_EmailLit b ON b.TenantId = a.TenantId

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

