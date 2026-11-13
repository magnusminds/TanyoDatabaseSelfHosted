/*
	EXEC ReportOrderSalesSummary
		@UserId = 4279
		,@TenantId = 2
		,@OrderFromDate = '2026-05-01'
		,@OrderToDate = '2026-05-31'
		,@PageIndex = 1
		,@PageSize = 20
		,@SortBy = 'OrderDate'
		,@SortOrder = 'DESC';
*/
CREATE PROCEDURE [dbo].[ReportOrderSalesSummary]
(
	@UserId BIGINT
	,@TenantId INT
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'OrderDate'
	,@SortOrder VARCHAR(10) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	;WITH FilteredOrders
	AS (
		SELECT O.OrderId
			,O.ApprovedDate AS OrderDate
			,CONCAT (
				C.FirstName
				,CASE 
					WHEN ISNULL(C.LastName, '') = ''
						THEN ''
					ELSE ' ' + C.LastName
					END
				) AS CustomerName
			,O.AmountBeforeGST + O.CGSTAmount + O.SGSTAmount + O.SpecialDiscount AS TotalAmount
		FROM Orders O WITH (NOLOCK)
		INNER JOIN Customers C WITH (NOLOCK) ON O.CustomerId = C.CustomerId
		WHERE O.TenantId = @TenantId
			AND O.STATUS IN (2, 3, 4, 5)
			AND (
				@OrderFromDate IS NULL
				OR CAST(O.ApprovedDate AS DATE) >= @OrderFromDate
				)
			AND (
				@OrderToDate IS NULL
				OR CAST(O.ApprovedDate AS DATE) <= @OrderToDate
				)
		)
	SELECT (
			SELECT FO.OrderDate
				,FO.CustomerName
				,FO.TotalAmount AS TotalAmountWithGST
			FROM FilteredOrders FO
			ORDER BY CASE 
					WHEN @SortBy = 'OrderDate'
						AND @SortOrder = 'ASC'
						THEN FO.OrderDate
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderDate'
						AND @SortOrder = 'DESC'
						THEN FO.OrderDate
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN FO.CustomerName
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN FO.CustomerName
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'ASC'
						THEN FO.TotalAmount
					END ASC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'DESC'
						THEN FO.TotalAmount
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY
			FOR JSON PATH
				,INCLUDE_NULL_VALUES
			) AS OrderDetails
		,(
			SELECT ISNULL(SUM(FO.TotalAmount), 0)
			FROM FilteredOrders FO
			) AS GrandTotal
		,(
			SELECT COUNT(1)
			FROM FilteredOrders
			) AS TotalCount
END

GO

