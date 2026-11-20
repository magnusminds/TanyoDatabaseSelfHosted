/*
	EXEC [dbo].[GetPORawMaterialItemsById]
		@TenantId = 2
		,@PORawMaterialId = 2
*/
CREATE   PROCEDURE [dbo].[GetPORawMaterialItemsById]
(
	@TenantId INT
    ,@PORawMaterialId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

	BEGIN TRY

		;WITH InwardBase AS (
			SELECT rmie.InwardId
			FROM RawMaterialInwardEntry rmie
			WHERE rmie.PORawMaterialId = @PORawMaterialId
			AND rmie.IsDeleted = 0
		),
		-- 1. Inward Quantities per Product
		InwardedQty AS (
			SELECT rmide.RawMaterialId
				,SUM(rmide.Quantity) AS TotalInwardQty
			FROM RawMaterialInwardDetailsEntry rmide
			INNER JOIN InwardBase ib ON rmide.InwardId = ib.InwardId
			WHERE rmide.IsDeleted = 0
			GROUP BY rmide.RawMaterialId
		),
		-- 2. Final product list (filtered)
		RawMaterialList AS (
			SELECT 
				rm.RawMaterialId AS Id
				,rm.Title AS Title
				,CAST(
					CASE 
						WHEN iq.TotalInwardQty IS NULL THEN prmi.Quantity
						ELSE prmi.Quantity - iq.TotalInwardQty
					END AS INT
				) AS Quantity
				,rm.ImagePath
			FROM PORawMaterialItems prmi
			INNER JOIN RawMaterials rm ON rm.RawMaterialId = prmi.RawMaterialId
			LEFT JOIN InwardedQty iq ON iq.RawMaterialId = prmi.RawMaterialId
			WHERE prmi.PORawMaterialId = @PORawMaterialId
			AND (iq.TotalInwardQty IS NULL OR prmi.Quantity - iq.TotalInwardQty > 0)
		)
		-- 3. Select RawMaterialList
		SELECT Id
			,Title
			,ImagePath
			,Quantity
		FROM RawMaterialList
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

