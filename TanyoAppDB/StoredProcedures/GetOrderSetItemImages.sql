/*
EXEC GetOrderSetItemImages
	@OrderId =1
*/
CREATE   PROCEDURE [dbo].[GetOrderSetItemImages] (@OrderId BIGINT)
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
		,OSIM.FileURL AS ImageURL
		,OSIM.OrderSetItemImageId
		,OSIM.FileType
	FROM OrderSetItemImages OSIM WITH (NOLOCK)
	INNER JOIN #OrderSetItems OSI ON OSI.OrderSetItemId = OSIM.OrderSetItemId
	WHERE OSIM.FileType = 'Image'

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

