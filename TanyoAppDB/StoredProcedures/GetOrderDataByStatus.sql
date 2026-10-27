/*  
 EXEC [dbo].[GetOrderDataByStatus]  
  @TenantId = 2  
  ,@CurrentUserId = 4528  
  ,@CategoryId = NULL  
*/
CREATE PROCEDURE [dbo].[GetOrderDataByStatus] (
	@TenantId INT = 1
	,@CurrentUserId INT
	,@DeliveryNo NVARCHAR(50) = NULL
	,@OrderNo NVARCHAR(20) = NULL
	,@CustomerName NVARCHAR(255) = NULL
	,@SalesmanName INT = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@OrderType SMALLINT = NULL
	,@CategoryId BIGINT
	,@DeliveryFromDate DATETIME = NULL
	,@DeliveryToDate DATETIME = NULL
	,@ApprovedFromDate DATE = NULL
	,@ApprovedToDate DATE = NULL
	,@ItemStatus INT = 2
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'TentativeDeliveryDate'
	,@SortOrder VARCHAR(50) = 'DESC'
	,@ProductTitle VARCHAR(150) = NULL
	,@PaymentCollectionStatus INT = - 1
	,@ModelNo VARCHAR(100) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL
			,@OrderToDateTime DATETIMEOFFSET = NULL

		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		SELECT osi.OrderId
			,o.OrderNo
			,osi.DeliveryNo
			,ISNULL(cat.CategoryName, '') AS CategoryName
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,p.ProductTitle AS ProductTitle
			,p.ModelNo AS ModelNo
			,osi.OrderSetItemId
			,osi.ItemStatus
			,@CurrentUserId AS UserId
			,o.TentativeDeliveryDate
			,o.ApprovedDate
			,o.CreatedDate AS OrderDate
			,ISNULL(u.FirstName + ' ' + u.LastName, '') + CASE 
				WHEN u.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS CreatedByName
			,osi.DeliveryDate
			,o.CreatedBy AS CreatedBy
			,o.OrderType
			,osi.Quantity AS Quantity
			,ISNULL(osi.DeliveryComment, '') AS DeliveryComment
			,cat.CategoryId
			,osi.SubjectId AS SubjectId
			,CASE 
				WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
					THEN 1
				WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
					THEN 2
				ELSE 3
				END AS PaymentCollectionStatus
			,CASE 
				WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
					THEN 'Paid'
				WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
					THEN 'Partial Paid'
				ELSE 'Unpaid'
				END AS PaymentCollectionStatusName
			,COUNT(1) OVER () AS TotalCount
		FROM OrderSetItems osi WITH (NOLOCK)
		INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
		INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
			AND c.TenantId = o.TenantId
		INNER JOIN AspNetUsers u WITH (NOLOCK) ON u.UserId = o.SalesmanId
		INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
			AND p.TenantId = o.TenantId
		INNER JOIN Categories cat WITH (NOLOCK) ON cat.CategoryId = p.CategoryId
			AND cat.TenantId = @TenantId
		LEFT JOIN (
			SELECT p.OrderId
				,ISNULL(SUM(p.ReceivedAmount), 0) AS TotalReceivedAmount
			FROM Payments p WITH (NOLOCK)
			WHERE p.IsDeleted = 0
				AND p.PaymentStatus = 1
				AND p.TenantId = @TenantId
			GROUP BY OrderId
			) pmt ON pmt.OrderId = o.OrderId
		WHERE o.TenantId = @TenantId
			AND osi.ParentOrderSetItemId IS NULL
			AND osi.ItemStatus = @ItemStatus
			AND osi.IsDeleted = 0
			AND o.Status <> 9
			AND (
				@DeliveryNo IS NULL
				OR osi.DeliveryNo LIKE '%' + @DeliveryNo + '%'
				)
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@CustomerName IS NULL
				OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@SalesmanName IS NULL
				OR O.SalesmanId = @SalesmanName
				)
			AND (
				@CategoryId IS NULL
				OR cat.CategoryId = @CategoryId
				)
			AND (
				@OrderType IS NULL
				OR o.OrderType = @OrderType
				)
			AND (
				@OrderFromDate IS NULL
				OR (o.ApprovedDate) >= @OrderFromDateTime
				)
			AND (
				@OrderToDate IS NULL
				OR (o.ApprovedDate) <= @OrderToDateTime
				)
			AND (
				(
					@DeliveryFromDate IS NULL
					AND @DeliveryToDate IS NULL
					)
				OR (
					osi.DeliveryDate BETWEEN ISNULL(@DeliveryFromDate, osi.DeliveryDate)
						AND ISNULL(@DeliveryToDate, osi.DeliveryDate)
					)
				)
			AND (
				@ProductTitle IS NULL
				OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
				)
			AND (
				@PaymentCollectionStatus IS NULL
				OR @PaymentCollectionStatus = - 1
				OR CASE 
					WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
						THEN 1
					WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
						THEN 2
					ELSE 3
					END = @PaymentCollectionStatus
				)
			AND (
				@ModelNo IS NULL
				OR p.ModelNo LIKE '%' + @ModelNo + '%'
				)
		ORDER BY CASE 
				WHEN @SortBy = 'DeliveryNo'
					AND @SortOrder = 'ASC'
					THEN DeliveryNo
				END
			,CASE 
				WHEN @SortBy = 'DeliveryNo'
					AND @SortOrder = 'DESC'
					THEN DeliveryNo
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN OrderNo
				END
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'ASC'
					THEN (u.FirstName + ' ' + u.LastName)
				END
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'DESC'
					THEN (u.FirstName + ' ' + u.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))
				END
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN p.ProductTitle
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN p.ProductTitle
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDateReadyToDelivered'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END
			,CASE 
				WHEN @SortBy = 'OrderDateReadyToDelivered'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
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
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'ASC'
					THEN osi.DeliveryDate
				END
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'DESC'
					THEN osi.DeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryComment'
					AND @SortOrder = 'ASC'
					THEN ISNULL(osi.DeliveryComment, '')
				END
			,CASE 
				WHEN @SortBy = 'DeliveryComment'
					AND @SortOrder = 'DESC'
					THEN ISNULL(osi.DeliveryComment, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'PaymentCollectionStatus'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
								THEN 1
							WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
								THEN 2
							ELSE 3
							END
				END
			,CASE 
				WHEN @SortBy = 'PaymentCollectionStatus'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
								THEN 1
							WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
								THEN 2
							ELSE 3
							END
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
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN cat.CategoryName
				END
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN cat.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN p.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN p.ModelNo
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

