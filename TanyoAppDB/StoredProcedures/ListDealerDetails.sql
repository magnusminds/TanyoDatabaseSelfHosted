CREATE   PROC [dbo].[ListDealerDetails] (
	@TenantId BIGINT
	,@DealerName VARCHAR(100) = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@LocationID VARCHAR(500) = NULL
	,@IsSubscribe BIT
	,@SalesmanId BIGINT = NULL
	,@Tags BIGINT = NULL
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
		IF OBJECT_ID('tempdb..#TempDealers') IS NOT NULL
		BEGIN
			DROP TABLE #TempDealers
		END

		CREATE TABLE #TempDealers (
			CustomerId BIGINT
			,LabelID BIGINT
			,LabelName VARCHAR(100)
			,ColorCode VARCHAR(10)
			,DealerName VARCHAR(100)
			,EmailAddress VARCHAR(100)
			,PhoneNumber VARCHAR(16)
			,Salesman VARCHAR(100)
			,LastModifiedBy VARCHAR(100)
			,LastModifiedOn VARCHAR(100)
			,LocationName VARCHAR(100)
			,TotalCount BIGINT
			,IsSubscribe BIT
			);

		INSERT INTO #TempDealers (
			CustomerId
			,LabelID
			,LabelName
			,ColorCode
			,DealerName
			,EmailAddress
			,PhoneNumber
			,Salesman
			,LastModifiedBy
			,LastModifiedOn
			,LocationName
			,TotalCount
			,IsSubscribe
			)
		SELECT c.CustomerId
			,CAST(ISNULL(c.LabelId, 0) AS BIGINT) AS LabelID
			,ISNULL(l.LabelName, '') AS LabelName
			,ISNULL(l.ColorCode, '') AS ColorCode
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS DealerName
			,ISNULL(c.EmailId, '') AS EmailAddress
			,c.PhoneNumber
			,sales.FirstName + ' ' + sales.LastName AS Salesman
			,CASE 
				WHEN c.UpdatedBy IS NULL
					THEN (au.FirstName + ' ' + au.LastName)
				ELSE (auu.FirstName + ' ' + auu.LastName)
				END AS LastModifiedBy
			,FORMAT(ISNULL(c.UpdatedDate, c.CreatedDate), 'dd/MM/yyyy hh:mm tt') AS LastModifiedOn
			,ISNULL(la.LocationName, '') AS LocationName
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			,c.IsSubscribe AS IsSubscribe
		FROM dbo.Customers c WITH (NOLOCK)
		--LEFT JOIN dbo.Vendors v WITH (NOLOCK) ON  v.TenantId = @TenantID and v.VendorTenantID = c.CustomerTenantID  
		LEFT JOIN dbo.Vendors v WITH (NOLOCK) ON v.TenantId = @TenantID
			AND v.DealerCustomerId = c.CustomerId
		LEFT JOIN dbo.AspNetUsers sales WITH (NOLOCK) ON sales.UserId = v.SalesmanId
			AND sales.IsDeleted = 0
		LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = c.CreatedBy
		LEFT JOIN dbo.AspNetUsers auu WITH (NOLOCK) ON auu.UserId = c.UpdatedBy
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = c.LocationID
			AND la.TenantID = c.TenantId
			AND la.IsDeleted = 0
		LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = c.LabelId
			AND l.TenantId = c.TenantId
			AND l.IsDeleted = 0
		WHERE c.TenantID = @TenantID
			AND c.CustomerTypeId = 4 -- Dealers    
			AND c.IsDeleted = 0
			AND (
				@Tags IS NULL
				OR c.LabelId = @Tags
				)
			AND (
				@SalesmanId IS NULL
				OR sales.UserId = @SalesmanId
				)
			AND (
				@IsSubscribe IS NULL
				OR c.IsSubscribe = @IsSubscribe
				)
			AND (
				@DealerName IS NULL
				OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @DealerName + '%'
				)
			AND (
				@PhoneNumber IS NULL
				OR (
					c.PhoneNumber LIKE '%' + @PhoneNumber + '%'
					OR c.AltPhoneNumber LIKE '%' + @PhoneNumber + '%'
					)
				)
			AND (
				@FromDate IS NULL
				OR (CAST(ISNULL(c.UpdatedDate, c.CreatedDate) AS DATE) >= @FromDate)
				)
			AND (
				@ToDate IS NULL
				OR (CAST(ISNULL(c.UpdatedDate, c.CreatedDate) AS DATE) <= @ToDate)
				)
			AND (
				@LocationID IS NULL
				OR c.LocationID IN (
					SELECT value
					FROM STRING_SPLIT(@LocationID, ',')
					)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'DealerName'
					AND @SortOrder = 'ASC'
					THEN (c.FirstName + ' ' + c.LastName)
				END
			,CASE 
				WHEN @SortBy = 'DealerName'
					AND @SortOrder = 'DESC'
					THEN (c.FirstName + ' ' + c.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'EmailAddress'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.EmailId, '')
				END
			,CASE 
				WHEN @SortBy = 'EmailAddress'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.EmailId, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.PhoneNumber, '')
				END
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.PhoneNumber, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'ASC'
					THEN (sales.FirstName + ' ' + sales.LastName)
				END
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'DESC'
					THEN (sales.FirstName + ' ' + sales.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedBy'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN c.UpdatedBy IS NULL
								THEN (au.FirstName + ' ' + au.LastName)
							ELSE (auu.FirstName + ' ' + auu.LastName)
							END
				END
			,CASE 
				WHEN @SortBy = 'LastModifiedBy'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN c.UpdatedBy IS NULL
								THEN (au.FirstName + ' ' + au.LastName)
							ELSE (auu.FirstName + ' ' + auu.LastName)
							END
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedOn'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.UpdatedDate, c.CreatedDate)
				END
			,CASE 
				WHEN @SortBy = 'LastModifiedOn'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.UpdatedDate, c.CreatedDate)
				END DESC
			,CASE 
				WHEN @SortBy = 'LocationName'
					AND @SortOrder = 'ASC'
					THEN la.LocationName
				END
			,CASE 
				WHEN @SortBy = 'LocationName'
					AND @SortOrder = 'DESC'
					THEN la.LocationName
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;

		WITH cteVisits
		AS (
			SELECT tc.CustomerId
				,COUNT(cv.CustomerVisitId) AS TotalVisits
			FROM dbo.CustomerVisits cv WITH (NOLOCK)
			INNER JOIN #TempDealers tc ON tc.CustomerId = cv.CustomerId
			GROUP BY tc.CustomerId
			)
			,cteOrders
		AS (
			SELECT tc.CustomerId
				,COUNT(o.OrderId) AS TotalCreatedOrder
			FROM dbo.Orders o WITH (NOLOCK)
			INNER JOIN #TempDealers tc ON tc.CustomerId = o.CustomerID
			WHERE o.TenantId = @TenantID
				AND o.Status <> 9
			GROUP BY tc.CustomerId
			)
			,cteOrdersRefer
		AS (
			SELECT tc.CustomerId
				,COUNT(o.OrderId) AS TotalReferredOrder
			FROM dbo.Orders o WITH (NOLOCK)
			INNER JOIN #TempDealers tc ON tc.CustomerId = o.RefferedBy
			WHERE o.TenantId = @TenantID
				AND o.Status <> 9
			GROUP BY tc.CustomerId
			)
		SELECT c.CustomerId
			,c.DealerName
			,c.EmailAddress
			,c.PhoneNumber
			,c.Salesman
			,c.LastModifiedBy
			,c.LastModifiedOn
			,ISNULL(cv.TotalVisits, 0) AS Visits
			,ISNULL(co.TotalCreatedOrder, 0) AS OrderCreated
			,ISNULL(cor.TotalReferredOrder, 0) AS OrderReferred
			,c.LocationName
			,c.TotalCount
			,c.IsSubscribe
			,c.LabelID
			,c.LabelName
			,c.ColorCode
		FROM #TempDealers c
		LEFT JOIN cteVisits cv ON cv.CustomerId = c.CustomerId
		LEFT JOIN cteOrders co ON co.CustomerId = c.CustomerId
		LEFT JOIN cteOrdersRefer cor ON cor.CustomerId = c.CustomerId

		IF OBJECT_ID('tempdb..#TempDealers') IS NOT NULL
		BEGIN
			DROP TABLE #TempDealers
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

