CREATE PROC [dbo].[ReportOrdersValue] (
	@TenantId INT
	,@Fromdate DATE
	,@Todate DATE
	,@LocationId VARCHAR(500) = ''
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'TotalOrder'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @IsBeforeGSTFlag BIT = 0;
		DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL
			,@OrderToDateTime DATETIMEOFFSET = NULL

		SELECT @OrderFromDateTime = CAST(@Fromdate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@Todate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		SELECT @IsBeforeGSTFlag = IsBeforeGST
		FROM Tenants
		WHERE TenantId = @TenantId

		IF (@IsBeforeGSTFlag = 1)
		BEGIN
			SELECT COUNT(DISTINCT OrderId) AS TotalOrders
				,(
					SELECT COUNT(1)
					FROM OrderSetitems AS os WITH (NOLOCK)
					INNER JOIN Orders AS o WITH (NOLOCK) ON o.orderid = os.OrderId
					--OUTER APPLY STRING_SPLIT(@StatusIDs, ',') AS st
					WHERE os.IsDeleted = 0
						AND TenantId = @TenantId
						AND o.STATUS <> 9
						AND o.CreatedDate >= @OrderFromDateTime
						AND o.CreatedDate <= @OrderToDateTime
						AND o.STATUS IN (
							2
							,3
							,4
							,5
							)
						AND (
							ISNULL(@LocationId, '') = ''
							OR o.LocationID IN (
								SELECT value
								FROM STRING_SPLIT(@LocationId, ',')
								)
							)
						AND o.LocationID = o1.LocationID
					) AS TotalItems
				,ROUND(SUM(o1.AmountBeforeGST), 0) AS TotalAmount
				,SUM(ROUND(SUM(o1.AmountBeforeGST), 0)) OVER (PARTITION BY 1) AS GrandTotalAmount
				,SUM(COUNT(DISTINCT o1.OrderId)) OVER (PARTITION BY 1) AS GrandTotalOrders
				,(
					SELECT COUNT(1)
					FROM OrderSetitems AS os WITH (NOLOCK)
					INNER JOIN Orders AS o WITH (NOLOCK) ON o.orderid = os.OrderId
					WHERE os.IsDeleted = 0
						AND TenantId = @TenantId
						AND o.STATUS <> 9
						AND o.CreatedDate >= @OrderFromDateTime
						AND o.CreatedDate <= @OrderToDateTime
						AND o.STATUS IN (
							2
							,3
							,4
							,5
							)
						AND (
							ISNULL(@LocationId, '') = ''
							OR o.LocationID IN (
								SELECT value
								FROM STRING_SPLIT(@LocationId, ',')
								)
							)
					) AS GrandTotalItems
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,LocationID AS LocationId
			FROM Orders AS o1 WITH (NOLOCK)
			--OUTER APPLY STRING_SPLIT(@StatusIDs, ',') AS st
			WHERE TenantId = @TenantId
				AND o1.STATUS <> 9
				AND o1.CreatedDate >= @OrderFromDateTime
				AND o1.CreatedDate <= @OrderToDateTime
				AND o1.STATUS IN (
					2
					,3
					,4
					,5
					)
				AND (
					ISNULL(@LocationId, '') = ''
					OR o1.LocationID IN (
						SELECT value
						FROM STRING_SPLIT(@LocationId, ',')
						)
					)
			GROUP BY LocationID
			ORDER BY CASE 
					WHEN @SortBy = 'TotalOrder'
						AND @SortOrder = 'ASC'
						THEN count(DISTINCT OrderId)
					END
				,CASE 
					WHEN @SortBy = 'TotalOrder'
						AND @SortOrder = 'DESC'
						THEN count(DISTINCT OrderId)
					END DESC
				,CASE 
					WHEN @SortBy = 'OrderSetitems'
						AND @SortOrder = 'ASC'
						THEN (
								SELECT Count(1)
								FROM OrderSetitems AS os
								)
					END
				,CASE 
					WHEN @SortBy = 'OrderSetitems'
						AND @SortOrder = 'DESC'
						THEN (
								SELECT Count(1)
								FROM OrderSetitems AS os
								)
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'ASC'
						THEN Round(Sum(o1.TotalAMt), 0)
					END
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'DESC'
						THEN Round(Sum(o1.TotalAMt), 0)
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
		END
		ELSE
		BEGIN
			SELECT COUNT(DISTINCT OrderId) AS TotalOrders
				,(
					SELECT COUNT(1)
					FROM OrderSetitems AS os WITH (NOLOCK)
					INNER JOIN Orders AS o WITH (NOLOCK) ON o.orderid = os.OrderId
					--OUTER APPLY STRING_SPLIT(@StatusIDs, ',') AS st
					WHERE os.IsDeleted = 0
						AND TenantId = @TenantId
						AND o.STATUS <> 9
						AND o.CreatedDate >= @OrderFromDateTime
						AND o.CreatedDate <= @OrderToDateTime
						AND o.STATUS IN (
							2
							,3
							,4
							,5
							)
						AND (
							ISNULL(@LocationId, '') = ''
							OR o.LocationID IN (
								SELECT value
								FROM STRING_SPLIT(@LocationId, ',')
								)
							)
						AND o.LocationID = o1.LocationID
					) AS TotalItems
				,ROUND(SUM(o1.TotalAmt), 0) AS TotalAmount
				,SUM(ROUND(SUM(o1.TotalAmt), 0)) OVER (PARTITION BY 1) AS GrandTotalAmount
				,SUM(COUNT(DISTINCT o1.OrderId)) OVER (PARTITION BY 1) AS GrandTotalOrders
				,(
					SELECT COUNT(1)
					FROM OrderSetitems AS os WITH (NOLOCK)
					INNER JOIN Orders AS o WITH (NOLOCK) ON o.orderid = os.OrderId
					WHERE os.IsDeleted = 0
						AND TenantId = @TenantId
						AND o.STATUS <> 9
						AND o.CreatedDate >= @OrderFromDateTime
						AND o.CreatedDate <= @OrderToDateTime
						AND o.STATUS IN (
							2
							,3
							,4
							,5
							)
						AND (
							ISNULL(@LocationId, '') = ''
							OR o.LocationID IN (
								SELECT value
								FROM STRING_SPLIT(@LocationId, ',')
								)
							)
					) AS GrandTotalItems
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,LocationID AS LocationId
			FROM Orders AS o1 WITH (NOLOCK)
			--OUTER APPLY STRING_SPLIT(@StatusIDs, ',') AS st
			WHERE TenantId = @TenantId
				AND o1.STATUS <> 9
				AND o1.CreatedDate >= @OrderFromDateTime
				AND o1.CreatedDate <= @OrderToDateTime
				AND o1.STATUS IN (
					2
					,3
					,4
					,5
					)
				AND (
					ISNULL(@LocationId, '') = ''
					OR o1.LocationID IN (
						SELECT value
						FROM STRING_SPLIT(@LocationId, ',')
						)
					)
			GROUP BY LocationID
			ORDER BY CASE 
					WHEN @SortBy = 'TotalOrder'
						AND @SortOrder = 'ASC'
						THEN count(DISTINCT OrderId)
					END
				,CASE 
					WHEN @SortBy = 'TotalOrder'
						AND @SortOrder = 'DESC'
						THEN count(DISTINCT OrderId)
					END DESC
				,CASE 
					WHEN @SortBy = 'OrderSetitems'
						AND @SortOrder = 'ASC'
						THEN (
								SELECT Count(1)
								FROM OrderSetitems AS os
								)
					END
				,CASE 
					WHEN @SortBy = 'OrderSetitems'
						AND @SortOrder = 'DESC'
						THEN (
								SELECT Count(1)
								FROM OrderSetitems AS os
								)
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'ASC'
						THEN Round(Sum(o1.TotalAMt), 0)
					END
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'DESC'
						THEN Round(Sum(o1.TotalAMt), 0)
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
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
END;

GO

