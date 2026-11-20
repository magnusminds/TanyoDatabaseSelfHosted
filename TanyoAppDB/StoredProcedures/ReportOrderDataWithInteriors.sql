CREATE PROCEDURE [dbo].[ReportOrderDataWithInteriors] (
	@TenantId INT
	,@FromDate DATE
	,@ToDate DATE
	,@OrderNo VARCHAR(20) = NULL
	,@ReferredBy INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'OrderNo'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT o.OrderId
			,o.OrderNo
			,o.CreatedDate AS OrderDate
			,ci.CustomerId
			,ci.FirstName + ' ' + ISNULL(ci.LastName, '') AS CustomerName
			,o.STATUS
			,o.DeliveryDate
			,o.TentativeDeliveryDate
			,o.RefferedBy
			,CASE 
				WHEN r.FirstName IS NOT NULL
					AND r.LastName IS NOT NULL
					THEN r.FirstName + ' ' + r.LastName
				ELSE NULL
				END AS RefferedName
			,CASE 
				WHEN o.STATUS IN (
						2
						,3
						,4
						,5
						,6
						)
					THEN o.ApprovedDate
				ELSE NULL
				END AS ApprovedDate
			,ISNULL(SUM(CAST(ROUND(osi.InteriorCommission, 0) AS INT)), 0) AS Benefits
			,SUM(ISNULL(SUM(CAST(ROUND(osi.InteriorCommission, 0) AS INT)), 0)) OVER (PARTITION BY 1) AS GrandTotalAmount
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM [dbo].[Orders] AS o WITH (NOLOCK)
		INNER JOIN [dbo].[Customers] AS y WITH (NOLOCK) ON o.RefferedBy = y.CustomerId
		INNER JOIN [dbo].[OrderSetItems] AS osi ON osi.OrderId = o.OrderId
		LEFT JOIN [dbo].[Customers] AS ci WITH (NOLOCK) ON o.CustomerID = ci.CustomerId
		LEFT JOIN [dbo].[Customers] AS r WITH (NOLOCK) ON o.RefferedBy = r.CustomerId
		WHERE y.CustomerTypeId = 2 --Interior  
			AND o.TenantId = @TenantId
			AND (
				o.STATUS IN (
					2
					,3
					,5
					)
				AND o.ApprovedDate >= @FromDate
				AND o.ApprovedDate < DATEADD(DAY, 1, @ToDate)
				)
			AND osi.IsDeleted = 0
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@ReferredBy = - 1
				OR @ReferredBy IS NULL
				OR @ReferredBy = o.RefferedBy
				)
		GROUP BY o.OrderId
			,o.OrderNo
			,o.CreatedDate
			,ci.CustomerID
			,ci.FirstName
			,ci.LastName
			,o.STATUS
			,o.DeliveryDate
			,o.TentativeDeliveryDate
			,o.RefferedBy
			,r.FirstName
			,r.LastName
			,o.ApprovedDate
		ORDER BY CASE 
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
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN ci.FirstName
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN ci.FirstName
				END ASC
			,CASE 
				WHEN @SortBy = 'ReferredBy'
					AND @SortOrder = 'DESC'
					THEN o.RefferedBy
				END DESC
			,CASE 
				WHEN @SortBy = 'ReferredBy'
					AND @SortOrder = 'ASC'
					THEN o.RefferedBy
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderStatus'
					AND @SortOrder = 'ASC'
					THEN o.STATUS
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderStatus'
					AND @SortOrder = 'DESC'
					THEN o.STATUS
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN o.CreatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN o.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'Benefits'
					AND @SortOrder = 'ASC'
					THEN SUM(osi.InteriorCommission)
				END ASC
			,CASE 
				WHEN @SortBy = 'Benefits'
					AND @SortOrder = 'DESC'
					THEN SUM(osi.InteriorCommission)
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.DeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.DeliveryDate
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
END;

GO

