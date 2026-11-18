/*
	EXEC [dbo].[ReportGetNotificationSummary]
		@TenantId = 7
		,@FromDate = '2023-01-01'
		,@ToDate = '2023-08-31'
		,@NotificationType = NULL
		,@PageIndex = 1
		,@PageSize = 50
		,@SortBy = 'NotificationType'
		,@SortOrder = 'ASC'
*/
CREATE PROCEDURE [dbo].[zReportGetNotificationSummary]
(
	@TenantId INT
	,@FromDate DATE
	,@ToDate DATE
	,@NotificationType VARCHAR(50) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'NotificationType'
	,@SortOrder VARCHAR(50) = 'ASC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
	BEGIN TRY
    
		SELECT nm.NotificationType
			,SUM(CASE WHEN nm.NotificationMethod = 'Email' THEN 1 ELSE 0 END) AS Email
			,SUM(CASE WHEN nm.NotificationMethod = 'SMS' THEN 1 ELSE 0 END) AS SMS
			,SUM(CASE WHEN nm.NotificationMethod = 'WhatsApp' THEN 1 ELSE 0 END) AS WhatsApp
			,COUNT(1) OVER() AS TotalCount
		FROM
			NotificationManagement nm WITH (NOLOCK)
		WHERE
			nm.CreatedDate >= @FromDate AND nm.CreatedDate <= @ToDate
			AND (ISNULL(@NotificationType, '') = '' OR nm.NotificationType = @NotificationType)
			AND nm.TenantId = @TenantId
		GROUP BY nm.NotificationType
		ORDER BY
			CASE WHEN @SortBy = 'NotificationType' AND @SortOrder ='ASC' THEN nm.NotificationType END
			,CASE WHEN @SortBy = 'NotificationType' AND @SortOrder ='DESC' THEN nm.NotificationType END DESC
			,CASE WHEN @SortBy = 'Email' AND @SortOrder ='ASC' THEN SUM(IIF(nm.NotificationMethod = 'Email', 1, 0)) END
			,CASE WHEN @SortBy = 'Email' AND @SortOrder ='DESC' THEN SUM(IIF(nm.NotificationMethod = 'Email', 1, 0)) END DESC
			,CASE WHEN @SortBy = 'SMS' AND @SortOrder ='ASC' THEN SUM(IIF(nm.NotificationMethod = 'SMS', 1, 0)) END
			,CASE WHEN @SortBy = 'SMS' AND @SortOrder ='DESC' THEN SUM(IIF(nm.NotificationMethod = 'SMS', 1, 0)) END DESC
			,CASE WHEN @SortBy = 'WhatsApp' AND @SortOrder ='ASC' THEN SUM(IIF(nm.NotificationMethod = 'WhatsApp', 1, 0)) END
			,CASE WHEN @SortBy = 'WhatsApp' AND @SortOrder ='DESC' THEN SUM(IIF(nm.NotificationMethod = 'WhatsApp', 1, 0)) END DESC
		OFFSET (@PageIndex-1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY
	
	END TRY
	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState)
    END CATCH
END

GO

