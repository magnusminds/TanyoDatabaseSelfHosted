/*    
	EXEC [dbo].[GlobalReportInventoryAsOfNow]
		@InventoryType = 0
		,@TenantId = 1

	EXEC [dbo].[GlobalReportInventoryAsOfNow]
		@InventoryType = 0
		,@TenantId = 2
		,@ProductTitle = ''
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'ReadyToDelivered'
		,@SortOrder = 'ASC'

	EXEC [dbo].[GlobalReportInventoryAsOfNow]
		@InventoryType = 2
		,@TenantId = 1
*/

CREATE   PROCEDURE [dbo].[GlobalReportInventoryAsOfNow]
(
	@InventoryType INT
	,@TenantId INT = NULL
	,@UserId INT
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
	DECLARE @DateOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
	
	DROP TABLE IF EXISTS #TenantIds
	CREATE TABLE #TenantIds (TenantId INT)

	INSERT INTO #TenantIds (TenantId)
	SELECT TenantId
	FROM UserTenantMapping WITH (NOLOCK)
	WHERE UserId = @UserId
	AND (@TenantId IS NULL OR TenantId = @TenantId)

	IF @InventoryType = 0 --Products
	BEGIN
		DROP TABLE IF EXISTS #ProductSubjectTypeIds
		CREATE TABLE #ProductSubjectTypeIds (ProductSubjectTypeId INT)

		INSERT INTO #ProductSubjectTypeIds (ProductSubjectTypeId)
		SELECT st.SubjectTypeId
		FROM SubjectTypes AS st WITH (NOLOCK)
		INNER JOIN #TenantIds utm ON st.TenantId = utm.TenantId
		WHERE st.SubjectTypeName = 'Products'
		AND st.IsDeleted = 0

		;WITH cteProducts AS (
			SELECT p.ProductId
				,p.CoverImage AS ImagePath
				,p.ProductTitle + ' - ' + p.ModelNo AS ProductTitle
				,c1.CategoryName AS CategoryName
				,c1.CategoryId AS CategoryId
				,ISNULL(ia.Quantity, 0) AS InStock
				,ISNULL(SUM(CASE 
							WHEN o.Status = 0
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS Inquiry
				,ISNULL(SUM(CASE 
							WHEN o.Status = 1
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS PendingForApproval
				,ISNULL(SUM(CASE 
							WHEN o.Status = 2
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS Approved
				,ISNULL(SUM(CASE 
							WHEN os.ItemStatus = 0
								AND o.Status > 2
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS ReadyToManufacturing
				,ISNULL(SUM(CASE 
							WHEN os.ItemStatus = 1
								AND o.Status > 2
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS Manufacturing
				,ISNULL(SUM(CASE 
							WHEN os.ItemStatus = 2
								AND o.Status > 2
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS ReadyToDelivered
				,ISNULL(SUM(CASE 
							WHEN os.ItemStatus = 3
								AND o.Status > 2
								AND pst.ProductSubjectTypeId IS NOT NULL
								THEN os.Quantity
							ELSE 0
							END), 0) AS Delivered
				,ISNULL((
						SELECT SUM(SOH.Quantity)
						FROM OrderSetItems AS OSI WITH (NOLOCK)
						INNER JOIN StockOnHold AS SOH WITH (NOLOCK) ON SOH.ORDERSETITEMID = OSI.ORDERSETITEMID
						INNER JOIN Orders AS O2 WITH (NOLOCK) ON O2.OrderId = SOH.OrderId
						WHERE OSI.IsDeleted = 0
						AND OSI.IsQuantityOnHold = 1
						AND SOH.IsStockOnHold = 1
						AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), SOH.CreatedDate) > @DateOffset
						AND SOH.ProductId = p.ProductId
						AND O2.Status = 0
						), 0) AS HoldOnQuantity
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,t.TenantName
			FROM [dbo].[Products] p WITH (NOLOCK)
			INNER JOIN Categories c1 WITH (NOLOCK) ON p.CategoryId = c1.CategoryId
				AND c1.IsDeleted = 0
			INNER JOIN [dbo].[ProductQuantities] ia WITH (NOLOCK) ON p.ProductId = ia.ProductId
			LEFT JOIN [dbo].[OrderSetItems] os WITH (NOLOCK) ON p.ProductId = os.SubjectId
			LEFT JOIN [dbo].[Orders] o WITH (NOLOCK) ON os.OrderId = o.OrderId
			LEFT JOIN [dbo].[Customers] c WITH (NOLOCK) ON c.CustomerId = o.CustomerId
			LEFT JOIN #ProductSubjectTypeIds pst ON os.SubjectTypeId = pst.ProductSubjectTypeId
			INNER JOIN Tenants t WITH (NOLOCK) ON p.TenantId = t.TenantId
			WHERE p.Status IN (0,1,2)
			AND os.IsDeleted = 0
			AND o.Status NOT IN (8, 9)
			AND c.IsDeleted = 0
			AND p.TenantId IN (SELECT TenantId FROM #TenantIds)
			AND (
					(
						@ProductTitle IS NULL
						OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
					)
					OR p.ModelNo LIKE '%' + @ProductTitle + '%'
					OR CONCAT (p.ProductTitle, ' - ', p.ModelNo) LIKE '%' + @ProductTitle + '%'
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
				,t.TenantName
		)
		SELECT p.ProductId
			,p.ImagePath
			,p.ProductTitle
			,p.CategoryName
			,p.CategoryId
			,p.InStock
			,p.Inquiry
			,p.PendingForApproval
			,p.Approved
			,p.ReadyToManufacturing
			,p.Manufacturing
			,p.ReadyToDelivered
			,p.Delivered
			,p.HoldOnQuantity
			,p.TotalCount
			,p.TenantName
		FROM cteProducts p
		ORDER BY CASE WHEN @SortBy = 'TenantName' AND @SortOrder = 'ASC' THEN p.TenantName END ASC
			,CASE WHEN @SortBy = 'TenantName' AND @SortOrder = 'DESC' THEN p.TenantName END DESC
			,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle END ASC
			,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC
			,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN p.CategoryName END ASC
			,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN p.CategoryName END DESC
			,CASE WHEN @SortBy = 'InStock' AND @SortOrder = 'ASC' THEN p.InStock END ASC
			,CASE WHEN @SortBy = 'InStock' AND @SortOrder = 'DESC' THEN p.InStock END DESC
			,CASE WHEN @SortBy = 'Inquiry' AND @SortOrder = 'ASC' THEN p.Inquiry END ASC
			,CASE WHEN @SortBy = 'Inquiry' AND @SortOrder = 'DESC' THEN p.Inquiry END DESC
			,CASE WHEN @SortBy = 'PendingForApproval' AND @SortOrder = 'ASC' THEN p.PendingForApproval END ASC
			,CASE WHEN @SortBy = 'PendingForApproval' AND @SortOrder = 'DESC' THEN p.PendingForApproval END DESC
			,CASE WHEN @SortBy = 'Approved' AND @SortOrder = 'ASC' THEN p.Approved END ASC
			,CASE WHEN @SortBy = 'Approved' AND @SortOrder = 'DESC' THEN p.Approved END DESC
			,CASE WHEN @SortBy = 'ReadyToManufacturing' AND @SortOrder = 'ASC' THEN p.ReadyToManufacturing END ASC
			,CASE WHEN @SortBy = 'ReadyToManufacturing' AND @SortOrder = 'DESC' THEN p.ReadyToManufacturing END DESC
			,CASE WHEN @SortBy = 'Manufacturing' AND @SortOrder = 'ASC' THEN p.Manufacturing END ASC
			,CASE WHEN @SortBy = 'Manufacturing' AND @SortOrder = 'DESC' THEN p.Manufacturing END DESC
			,CASE WHEN @SortBy = 'ReadyToDelivered' AND @SortOrder = 'ASC' THEN p.ReadyToDelivered END ASC
			,CASE WHEN @SortBy = 'ReadyToDelivered' AND @SortOrder = 'DESC' THEN p.ReadyToDelivered END DESC
			,CASE WHEN @SortBy = 'Delivered' AND @SortOrder = 'ASC' THEN p.Delivered END ASC
			,CASE WHEN @SortBy = 'Delivered' AND @SortOrder = 'DESC' THEN p.Delivered END DESC
			,CASE WHEN @SortBy = 'HoldOnQuantity' AND @SortOrder = 'ASC' THEN p.HoldOnQuantity END ASC
			,CASE WHEN @SortBy = 'HoldOnQuantity' AND @SortOrder = 'DESC' THEN p.HoldOnQuantity END DESC 
		OFFSET(@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY;
	END

	IF @InventoryType = 2 -- Fabrics
	BEGIN
		DROP TABLE IF EXISTS #FabricSubjectTypeIds
		CREATE TABLE #FabricSubjectTypeIds (FabricSubjectTypeId INT)

		INSERT INTO #FabricSubjectTypeIds (FabricSubjectTypeId)
		SELECT st.SubjectTypeId
		FROM SubjectTypes AS st WITH (NOLOCK)
		INNER JOIN #TenantIds utm ON st.TenantId = utm.TenantId
		WHERE st.SubjectTypeName = 'Fabrics'
		AND st.IsDeleted = 0

		;WITH cteFabrics AS (
			SELECT CAST(f.FabricId AS BIGINT) AS ProductId
				,f.ImagePath AS ImagePath
				,f.Title + ' - ' + f.ModelNo AS ProductTitle
				,c1.CompanyName AS CategoryName
				,CAST(c1.CompanyId AS BIGINT) AS CategoryId
				,0 AS InStock
				,ISNULL(SUM(CASE 
								WHEN o.Status = 0
									AND fst.FabricSubjectTypeId IS NOT NULL
									THEN os.Quantity 
									ELSE 0 
									END), 0) AS Inquiry
				,ISNULL(SUM(CASE WHEN o.Status = 1
									AND fst.FabricSubjectTypeId IS NOT NULL 
									THEN os.Quantity 
									ELSE 0 
									END), 0) AS PendingForApproval
				,ISNULL(SUM(CASE WHEN o.Status = 2
									AND fst.FabricSubjectTypeId IS NOT NULL 
									THEN os.Quantity 
									ELSE 0 
									END), 0) AS Approved
				,ISNULL(SUM(CASE WHEN os.ItemStatus = 0
									AND o.Status > 2
									AND fst.FabricSubjectTypeId IS NOT NULL 
									THEN os.Quantity 
									ELSE 0 
									END), 0) AS ReadyToManufacturing
				,ISNULL(SUM(CASE WHEN os.ItemStatus = 1
									AND o.Status > 2
									AND fst.FabricSubjectTypeId IS NOT NULL 
									THEN os.Quantity 
									ELSE 0 
									END), 0) AS Manufacturing
				,ISNULL(SUM(CASE WHEN os.ItemStatus = 2
									AND o.Status > 2
									AND fst.FabricSubjectTypeId IS NOT NULL 
									THEN os.Quantity 
									ELSE 0 
									END), 0) AS ReadyToDelivered
				,ISNULL(SUM(CASE WHEN os.ItemStatus = 3
									AND o.Status > 2
									AND fst.FabricSubjectTypeId IS NOT NULL 
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
						AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), SOH.CreatedDate) > @DateOffset
						AND ProductId = f.FabricId
						AND O.Status = 0
						GROUP BY SOH.ProductId
						), 0) AS HoldOnQuantity
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,t.TenantName
			FROM [dbo].[Fabrics] f WITH (NOLOCK)
			RIGHT JOIN Companies c1 WITH (NOLOCK) ON c1.CompanyId = f.CompanyId 
				AND c1.TenantId = f.TenantId
			LEFT JOIN [dbo].[OrderSetItems] os WITH (NOLOCK) ON os.SubjectId = f.FabricId
			LEFT JOIN [dbo].[Orders] o WITH (NOLOCK) ON os.OrderId = o.OrderId
			LEFT JOIN [dbo].[Customers] c WITH (NOLOCK) ON c.CustomerId = o.CustomerId
			LEFT JOIN #FabricSubjectTypeIds fst WITH (NOLOCK) ON os.SubjectTypeId = fst.FabricSubjectTypeId
			INNER JOIN Tenants t WITH (NOLOCK) ON f.TenantId = t.TenantId
			WHERE f.TenantId IN (SELECT TenantId FROM #TenantIds)
			AND C.IsDeleted = 0
			AND o.[Status] NOT IN (8, 9)
			AND os.IsDeleted = 0
			AND f.IsDeleted = 0
			AND (
					(
						@ProductTitle IS NULL
						OR f.Title LIKE '%' + @ProductTitle + '%'
					)
					OR f.ModelNo LIKE '%' + @ProductTitle + '%'
					OR CONCAT ( f.Title, ' - ' ,f.ModelNo ) LIKE '%' + @ProductTitle + '%'
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
				,t.TenantName
		)
		SELECT fb.ProductId
			,fb.ImagePath
			,fb.ProductTitle
			,fb.CategoryName
			,fb.CategoryId
			,fb.InStock
			,fb.Inquiry
			,fb.PendingForApproval
			,fb.Approved
			,fb.ReadyToManufacturing
			,fb.Manufacturing
			,fb.ReadyToDelivered
			,fb.Delivered
			,fb.HoldOnQuantity
			,fb.TotalCount
			,fb.TenantName
		FROM cteFabrics fb
		ORDER BY CASE WHEN @SortBy = 'TenantName' AND @SortOrder = 'ASC' THEN fb.TenantName END ASC
			,CASE WHEN @SortBy = 'TenantName' AND @SortOrder = 'DESC' THEN fb.TenantName END DESC
			,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN fb.ProductTitle END ASC
			,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN fb.ProductTitle END DESC
			,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN fb.CategoryName END ASC
			,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN fb.CategoryName END DESC
			,CASE WHEN @SortBy = 'Inquiry' AND @SortOrder = 'DESC' THEN fb.Inquiry END DESC
			,CASE WHEN @SortBy = 'Inquiry' AND @SortOrder = 'ASC' THEN fb.Inquiry END ASC
			,CASE WHEN @SortBy = 'PendingForApproval' AND @SortOrder = 'DESC' THEN fb.PendingForApproval END DESC
			,CASE WHEN @SortBy = 'PendingForApproval' AND @SortOrder = 'ASC' THEN fb.PendingForApproval END ASC
			,CASE WHEN @SortBy = 'Approved' AND @SortOrder = 'DESC' THEN fb.Approved END DESC
			,CASE WHEN @SortBy = 'Approved' AND @SortOrder = 'ASC' THEN fb.Approved END ASC
			,CASE WHEN @SortBy = 'ReadyToManufacturing' AND @SortOrder = 'DESC' THEN fb.ReadyToManufacturing END DESC
			,CASE WHEN @SortBy = 'ReadyToManufacturing' AND @SortOrder = 'ASC' THEN fb.ReadyToManufacturing END ASC
			,CASE WHEN @SortBy = 'Manufacturing' AND @SortOrder = 'DESC' THEN fb.Manufacturing END DESC
			,CASE WHEN @SortBy = 'Manufacturing' AND @SortOrder = 'ASC' THEN fb.Manufacturing END ASC
			,CASE WHEN @SortBy = 'ReadyToDelivered' AND @SortOrder = 'DESC' THEN fb.ReadyToDelivered END DESC
			,CASE WHEN @SortBy = 'ReadyToDelivered' AND @SortOrder = 'ASC' THEN fb.ReadyToDelivered END ASC
			,CASE WHEN @SortBy = 'Delivered' AND @SortOrder = 'DESC' THEN fb.Delivered END DESC
			,CASE WHEN @SortBy = 'Delivered' AND @SortOrder = 'ASC' THEN fb.Delivered END ASC
			,CASE WHEN @SortBy = 'HoldOnQuantity' AND @SortOrder = 'DESC' THEN fb.HoldOnQuantity END DESC
			,CASE WHEN @SortBy = 'HoldOnQuantity' AND @SortOrder = 'ASC' THEN fb.HoldOnQuantity END ASC 
		OFFSET(@PageIndex - 1) * @PageSize ROWS
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

