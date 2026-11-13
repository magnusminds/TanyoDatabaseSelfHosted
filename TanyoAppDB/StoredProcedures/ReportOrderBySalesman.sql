/*
	EXEC [dbo].[ReportOrderBySalesman]
		@TenantId = 9
		,@FromDate = '2026-07-01'
		,@ToDate = '2026-07-22'
		,@Salesman = -1
*/
CREATE PROCEDURE [dbo].[ReportOrderBySalesman]
(
	@TenantId INT
	,@FromDate DATE
	,@ToDate DATE
	,@Salesman BIGINT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'NoofOrders'
	,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ApproveFromDateTime DATETIME
		,@ApproveToDateTime DATETIME

	SET @ApproveFromDateTime = CAST(@FromDate AS DATETIME);
	SET @ApproveToDateTime = DATEADD(MILLISECOND, -3, DATEADD(DAY, 1, CAST(@ToDate AS DATETIME)));

	BEGIN TRY

		;WITH OrderSummary AS (
			SELECT o.SalesmanId
				,COUNT(DISTINCT o.OrderId) AS NoofOrders
				,SUM(o.AmountBeforeGST + o.CGSTAmount + o.SGSTAmount + o.SpecialDiscount) AS ValueofOrders
				,SUM(o.CGSTAmount + o.SGSTAmount) AS GSTAmount
			FROM Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
			AND o.STATUS IN (2,3,4,5) -- Approved to Delivered
			AND o.ApprovedDate >= @ApproveFromDateTime
			AND o.ApprovedDate <= @ApproveToDateTime
			GROUP BY o.SalesmanId
		),CommissionSummary AS
		(
			SELECT o.SalesmanId
				,SUM(CAST(osi.SalesmanCommission AS INT)) AS SalesmanCommission
			FROM Orders o WITH (NOLOCK)
			INNER JOIN OrderSetItems osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
			WHERE o.TenantId = @TenantId
			AND o.STATUS IN (2,3,4,5) -- Approved to Delivered
			AND osi.IsDeleted = 0
			AND o.ApprovedDate >= @ApproveFromDateTime
			AND o.ApprovedDate <= @ApproveToDateTime
			GROUP BY o.SalesmanId
		)
		SELECT aus.FirstName + ' ' + aus.LastName + CASE 
				WHEN aus.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS SalesmanName
			,aus.UserId AS SalesmanId
			,os.NoofOrders
			,CAST(os.ValueofOrders AS NUMERIC(18,2)) AS ValueofOrders
			,CAST(os.GSTAmount AS INT) AS GSTAmount
			,ROUND(ISNULL(cs.SalesmanCommission, 0), 2) AS SalesmanCommission
			,COUNT(1) OVER () AS TotalCount
			,SUM(os.NoofOrders) OVER () AS GrandNoofOrders
			,SUM(CAST(os.ValueofOrders AS NUMERIC(18,2))) OVER () AS GrandValueOfOrders
			,SUM(CAST(os.GSTAmount AS INT)) OVER () AS GrandGSTAmount
			,SUM(ROUND(ISNULL(cs.SalesmanCommission, 0), 2)) OVER () AS GrandSalesmanCommission
			,aus.IsDeleted AS IsSalesmanDeleted
		FROM AspNetUsers aus WITH (NOLOCK)
		INNER JOIN OrderSummary os ON os.SalesmanId = aus.UserId
		LEFT JOIN CommissionSummary cs ON cs.SalesmanId = aus.UserId
		WHERE (
				ISNULL(@Salesman, '') = '-1'
				OR aus.UserId = @Salesman
				)
		ORDER BY CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'ASC'
					THEN aus.FirstName + ' ' + aus.LastName
				END
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'DESC'
					THEN aus.FirstName + ' ' + aus.LastName
				END DESC
			,CASE 
				WHEN @SortBy = 'NoofOrders'
					AND @SortOrder = 'ASC'
					THEN os.NoofOrders
				END
			,CASE 
				WHEN @SortBy = 'NoofOrders'
					AND @SortOrder = 'DESC'
					THEN os.NoofOrders
				END DESC
			,CASE 
				WHEN @SortBy = 'GSTAmount'
					AND @SortOrder = 'ASC'
					THEN os.GSTAmount
				END
			,CASE 
				WHEN @SortBy = 'GSTAmount'
					AND @SortOrder = 'DESC'
					THEN os.GSTAmount
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanCommission'
					AND @SortOrder = 'ASC'
					THEN ISNULL(cs.SalesmanCommission, 0)
				END
			,CASE 
				WHEN @SortBy = 'SalesmanCommission'
					AND @SortOrder = 'DESC'
					THEN ISNULL(cs.SalesmanCommission, 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'ValueofOrders'
					AND @SortOrder = 'ASC'
					THEN os.ValueofOrders
				END
			,CASE 
				WHEN @SortBy = 'ValueofOrders'
					AND @SortOrder = 'DESC'
					THEN os.ValueofOrders
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY
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

