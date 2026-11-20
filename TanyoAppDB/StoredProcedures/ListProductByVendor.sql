/*
	EXEC dbo.ListProductByVendor
		@TenantId = 88
	   ,@VendorId = 38
	   ,@Search = ''
	   --,@PageIndex = 1
	   --,@PageSize = 50
*/

CREATE PROC [dbo].[ListProductByVendor]
(
	@TenantId BIGINT,
	@VendorId BIGINT,
	@Search VARCHAR(50)
	--,@PageIndex INT = 1,
	--,@PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @DisplayStockToDealer BIT = 0

	SELECT @DisplayStockToDealer = T.DisplayStockToDealer
	FROM Vendors V WITH (NOLOCK)
	INNER JOIN Tenants T  WITH (NOLOCK) ON T.TenantId = V.VendorTenantID
	WHERE V.VendorId = @VendorId

	-- check AcceptRejectStatus in Vendors table
	IF EXISTS (
		SELECT 1
		FROM Vendors WITH (NOLOCK)
		WHERE VendorId = @VendorId AND AcceptRejectStatus = 1
	)
	BEGIN
		-- get product from Products table
		SELECT p.ProductId
			,p.ProductTitle
			,p.ModelNo
			,(
				SELECT TOP 1 pii.ImagePath 
				FROM ProductImages pii WITH (NOLOCK)
				WHERE pii.ProductId = p.ProductId AND pii.IsCover = 1
			) AS ProductImage
			,p.VendorProductPrice
			,pvm.VendorProductId
			,CASE 
				WHEN p.Status = 1 THEN CAST(1 AS BIT)
				WHEN p.Status = 2 THEN CAST(0 AS BIT)
				ELSE NULL 
			END AS IsPublished
			,CASE 
				WHEN @DisplayStockToDealer = 1 THEN pq.Quantity
				ELSE 0
			END AS InStock
			,@DisplayStockToDealer AS DisplayStockToDealer
			,COUNT(1) OVER(PARTITION BY 1) AS TotalCount
		FROM Products p WITH (NOLOCK)
		INNER JOIN ProductVendorMapping pvm WITH (NOLOCK) ON pvm.ProductId = p.ProductId
			AND pvm.IsDeleted = 0
		LEFT JOIN ProductQuantities pq WITH (NOLOCK) ON  pq.ProductId = pvm.VendorProductId
		WHERE p.TenantId = @TenantId
		  AND pvm.VendorId = @VendorId
		  AND p.Status = 1
		  AND (@Search IS NULL OR @Search = '' OR p.ModelNo LIKE '%' + @Search + '%' OR p.ProductTitle LIKE '%' + @Search + '%')
		ORDER BY 1 DESC
	END
	ELSE
	BEGIN
		-- get product from mapping if vendor not approved
		SELECT p.ProductId
			,p.ProductTitle
			,p.ModelNo
			,(
				SELECT TOP 1 pii.ImagePath 
				FROM ProductImages pii WITH (NOLOCK)
				WHERE pii.ProductId = p.ProductId AND pii.IsCover = 1
			) AS ProductImage
			,p.VendorProductPrice
			,pvm.VendorProductId
			,CASE 
				WHEN p.Status = 1 THEN CAST(1 AS BIT)
				WHEN p.Status = 2 THEN CAST(0 AS BIT)
				ELSE NULL 
			END AS IsPublished
			,CASE 
				WHEN @DisplayStockToDealer = 1 THEN pq.Quantity
				ELSE 0
			END AS InStock
			,@DisplayStockToDealer AS DisplayStockToDealer
			,COUNT(1) OVER(PARTITION BY 1) AS TotalCount
		FROM ProductVendorMapping pvm WITH (NOLOCK)
		INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = pvm.ProductId
		LEFT JOIN ProductQuantities pq WITH (NOLOCK) ON  pq.ProductId = pvm.VendorProductId
		WHERE p.TenantId = @TenantId
		  AND p.Status = 1
		  AND pvm.VendorId = @VendorId
		  AND pvm.IsDeleted = 0
		  AND (@Search IS NULL OR @Search = '' OR p.ModelNo LIKE '%' + @Search + '%' OR p.ProductTitle LIKE '%' + @Search + '%')
		ORDER BY 1 DESC
	END

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

