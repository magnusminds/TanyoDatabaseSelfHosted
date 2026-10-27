/*  
 EXEC [dbo].[ListPOProductsByVendorId]  
  @TenantId = 2  
  ,@VendorId = 13  
  ,@PONumber = NULL  
*/
CREATE PROCEDURE [dbo].[ListPOProductsByVendorId] (
	@TenantId INT
	,@VendorId BIGINT
	,@PONumber NVARCHAR(100) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		-- PO lines for this vendor's POs (rows pre-filtered so the window below stays small).
		
		;WITH PoLineBase
		AS (
			SELECT po.POProductId
				,po.PONumber
				,poi.ProductId
				,
				-- Total ordered qty per (PO, Product): duplicate lines must be summed before comparing
				-- with the product-wide inwarded qty, otherwise a partially-inwarded PO disappears.
				SUM(poi.Quantity) OVER (
					PARTITION BY po.POProductId
					,poi.ProductId
					) AS ProductPOQty
			FROM POProducts po
			INNER JOIN POProductItems poi ON po.POProductId = poi.POProductId
			WHERE po.VendorId = @VendorId
				AND po.TenantID = @TenantId
				AND LTRIM(RTRIM(po.PONumber)) <> ''
				AND (
					@PONumber IS NULL
					OR LTRIM(RTRIM(LOWER(po.PONumber))) LIKE '%' + LTRIM(RTRIM(LOWER(@PONumber))) + '%'
					)
				AND po.STATUS IN (
					2
					,5
					) -- approved 2, material ready 5.  
			)
			,InwardedQty
		AS (
			SELECT rmie.PONumber
				,rmide.ProductId
				,SUM(rmide.Quantity) AS TotalInwardQty
			FROM InwardEntry rmie
			INNER JOIN InwardDetailsEntry rmide ON rmie.InwardId = rmide.InwardId
			WHERE rmie.IsDeleted = 0
			GROUP BY rmie.PONumber
				,rmide.ProductId
			)
		SELECT plb.POProductId AS ID
			,plb.PONumber AS PONumber
		FROM PoLineBase plb
		LEFT JOIN InwardedQty inward ON inward.PONumber = plb.PONumber
			AND inward.ProductId = plb.ProductId
		WHERE inward.TotalInwardQty IS NULL
			OR inward.TotalInwardQty < plb.ProductPOQty
		GROUP BY plb.POProductId
			,plb.PONumber
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

