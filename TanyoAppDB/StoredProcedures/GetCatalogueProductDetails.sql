/*
	EXEC [dbo].[GetCatalogueProductDetails] @ProductId = 11003
*/
CREATE PROCEDURE [dbo].[GetCatalogueProductDetails] (
	 @ProductId BIGINT
	,@hosturl VARCHAR(255) = 'https://localhost:7253'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT P.ProductId
			,P.ProductTitle
			,P.ModelNo
			,ISNULL(p.CoverImage, @hosturl + '/images/No-coverimage.png') AS ProductCoverImage
			,ISNULL((
					SELECT PIM.ImagePath
					FROM ProductImages PIM WITH (NOLOCK)
					WHERE PIM.ProductId = P.ProductId
					FOR JSON PATH
					), '[]') AS ProductImages
			,P.RetailerPrice
			,P.WholesalerPrice
			,P.Height
			,P.Width
			,P.Depth
			,P.Diameter
			,P.DimensionUnitId
			,P.Features AS Description
			,C.CategoryName
			,ISNULL(PQ.Quantity, 0) AS Instock
		FROM Products P WITH (NOLOCK)
		INNER JOIN Categories C WITH (NOLOCK) ON C.CategoryId = P.CategoryId
		INNER JOIN ProductQuantities PQ WITH (NOLOCK) ON PQ.ProductId = P.ProductId
		WHERE P.ProductId = @ProductId
			AND C.IsDeleted = 0;
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

