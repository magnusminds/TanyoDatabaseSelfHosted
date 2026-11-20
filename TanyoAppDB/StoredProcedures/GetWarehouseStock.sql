-- =============================================
-- Description	: Get products with available stock in a warehouse (excludes qty 0). Supports product name search.
-- =============================================
/*
	EXEC [dbo].[GetWarehouseStock]
		@TenantId = 2
		,@WarehouseId = 9
		,@Search = NULL
*/
CREATE   PROCEDURE [dbo].[GetWarehouseStock]
(
	@TenantId INT,
	@WarehouseId BIGINT,
	@Search NVARCHAR(200) = NULL
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT
		p.ProductId
		,p.ProductTitle
		,p.ModelNo
		,p.CoverImage AS ProductImage
		,CAST(CASE WHEN c.CategoryTypeId = 2 THEN 1 ELSE 0 END AS BIT) AS IsFabric
		,pq.Quantity
	FROM dbo.ProductQuantitiesByWarehouse pq WITH(NOLOCK)
	INNER JOIN dbo.Products p WITH(NOLOCK) ON p.ProductId = pq.ProductId
		AND p.Status <> 3
		AND p.TenantId = @TenantId
	INNER JOIN dbo.Categories c WITH(NOLOCK) ON c.CategoryId = p.CategoryId
		AND c.IsDeleted = 0
	INNER JOIN dbo.Warehouse w WITH(NOLOCK) ON w.Id = pq.WarehouseId
		AND w.IsDeleted = 0
		AND w.TenantId = @TenantId
	WHERE pq.WarehouseId = @WarehouseId
		AND pq.Quantity > 0
		AND (
			@Search IS NULL
			OR LTRIM(RTRIM(@Search)) = ''
			OR p.ProductTitle LIKE '%' + @Search + '%'
		)
	ORDER BY p.ProductTitle

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

