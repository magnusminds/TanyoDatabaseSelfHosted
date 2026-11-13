CREATE PROCEDURE [dbo].[ReportUpcomingFollowup] (
	@FromDate DATETIME
	,@ToDate DATETIME
	,@OrderNo VARCHAR(100) = NULL
	,@CustomerId BIGINT = NULL
	,@SalesmanId BIGINT = NULL
	,@TenantId INT = 0
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'FollowUpDate'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		SELECT FO.FollowUpOrdersId
			,O.OrderId
			,O.OrderNo
			,FO.FollowUpDate
			,FO.FollowUpComment
			,ROUND(O.AmountBeforeGST, 0) AS TotalAmount
			,C.FirstName + ' ' + ISNULL(C.LastName, '') AS CustomerName
			,AU.FirstName + ' ' + ISNULL(AU.LastName, '') + CASE 
				WHEN AU.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS SalesmanName
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM FollowUpOrders AS FO WITH (NOLOCK)
		INNER JOIN Orders AS O WITH (NOLOCK) ON FO.OrderId = O.OrderId
			AND o.Status <> 9
		INNER JOIN Customers C WITH (NOLOCK) ON O.CustomerID = C.CustomerId
		LEFT JOIN AspNetUsers AU WITH (NOLOCK) ON O.SalesmanId = AU.UserId
		WHERE O.TenantId = @TenantId
			AND CAST(FO.FollowUpDate AS DATE) BETWEEN CAST(@FromDate AS DATE)
				AND CAST(@ToDate AS DATE)
			AND (
				ISNULL(@OrderNo, '') = ''
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				ISNULL(@CustomerId, 0) = 0
				OR C.CustomerId = @CustomerId
				)
			AND (
				ISNULL(@SalesmanId, 0) = 0
				OR AU.UserId = @SalesmanId
				)
		ORDER BY CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'ASC'
					THEN FO.FollowUpDate
				END ASC
			,CASE 
				WHEN @SortBy = 'FollowUpDate'
					AND @SortOrder = 'DESC'
					THEN FO.FollowUpDate
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

