/*
	EXEC [dbo].[DeleteProductOfferAndMapping] @TenantId = NULL, @ProductIds = ''
*/
CREATE     PROCEDURE [dbo].[DeleteProductOfferAndMapping] (
	@TenantId INT = NULL
	,@ProductIds VARCHAR(MAX) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @Dt DATETIME = GETDATE()

	DECLARE @Tmp_ProductIds AS TABLE
	(
		Id INT IDENTITY(1,1)
		,ProductId BIGINT PRIMARY KEY
	)

	BEGIN TRY

	INSERT INTO @Tmp_ProductIds
	(
		ProductId
	)
	SELECT value 
	FROM string_split(@ProductIds,',')

	BEGIN TRANSACTION DeleteProductMapping
	
	DELETE FROM ProductOffers WHERE TenantId = @TenantId AND ProductId IN (SELECT ProductId FROM @Tmp_ProductIds)
	DELETE FROM OfferProductMapping WHERE ProductId IN (SELECT ProductId FROM @Tmp_ProductIds)
	UPDATE Products
	SET RetailOfferPrice = NULL
	WHERE TenantId = @TenantId
	  AND ProductId IN (SELECT ProductId FROM @Tmp_ProductIds)

	COMMIT TRANSACTION DeleteProductMapping
		
	END TRY

BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION DeleteProductMapping;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

