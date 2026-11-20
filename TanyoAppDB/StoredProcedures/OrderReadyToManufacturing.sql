/*
	EXEC OrderReadyToManufacturing
		 @TenantId = 1
		,@OrderNo = ''
		,@TentativeDeliveryFromDate = ''
		,@TentativeDeliveryToDate = null
		,@OrderFromDate = null
		,@OrderToDate = ''
		,@OrderType = -1
		,@PageIndex = 1
		,@PageSize = 50
		,@SortBy = 'TentativeDeliveryDate'
		,@SortOrder = 'ASC'
*/
CREATE   PROCEDURE [dbo].[OrderReadyToManufacturing] (
	@TenantId INT
	   ,@OrderNo VARCHAR(20) = NULL
	,@TentativeDeliveryFromDate DATE
	,@TentativeDeliveryToDate DATE
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@OrderType INT
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = ''
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @ProductSubjectTypeId INT;

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		SELECT osi.DeliveryNo AS ManufacturingOrderNumber
			,orders.OrderNo AS OrderNo
			,categories.CategoryName AS CategoryName
			,product.ProductTitle AS ProductTitle
			,product.ModelNo AS modelNo
			,product.CoverImage as CoverImage
			,osi.OrderSetItemId AS OrderSetItemId
			,orders.OrderType AS OrderType
			,orders.TentativeDeliveryDate AS TentativeDeliveryDate
			,orders.OrderId AS OrderId
			,product.ProductId AS ProductId
			,orders.ApprovedDate AS ApprovedDate
			,osi.ItemStatus
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM OrderSetItems AS osi
		INNER JOIN (
			SELECT ord.OrderId
				,ord.ApprovedDate
				,ord.OrderNo
				,ord.OrderType
				,ord.STATUS
				,ord.TentativeDeliveryDate
			FROM Orders AS ord
			WHERE ord.TenantId = @TenantId
				AND ord.STATUS <> 9 -- Delete status
				AND (
					@OrderNo IS NULL
					OR ord.OrderNo LIKE '%' + @OrderNo + '%'
					)
			) AS orders ON osi.OrderId = orders.OrderId
		INNER JOIN (
			SELECT prod.ProductId
				,prod.CategoryId
				,prod.ProductTitle
				,prod.ModelNo
				,prod.CoverImage
			FROM Products AS prod
			WHERE prod.TenantId = @TenantId
				AND prod.STATUS <> 3 -- Delete status				
			) AS product ON osi.SubjectId = product.ProductId
		INNER JOIN (
			SELECT cat.CategoryId
				,cat.CategoryName
			FROM Categories AS cat
			WHERE cat.IsDeleted = CAST(0 AS BIT)
				AND cat.TenantId = @TenantId
			) AS categories ON CAST(product.CategoryId AS BIGINT) = categories.CategoryId
		WHERE osi.IsDeleted = CAST(0 AS BIT)
			AND osi.SubjectTypeId = @ProductSubjectTypeId
			AND orders.STATUS = 3 -- InProgress Status
			AND osi.ItemStatus = 0
			AND (
				(
					@TentativeDeliveryFromDate IS NULL
					OR @TentativeDeliveryFromDate = ''
					)
				OR (
					@TentativeDeliveryToDate IS NULL
					OR @TentativeDeliveryToDate = ''
					)
				OR CONVERT(DATE, orders.TentativeDeliveryDate) BETWEEN @TentativeDeliveryFromDate
					AND @TentativeDeliveryToDate
				)
			AND (
				(
					@OrderType IS NULL
					OR @OrderType = - 1
					)
				OR orders.OrderType = @OrderType
				)
			AND (
				(
					@OrderFromDate IS NULL
					OR @OrderFromDate = ''
					)
				OR (
					@OrderToDate IS NULL
					OR @OrderToDate = ''
					)
				OR CONVERT(DATE, orders.ApprovedDate) BETWEEN @OrderFromDate
					AND @OrderToDate
				)
		ORDER BY CASE 
				WHEN @SortBy = 'ManufacturingOrderNumber'
					AND @SortOrder = 'ASC'
					THEN osi.DeliveryNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ManufacturingOrderNumber'
					AND @SortOrder = 'DESC'
					THEN osi.DeliveryNo
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN orders.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN orders.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN categories.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN categories.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN product.ProductTitle
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN product.ProductTitle
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN product.ModelNo
				END DESC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN product.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'DESC'
					THEN orders.TentativeDeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'ASC'
					THEN orders.TentativeDeliveryDate
				END ASC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'DESC'
					THEN orders.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'ASC'
					THEN orders.ApprovedDate
				END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY
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

