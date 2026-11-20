/*

EXEC GetOrderSetItemAudio
	@OrderId =1
*/
CREATE PROCEDURE [dbo].[GetOrderSetItemAudio] (@OrderId BIGINT)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	IF OBJECT_ID('tempdb..#OrderSetItems') IS NOT NULL
		DROP TABLE #OrderSetItems

	SELECT OrderSetItemId
	INTO #OrderSetItems
	FROM OrderSetItems WITH (NOLOCK)
	WHERE OrderId = @OrderId
		AND IsDeleted = 0

	SELECT @OrderId AS OrderId
		,OSI.OrderSetItemId
		,OSIMA.FileURL AS AudioURL
		,OSIMA.OrderSetItemImageId AS OrderSetItemAudioId
		,OSIMA.FileType
	FROM OrderSetItemImages OSIMA WITH (NOLOCK)
	INNER JOIN #OrderSetItems OSI ON OSI.OrderSetItemId = OSIMA.OrderSetItemId
	WHERE OSIMA.FileType = 'Audio'

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

