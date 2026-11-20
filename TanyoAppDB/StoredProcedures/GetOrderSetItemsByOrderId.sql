/*
	EXEC dbo.GetOrderSetItemsByOrderId
		@TenantId = 2
		,@OrderId = 54453
		,@ProductTitle = NULL
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE   PROC [dbo].[GetOrderSetItemsByOrderId]
(
	@TenantId INT
	,@OrderId INT
	,@ProductTitle VARCHAR(100) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @ProductSubjectTypeId INT
		DECLARE @OtherWarehouseId BIGINT

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId

		SELECT @OtherWarehouseId = Id
		FROM Warehouse WITH (NOLOCK)
		WHERE TenantId = @TenantId
			AND IsDeleted = 0
			AND Name = 'Other'

		SELECT o.OrderId
			,o.OrderNo
			,osi.OrderSetItemId
			,osi.SubjectId AS ProductId
			,CASE
				WHEN osi.SubjectTypeId = @ProductSubjectTypeId THEN p.ProductTitle
				ELSE ''
				END AS ProductTitle
			,CASE
				WHEN osi.SubjectTypeId = @ProductSubjectTypeId THEN p.ModelNo
				ELSE ''
				END AS ModelNo
			,osi.ProductImage
			,CAST(osi.Quantity AS INT) AS Quantity
			,CAST(CASE
					WHEN C.CategoryTypeId = 2 THEN 1
					ELSE 0
					END AS BIT) AS IsFabric
			,COALESCE(prevWarehouse.PreviousWarehouseId, @OtherWarehouseId) AS PreviousWarehouseId
			,COUNT(1) OVER () AS TotalCount
		FROM Orders AS o WITH (NOLOCK)
		INNER JOIN OrderSetItems AS osi WITH (NOLOCK) ON o.OrderId = osi.OrderId
		INNER JOIN Products AS p WITH (NOLOCK) ON osi.SubjectId = p.ProductId
			AND osi.SubjectTypeId = @ProductSubjectTypeId
		INNER JOIN Categories AS c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
		OUTER APPLY (
			SELECT TOP 1 ide.WarehouseId AS PreviousWarehouseId
			FROM InwardDetailsEntry AS ide WITH (NOLOCK)
			INNER JOIN InwardEntry AS ie WITH (NOLOCK) ON ide.InwardId = ie.InwardId
			WHERE ide.ProductId = osi.SubjectId
				AND ide.IsDeleted = 0
				AND ie.IsDeleted = 0
				AND ie.TenantId = @TenantId
				AND ide.WarehouseId IS NOT NULL
				AND ide.WarehouseId > 0
			ORDER BY ie.CreatedDate DESC
			) AS prevWarehouse
		WHERE o.TenantId = @TenantId
			AND o.OrderId = @OrderId
			AND osi.ParentOrderSetItemId IS NULL
			AND (
				@ProductTitle IS NULL
				OR (
					osi.SubjectTypeId = @ProductSubjectTypeId
					AND (
						p.ProductTitle LIKE '%' + @ProductTitle + '%'
						OR p.ModelNo LIKE '%' + @ProductTitle + '%'
						)
					)
				)
			AND o.Status IN (3, 4, 5) -- InProgress, Completed, Delivered
			AND osi.ItemStatus = 3 -- Delivered
		ORDER BY ProductTitle ASC
		OFFSET (@PageIndex - 1) * @PageSize ROWS

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

