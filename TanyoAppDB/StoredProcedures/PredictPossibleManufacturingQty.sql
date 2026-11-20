/*
	EXEC [dbo].[PredictPossibleManufacturingQty]
		@ProductId = 2439,
		@TenantId = 2,
		@PageIndex = 1,
		@PageSize = 50
*/
CREATE PROCEDURE [dbo].[PredictPossibleManufacturingQty] (
	@ProductId INT
	,@TenantId INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
	)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	DECLARE @SubjectTypeId INT = NULL
		,@MinimumQuantity INT = NULL

	SELECT @SubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE TenantId = @TenantId
		AND SubjectTypeName IN ('RawMaterials')

	SELECT p.ProductId
		,p.ProductTitle
		,rm.Title AS RawMaterialName
		,PM.Qty AS QtyNeededToCreateSingleProduct
		,CAST(rmi.Inventory AS NUMERIC(18, 2)) AS StockQty
		,CAST(CASE 
				WHEN (ISNULL(RMI.Inventory, 0) / ISNULL(PM.Qty, 1)) < 0
					THEN 0
				ELSE ((ISNULL(RMI.Inventory, 0) / ISNULL(PM.Qty, 1)))
				END AS NUMERIC(18, 2)) AS PredictedQuantity
		,COUNT(1) OVER () AS TotalCount
	FROM ProductMaterials pm WITH (NOLOCK)
	INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = pm.ProductId
	INNER JOIN RawMaterials rm WITH (NOLOCK) ON rm.RawMaterialId = pm.SubjectId
	LEFT JOIN RawMaterialInventory rmi WITH (NOLOCK) ON rmi.RawMaterialId = rm.RawMaterialId
	WHERE SubjectTypeId = @SubjectTypeId
		AND p.ProductId = @ProductId
	ORDER BY rm.Title OFFSET((@PageIndex - 1) * @PageSize) ROWS

	FETCH NEXT @PageSize ROWS ONLY;

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

