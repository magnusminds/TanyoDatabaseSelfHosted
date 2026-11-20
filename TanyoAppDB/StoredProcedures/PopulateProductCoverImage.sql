-- =============================================  
-- Author		: MagnusMinds  
-- Create date	: 02-07-2025  
-- Description	: Update the cover image to the product
-- =============================================  
/*  
	EXEC [dbo].[PopulateProductCoverImage]
*/
CREATE PROCEDURE [dbo].[PopulateProductCoverImage]
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SET NOCOUNT OFF;

	UPDATE p
	SET CoverImage = x.ImagePath
	FROM Products p
	LEFT JOIN (
		SELECT x.ProductId
			,x.ImagePath
		FROM (
			SELECT im.ProductId
				,im.ImagePath
				,ROW_NUMBER() OVER (
					PARTITION BY im.ProductId ORDER BY im.IsCover DESC
						,im.CreatedUTCDate DESC, im.ProductImageID DESC
					) AS RowID
			FROM ProductImages im WITH (NOLOCK)
			INNER JOIN Products tp ON tp.ProductId = im.Productid
			) x
		WHERE x.RowID = 1
		) x ON x.ProductId = p.ProductId
	WHERE ISNULL(p.CoverImage, '') <> ISNULL(x.ImagePath, '')

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

