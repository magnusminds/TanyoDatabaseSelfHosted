/*  
 EXEC [dbo].[GetPOProductItemsById]  
  @TenantId = 2  
  ,@POProductId = 2  
*/
CREATE PROCEDURE [dbo].[GetPOProductItemsById] (
	@TenantId INT
	,@POProductId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @OtherWarehouseId BIGINT

		SELECT @OtherWarehouseId = Id
		FROM Warehouse WITH (NOLOCK)
		WHERE TenantId = @TenantId
			AND IsDeleted = 0
			AND Name = 'Other';

		WITH InwardBase
		AS (
			SELECT ie.InwardId
			FROM InwardEntry AS ie WITH (NOLOCK)
			WHERE ie.POProductId = @POProductId
				AND ie.IsDeleted = 0
			)
			,
			-- 3. Inward Quantities per Product  
		InwardedQty
		AS (
			SELECT ide.ProductId
				,SUM(ide.Quantity) AS TotalInwardQty
			FROM InwardDetailsEntry AS ide WITH (NOLOCK)
			INNER JOIN InwardBase AS ib WITH (NOLOCK) ON ide.InwardId = ib.InwardId
			WHERE ide.IsDeleted = 0
			GROUP BY ide.ProductId
			)
			,
			-- 4. Final product list (filtered)
		ProductList
		AS (
			SELECT p.ProductId AS Id
				,p.ProductTitle AS Title
				,p.ModelNo AS Number
				-- Line-level remaining: allocate product-wide inwarded qty sequentially across lines
				,CAST(CASE 
						WHEN ISNULL(iq.TotalInwardQty, 0) >= SUM(bii.Quantity) OVER (
								PARTITION BY bii.ProductID ORDER BY bii.POProductItemId ROWS BETWEEN UNBOUNDED PRECEDING
										AND CURRENT ROW
								)
							THEN 0
						WHEN ISNULL(iq.TotalInwardQty, 0) > (
								SUM(bii.Quantity) OVER (
									PARTITION BY bii.ProductID ORDER BY bii.POProductItemId ROWS BETWEEN UNBOUNDED PRECEDING
											AND CURRENT ROW
									) - bii.Quantity
								)
							THEN SUM(bii.Quantity) OVER (
									PARTITION BY bii.ProductID ORDER BY bii.POProductItemId ROWS BETWEEN UNBOUNDED PRECEDING
											AND CURRENT ROW
									) - ISNULL(iq.TotalInwardQty, 0)
						ELSE bii.Quantity
						END AS NUMERIC(18, 2)) AS Quantity
				,p.CoverImage
				,CAST(CASE 
						WHEN c.CategoryTypeId = 2
							THEN 1
						ELSE 0
						END AS BIT) AS IsFabric
				,COALESCE(prevWarehouse.PreviousWarehouseId, @OtherWarehouseId) AS PreviousWarehouseId
				,bii.POProductItemId
				,bii.ParentPOProductItemId
				,bii.IsAddOn
			FROM POProductItems AS bii WITH (NOLOCK)
			INNER JOIN Products AS p WITH (NOLOCK) ON p.ProductId = bii.ProductID
			INNER JOIN Categories AS c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
			LEFT JOIN InwardedQty AS iq WITH (NOLOCK) ON iq.ProductId = bii.ProductID
			OUTER APPLY (
				SELECT TOP 1 ide.WarehouseId AS PreviousWarehouseId
				FROM InwardDetailsEntry AS ide WITH (NOLOCK)
				INNER JOIN InwardEntry AS ie WITH (NOLOCK) ON ide.InwardId = ie.InwardId
				WHERE ide.ProductId = p.ProductId
					AND ide.IsDeleted = 0
					AND ie.IsDeleted = 0
					AND ie.TenantId = @TenantId
					AND ide.WarehouseId IS NOT NULL
					AND ide.WarehouseId > 0
				ORDER BY ie.CreatedDate DESC
				) AS prevWarehouse
			WHERE bii.POProductId = @POProductId
				AND p.Status = 1 -- Published  
			)
		-- 5. Select with pagination + total count
		SELECT Id
			,Title
			,Number
			,Quantity
			,CoverImage
			,IsFabric
			,PreviousWarehouseId
			,POProductItemId
			,ParentPOProductItemId
			,IsAddOn
		FROM ProductList
		WHERE Quantity > 0 -- keeps duplicate lines together instead of dropping them all
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

