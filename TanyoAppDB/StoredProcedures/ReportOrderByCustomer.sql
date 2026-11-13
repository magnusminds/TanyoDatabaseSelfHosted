/*
	EXEC [dbo].[ReportOrderByCustomer]
		@TenantId = 9
		,@FromDate = '2026-07-01'
		,@ToDate = '2026-07-22'
		,@CustomerID = -1
*/
CREATE PROCEDURE [dbo].[ReportOrderByCustomer] (
	@TenantId INT
	,@FromDate DATE
	,@ToDate DATE
	,@CustomerID BIGINT = NULL
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
	SET @ApproveToDateTime = DATEADD(MILLISECOND, - 3, DATEADD(DAY, 1, CAST(@ToDate AS DATETIME)));

	BEGIN TRY

		;WITH OrderSummary
		AS (
			SELECT o.CustomerID
				,COUNT(DISTINCT o.OrderId) AS NoofOrders
				,SUM(o.AmountBeforeGST + o.SpecialDiscount) AS ValueofOrders
				,SUM(o.CGSTAmount + o.SGSTAmount) AS GSTAmount
			FROM Orders o WITH (NOLOCK)
			WHERE o.TenantId = @TenantId
				AND o.Status IN (
					2
					,3
					,4
					,5
					) -- Approved to Delivered
				AND o.ApprovedDate >= @ApproveFromDateTime
				AND o.ApprovedDate <= @ApproveToDateTime
			GROUP BY o.CustomerID
			)
		SELECT c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,c.CustomerID AS CustomerId
			,os.NoofOrders
			,CAST(os.ValueofOrders AS NUMERIC(18, 2)) AS ValueofOrders
			,CAST(os.GSTAmount AS INT) AS GSTAmount
			,COUNT(1) OVER () AS TotalCount
			,SUM(os.NoofOrders) OVER () AS GrandNoofOrders
			,SUM(CAST(os.ValueofOrders AS NUMERIC(18, 2))) OVER () AS GrandValueOfOrders
			,SUM(CAST(os.GSTAmount AS INT)) OVER () AS GrandGSTAmount
		FROM Customers c WITH (NOLOCK)
		INNER JOIN OrderSummary os ON os.CustomerID = c.CustomerID
		WHERE (
				ISNULL(@CustomerID, '') = '-1'
				OR c.CustomerID = @CustomerID
				)
		ORDER BY CASE 
				WHEN @SortBy = 'Customer'
					AND @SortOrder = 'ASC'
					THEN c.FirstName + ' ' + ISNULL(c.LastName, '')
				END
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
		DECLARE @ObjectName VARCHAR(500)
		DECLARE @ResultMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ResultMessage = ERROR_MESSAGE()

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ResultMessage = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ResultMessage
	END CATCH
END

GO

