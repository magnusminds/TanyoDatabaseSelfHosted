/*  
EXEC DeleteProduct  
 @ProductId = 10101  
 ,@TenantId = 2  
 ,@UserId = 4486  
*/
CREATE PROCEDURE [dbo].[DeleteProduct] (
	@ProductId BIGINT
	,@TenantId INT
	,@UserId INT
	,@SkipInquiryCheck BIT = 0
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	DECLARE @SubjectTypeId INT
		,@Dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@DtUTC DATETIME = GETUTCDATE()
		,@CategoryTypeId BIGINT
		,@ProductIds VARCHAR(20)
		,@ActivityDescription VARCHAR(MAX)
		,@ProductStatus INT;

	-- 1. Validate Product
	IF NOT EXISTS (
		SELECT 1
		FROM dbo.Products WITH (NOLOCK)
		WHERE ProductId = @ProductId
	)
	BEGIN
		SELECT CAST(0 AS BIT) AS Status,
			'Product not found.' AS [Message]
		RETURN;
	END

	SELECT @ProductStatus = Ps.Status
	FROM Products AS Ps WITH (NOLOCK)
	WHERE Ps.ProductId = @ProductId
		AND Ps.TenantId = @TenantId

	-- 2. Validate if product is already deleted
	IF @ProductStatus = 3
	BEGIN
		SELECT Cast(0 AS BIT) AS Status
			,'This product has already been deleted.' AS [Message];

		RETURN;
	END

	SELECT @SubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId
		AND IsDeleted = 0;

	SELECT @CategoryTypeId = CT.CategoryTypeId
	FROM Products AS Ps WITH (NOLOCK)
	INNER JOIN Categories AS CT WITH (NOLOCK) ON PS.CategoryId = Ct.CategoryId
	WHERE Ps.ProductId = @ProductId
		AND Ps.TenantId = @TenantId
		AND Ps.Status <> 3;

	IF @SkipInquiryCheck = 0
		AND EXISTS (
			SELECT 1
			FROM Orders O
			INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON O.OrderId = OSI.OrderId
			WHERE OSI.SubjectTypeId = @SubjectTypeId
				AND OSI.SubjectId = @ProductId
				AND O.Status NOT IN (
					5
					,9
					) -- Delivered And deleted
				AND NOT (O.Status = 0 AND O.IsArchive = 1)
				AND O.TenantId = @TenantId
				AND OSI.IsDeleted = 0
			)
	BEGIN
		SELECT Cast(0 AS BIT) AS Status
			,CONCAT (
				CASE 
					WHEN @CategoryTypeId = 1
						THEN 'Product '
					ELSE 'Fabric '
					END
				,'is already exists with an order.'
				) AS [Message]
			,@ProductId AS ProductId;

		RETURN;
	END

	BEGIN TRY
		BEGIN TRANSACTION DeleteProduct;

		IF EXISTS (
				SELECT 1
				FROM ProductWorkflows WITH (NOLOCK)
				WHERE ProductID = @ProductId
				)
		BEGIN
			DELETE
			FROM ProductWorkflows
			WHERE ProductID = @ProductId;
		END

		--IF EXISTS (  
		--  SELECT 1  
		--  FROM ProductMaterials  
		--  WHERE ProductId = @ProductId  
		--  )  
		--BEGIN  
		-- DELETE  
		-- FROM ProductMaterials  
		-- WHERE ProductId = @ProductId;  
		--END  
		--IF EXISTS (  
		--  SELECT 1  
		--  FROM ProductImages  
		--  WHERE ProductId = @ProductId  
		--  )  
		--BEGIN  
		-- DELETE  
		-- FROM ProductImages  
		-- WHERE ProductId = @ProductId;  
		--END  
		--IF EXISTS (  
		--  SELECT 1  
		--  FROM ProductVendorMapping  
		--  WHERE ProductID = @ProductId  
		--  )  
		--BEGIN  
		-- DELETE  
		-- FROM ProductVendorMapping  
		-- WHERE ProductID = @ProductId;  
		--END  
		--IF EXISTS (  
		--  SELECT 1  
		--  FROM ProductVariants  
		--  WHERE ProductID = @ProductId  
		--  )  
		--BEGIN  
		-- DELETE  
		-- FROM ProductVariants  
		-- WHERE ProductID = @ProductId;  
		--END  
		--IF EXISTS (  
		--  SELECT 1  
		--  FROM ProductCustomFields  
		--  WHERE ProductID = @ProductId  
		--  )  
		--BEGIN  
		-- DELETE  
		-- FROM ProductCustomFields  
		-- WHERE ProductID = @ProductId;  
		--END  
		SET @ProductIds = CAST(@ProductId AS VARCHAR(20));

		EXEC [dbo].[DeleteProductOfferAndMapping] @TenantId = @TenantId
			,@ProductIds = @ProductIds

		IF EXISTS (
				SELECT 1
				FROM Products WITH (NOLOCK)
				WHERE ProductID = @ProductId
					AND TenantId = @TenantId
					AND Status <> 3
				)
		BEGIN
			UPDATE PT
			SET PT.Status = 3
				,UpdatedBy = @UserId
				,UpdatedDate = @Dt
				,UpdatedUTCDate = @DtUTC
			FROM Products PT
			WHERE ProductId = @ProductId
				AND TenantId = @TenantId;

			SELECT @ActivityDescription = CONCAT (
					CASE 
						WHEN @CategoryTypeId = 1
							THEN 'Product '
						ELSE 'Fabric '
						END
					,pt.ProductTitle
					,' has been deleted'
					)
			FROM Products PT WITH (NOLOCK)
			WHERE ProductId = @ProductId;

			EXEC dbo.SaveActivityLog @SubjectTypeId = @SubjectTypeId
				,@SubjectId = @ProductId
				,@Description = @ActivityDescription
				,@Action = 'DELETE'
				,@CreatedBy = @UserId
				,@CreatedDate = @Dt
				,@CreatedUTCDate = @DtUTC;
		END

		COMMIT TRANSACTION DeleteProduct;

		SELECT Cast(1 AS BIT) AS Status
			,'Your record has been deleted.' AS [Message]
			,@ProductId AS ProductId;
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRANSACTION DeleteProduct;

		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ObjectName VARCHAR(500)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ObjectName = OBJECT_NAME(@@PROCID)

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage

		SELECT Cast(0 AS BIT) AS Status
			,ERROR_MESSAGE() AS [Message]
			,@ProductId AS ProductId;
	END CATCH
END

GO

