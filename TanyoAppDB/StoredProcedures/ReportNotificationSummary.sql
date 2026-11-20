-- =============================================
-- Author		: MagnusMinds
-- Create date	: 06-09-2023
-- Description	: Report - Notification Summary
-- =============================================
/*
	EXEC [dbo].[ReportNotificationSummary]
		@TenantId = 1
		,@FromDate = '2023-01-01'
		,@ToDate = '2023-08-31'
		,@NotificationType = NULL
		,@PageIndex = 1
		,@PageSize = 50
		,@SortBy = 'NotificationType'
		,@SortOrder = 'ASC'
*/
CREATE PROCEDURE [dbo].[ReportNotificationSummary] (
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
			,COUNT(1) OVER () AS TotalCount
		FROM [dbo].[NotificationManagement] AS nm WITH(NOLOCK)
		WHERE CONVERT(date, nm.CreatedDate) BETWEEN @FromDate AND @ToDate
			AND (
				ISNULL(@NotificationType, '') = ''
				OR nm.NotificationType = @NotificationType
				)
			AND nm.TenantId = @TenantId
		GROUP BY nm.NotificationType
		ORDER BY CASE WHEN @SortBy = 'NotificationType' AND @SortOrder = 'ASC' THEN nm.NotificationType END
			,CASE WHEN @SortBy = 'NotificationType' AND @SortOrder = 'DESC' THEN nm.NotificationType END DESC
			,CASE WHEN @SortBy = 'Email' AND @SortOrder = 'ASC' THEN SUM(IIF(nm.NotificationMethod = 'Email', 1, 0)) END
			,CASE WHEN @SortBy = 'Email' AND @SortOrder = 'DESC' THEN SUM(IIF(nm.NotificationMethod = 'Email', 1, 0)) END DESC
			,CASE WHEN @SortBy = 'SMS' AND @SortOrder = 'ASC' THEN SUM(IIF(nm.NotificationMethod = 'SMS', 1, 0)) END
			,CASE WHEN @SortBy = 'SMS' AND @SortOrder = 'DESC' THEN SUM(IIF(nm.NotificationMethod = 'SMS', 1, 0)) END DESC
			,CASE WHEN @SortBy = 'WhatsApp' AND @SortOrder = 'ASC' THEN SUM(IIF(nm.NotificationMethod = 'WhatsApp', 1, 0)) END
			,CASE WHEN @SortBy = 'WhatsApp' AND @SortOrder = 'DESC' THEN SUM(IIF(nm.NotificationMethod = 'WhatsApp', 1, 0)) END DESC 
		OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY
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

