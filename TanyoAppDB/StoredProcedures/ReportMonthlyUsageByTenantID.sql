/*
	EXEC [dbo].[ReportMonthlyUsageByTenantID]
		@TenantID = 2
*/
CREATE PROC ReportMonthlyUsageByTenantID
(
	@TenantID BIGINT
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;


	BEGIN TRY
	SELECT MONTH(o.CreatedDate) AS MonthNo
		,YEAR(o.CreatedDate) AS YearNo
		,DATENAME(MONTH, DATEADD(MONTH, CAST(MONTH(o.CreatedDate) AS INT), -1 )) + '-' + CAST(YEAR(o.CreatedDate) AS VARCHAR(4)) AS MonthYear
		,COUNT(DISTINCT o.OrderId) AS TotalOrders
		,COUNT(osi.OrderSetItemId) AS TotalOrderItems
		,COUNT(osi.OrderSetItemId) * MAX(tc.PricePerSKU) AS TotalPricePerSKU
	FROM OrderSetItems osi WITH (NOLOCK)
	INNER JOIN Orders o WITH (NOLOCK) ON o.OrderId = osi.OrderId
	INNER JOIN TenantContracts tc WITH (NOLOCK) ON tc.TenantID = o.TenantId
	WHERE o.TenantId = @TenantID
	GROUP BY MONTH(o.CreatedDate), YEAR(o.CreatedDate), DATENAME(MONTH, DATEADD(MONTH, CAST(MONTH(o.CreatedDate) AS INT), -1 )) + '-' + CAST(YEAR(o.CreatedDate) AS VARCHAR(4))
	ORDER BY 2 DESC, 1 DESC

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

