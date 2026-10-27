
-- =====================================================================
-- Report   : Stock Outward Report (TAN-4455)
-- Purpose  : Physical stock outward for delivered order items
--            (OrderSetItems.ItemStatus = 3 Delivered), one row per
--            item x warehouse from OrderDeliveryDetails. Items with no
--            outward detail rows (legacy data) appear once with blank
--            warehouse and the ordered quantity.
-- Scope    : Orders not archived, Status NOT IN (6 Canceled, 8 Declined);
--            partially delivered orders (Status 2/3) ARE included.
-- Date     : Delivery Date filter is on OrderSetItems.DeliveryDate
--            (item-level, set when marked Delivered), inclusive range.
-- Qty      : COALESCE(OrderDeliveryDetails.DeliverQuantity, ordered qty).
-- Delivered: COALESCE(odd.LastModifiedBy, osi.UpdatedBy) -> AspNetUsers
--            FirstName + LastName + ' (Inactive)' when user deleted.
-- NOTE     : Only product items (SubjectTypeId = tenant's 'Products'
--            subject type) are reported; fabric/other-subject items are
--            excluded (columns Model No / Category are product-specific).
-- =====================================================================
/*
EXEC [dbo].[ReportStockOutward] @TenantId= 1206
*/
CREATE PROCEDURE [dbo].[ReportStockOutward] 
	 @TenantId INT
	,@DeliveryFromDate DATE = NULL
	,@DeliveryToDate DATE = NULL
	,@WarehouseId BIGINT = NULL
	,@DeliveredById INT = NULL
	,@CustomerId BIGINT = NULL
	,@CategoryId INT = NULL
	,@OrderNo VARCHAR(100) = NULL
	,@ModelNo VARCHAR(100) = NULL
	,@ProductTitle VARCHAR(500) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy VARCHAR(50) = 'DeliveryDate'
	,@SortOrder VARCHAR(4) = 'desc'
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		-- SubjectTypes are tenant-scoped; resolve the 'Products' subject type
		-- so fabric/other-subject items never join onto a colliding ProductId.
		DECLARE @ProductSubjectTypeId INT = (
				SELECT TOP 1 st.SubjectTypeId
				FROM dbo.SubjectTypes st WITH (NOLOCK)
				WHERE st.TenantId = @TenantId
					AND st.SubjectTypeName = 'Products'
				);

			SELECT ISNULL(CONVERT(VARCHAR(10), COALESCE(o.DeliveryDate, osi.DeliveryDate), 103), '') AS DeliveryDate
				,COALESCE(o.DeliveryDate, osi.DeliveryDate) AS DeliveryDateSort
				,o.OrderNo AS OrderNo
				,LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))) AS CustomerName
				,ISNULL(w.Name, '') AS Warehouse
				,ISNULL(cat.CategoryName, '') AS ProductCategory
				,ISNULL(p.ModelNo, '') AS ModelNo
				,ISNULL(p.ProductTitle, '') AS ProductTitle
				,COALESCE(odd.DeliverQuantity, osi.Quantity) AS Quantity
				,ISNULL(au.FirstName + ' ' + au.LastName, '') + CASE 
					WHEN au.IsDeleted = 1
						THEN ' (Inactive)'
					ELSE ''
					END AS DeliveredByName
				,osi.OrderSetItemId AS OrderSetItemId
				,odd.OrderDeliveryDetailId AS OrderDeliveryDetailId
				,COUNT(1) OVER () AS TotalCount
			FROM OrderSetItems osi WITH (NOLOCK)
			INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
			INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
			INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
				AND p.TenantId = @TenantId
			INNER JOIN Categories cat WITH (NOLOCK) ON cat.CategoryId = p.CategoryId
			LEFT JOIN OrderDeliveryDetails odd WITH (NOLOCK) ON odd.OrderSetItemId = osi.OrderSetItemId
			LEFT JOIN Warehouse w WITH (NOLOCK) ON w.Id = odd.WarehouseId
			LEFT JOIN AspNetUsers au WITH (NOLOCK) ON au.UserId = COALESCE(odd.LastModifiedBy, osi.UpdatedBy)
			WHERE o.TenantId = @TenantId
				AND osi.SubjectTypeId = @ProductSubjectTypeId -- product items only
				AND osi.ItemStatus = 3 -- OrderSetItemsStatus.Delivered
				AND osi.IsDeleted = 0
				AND o.Status NOT IN (
					6
					,8
					) -- skip Canceled / Declined
				AND o.IsArchive = 0
				AND (
					@DeliveryFromDate IS NULL
					OR COALESCE(o.DeliveryDate, osi.DeliveryDate) >= @DeliveryFromDate
					)
				AND (
					@DeliveryToDate IS NULL
					OR COALESCE(o.DeliveryDate, osi.DeliveryDate) < DATEADD(DAY, 1, CAST(@DeliveryToDate AS DATETIME))
					)
				AND (
					@WarehouseId IS NULL
					OR odd.WarehouseId = @WarehouseId
					)
				AND (
					@DeliveredById IS NULL
					OR COALESCE(odd.LastModifiedBy, osi.UpdatedBy) = @DeliveredById
					)
				AND (
					@CustomerId IS NULL
					OR o.CustomerID = @CustomerId
					)
				AND (
					@CategoryId IS NULL
					OR p.CategoryId = @CategoryId
					)
				AND (
					@OrderNo IS NULL
					OR LTRIM(RTRIM(@OrderNo)) = ''
					OR o.OrderNo LIKE '%' + @OrderNo + '%'
					)
				AND (
					@ModelNo IS NULL
					OR LTRIM(RTRIM(@ModelNo)) = ''
					OR p.ModelNo LIKE '%' + @ModelNo + '%'
					)
				AND (
					@ProductTitle IS NULL
					OR LTRIM(RTRIM(@ProductTitle)) = ''
					OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
					)
		ORDER BY 
			CASE WHEN @SortBy = 'DeliveryDate' AND @SortOrder = 'asc' THEN  COALESCE(o.DeliveryDate, osi.DeliveryDate) END ASC,
			CASE WHEN @SortBy = 'DeliveryDate' AND @SortOrder = 'desc' THEN  COALESCE(o.DeliveryDate, osi.DeliveryDate) END DESC,
			CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'asc' THEN o.OrderNo END ASC,
			CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'desc' THEN o.OrderNo END DESC,
			CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'asc' THEN c.FirstName END ASC,
			CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'desc' THEN c.FirstName END DESC,
			CASE WHEN @SortBy = 'Warehouse' AND @SortOrder = 'asc' THEN w.Name END ASC,
			CASE WHEN @SortBy = 'Warehouse' AND @SortOrder = 'desc' THEN w.Name END DESC,
			CASE WHEN @SortBy = 'ProductCategory' AND @SortOrder = 'asc' THEN cat.CategoryName END ASC,
			CASE WHEN @SortBy = 'ProductCategory' AND @SortOrder = 'desc' THEN cat.CategoryName END DESC,
			CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'asc' THEN p.ModelNo END ASC,
			CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'desc' THEN p.ModelNo END DESC,
			CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'asc' THEN p.ProductTitle END ASC,
			CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'desc' THEN p.ProductTitle END DESC,
			CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'asc' THEN COALESCE(odd.DeliverQuantity, osi.Quantity) END ASC,
			CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'desc' THEN COALESCE(odd.DeliverQuantity, osi.Quantity) END DESC,
			CASE WHEN @SortBy = 'DeliveredByName' AND @SortOrder = 'asc' THEN au.FirstName END ASC,
			CASE WHEN @SortBy = 'DeliveredByName' AND @SortOrder = 'desc' THEN au.FirstName END DESC,
			osi.DeliveryDate DESC OFFSET(@PageIndex - 1) * @PageSize ROWS
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
END;

GO

