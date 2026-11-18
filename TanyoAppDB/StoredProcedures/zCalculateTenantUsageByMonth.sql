-- =============================================
-- Author:		Parshwa Kapadia
-- Create date: 03-Feb-2025
-- Description:	Calculate tenant statistics monthly, rank them based on module usage.
-- =============================================
/*
	--TRUNCATE TABLE TenantUsageStatistics
	EXEC dbo.CalculateTenantUsageByMonth
*/
CREATE   PROC [dbo].[zCalculateTenantUsageByMonth]
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @StartDate DATE, @EndDate DATE

	SET @StartDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()) - 1, 0)
	SET @EndDate = DATEADD(MONTH, DATEDIFF(MONTH, 0, GETDATE()), 0)

	IF EXISTS
	(
		SELECT TOP 1 1
		FROM dbo.TenantUsageStatistics
		WHERE [Month] = FORMAT(@StartDate, 'MMMM')
		AND [Year] = FORMAT(@StartDate, 'yyyy')
	)
	BEGIN
		RETURN
	END

	;WITH cteTenants AS
	(
		SELECT t.TenantId
		FROM dbo.Tenants t WITH (NOLOCK)
		WHERE t.IsDemo = 0
	), cteInquiries AS (
		SELECT t.TenantId
			,COUNT(o.OrderId) AS TotalInquiries
		FROM dbo.Orders o WITH (NOLOCK)
		LEFT JOIN cteTenants t ON t.TenantId = o.TenantId
		WHERE o.CreatedDate >= @StartDate
		AND o.CreatedDate < @EndDate
		GROUP BY t.TenantId
	), cteProducts AS (
		SELECT t.TenantId
			,COUNT(p.ProductId) AS TotalProducts
		FROM dbo.Products p WITH (NOLOCK)
		LEFT JOIN cteTenants t ON t.TenantId = p.TenantId
		WHERE p.CreatedDate >= @StartDate
		AND p.CreatedDate < @EndDate
		GROUP BY t.TenantId
	), cteCustomers AS (
		SELECT t.TenantId
			,COUNT(c.CustomerId) AS TotalCustomers
		FROM dbo.Customers c WITH (NOLOCK)
		LEFT JOIN cteTenants t ON t.TenantId = c.TenantId
		WHERE c.CreatedDate >= @StartDate
		AND c.CreatedDate < @EndDate
		GROUP BY t.TenantId
	), cteLeads AS (
		SELECT t.TenantId
			,COUNT(l.LeadId) AS TotalLeads
		FROM dbo.Leads l WITH (NOLOCK)
		LEFT JOIN cteTenants t ON t.TenantId = l.TenantId
		WHERE l.CreatedDate >= @StartDate
		AND l.CreatedDate < @EndDate
		GROUP BY t.TenantId
	), cteCombined AS (
		SELECT t.TenantId
			,ISNULL(o.TotalInquiries, 0) AS TotalInquiries
			,ISNULL(p.TotalProducts, 0) AS TotalProducts
			,ISNULL(c.TotalCustomers, 0) AS TotalCustomers
			,ISNULL(l.TotalLeads, 0) AS TotalLeads
		FROM cteTenants t
		LEFT JOIN cteInquiries o ON o.TenantId = t.TenantId
		LEFT JOIN cteProducts p ON p.TenantId = t.TenantId
		LEFT JOIN cteCustomers c ON c.TenantId = t.TenantId
		LEFT JOIN cteLeads l ON l.TenantId = t.TenantId
	), cteFiltered AS (
		SELECT *
		FROM cteCombined
		WHERE TotalInquiries > 0
		OR TotalProducts > 0
		OR TotalCustomers > 0
		OR TotalLeads > 0
	)
	INSERT INTO TenantUsageStatistics
	(
		TenantId
		,[Month]
		,[Year]
		,ModuleName
		,TotalCount
		,Position
	)
	SELECT TenantId
		,FORMAT(@StartDate, 'MMMM') AS [Month]
		,FORMAT(@StartDate, 'yyyy') AS [Year]
		,ModuleName
		,Value AS TotalCount
		,DENSE_RANK() OVER (PARTITION BY ModuleName ORDER BY Value DESC) AS RowId
	FROM (
		SELECT TenantId, 'Inquiries' AS ModuleName, TotalInquiries AS Value FROM cteFiltered
		UNION ALL
		SELECT TenantId, 'Products' AS ModuleName, TotalProducts AS Value FROM cteFiltered
		UNION ALL
		SELECT TenantId, 'Customers' AS ModuleName, TotalCustomers AS Value FROM cteFiltered
		UNION ALL
		SELECT TenantId, 'Leads' AS ModuleName, TotalLeads AS Value FROM cteFiltered
	) AS UnpivotedData
	ORDER BY 1, 3

END

GO

