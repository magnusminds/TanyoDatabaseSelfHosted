/*
	EXEC [dbo].[GetFollowUpLeads]
*/
CREATE   PROC [dbo].[GetFollowUpLeads]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @FollowUpDate DATETIME = DATEADD(HOUR, DATEDIFF(HOUR, 0, GETDATE()), 0)

	IF OBJECT_ID('tempdb..#InquirySubjectTypeByTenant') IS NOT NULL
		DROP TABLE #InquirySubjectTypeByTenant

	SELECT TenantID
		,SubjectTypeId
	INTO #InquirySubjectTypeByTenant
	FROM dbo.SubjectTypes st WITH (NOLOCK)
	WHERE st.SubjectTypeName = 'Inquiries'
		AND st.IsDeleted = 0

	INSERT INTO dbo.Notifications (
		EntityTypeId
		,EntityId
		,NotificationType
		,Message
		,IsRead
		,SentTo
		,SentBy
		,TenantId
		,CreatedBy
		,ApplicationType
		)
	SELECT ISTBT.SubjectTypeId AS EntityTypeId
		,l.LeadId AS EntityId
		,'Followup' AS NotificationType
		,ISNULL(ful.FollowUpComment, 'It''s time to take a follow up.') AS Message
		,0 AS IsRead
		,l.SalesmanId AS SentTo
		,l.CreatedBy AS SentBy
		,l.TenantId AS TenantId
		,l.CreatedBy AS CreatedBy
		,2 AS ApplicationType
	FROM dbo.FollowUpLeads ful WITH (NOLOCK)
	INNER JOIN dbo.Leads l WITH (NOLOCK) ON l.LeadId = ful.LeadId
	INNER JOIN #InquirySubjectTypeByTenant ISTBT WITH (NOLOCK) ON ISTBT.TenantId = L.TenantId
	INNER JOIN AspNetUsers anu WITH (NOLOCK) ON anu.UserId = l.SalesmanId
	WHERE l.STATUS <> 6
		AND DATEADD(HOUR, DATEDIFF(HOUR, 0, ful.FollowUpDate), 0) = @FollowUpDate
		AND ful.FollowUpDate IS NOT NULL
		AND ISNULL(ful.FollowUpComment, '') <> ''

	SELECT l.LeadId
		,CAST(ful.FollowUpDate AS DATE) AS FollowUpDate
		,ful.FollowUpComment
		,anu.RegisteredFCMToken
		,L.TenantId
		,T.TenantName
	FROM dbo.FollowUpLeads ful WITH (NOLOCK)
	INNER JOIN dbo.Leads l WITH (NOLOCK) ON l.LeadId = ful.LeadId
	INNER JOIN #InquirySubjectTypeByTenant ISTBT WITH (NOLOCK) ON ISTBT.TenantId = L.TenantId
	INNER JOIN Tenants T WITH (NOLOCK) ON T.TenantId = L.TenantId
		AND T.IsDeleted = 0
	INNER JOIN AspNetUsers anu WITH (NOLOCK) ON anu.UserId = l.SalesmanId
	WHERE l.STATUS <> 6
		AND DATEADD(HOUR, DATEDIFF(HOUR, 0, ful.FollowUpDate), 0) = @FollowUpDate
		AND ISNULL(anu.RegisteredFCMToken, '') <> ''
		AND ful.FollowUpDate IS NOT NULL
		AND ISNULL(ful.FollowUpComment, '') <> ''

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

