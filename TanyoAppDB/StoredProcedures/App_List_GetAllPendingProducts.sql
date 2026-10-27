/*
EXEC [dbo].[App_List_GetAllPendingProducts]
    @TenantId = 2
    ,@UserId = 4279
    ,@OrderNo = NULL
    ,@DeliveryNo = NULL
    ,@CustomerName = NULL
    ,@SalesmanId = NULL
    ,@OrderFromDate = NULL
    ,@OrderToDate = NULL
    ,@ProductTitle = NULL
    ,@TentativeDeliveryFromDate = NULL
    ,@TentativeDeliveryToDate = NULL
    ,@PageIndex = 1
    ,@PageSize = 30
    ,@SortBy = 'CreatedDate'
    ,@SortOrder = 'DESC'
    ,@PaymentCollectionStatusEnum = -1;
*/
CREATE PROCEDURE [dbo].[App_List_GetAllPendingProducts] (
	@TenantId BIGINT
	,@UserId INT
	,@OrderNo VARCHAR(50) = NULL
	,@DeliveryNo VARCHAR(50) = NULL
	,@CustomerName VARCHAR(200) = NULL
	,@SalesmanId BIGINT = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@ProductTitle VARCHAR(200) = NULL
	,@TentativeDeliveryFromDate DATE = NULL
	,@TentativeDeliveryToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	,@PaymentCollectionStatusEnum INT = - 1
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @Offset INT = (@PageIndex - 1) * @PageSize;
		DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL;
		DECLARE @OrderToDateTime DATETIMEOFFSET = NULL;

		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30';

		DECLARE @RoleId VARCHAR(450);
		DECLARE @HasApprovePermission BIT = 0;
		DECLARE @HasSuperAccess BIT = 0;
		DECLARE @IsWholesaler BIT = 0;
		DECLARE @OrderType INT;

		SELECT TOP 1 @RoleId = RoleId
		FROM AspNetUserRoles AS asp
		INNER JOIN AspNetUsers AS u ON asp.UserId = u.Id
		WHERE u.UserId = @UserId;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.Approve'
						,'Permissions.General.Order.Approve'
						)
				)
			SET @HasApprovePermission = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.SuperAccess'
						,'Permissions.General.Order.SuperAccess'
						)
				)
			SET @HasSuperAccess = 1;

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.WholeselerPrice'
						,'Permissions.General.Order.WholeselerPrice'
						)
				)
			SET @IsWholesaler = 1;
		SET @OrderType = CASE 
				WHEN @IsWholesaler = 1
					THEN 2
				ELSE 1
				END;

		DECLARE @ProductSubjectTypeId INT;
		DECLARE @PolishSubjectTypeId INT;
		DECLARE @FabricSubjectTypeId INT;

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId;

		SELECT @PolishSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'Polish'
			AND TenantId = @TenantId;

		SELECT @FabricSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE SubjectTypeName = 'Fabrics'
			AND TenantId = @TenantId;

		SELECT os.DeliveryNo
			,os.OrderSetItemId
			,o.OrderNo
			,(u.FirstName + ' ' + u.LastName) AS SalesmanName
			,(c.FirstName + ' ' + ISNULL(c.LastName, '')) AS CustomerName
			,CASE 
				WHEN os.SubjectTypeId = @ProductSubjectTypeId
					THEN p.ProductTitle
				WHEN os.SubjectTypeId = @PolishSubjectTypeId
					THEN pol.Title
				WHEN os.SubjectTypeId = @FabricSubjectTypeId
					THEN f.Title
				ELSE ''
				END AS ProductTitle
			,CASE 
				WHEN os.SubjectTypeId = @ProductSubjectTypeId
					THEN p.ModelNo
				WHEN os.SubjectTypeId = @PolishSubjectTypeId
					THEN pol.ModelNo
				WHEN os.SubjectTypeId = @FabricSubjectTypeId
					THEN f.ModelNo
				ELSE ''
				END AS ModelNo
			,os.SubjectId AS ProductId
			,o.ApprovedDate AS OrderDate
			,o.TentativeDeliveryDate
			,os.Quantity AS OrderQty
			,os.StockQty AS DeliveredQty
			,o.OrderType
			,o.CreatedDate
			,o.ApprovedDate
			,o.CreatedBy
			,u.IsDeleted AS IsSalesmanDeleted
			,CASE 
				WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
					THEN 1
				WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
					THEN 2
				ELSE 3
				END AS PaymentCollectionStatusEnum
			,CASE 
				WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
					THEN 'Paid'
				WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
					THEN 'Partial Paid'
				ELSE 'Unpaid'
				END AS PaymentCollectionStatusEnumName
			,os.ProductImage
			,COUNT(1) OVER () AS TotalCount
		FROM OrderSetItems os
		INNER JOIN Orders o ON os.OrderId = o.OrderId
		INNER JOIN Customers c ON o.CustomerID = c.CustomerId
		INNER JOIN AspNetUsers u ON o.CreatedBy = u.UserId
		LEFT JOIN Products p ON os.SubjectId = p.ProductId
			AND os.SubjectTypeId = @ProductSubjectTypeId
		LEFT JOIN Fabrics f ON os.SubjectId = f.FabricId
			AND os.SubjectTypeId = @FabricSubjectTypeId
		LEFT JOIN Polish pol ON os.SubjectId = pol.PolishId
			AND os.SubjectTypeId = @PolishSubjectTypeId
		LEFT JOIN (
			SELECT OrderId
				,ISNULL(SUM(ReceivedAmount), 0) AS TotalReceivedAmount
			FROM Payments
			WHERE IsDeleted = 0
				AND PaymentStatus = 1
			GROUP BY OrderId
			) pmt ON pmt.OrderId = o.OrderId
		WHERE os.ItemStatus = 4 -- Pending
			AND os.ParentOrderSetItemId IS NULL
			AND o.IsArchive = 0
			AND o.Status <> 9
			AND o.TenantId = @TenantId
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@DeliveryNo IS NULL
				OR os.DeliveryNo LIKE '%' + @DeliveryNo + '%'
				)
			AND (
				@CustomerName IS NULL
				OR (c.FirstName + ' ' + c.LastName) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@SalesmanId IS NULL
				OR o.CreatedBy = @SalesmanId
				)
			AND (
				@OrderFromDate IS NULL
				OR o.ApprovedDate >= @OrderFromDateTime
				)
			AND (
				@OrderToDate IS NULL
				OR o.ApprovedDate <= @OrderToDateTime
				)
			AND (
				@ProductTitle IS NULL
				OR (
					(
						os.SubjectTypeId = @ProductSubjectTypeId
						AND p.ProductTitle LIKE '%' + @ProductTitle + '%'
						)
					OR (
						os.SubjectTypeId = @PolishSubjectTypeId
						AND pol.Title LIKE '%' + @ProductTitle + '%'
						)
					OR (
						os.SubjectTypeId = @FabricSubjectTypeId
						AND f.Title LIKE '%' + @ProductTitle + '%'
						)
					)
				)
			AND (
				@TentativeDeliveryFromDate IS NULL
				OR o.TentativeDeliveryDate >= @TentativeDeliveryFromDate
				)
			AND (
				@TentativeDeliveryToDate IS NULL
				OR o.TentativeDeliveryDate < DATEADD(DAY, 1, @TentativeDeliveryToDate)
				)
			AND (
				@HasApprovePermission = 1
				OR (
					@HasApprovePermission = 0
					AND @HasSuperAccess = 1
					AND o.OrderType = @OrderType
					)
				OR (
					@HasApprovePermission = 0
					AND @HasSuperAccess = 0
					AND o.CreatedBy = @UserId
					AND o.OrderType = @OrderType
					)
				)
			AND (
				@PaymentCollectionStatusEnum IS NULL
				OR @PaymentCollectionStatusEnum = - 1
				OR CASE 
					WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
						THEN 1
					WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
						THEN 2
					ELSE 3
					END = @PaymentCollectionStatusEnum
				)
		ORDER BY CASE 
				WHEN @SortBy = 'DeliveryNo'
					AND @SortOrder = 'ASC'
					THEN os.DeliveryNo
				END ASC
			,CASE 
				WHEN @SortBy = 'DeliveryNo'
					AND @SortOrder = 'DESC'
					THEN os.DeliveryNo
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN o.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN o.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'ASC'
					THEN (u.FirstName + ' ' + u.LastName)
				END ASC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'DESC'
					THEN (u.FirstName + ' ' + u.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN (c.FirstName + ' ' + ISNULL(c.LastName, ''))
				END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN (c.FirstName + ' ' + ISNULL(c.LastName, ''))
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ProductTitle
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pol.Title
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.Title
							END
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ProductTitle
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pol.Title
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.Title
							END
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.TentativeDeliveryDate
				END ASC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.TentativeDeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderQty'
					AND @SortOrder = 'ASC'
					THEN os.Quantity
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderQty'
					AND @SortOrder = 'DESC'
					THEN os.Quantity
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveredQty'
					AND @SortOrder = 'ASC'
					THEN os.StockQty
				END ASC
			,CASE 
				WHEN @SortBy = 'DeliveredQty'
					AND @SortOrder = 'DESC'
					THEN os.StockQty
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderType'
					AND @SortOrder = 'ASC'
					THEN o.OrderType
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderType'
					AND @SortOrder = 'DESC'
					THEN o.OrderType
				END DESC
			,CASE 
				WHEN @SortBy = 'CreatedDate'
					AND @SortOrder = 'ASC'
					THEN ISNULL(os.UpdatedDate, os.CreatedDate)
				END ASC
			,CASE 
				WHEN @SortBy = 'CreatedDate'
					AND @SortOrder = 'DESC'
					THEN ISNULL(os.UpdatedDate, os.CreatedDate)
				END DESC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'PaymentCollectionStatusEnum'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
								THEN 1
							WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
								THEN 2
							ELSE 3
							END
				END ASC
			,CASE 
				WHEN @SortBy = 'PaymentCollectionStatusEnum'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN ROUND(ISNULL(o.TotalAmt, 0), 0) - ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) <= 0
								THEN 1
							WHEN ROUND(ISNULL(pmt.TotalReceivedAmount, 0), 0) > 0
								THEN 2
							ELSE 3
							END
				END DESC
			,
			-- ModelNo
			CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ModelNo
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pol.ModelNo
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.ModelNo
							END
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ModelNo
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pol.ModelNo
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.ModelNo
							END
				END DESC
			,ISNULL(os.UpdatedDate, os.CreatedDate) DESC OFFSET @Offset ROWS

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

