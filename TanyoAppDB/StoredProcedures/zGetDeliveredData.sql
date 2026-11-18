
/*
	EXEC [dbo].[GetDeliveredData]
		@TenantID = 2
		,@CurrentUserId = 1
		,@DeliveryNo = NULL
		,@OrderNo = NULL
		,@CustomerName = null
		,@SalesmanName = NULL
		,@OrderFromDate = null
		,@OrderToDate = null
		,@OrderType = NULL
		,@CategoryId = null
		,@DeliveryFromDate = null
		,@DeliveryToDate = null
*/
CREATE PROCEDURE [dbo].[zGetDeliveredData] @TenantId INT = 1
	,@CurrentUserId INT
	,@DeliveryNo NVARCHAR(50) = NULL
	,@OrderNo NVARCHAR(20) = NULL
	,@CustomerName NVARCHAR(255) = NULL
	,@SalesmanName INT = NULL
	,@OrderFromDate DATETIME = NULL
	,@OrderToDate DATETIME = NULL
	,@OrderType SMALLINT = NULL
	,@CategoryId BIGINT
	,@DeliveryFromDate DATETIME = NULL
	,@DeliveryToDate DATETIME = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = '10'
	,@SortOrder VARCHAR(50) = 'DESC'
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL
			,@OrderToDateTime DATETIMEOFFSET = NULL

		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		-- Get SubjectTypeIds
		DECLARE @ProductSubjectTypeId INT
			,@PolishSubjectTypeId INT
			,@FabricSubjectTypeId INT;

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId;

		SELECT @PolishSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Polish'
			AND TenantId = @TenantId;

		SELECT @FabricSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Fabrics'
			AND TenantId = @TenantId;

		SELECT --DISTINCT
			os.OrderId
			,o.OrderNo
			,os.DeliveryNo
			,ISNULL(cat.CategoryName, '') AS CategoryName
			,c.FirstName + ' ' + c.LastName AS CustomerName
			,CASE 
				WHEN os.SubjectTypeId = @ProductSubjectTypeId
					THEN p.ProductTitle
				WHEN os.SubjectTypeId = @PolishSubjectTypeId
					THEN pl.Title
				WHEN os.SubjectTypeId = @FabricSubjectTypeId
					THEN f.Title
				ELSE ''
				END AS ProductTitle
			,os.OrderSetItemId
			,os.ItemStatus
			,@CurrentUserId AS UserId
			,o.TentativeDeliveryDate
			,o.ApprovedDate
			,o.CreatedDate AS OrderDate
			,os.DeliveryDate
			,o.OrderType
			,ISNULL(os.DeliveryComment, '') AS DeliveryComment
			,cat.CategoryId
			,COUNT(1) OVER () AS TotalCount
		FROM OrderSetItems os WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON os.OrderId = o.OrderId
		LEFT JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
		LEFT JOIN Products p WITH (NOLOCK) ON os.SubjectId = p.ProductId
			AND os.SubjectTypeId = @ProductSubjectTypeId
		LEFT JOIN Polish pl WITH (NOLOCK) ON os.SubjectId = pl.PolishId
			AND os.SubjectTypeId = @PolishSubjectTypeId
		LEFT JOIN Fabrics f WITH (NOLOCK) ON os.SubjectId = f.FabricId
			AND os.SubjectTypeId = @FabricSubjectTypeId
		LEFT JOIN Categories cat WITH (NOLOCK) ON p.CategoryId = cat.CategoryId
		WHERE o.TenantId = @TenantId
			AND os.ItemStatus = 3 --Delivered
			AND (
				@DeliveryNo IS NULL
				OR os.DeliveryNo LIKE '%' + @DeliveryNo + '%'
				)
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@CustomerName IS NULL
				OR (c.FirstName + ' ' + c.LastName) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@SalesmanName IS NULL
				OR o.SalesmanId = @SalesmanName
				)
			AND (
				@OrderType IS NULL
				OR o.OrderType = @OrderType
				)
			AND (
				@CategoryId IS NULL
				OR cat.CategoryId = @CategoryId
				)
			AND (
				@OrderFromDate IS NULL
				OR (o.CreatedDate) >= @OrderFromDateTime
				)
			AND (
				@OrderToDate IS NULL
				OR (o.CreatedDate) <= @OrderToDateTime
				)
			AND (
				(
					@DeliveryFromDate IS NULL
					AND @DeliveryToDate IS NULL
					)
				OR (
					os.DeliveryDate BETWEEN os.DeliveryDate
						AND os.DeliveryDate
					)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN O.OrderNo
				END
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN O.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryNo'
					AND @SortOrder = 'ASC'
					THEN OS.DeliveryNo
				END
			,CASE 
				WHEN @SortBy = 'DeliveryNo'
					AND @SortOrder = 'DESC'
					THEN OS.DeliveryNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN (c.FirstName + ' ' + c.LastName)
				END
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN (c.FirstName + ' ' + c.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN ISNULL(cat.CategoryName, '')
				END
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN ISNULL(cat.CategoryName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ProductTitle
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pl.Title
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.Title
							ELSE ''
							END
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ProductTitle
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pl.Title
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.Title
							ELSE ''
							END
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN o.CreatedDate
				END
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN o.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.TentativeDeliveryDate
				END
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.TentativeDeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'ASC'
					THEN os.DeliveryDate
				END
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'DESC'
					THEN os.DeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryComment'
					AND @SortOrder = 'ASC'
					THEN ISNULL(os.DeliveryComment, '')
				END
			,CASE 
				WHEN @SortBy = 'DeliveryComment'
					AND @SortOrder = 'DESC'
					THEN ISNULL(os.DeliveryComment, '')
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS 
			FETCH NEXT @PageSize ROWS ONLY;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				)
	END CATCH
END

GO

