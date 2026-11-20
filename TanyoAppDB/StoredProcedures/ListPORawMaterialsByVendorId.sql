/*
	EXEC [dbo].[ListPORawMaterialsByVendorId]
		@TenantId = 2
		,@VendorId = 13
		,@PONumber = NULL
*/
CREATE   PROCEDURE [dbo].[ListPORawMaterialsByVendorId]
(
	@TenantId INT
    ,@VendorId BIGINT
    ,@PONumber NVARCHAR(100) = NULL
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	BEGIN TRY
		
		SELECT prm.PORawMaterialId AS ID
			,prm.PONumber AS PONumber
		FROM PORawMaterials prm
		INNER JOIN PORawMaterialItems prmi ON prm.PORawMaterialId = prmi.PORawMaterialId
		LEFT JOIN (
			SELECT 
				rmie.PONumber,
				rmide.RawMaterialId,
				SUM(rmide.Quantity) AS TotalInwardQty
			FROM RawMaterialInwardEntry rmie
			INNER JOIN RawMaterialInwardDetailsEntry rmide ON rmie.InwardId = rmide.InwardId
			WHERE rmie.IsDeleted = 0
			GROUP BY rmie.PONumber, rmide.RawMaterialId
		) AS inward ON inward.PONumber = prm.PONumber AND inward.RawMaterialId = prmi.RawMaterialId
		WHERE prm.VendorId = @VendorId
		  AND prm.TenantID = @TenantId
		  AND LTRIM(RTRIM(prm.PONumber)) <> ''
		  AND (
			  inward.TotalInwardQty IS NULL 
			  OR inward.TotalInwardQty < prmi.Quantity
		  )
		  AND (
			  @PONumber IS NULL 
			  OR LTRIM(RTRIM(LOWER(prm.PONumber))) LIKE '%' + LTRIM(RTRIM(LOWER(@PONumber))) + '%'
		  )
		GROUP BY prm.PORawMaterialId, prm.PONumber
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

