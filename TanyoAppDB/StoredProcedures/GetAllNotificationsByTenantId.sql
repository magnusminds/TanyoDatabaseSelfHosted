/*
	EXEC [dbo].[GetAllNotificationsByTenantId]
		@TenantId  = 2
		,@ApplicationType  = 1
		,@PageIndex = 1
		,@PageSize = 25	
*/
CREATE PROCEDURE [dbo].[GetAllNotificationsByTenantId]
(@TenantId INT 
,@ApplicationType  INT = NULL
,@PageIndex INT = 1
,@PageSize INT = 25
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
			SELECT n.NotificationId
			 ,n.Message
			 ,n.CreatedDate
			 ,n.EntityId
			 ,n.IsRead
			 ,COUNT(1) OVER () AS TotalCount
			FROM Notifications n WITH (NOLOCK)
			WHERE n.TenantId = @TenantId
			AND n.ApplicationType = @ApplicationType
			ORDER BY n.CreatedDate DESC
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

