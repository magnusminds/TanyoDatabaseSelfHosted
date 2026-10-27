/*
	EXEC [dbo].[ListCustomerDetails]
		@TenantID = 1
		,@CustomerName = NULL
		,@PhoneNumber = NULL
		,@FromDate = NULL
		,@ToDate = NULL
		,@RefferedBy = NULL
		,@SalesmanID = NULL
		,@Tags = NULL
		,@LocationID = NULL
		,@PageIndex = 1
		,@PageSize = 25
		,@SortBy = 'LastModifiedOn'
		,@SortOrder = 'DESC'
*/
CREATE PROC [dbo].[ListCustomerDetails]
(
	@TenantID BIGINT
	,@CustomerName VARCHAR(100) = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@RefferedBy BIGINT = NULL
	,@SalesmanID BIGINT = NULL
	,@Tags BIGINT = NULL
	,@LocationID VARCHAR(500) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'LastModifiedOn'
	,@SortOrder VARCHAR(10) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY

		IF OBJECT_ID('tempdb..#TempCustomers') IS NOT NULL
		BEGIN
			DROP TABLE #TempCustomers
		END
	
		CREATE TABLE #TempCustomers
		(
			CustomerId BIGINT
			,LabelID BIGINT
			,LabelName VARCHAR(100)
			,ColorCode VARCHAR(10)
			,CustomerName VARCHAR(100)
			,RefferedBy VARCHAR(100)
			,EmailAddress VARCHAR(100)
			,PhoneNumber VARCHAR(16)
			,Salesman VARCHAR(100)
			,LastModifiedBy VARCHAR(100)
			,LastModifiedOn VARCHAR(100)
			,LocationName VARCHAR(100)
			,TotalCount BIGINT
		);

		INSERT INTO #TempCustomers
		(
			CustomerId
			,LabelID
			,LabelName
			,ColorCode
			,CustomerName
			,RefferedBy
			,EmailAddress
			,PhoneNumber
			,Salesman
			,LastModifiedBy
			,LastModifiedOn
			,LocationName
			,TotalCount
		)
		SELECT c.CustomerId
			,ISNULL(c.LabelId, 0) AS LabelID
			,ISNULL(l.LabelName, '') AS LabelName
			,ISNULL(l.ColorCode, '') AS ColorCode
			,ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'') AS CustomerName
			,ISNULL(ref.FirstName + ' ' + ref.LastName, '') AS RefferedBy
			,ISNULL(c.EmailId, '') AS EmailAddress
			,c.PhoneNumber
			,au.FirstName + ' ' + au.LastName AS Salesman
			,CASE WHEN c.UpdatedBy IS NULL
				THEN (au.FirstName + ' ' + au.LastName)
				ELSE (auu.FirstName + ' ' + auu.LastName)
			END AS LastModifiedBy
			,FORMAT(ISNULL(c.UpdatedDate, c.CreatedDate), 'dd/MM/yyyy hh:mm tt') AS LastModifiedOn
			,ISNULL(la.LocationName, '') AS LocationName
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM dbo.Customers c WITH (NOLOCK)
		INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = c.CreatedBy
		LEFT JOIN dbo.AspNetUsers auu WITH (NOLOCK) ON auu.UserId = c.UpdatedBy
		LEFT JOIN dbo.Customers ref WITH (NOLOCK) ON ref.CustomerId = c.RefferedBy
		LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = c.LabelId
			 AND l.TenantId = c.TenantId
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = c.LocationID
			AND la.TenantID = c.TenantId
			AND la.IsDeleted = 0
		WHERE c.TenantId = @TenantID
		AND c.CustomerTypeId = 1 -- Customers
		AND c.IsDeleted = 0
		AND (@CustomerName IS NULL OR (ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'')) LIKE '%' + @CustomerName + '%')
		AND (@PhoneNumber IS NULL OR (c.PhoneNumber LIKE '%' + @PhoneNumber + '%' OR c.AltPhoneNumber LIKE '%' + @PhoneNumber + '%'))
		AND (@FromDate IS NULL OR (CAST(ISNULL(c.UpdatedDate, c.CreatedDate) AS DATE) >= @FromDate))
		AND (@ToDate IS NULL OR (CAST(ISNULL(c.UpdatedDate, c.CreatedDate) AS DATE) <= @ToDate))
		AND (@RefferedBy IS NULL OR ref.CustomerId = @RefferedBy)
		AND (@SalesmanID IS NULL OR c.CreatedBy = @SalesmanID)
		AND (@Tags IS NULL OR c.LabelId = @Tags)
		AND (@LocationID IS NULL OR c.LocationID IN (SELECT value FROM STRING_SPLIT(@LocationID, ',')))
		ORDER BY CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN (c.FirstName + ' ' + c.LastName) END
			,CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN (c.FirstName + ' ' + c.LastName) END DESC
			,CASE WHEN @SortBy = 'RefferedBy' AND @SortOrder = 'ASC' THEN ISNULL(ref.FirstName + ' ' + ref.LastName, '') END
			,CASE WHEN @SortBy = 'RefferedBy' AND @SortOrder = 'DESC' THEN ISNULL(ref.FirstName + ' ' + ref.LastName, '') END DESC
			,CASE WHEN @SortBy = 'EmailAddress' AND @SortOrder = 'ASC' THEN ISNULL(c.EmailId, '') END
			,CASE WHEN @SortBy = 'EmailAddress' AND @SortOrder = 'DESC' THEN ISNULL(c.EmailId, '') END DESC
			,CASE WHEN @SortBy = 'PhoneNumber' AND @SortOrder = 'ASC' THEN ISNULL(c.PhoneNumber, '') END
			,CASE WHEN @SortBy = 'PhoneNumber' AND @SortOrder = 'DESC' THEN ISNULL(c.PhoneNumber, '') END DESC
			,CASE WHEN @SortBy = 'Salesman' AND @SortOrder = 'ASC' THEN (au.FirstName + ' ' + au.LastName) END
			,CASE WHEN @SortBy = 'Salesman' AND @SortOrder = 'DESC' THEN (au.FirstName + ' ' + au.LastName) END DESC
			,CASE WHEN @SortBy = 'LastModifiedBy' AND @SortOrder = 'ASC' THEN CASE WHEN c.UpdatedBy IS NULL THEN (au.FirstName + ' ' + au.LastName) ELSE (auu.FirstName + ' ' + auu.LastName)END END
			,CASE WHEN @SortBy = 'LastModifiedBy' AND @SortOrder = 'DESC' THEN CASE WHEN c.UpdatedBy IS NULL THEN (au.FirstName + ' ' + au.LastName) ELSE (auu.FirstName + ' ' + auu.LastName) END END DESC
			,CASE WHEN @SortBy = 'LastModifiedOn' AND @SortOrder = 'ASC' THEN ISNULL(c.UpdatedDate, c.CreatedDate) END
			,CASE WHEN @SortBy = 'LastModifiedOn' AND @SortOrder = 'DESC' THEN ISNULL(c.UpdatedDate, c.CreatedDate) END DESC
			,CASE WHEN @SortBy = 'LocationName' AND @SortOrder = 'ASC' THEN la.LocationName END
			,CASE WHEN @SortBy = 'LocationName' AND @SortOrder = 'DESC' THEN la.LocationName END DESC
		OFFSET(@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY

		;WITH cteVisits AS (
			SELECT tc.CustomerId
				,COUNT(cv.CustomerVisitId) AS TotalVisits
			FROM dbo.CustomerVisits cv WITH (NOLOCK)
			INNER JOIN #TempCustomers tc ON tc.CustomerId = cv.CustomerId
			GROUP BY tc.CustomerId
		), cteOrders AS (
			SELECT tc.CustomerId
				,COUNT(o.OrderId) AS TotalOrders
			FROM dbo.Orders o WITH (NOLOCK)
			INNER JOIN #TempCustomers tc ON tc.CustomerId = o.CustomerID
			WHERE o.TenantId = @TenantID
			AND o.Status <> 9
			GROUP BY tc.CustomerId
		)
		SELECT c.CustomerId
			,c.LabelID
			,c.LabelName
			,c.ColorCode
			,c.CustomerName
			,c.RefferedBy
			,c.EmailAddress
			,c.PhoneNumber
			,c.Salesman
			,c.LastModifiedBy
			,c.LastModifiedOn
			,ISNULL(cv.TotalVisits, 0) AS Visits
			,ISNULL(co.TotalOrders, 0) AS Orders
			,c.LocationName
			,c.TotalCount
		FROM #TempCustomers c
		LEFT JOIN cteVisits cv ON cv.CustomerId = c.CustomerId
		LEFT JOIN cteOrders co ON co.CustomerId = c.CustomerId

		IF OBJECT_ID('tempdb..#TempCustomers') IS NOT NULL
		BEGIN
			DROP TABLE #TempCustomers
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
END

GO

