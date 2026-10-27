
/*
    EXEC [dbo].[GetOrderSetItemPdf] @OrderId = 261468
*/
CREATE PROCEDURE [dbo].[GetOrderSetItemPdf] (
    @OrderId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    BEGIN TRY
        SELECT OrderId AS OrderId
            ,OSI.OrderSetItemId
            ,OSIM.FileURL AS PdfURL
            ,OSIM.OrderSetItemImageId AS OrderSetItemPdfId
            ,OSIM.FileType AS Filetype
            ,OSIM.[FileName] AS [FileName]
        FROM OrderSetItemImages OSIM WITH (NOLOCK)
        INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = OSIM.OrderSetItemId
        WHERE OSIM.FileType = 'Pdf'
        AND @OrderId = OSI.OrderId
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

