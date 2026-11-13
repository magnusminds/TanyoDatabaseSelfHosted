CREATE   PROCEDURE [dbo].[GetOrderSummaryByCustomer] (
	@TenantId INT
	,@CustomerID BIGINT
	,@LeadDate DATE
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'TotalAmount'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SELECT ORD.CreatedDate AS InquiryDate
		,ORD.OrderNo
		,ORD.STATUS
		,ROUND(ORD.TotalAmt, 0) As TotalAmount
		,CONCAT (
			AU.FirstName
			,' '
			,AU.LastName
			) AS SalesmanName
		,COUNT(*) OVER () AS TotalCount
	FROM Orders ORD WITH (NOLOCK)
	INNER JOIN AspNetUsers AU WITH (NOLOCK) ON ORD.SalesmanId = AU.UserId
	WHERE ORD.CustomerID = @CustomerID
		AND CAST(ORD.CreatedDate AS DATE) >= @LeadDate
		AND ORD.TenantId = @TenantId
		AND ORD.STATUS <> 9
	ORDER BY CASE 
			WHEN @SortBy = 'InquiryDate'
				AND @SortOrder = 'DESC'
				THEN ORD.CreatedDate
			END DESC
		,CASE 
			WHEN @SortBy = 'InquiryDate'
				AND @SortOrder = 'ASC'
				THEN ORD.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'OrderNo'
				AND @SortOrder = 'DESC'
				THEN ORD.OrderNo
			END DESC
		,CASE 
			WHEN @SortBy = 'OrderNo'
				AND @SortOrder = 'ASC'
				THEN ORD.OrderNo
			END ASC
		,CASE 
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'DESC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						)
			END DESC
		,CASE 
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'ASC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						)
			END ASC
		,CASE 
			WHEN @SortBy = 'Status'
				AND @SortOrder = 'DESC'
				THEN ORD.[Status]
			END DESC
		,CASE 
			WHEN @SortBy = 'Status'
				AND @SortOrder = 'ASC'
				THEN ORD.[Status]
			END ASC
		,CASE 
			WHEN @SortBy = 'TotalAmount'
				AND @SortOrder = 'DESC'
				THEN ORD.TotalAmt
			END DESC
		,CASE 
			WHEN @SortBy = 'TotalAmount'
				AND @SortOrder = 'ASC'
				THEN ORD.TotalAmt
			END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY
END

GO

