CREATE PROCEDURE [dbo].[GetSplitOrderView] (
	@TenantID BIGINT
	,@CustomerId BIGINT = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'OrderNo'
	,@SortOrder VARCHAR(10) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT o.OrderId
		,o.OrderNo
		,au.FirstName + ' ' + au.LastName AS SalesmanName
		,c.CustomerId
		,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS CustomerName
		,ISNULL(c.PhoneNumber, '') AS PhoneNumber
		,ROUND(ISNULL(o.TotalAmt, 0), 0) AS TotalAmount
		,COUNT(1) OVER () AS TotalCount
	FROM dbo.Orders base WITH (NOLOCK)
	INNER JOIN dbo.OrderFamily ofl WITH (NOLOCK) ON ofl.OrderId = base.OrderId
	INNER JOIN dbo.OrderFamily oflf WITH (NOLOCK) ON oflf.CustFamilyId = ofl.CustFamilyId
	INNER JOIN dbo.Orders o WITH (NOLOCK) ON o.OrderId = oflf.OrderId
	INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
	INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId
	WHERE base.TenantId = @TenantID
		AND base.STATUS <> 9
		AND  base.CustomerID = @CustomerId			
		AND (
			@FromDate IS NULL
			OR o.CreatedDate >= @FromDate
			)
		AND (
			@ToDate IS NULL
			OR o.CreatedDate < DATEADD(DAY, 1, @ToDate)
			)
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
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'ASC'
				THEN au.FirstName + ' ' + au.LastName
			END ASC
		,CASE 
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'DESC'
				THEN au.FirstName + ' ' + au.LastName
			END DESC
		,CASE 
			WHEN @SortBy = 'CustomerName'
				AND @SortOrder = 'ASC'
				THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
			END ASC
		,CASE 
			WHEN @SortBy = 'CustomerName'
				AND @SortOrder = 'DESC'
				THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
			END DESC
		,CASE 
			WHEN @SortBy = 'PhoneNumber'
				AND @SortOrder = 'ASC'
				THEN ISNULL(c.PhoneNumber, '')
			END ASC
		,CASE 
			WHEN @SortBy = 'PhoneNumber'
				AND @SortOrder = 'DESC'
				THEN ISNULL(c.PhoneNumber, '')
			END DESC
		,CASE 
			WHEN @SortBy = 'TotalAmount'
				AND @SortOrder = 'ASC'
				THEN ROUND(ISNULL(o.TotalAmt, 0), 0)
			END ASC
		,CASE 
			WHEN @SortBy = 'TotalAmount'
				AND @SortOrder = 'DESC'
				THEN ROUND(ISNULL(o.TotalAmt, 0), 0)
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS
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
END

GO

