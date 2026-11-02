/*
	EXEC [dbo].[GetCatalogueProductVariants]	@ProductId = 26746
*/
CREATE PROCEDURE [dbo].[GetCatalogueProductVariants] (
	 @ProductId BIGINT
	,@hosturl VARCHAR(255) = 'https://localhost:7253'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @ProductVariantId BIGINT

		SELECT @ProductVariantId = ProductVariantId
		FROM dbo.Products
		WHERE ProductId = @ProductId;

		SELECT p.ProductId
			,p.ProductTitle
			,p.ModelNo
			,ISNULL(p.CoverImage, @hosturl + '/images/No-coverimage.png') AS ProductCoverImage
			,p.RetailerPrice
			,p.WholesalerPrice
			,p.Height
			,p.Width
			,p.Depth
			,p.Diameter
			,p.DimensionUnitId
			,c.CategoryName
			,ISNULL(pq.Quantity, 0) AS InStock
		FROM dbo.ProductVariants AS pv WITH (NOLOCK)
		INNER JOIN dbo.Products AS p WITH (NOLOCK) ON pv.ProductId = p.ProductId
		INNER JOIN dbo.Categories AS c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
		INNER JOIN dbo.ProductQuantities AS pq WITH (NOLOCK) ON p.ProductId = pq.ProductId
		WHERE pv.ProductVariantId = @ProductVariantId
			AND pv.ProductId <> @ProductId
		ORDER BY p.ProductId ASC;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ObjectName VARCHAR(500)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()
			,@ObjectName = OBJECT_NAME(@@PROCID)

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage

	END CATCH
END

GO

