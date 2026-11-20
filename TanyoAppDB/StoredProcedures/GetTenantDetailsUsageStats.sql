CREATE   PROCEDURE [dbo].[GetTenantDetailsUsageStats] (
	@TenantId BIGINT = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'TenantName'
	,@SortOrder VARCHAR(4) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF OBJECT_ID('tempdb..#Leads') IS NOT NULL
		DROP TABLE #Leads;

	IF OBJECT_ID('tempdb..#Customers') IS NOT NULL
		DROP TABLE #Customers;

	IF OBJECT_ID('tempdb..#Products') IS NOT NULL
		DROP TABLE #Products;

	IF OBJECT_ID('tempdb..#ProductImages') IS NOT NULL
		DROP TABLE #ProductImages;

	IF OBJECT_ID('tempdb..#Orders') IS NOT NULL
		DROP TABLE #Orders;

	IF OBJECT_ID('tempdb..#Users') IS NOT NULL
		DROP TABLE #Users;

	IF OBJECT_ID('tempdb..#Inwards') IS NOT NULL
		DROP TABLE #Inwards;

	IF OBJECT_ID('tempdb..#Complaints') IS NOT NULL
		DROP TABLE #Complaints;

	IF OBJECT_ID('tempdb..#Catalogues') IS NOT NULL
		DROP TABLE #Catalogues;

	IF OBJECT_ID('tempdb..#Notifications') IS NOT NULL
		DROP TABLE #Notifications;

	IF OBJECT_ID('tempdb..#Tenants') IS NOT NULL
		DROP TABLE #Tenants;

	DECLARE @StatsDate DATETIME = GETDATE();

	IF(@FromDate IS NOT NULL)
	BEGIN
		DECLARE @FromDateTime DATETIMEOFFSET= CAST(CAST(@FromDate AS VARCHAR(10))+' 00:00:00.0000001 +05:30' AS datetimeoffset)
	END

	IF(@ToDate IS NOT NULL)
	BEGIN
		DECLARE @ToDateTime DATETIMEOFFSET = CAST(CAST(@ToDate AS VARCHAR(10))+' 23:59:59.9999999 +05:30' AS datetimeoffset)
	END

	SELECT t.TenantId
		,t.TenantName
		,t.City
	INTO #Tenants
	FROM Tenants t WITH (NOLOCK)
	WHERE t.IsDemo = 0
		AND t.IsDeleted = 0
		AND (
			@TenantId IS NULL
			OR t.TenantId = @TenantId
			);

	SELECT L.TenantId
		,COUNT(L.LeadId) AS CountOfLeads
	INTO #Leads
	FROM dbo.Leads L WITH (NOLOCK)
	INNER JOIN #Tenants T ON L.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY L.TenantId;

	SELECT C.TenantId
		,COUNT(C.CustomerId) AS CountOfCustomers
	INTO #Customers
	FROM dbo.Customers C WITH (NOLOCK)
	INNER JOIN #Tenants T ON C.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY C.TenantId;

	SELECT PT.TenantId
		,COUNT(PT.ProductId) AS CountOfProducts
	INTO #Products
	FROM dbo.Products PT WITH (NOLOCK)
	INNER JOIN #Tenants T ON PT.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY PT.TenantId;

	SELECT PT.TenantId
		,COUNT(PIM.ProductImageID) AS CountOfProductImages
	INTO #ProductImages
	FROM dbo.ProductImages PIM WITH (NOLOCK)
	INNER JOIN dbo.Products PT WITH (NOLOCK) ON PT.ProductId = PIM.ProductId
	INNER JOIN #Tenants T ON PT.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, PIM.CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, PIM.CreatedDate) <= @ToDateTime
			)
	GROUP BY PT.TenantId;

	SELECT ORD.TenantId
		,COUNT(ORD.OrderId) AS CountOfQuotations
	INTO #Orders
	FROM dbo.Orders ORD WITH (NOLOCK)
	INNER JOIN #Tenants T ON ORD.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY ORD.TenantId;

	SELECT UTM.TenantId
		,COUNT(UTM.UserId) AS CountOfUsers
	INTO #Users
	FROM dbo.UserTenantMapping UTM WITH (NOLOCK)
	INNER JOIN #Tenants T ON UTM.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY UTM.TenantId;

	SELECT IE.TenantId
		,COUNT(IE.InwardId) AS CountOfInwards
	INTO #Inwards
	FROM dbo.InwardEntry IE WITH (NOLOCK)
	INNER JOIN #Tenants T ON IE.TenantId = T.TenantId	
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY IE.TenantId;

	SELECT CS.TenantId
		,COUNT(CS.ComplainId) AS CountOfComplains
	INTO #Complaints
	FROM dbo.Complains CS WITH (NOLOCK)
	INNER JOIN #Tenants T ON CS.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY CS.TenantId;

	SELECT CG.TenantId
		,COUNT(CG.CatalogueId) AS CountOfCatalogues
	INTO #Catalogues
	FROM dbo.Catalogue CG WITH (NOLOCK)
	INNER JOIN #Tenants T ON CG.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY CG.TenantId;

	SELECT N.TenantId
		,COUNT(N.NotificationId) AS CountOfNotifications
	INTO #Notifications
	FROM dbo.Notifications N WITH (NOLOCK)
	INNER JOIN #Tenants T ON N.TenantId = T.TenantId
	WHERE (
			@FromDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) >= @FromDateTime
			)
		AND (
			@ToDateTime IS NULL
			OR CONVERT(DATE, CreatedDate) <= @ToDateTime
			)
	GROUP BY N.TenantId;

	SELECT @StatsDate AS StatsDate
		,t.TenantId
		,t.TenantName
		,t.City
		,ISNULL(l.CountOfLeads, 0) AS CountOfLeads
		,ISNULL(c.CountOfCustomers, 0) AS CountOfCustomers
		,ISNULL(o.CountOfQuotations, 0) AS CountOfQuotations
		,ISNULL(p.CountOfProducts, 0) AS CountOfProducts
		,ISNULL(pi.CountOfProductImages, 0) AS CountOfProductImages
		,ISNULL(u.CountOfUsers, 0) AS CountOfUsers
		,ISNULL(i.CountOfInwards, 0) AS CountOfInwards
		,ISNULL(co.CountOfComplains, 0) AS CountOfComplains
		,ISNULL(cat.CountOfCatalogues, 0) AS CountOfCatalogues
		,ISNULL(n.CountOfNotifications, 0) AS CountOfNotifications
		,COUNT(*) OVER () AS TotalCount
	FROM #Tenants t WITH (NOLOCK)
	LEFT JOIN #Leads l ON l.TenantId = t.TenantId
	LEFT JOIN #Customers c ON c.TenantId = t.TenantId
	LEFT JOIN #Orders o ON o.TenantId = t.TenantId
	LEFT JOIN #Products p ON p.TenantId = t.TenantId
	LEFT JOIN #ProductImages pi ON pi.TenantId = t.TenantId
	LEFT JOIN #Users u ON u.TenantId = t.TenantId
	LEFT JOIN #Inwards i ON i.TenantId = t.TenantId
	LEFT JOIN #Complaints co ON co.TenantId = t.TenantId
	LEFT JOIN #Catalogues cat ON cat.TenantId = t.TenantId
	LEFT JOIN #Notifications n ON n.TenantId = t.TenantId
	WHERE NOT (
			ISNULL(l.CountOfLeads, 0) = 0
			AND ISNULL(c.CountOfCustomers, 0) = 0
			AND ISNULL(o.CountOfQuotations, 0) = 0
			AND ISNULL(p.CountOfProducts, 0) = 0
			AND ISNULL(pi.CountOfProductImages, 0) = 0
			AND ISNULL(u.CountOfUsers, 0) = 0
			AND ISNULL(i.CountOfInwards, 0) = 0
			AND ISNULL(co.CountOfComplains, 0) = 0
			AND ISNULL(cat.CountOfCatalogues, 0) = 0
			AND ISNULL(n.CountOfNotifications, 0) = 0
			)
	ORDER BY CASE 
			WHEN @SortBy = 'TenantName'
				AND @SortOrder = 'ASC'
				THEN TenantName
			END ASC
		,CASE 
			WHEN @SortBy = 'TenantName'
				AND @SortOrder = 'DESC'
				THEN TenantName
			END DESC
		,CASE 
			WHEN @SortBy = 'City'
				AND @SortOrder = 'ASC'
				THEN City
			END ASC
		,CASE 
			WHEN @SortBy = 'City'
				AND @SortOrder = 'DESC'
				THEN City
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfLeads'
				AND @SortOrder = 'ASC'
				THEN CountOfLeads
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfLeads'
				AND @SortOrder = 'DESC'
				THEN CountOfLeads
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfCustomers'
				AND @SortOrder = 'ASC'
				THEN CountOfCustomers
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfCustomers'
				AND @SortOrder = 'DESC'
				THEN CountOfCustomers
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfQuotations'
				AND @SortOrder = 'ASC'
				THEN CountOfQuotations
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfQuotations'
				AND @SortOrder = 'DESC'
				THEN CountOfQuotations
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfProducts'
				AND @SortOrder = 'ASC'
				THEN CountOfProducts
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfProducts'
				AND @SortOrder = 'DESC'
				THEN CountOfProducts
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfProductImages'
				AND @SortOrder = 'ASC'
				THEN CountOfProductImages
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfProductImages'
				AND @SortOrder = 'DESC'
				THEN CountOfProductImages
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfUsers'
				AND @SortOrder = 'ASC'
				THEN CountOfUsers
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfUsers'
				AND @SortOrder = 'DESC'
				THEN CountOfUsers
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfInwards'
				AND @SortOrder = 'ASC'
				THEN CountOfInwards
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfInwards'
				AND @SortOrder = 'DESC'
				THEN CountOfInwards
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfComplains'
				AND @SortOrder = 'ASC'
				THEN CountOfComplains
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfComplains'
				AND @SortOrder = 'DESC'
				THEN CountOfComplains
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfCatalogues'
				AND @SortOrder = 'ASC'
				THEN CountOfCatalogues
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfCatalogues'
				AND @SortOrder = 'DESC'
				THEN CountOfCatalogues
			END DESC
		,CASE 
			WHEN @SortBy = 'CountOfNotifications'
				AND @SortOrder = 'ASC'
				THEN CountOfNotifications
			END ASC
		,CASE 
			WHEN @SortBy = 'CountOfNotifications'
				AND @SortOrder = 'DESC'
				THEN CountOfNotifications
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

