/*  
 EXEC [dbo].[Report_RPT_ProfitsByOrder] @TenantId  = 2  
 ,@FromDate = NULL  
 ,@ToDate = NULL  
 ,@OrderNo = NULL  
 ,@ReferredBy = NULL  
 ,@SalesmanId = NULL  
 ,@PageIndex = 1  
 ,@PageSize = 50  
 ,@SortBy = 'OrderNo'  
 ,@SortOrder = 'ASC'  
 ,@OrderStatus = NULL  
 ,@OrderType = NULL  
 ,@DeliveryFromDate = NULL  
 ,@DeliveryToDate = NULL  
 ,@CustomerId = NULL  
*/
CREATE PROCEDURE [dbo].[Report_RPT_ProfitsByOrder] (
	@TenantId INT
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@OrderNo VARCHAR(20) = NULL
	,@ReferredBy INT = NULL
	,@SalesmanId INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'OrderNo'
	,@SortOrder VARCHAR(50) = 'ASC'
	,@OrderStatus INT = NULL
	,@OrderType SMALLINT = NULL
	,@DeliveryFromDate DATE = NULL
	,@DeliveryToDate DATE = NULL
	,@CustomerId BIGINT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @IsBeforeGSTFlag BIT = 0
			,@DeliveryFromDateTime DATETIMEOFFSET = NULL
			,@DeliveryToDateTime DATETIMEOFFSET = NULL
			,@ApprovedFromDateTime DATETIMEOFFSET = NULL
			,@ApprovedToDateTime DATETIMEOFFSET = NULL;

		SELECT @DeliveryFromDateTime = CAST(@DeliveryFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@DeliveryToDateTime = CAST(@DeliveryToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'
			,@ApprovedFromDateTime = CAST(@FromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@ApprovedToDateTime = CAST(@ToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		SELECT @IsBeforeGSTFlag = IsBeforeGST
		FROM Tenants
		WHERE TenantId = @TenantId

		IF (@IsBeforeGSTFlag = 1)
		BEGIN
				;

			WITH ProfitsByOrderDetails
			AS (
				SELECT o.OrderId
					,o.OrderNo AS OrderNo
					,o.CustomerID
					,ISNULL(ci.FirstName + ' ' + ISNULL(ci.LastName, ''), '') AS CustomerName
					,o.SalesmanId AS SalesmanId
					,(
						aus.FirstName + ' ' + aus.LastName + CASE 
							WHEN aus.IsDeleted = 1
								THEN ' (Inactive)'
							ELSE ''
							END
						) AS SalesmanName
					,ISNULL(r.FirstName + ' ' + ISNULL(r.LastName, ''), NULL) AS ReferredName
					,ISNULL(CAST(SUM(osi.AmountBeforeGST) AS INT), 0) AS InvoiceAmt
					,ISNULL(CAST(SUM(osi.CGSTAmount + osi.SGSTAmount) AS INT), 0) AS GSTAmount
					,ISNULL((- 1) * CAST(SUM(ROUND(osi.SalesmanCommission, 0)) AS INT), 0) AS SalesmanCommission
					,ISNULL((- 1) * CAST(SUM(ROUND(osi.InteriorCommission, 0)) AS INT), 0) AS InteriorCommission
					,CAST(SUM(ISNULL(osi.AmountBeforeGST, 0) - ISNULL(osi.InteriorCommission, 0) - ISNULL(osi.SalesmanCommission, 0) - ISNULL(osi.InstantCostPrice * osi.Quantity, 0)) AS INT) AS TotalProfit
					,o.Status AS OrderStatus
					,FORMAT(o.ApprovedDate, 'dd/MM/yyyy') AS ApprovedDate
					,FORMAT(o.DeliveryDate, 'dd/MM/yyyy') AS DeliveryDate
					,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
					,ISNULL(CAST(SUM(osi.InstantCostPrice * osi.Quantity) AS INT), 0) AS TotalCostPriceByOrder
				FROM [dbo].[Orders] AS o WITH (NOLOCK)
				INNER JOIN [dbo].[OrderSetItems] AS osi ON osi.OrderId = o.OrderId
					AND osi.IsDeleted = 0
				INNER JOIN [dbo].[Customers] AS ci WITH (NOLOCK) ON o.CustomerID = ci.CustomerId
				LEFT JOIN [dbo].[Customers] AS r WITH (NOLOCK) ON o.RefferedBy = r.CustomerId
				LEFT JOIN [dbo].[AspNetUsers] AS aus WITH (NOLOCK) ON aus.UserId = o.SalesmanId
				WHERE o.TenantId = @TenantId
					AND (
						(
							(
								@OrderStatus IS NULL
								AND o.Status IN (
									2
									,3
									,4
									,5
									)
								)
							OR @OrderStatus = o.Status
							)
						AND (
							@FromDate IS NULL
							OR o.ApprovedDate >= @ApprovedFromDateTime
							)
						AND (
							@ToDate IS NULL
							OR o.ApprovedDate < DATEADD(DAY, 1, @ApprovedToDateTime)
							)
						)
					AND (
						@OrderNo IS NULL
						OR o.OrderNo LIKE '%' + @OrderNo + '%'
						)
					AND (
						@ReferredBy IS NULL
						OR @ReferredBy = r.CustomerId
						)
					AND (
						@CustomerId IS NULL
						OR O.CustomerID = @CustomerId
						)
					AND (
						@SalesmanId IS NULL
						OR @SalesmanId = o.SalesmanId
						)
					AND (
						@OrderType IS NULL
						OR o.OrderType = @OrderType
						)
					AND (
						@DeliveryFromDate IS NULL
						OR o.DeliveryDate >= @DeliveryFromDateTime
						)
					AND (
						@DeliveryToDate IS NULL
						OR o.DeliveryDate <= @DeliveryToDateTime
						)
				GROUP BY o.OrderId
					,o.OrderNo
					,o.CustomerID
					,ci.FirstName
					,ci.LastName
					,o.Status
					,r.FirstName
					,r.LastName
					,o.ApprovedDate
					,O.DeliveryDate
					,o.SalesmanId
					,aus.FirstName + ' ' + aus.LastName
					,aus.IsDeleted
				)
			SELECT OrderId
				,OrderNo AS OrderNo
				,CustomerID
				,CustomerName
				,SalesmanId
				,SalesmanName
				,ReferredName
				,InvoiceAmt
				,GSTAmount
				,SalesmanCommission
				,InteriorCommission
				,TotalProfit
				,OrderStatus
				,ApprovedDate
				,DeliveryDate
				,TotalCount
				,TotalCostPriceByOrder
				,SUM(InvoiceAmt) OVER () AS TotalInvoiceAmt
				,SUM(GSTAmount) OVER () AS TotalGSTAmount
				,SUM(TotalCostPriceByOrder) OVER () AS TotalCostPrice
				,SUM(SalesmanCommission) OVER () AS TotalSalesmanCommission
				,SUM(InteriorCommission) OVER () AS TotalInteriorCommission
				,SUM(TotalProfit) OVER () AS TotalProfitAllOrders
			FROM ProfitsByOrderDetails
			ORDER BY CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'ASC'
						THEN OrderNo
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'DESC'
						THEN OrderNo
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN CustomerName
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN CustomerName
					END ASC
				,CASE 
					WHEN @SortBy = 'CostPrice'
						AND @SortOrder = 'ASC'
						THEN TotalCostPriceByOrder
					END ASC
				,CASE 
					WHEN @SortBy = 'CostPrice'
						AND @SortOrder = 'DESC'
						THEN TotalCostPriceByOrder
					END DESC
				,CASE 
					WHEN @SortBy = 'InvoiseAmt'
						AND @SortOrder = 'ASC'
						THEN InvoiceAmt
					END ASC
				,CASE 
					WHEN @SortBy = 'InvoiseAmt'
						AND @SortOrder = 'DESC'
						THEN InvoiceAmt
					END DESC
				,CASE 
					WHEN @SortBy = 'GSTAmount'
						AND @SortOrder = 'ASC'
						THEN GSTAmount
					END ASC
				,CASE 
					WHEN @SortBy = 'GSTAmount'
						AND @SortOrder = 'DESC'
						THEN GSTAmount
					END DESC
				,CASE 
					WHEN @SortBy = 'SalesmanCommission'
						AND @SortOrder = 'ASC'
						THEN SalesmanCommission
					END ASC
				,CASE 
					WHEN @SortBy = 'SalesmanCommission'
						AND @SortOrder = 'DESC'
						THEN SalesmanCommission
					END DESC
				,CASE 
					WHEN @SortBy = 'InteriorCommission'
						AND @SortOrder = 'ASC'
						THEN InteriorCommission
					END ASC
				,CASE 
					WHEN @SortBy = 'InteriorCommission'
						AND @SortOrder = 'DESC'
						THEN InteriorCommission
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalProfit'
						AND @SortOrder = 'ASC'
						THEN TotalProfit
					END ASC
				,CASE 
					WHEN @SortBy = 'TotalProfit'
						AND @SortOrder = 'DESC'
						THEN TotalProfit
					END DESC
				,CASE 
					WHEN @SortBy = 'ApproveDate'
						AND @SortOrder = 'ASC'
						THEN ApprovedDate
					END ASC
				,CASE 
					WHEN @SortBy = 'ApproveDate'
						AND @SortOrder = 'DESC'
						THEN ApprovedDate
					END DESC
				,CASE 
					WHEN @SortBy = 'DeliveryDate'
						AND @SortOrder = 'ASC'
						THEN DeliveryDate
					END ASC
				,CASE 
					WHEN @SortBy = 'DeliveryDate'
						AND @SortOrder = 'DESC'
						THEN DeliveryDate
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
		END
		ELSE
		BEGIN
				;

			WITH ProfitsOrderDetails
			AS (
				SELECT o.OrderId
					,o.OrderNo AS OrderNo
					,o.CustomerID
					,ISNULL(ci.FirstName + ' ' + ISNULL(ci.LastName, ''), '') AS CustomerName
					,o.SalesmanId AS SalesmanId
					,(
						aus.FirstName + ' ' + aus.LastName + CASE 
							WHEN aus.IsDeleted = 1
								THEN ' (Inactive)'
							ELSE ''
							END
						) AS SalesmanName
					,ISNULL(r.FirstName + ' ' + ISNULL(r.LastName, ''), NULL) AS ReferredName
					,ISNULL(CAST(SUM(osi.TotalAmount) AS INT), 0) AS InvoiceAmt
					,ISNULL(CAST(SUM(osi.CGSTAmount + osi.SGSTAmount) AS INT), 0) AS GSTAmount
					,ISNULL((- 1) * CAST(SUM(osi.SalesmanCommission) AS INT), 0) AS SalesmanCommission
					,ISNULL((- 1) * CAST(SUM(osi.InteriorCommission) AS INT), 0) AS InteriorCommission
					,CAST(SUM(ISNULL(osi.AmountBeforeGST, 0) - ISNULL(osi.InteriorCommission, 0) - ISNULL(osi.SalesmanCommission, 0) - ISNULL(osi.InstantCostPrice * osi.Quantity, 0)) AS INT) AS TotalProfit
					,o.Status AS OrderStatus
					,FORMAT(o.ApprovedDate, 'dd/MM/yyyy') AS ApprovedDate
					,FORMAT(o.DeliveryDate, 'dd/MM/yyyy') AS DeliveryDate
					,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
					,ISNULL(CAST(SUM(osi.InstantCostPrice * osi.Quantity) AS INT),0) AS TotalCostPriceByOrder
				FROM [dbo].[Orders] AS o WITH (NOLOCK)
				INNER JOIN [dbo].[OrderSetItems] AS osi ON osi.OrderId = o.OrderId
					AND osi.IsDeleted = 0
				INNER JOIN [dbo].[Customers] AS ci WITH (NOLOCK) ON o.CustomerID = ci.CustomerId
				LEFT JOIN [dbo].[Customers] AS r WITH (NOLOCK) ON o.RefferedBy = r.CustomerId
				LEFT JOIN [dbo].[AspNetUsers] AS aus WITH (NOLOCK) ON aus.UserId = o.SalesmanId
				WHERE o.TenantId = @TenantId
					AND (
						(
							(
								@OrderStatus IS NULL
								AND o.Status IN (
									2
									,3
									,4
									,5
									)
								)
							OR @OrderStatus = o.Status
							)
						AND (
							@FromDate IS NULL
							OR o.ApprovedDate >= @ApprovedFromDateTime
							)
						AND (
							@ToDate IS NULL
							OR o.ApprovedDate < DATEADD(DAY, 1, @ApprovedToDateTime)
							)
						)
					AND (
						@OrderNo IS NULL
						OR o.OrderNo LIKE '%' + @OrderNo + '%'
						)
					AND (
						@ReferredBy IS NULL
						OR @ReferredBy = r.CustomerId
						)
					AND (
						@CustomerId IS NULL
						OR O.CustomerID = @CustomerId
						)
					AND (
						@SalesmanId IS NULL
						OR @SalesmanId = o.SalesmanId
						)
					AND (
						@OrderType IS NULL
						OR o.OrderType = @OrderType
						)
					AND (
						@DeliveryFromDate IS NULL
						OR o.DeliveryDate >= @DeliveryFromDateTime
						)
					AND (
						@DeliveryToDate IS NULL
						OR o.DeliveryDate <= @DeliveryToDateTime
						)
				GROUP BY o.OrderId
					,o.OrderNo
					,o.CustomerID
					,ci.FirstName
					,ci.LastName
					,o.Status
					,r.FirstName
					,r.LastName
					,o.ApprovedDate
					,o.DeliveryDate
					,o.SalesmanId
					,aus.FirstName + ' ' + aus.LastName
					,aus.IsDeleted
				)
			SELECT OrderId
				,OrderNo
				,CustomerID
				,CustomerName
				,SalesmanId
				,SalesmanName
				,ReferredName
				,InvoiceAmt
				,GSTAmount
				,SalesmanCommission
				,InteriorCommission
				,TotalProfit
				,OrderStatus
				,ApprovedDate
				,DeliveryDate
				,TotalCount
				,TotalCostPriceByOrder
				,SUM(InvoiceAmt) OVER () AS TotalInvoiceAmt
				,SUM(GSTAmount) OVER () AS TotalGSTAmount
				,SUM(TotalCostPriceByOrder) OVER () AS TotalCostPrice
				,SUM(SalesmanCommission) OVER () AS TotalSalesmanCommission
				,SUM(InteriorCommission) OVER () AS TotalInteriorCommission
				,SUM(TotalProfit) OVER () AS TotalProfitAllOrders
			FROM ProfitsOrderDetails
			ORDER BY CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'ASC'
						THEN OrderNo
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'DESC'
						THEN OrderNo
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN CustomerName
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN CustomerName
					END ASC
				,CASE 
					WHEN @SortBy = 'InvoiseAmt'
						AND @SortOrder = 'ASC'
						THEN InvoiceAmt
					END ASC
				,CASE 
					WHEN @SortBy = 'InvoiseAmt'
						AND @SortOrder = 'DESC'
						THEN InvoiceAmt
					END DESC
				,CASE 
					WHEN @SortBy = 'GSTAmount'
						AND @SortOrder = 'ASC'
						THEN GSTAmount
					END ASC
				,CASE 
					WHEN @SortBy = 'GSTAmount'
						AND @SortOrder = 'DESC'
						THEN GSTAmount
					END DESC
				,CASE 
					WHEN @SortBy = 'SalesmanCommission'
						AND @SortOrder = 'ASC'
						THEN SalesmanCommission
					END DESC
				,CASE 
					WHEN @SortBy = 'SalesmanCommission'
						AND @SortOrder = 'DESC'
						THEN SalesmanCommission
					END ASC
				,CASE 
					WHEN @SortBy = 'InteriorCommission'
						AND @SortOrder = 'ASC'
						THEN InteriorCommission
					END DESC
				,CASE 
					WHEN @SortBy = 'InteriorCommission'
						AND @SortOrder = 'DESC'
						THEN InteriorCommission
					END ASC
				,CASE 
					WHEN @SortBy = 'TotalProfit'
						AND @SortOrder = 'ASC'
						THEN TotalProfit
					END ASC
				,CASE 
					WHEN @SortBy = 'TotalProfit'
						AND @SortOrder = 'DESC'
						THEN TotalProfit
					END DESC
				,CASE 
					WHEN @SortBy = 'ApproveDate'
						AND @SortOrder = 'ASC'
						THEN ApprovedDate
					END ASC
				,CASE 
					WHEN @SortBy = 'ApproveDate'
						AND @SortOrder = 'DESC'
						THEN ApprovedDate
					END DESC
				,CASE 
					WHEN @SortBy = 'DeliveryDate'
						AND @SortOrder = 'ASC'
						THEN DeliveryDate
					END ASC
				,CASE 
					WHEN @SortBy = 'DeliveryDate'
						AND @SortOrder = 'DESC'
						THEN DeliveryDate
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
		END
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog 
			 @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

