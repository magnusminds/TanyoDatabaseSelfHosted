/*    
	EXEC [dbo].[ReportProductInventoryVSOrders]
		@InventoryType = 3
		,@TenantId = 2

	EXEC [dbo].[ReportProductInventoryVSOrders]
		@InventoryType = 2
		,@TenantId = 2
		,@ProductTitle = ''
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'ReadyToDelivered'
		,@SortOrder = 'ASC'

	EXEC [dbo].[ReportProductInventoryVSOrders]
		@InventoryType = 2
		,@TenantId = 1
*/
CREATE PROCEDURE [dbo].[ReportProductInventoryVSOrders] (
	@InventoryType INT
	,@TenantId INT
	,@ProductTitle VARCHAR(100) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'ProductTitle'
	,@SortOrder VARCHAR(50) = 'ASC'
	,@CategoryId BIGINT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF @InventoryType = 0
	BEGIN
		DECLARE @ProductSubjectTypeId INT;

		
		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		SELECT p.ProductId
			,p.CoverImage AS ImagePath
			,CASE 
				WHEN p.ModelNo <> NULL
					OR p.ModelNo <> ''
					THEN p.ProductTitle + ' - ' + p.ModelNo
				ELSE p.ProductTitle
				END AS ProductTitle
			,c1.CategoryName AS CategoryName
			,c1.CategoryId AS CategoryId
			,ISNULL(ia.Quantity, 0) AS InStock
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 0
							AND os.IsDeleted != 1
							AND o.STATUS != 9
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Inquiry
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 1
							AND os.IsDeleted != 1
							AND o.STATUS != 9
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS PendingForApproval
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 2
							AND os.IsDeleted != 1
							AND o.STATUS != 9
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Approved
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 0
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS ReadyToManufacturing
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 1
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Manufacturing
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 2
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS ReadyToDelivered
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 3
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Delivered
			,ISNULL((
					SELECT SUM(SOH.Quantity) AS TotalQuntity
					FROM OrderSetItems AS OSI WITH (NOLOCK)
					INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
					INNER JOIN Orders AS O WITH (NOLOCK) ON O.OrderId = SOH.OrderId
					WHERE OSI.IsDeleted = 0
						AND OSI.IsQuantityOnHold = 1
						AND SOH.IsStockOnHold = 1
						AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(SOH.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
						AND ProductId = p.ProductId
						AND O.STATUS = 0
					GROUP BY SOH.ProductId
					), 0) AS HoldOnQuantity
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM [dbo].[Products] p
		RIGHT JOIN Categories c1 ON p.CategoryId = c1.CategoryId
		LEFT JOIN [dbo].[ProductQuantities] ia ON p.ProductId = ia.ProductId
		LEFT JOIN [dbo].[OrderSetItems] os ON p.ProductId = os.SubjectId
		LEFT JOIN [dbo].[Orders] o ON os.OrderId = o.OrderId
		LEFT JOIN [dbo].[Customers] c ON c.CustomerId = o.CustomerId
		WHERE p.TenantId = @TenantId
			AND p.STATUS IN (
				0
				,1
				,2
				)
			--AND o.Status IN (0, 1) --Inquiry, Pending For Approval    
			AND (
				(
					@ProductTitle IS NULL
					OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
					)
				OR p.ModelNo LIKE '%' + @ProductTitle + '%'
				OR CONCAT (
					p.ProductTitle
					,' - '
					,p.ModelNo
					) LIKE '%' + @ProductTitle + '%'
				)
			AND (
				@CategoryId IS NULL
				OR c1.CategoryId = @CategoryId
				)
		GROUP BY p.ProductId
			,p.ProductTitle
			,c1.CategoryName
			,c1.CategoryId
			,p.ModelNo
			,ia.Quantity
			,p.CoverImage
		ORDER BY CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN p.ProductTitle + ' - ' + p.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN p.ProductTitle + ' - ' + p.ModelNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN c1.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN c1.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'InStock'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ia.Quantity, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'InStock'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ia.Quantity, 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Inquiry'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 0
										AND o.STATUS != 9
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Inquiry'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 0
										AND o.STATUS != 9
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'PendingForApproval'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 1
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'PendingForApproval'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 1
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Approved'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 2
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Approved'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 2
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'ReadyToManufacturing'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 0
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ReadyToManufacturing'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 0
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Manufacturing'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 1
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Manufacturing'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 1
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'ReadyToDelivered'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 2
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ReadyToDelivered'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 2
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Delivered'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 3
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Delivered'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 3
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'HoldOnQuantity'
					AND @SortOrder = 'DESC'
					THEN ISNULL((
								SELECT SUM(SOH.Quantity)
								FROM OrderSetItems AS OSI WITH (NOLOCK)
								INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
								INNER JOIN Orders AS O WITH (NOLOCK) ON O.OrderId = SOH.OrderId
								WHERE OSI.IsDeleted = 0
									AND OSI.IsQuantityOnHold = 1
									AND SOH.IsStockOnHold = 1
									AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(SOH.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
									AND SOH.ProductId = p.ProductId
									AND O.STATUS = 0
								GROUP BY SOH.ProductId
								), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'HoldOnQuantity'
					AND @SortOrder = 'ASC'
					THEN ISNULL((
								SELECT SUM(SOH.Quantity)
								FROM OrderSetItems AS OSI WITH (NOLOCK)
								INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
								INNER JOIN Orders AS O WITH (NOLOCK) ON O.OrderId = SOH.OrderId
								WHERE OSI.IsDeleted = 0
									AND OSI.IsQuantityOnHold = 1
									AND SOH.IsStockOnHold = 1
									AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(SOH.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
									AND SOH.ProductId = p.ProductId
									AND O.STATUS = 0
								GROUP BY SOH.ProductId
								), 0)
				END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
	END

	IF @InventoryType = 1
	BEGIN
		DECLARE @RawMaterialSubjectTypeId INT;

		SELECT @RawMaterialSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'RawMaterials'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		SELECT CAST(r.RawMaterialId AS BIGINT) AS ProductId
			,r.ImagePath AS ImagePath
			,r.Title AS ProductTitle
			,CAST(ISNULL(ri.Inventory, 0) AS NUMERIC(18, 2)) AS InStock
			,CAST(0.00 AS DECIMAL(18, 2)) AS Inquiry
			,CAST(0.00 AS DECIMAL(18, 2)) AS PendingForApproval
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 2
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Approved
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 0
							AND o.STATUS > 2
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS ReadyToManufacturing
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 1
							AND o.STATUS > 2
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Manufacturing
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 2
							AND o.STATUS > 2
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS ReadyToDelivered
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 3
							AND o.STATUS > 2
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @ProductSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Delivered
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM [dbo].[RawMaterials] r
		LEFT JOIN [dbo].[RawMaterialInventory] ri ON r.RawMaterialId = ri.RawMaterialId
		LEFT JOIN [dbo].ProductMaterials pm ON r.RawMaterialId = pm.SubjectId
		LEFT JOIN [dbo].[OrderSetItems] os ON pm.ProductId = os.SubjectId
		LEFT JOIN [dbo].[Orders] o ON os.OrderId = o.OrderId
		WHERE r.TenantId = @TenantId
			AND r.IsDeleted = 0
			--AND o.Status IN (0, 1) --Inquiry, Pending For Approval    
			AND (
				@ProductTitle IS NULL
				OR r.Title LIKE '%' + @ProductTitle + '%'
				)
		GROUP BY r.RawMaterialId
			,r.ImagePath
			,r.Title
			,ri.Inventory
		ORDER BY CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN r.Title
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN r.Title
				END DESC
			,CASE 
				WHEN @SortBy = 'InStock'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ri.Inventory, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'InStock'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ri.Inventory, 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Inquiry'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ri.Inventory, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Inquiry'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ri.Inventory, 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'PendingForApproval'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ri.Inventory, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'PendingForApproval'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ri.Inventory, 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Approved'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Approved'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'ReadyToManufacturing'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 0
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ReadyToManufacturing'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 0
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Manufacturing'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 1
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Manufacturing'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 1
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'ReadyToDelivered'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 2
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ReadyToDelivered'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 2
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Delivered'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 3
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Delivered'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 3
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @ProductSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
	END

	IF @InventoryType = 2
	BEGIN
		DECLARE @FabricSubjectTypeId INT;

		SELECT @FabricSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'Fabrics'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		SELECT CAST(f.FabricId AS BIGINT) AS ProductId
			,f.ImagePath AS ImagePath
			,CASE 
				WHEN f.ModelNo <> NULL
					OR f.ModelNo <> ''
					THEN f.Title + ' - ' + f.ModelNo
				ELSE f.Title
				END AS ProductTitle
			,c1.CompanyName AS CategoryName
			,CAST(c1.CompanyId AS BIGINT) AS CategoryId
			,CAST(0 AS NUMERIC(18, 2)) AS InStock
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 0
							AND os.IsDeleted != 1
							AND o.STATUS != 9
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Inquiry
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 1
							AND os.IsDeleted != 1
							AND o.STATUS != 9
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS PendingForApproval
			,ISNULL(SUM(CASE 
						WHEN o.STATUS = 2
							AND os.IsDeleted != 1
							AND o.STATUS != 9
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Approved
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 0
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS ReadyToManufacturing
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 1
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Manufacturing
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 2
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS ReadyToDelivered
			,ISNULL(SUM(CASE 
						WHEN os.ItemStatus = 3
							AND o.STATUS > 2
							AND o.STATUS NOT IN (
								8
								,9
								)
							AND os.IsDeleted != 1
							AND os.SubjectTypeId = @FabricSubjectTypeId
							THEN os.Quantity
						ELSE 0
						END), 0) AS Delivered
			,ISNULL((
					SELECT SUM(SOH.Quantity) AS TotalQuntity
					FROM OrderSetItems AS OSI WITH (NOLOCK)
					INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
					INNER JOIN Orders AS O WITH (NOLOCK) ON O.OrderId = SOH.OrderId
					WHERE OSI.IsDeleted = 0
						AND OSI.IsQuantityOnHold = 1
						AND SOH.IsStockOnHold = 1
						AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(SOH.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
						AND ProductId = f.FabricId
						AND O.STATUS = 0
					GROUP BY SOH.ProductId
					), 0) AS HoldOnQuantity
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM [dbo].[Fabrics] f
		RIGHT JOIN Companies c1 ON c1.CompanyId = f.CompanyId
			AND c1.TenantId = f.TenantId
		LEFT JOIN [dbo].[OrderSetItems] os ON os.SubjectId = f.FabricId
		LEFT JOIN [dbo].[Orders] o ON os.OrderId = o.OrderId
		LEFT JOIN [dbo].[Customers] c ON c.CustomerId = o.CustomerId
		WHERE f.TenantId = @TenantId
			AND C.IsDeleted = 0
			AND f.IsDeleted = 0
			AND (
				(
					@ProductTitle IS NULL
					OR f.Title LIKE '%' + @ProductTitle + '%'
					)
				OR f.ModelNo LIKE '%' + @ProductTitle + '%'
				OR CONCAT (
					f.Title
					,' - '
					,f.ModelNo
					) LIKE '%' + @ProductTitle + '%'
				)
			AND (
				@CategoryId IS NULL
				OR c1.CompanyId = @CategoryId
				)
		GROUP BY f.FabricId
			,f.Title
			,c1.CompanyName
			,c1.CompanyId
			,f.ModelNo
			,f.ImagePath
		ORDER BY CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN f.Title + ' - ' + f.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN f.Title + ' - ' + f.ModelNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN c1.CompanyName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN c1.CompanyName
				END DESC
			,CASE 
				WHEN @SortBy = 'Inquiry'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 0
										AND o.STATUS != 9
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Inquiry'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 0
										AND o.STATUS != 9
										AND os.IsDeleted != 1
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'PendingForApproval'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 1
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'PendingForApproval'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 1
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Approved'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 2
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Approved'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN o.STATUS = 2
										AND os.IsDeleted != 1
										AND o.STATUS != 9
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'ReadyToManufacturing'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 0
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ReadyToManufacturing'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 0
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Manufacturing'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 1
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Manufacturing'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 1
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'ReadyToDelivered'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 2
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ReadyToDelivered'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 2
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'Delivered'
					AND @SortOrder = 'DESC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 3
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'Delivered'
					AND @SortOrder = 'ASC'
					THEN ISNULL(SUM(CASE 
									WHEN os.ItemStatus = 3
										AND o.STATUS > 2
										AND os.IsDeleted != 1
										AND o.STATUS NOT IN (
											8
											,9
											)
										AND os.SubjectTypeId = @FabricSubjectTypeId
										THEN os.Quantity
									ELSE 0
									END), 0)
				END ASC
			,CASE 
				WHEN @SortBy = 'HoldOnQuantity'
					AND @SortOrder = 'DESC'
					THEN ISNULL((
								SELECT SUM(SOH.Quantity)
								FROM OrderSetItems AS OSI WITH (NOLOCK)
								INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
								INNER JOIN Orders AS O WITH (NOLOCK) ON O.OrderId = SOH.OrderId
								WHERE OSI.IsDeleted = 0
									AND OSI.IsQuantityOnHold = 1
									AND SOH.IsStockOnHold = 1
									AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(SOH.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
									AND SOH.ProductId = f.FabricId
									AND O.STATUS = 0
								GROUP BY SOH.ProductId
								), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'HoldOnQuantity'
					AND @SortOrder = 'ASC'
					THEN ISNULL((
								SELECT SUM(SOH.Quantity)
								FROM OrderSetItems AS OSI WITH (NOLOCK)
								INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
								INNER JOIN Orders AS O WITH (NOLOCK) ON O.OrderId = SOH.OrderId
								WHERE OSI.IsDeleted = 0
									AND OSI.IsQuantityOnHold = 1
									AND SOH.IsStockOnHold = 1
									AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(SOH.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
									AND SOH.ProductId = f.FabricId
									AND O.STATUS = 0
								GROUP BY SOH.ProductId
								), 0)
				END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
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

