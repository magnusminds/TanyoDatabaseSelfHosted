/*
    EXEC ProductSetDetailsById
    @ProductSetId = 70045
    ,@TenantId = 2
*/
CREATE   PROCEDURE [dbo].[ProductSetDetailsById]
(
    @ProductSetId BIGINT
    ,@TenantId INT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT ps.ProductSetId
		,ps.SetName
		,ps.Description
		,ps.QRImage
		,ps.SetImage
		,ISNULL(img.ProductSetImageID, 0) AS ProductSetImageID
		,img.ImagePath
		,ISNULL(img.IsCover, 0) AS IsCover
		,img.ImageName
		,psi.ProductSetItemId
		,psi.ProductId
		,p.ProductTitle
		,p.ModelNo
		,p.CoverImage
		,c.CategoryName
		,c.CategoryID
		,CAST(CASE 
			WHEN C.CategoryTypeId = 2 
				THEN 1 
				ELSE 0 
			END AS BIT) AS IsFabric
		,psi.Quantity
	FROM ProductSets AS ps WITH (NOLOCK)
	LEFT JOIN ProductSetImage img WITH (NOLOCK) 
    	ON ps.ProductSetId = img.ProductSetId
	INNER JOIN ProductSetItems AS psi WITH (NOLOCK)
    	ON ps.ProductSetId = psi.ProductSetId
	INNER JOIN Products AS p WITH (NOLOCK) 
    	ON psi.ProductId = p.ProductId
	INNER JOIN Categories AS c WITH (NOLOCK) 
    	ON p.CategoryId = c.CategoryId
	WHERE ps.ProductSetId = @ProductSetId
		AND ps.TenantId = @TenantId
		AND ps.IsDeleted = 0;

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

