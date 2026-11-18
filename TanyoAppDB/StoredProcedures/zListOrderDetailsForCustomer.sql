
/*
	EXEC [dbo].[ListOrderDetailsForCustomer]
		@TenantID = 2		
		,@CustomerId = 1
*/
Create   PROC [dbo].[zListOrderDetailsForCustomer]
(
	@TenantID BIGINT
	,@CustomerId INT = NULL	
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;		

	BEGIN TRY

		SELECT o.OrderId
			,ISNULL(o.LabelId, 0) AS LabelID
			,ISNULL(l.LabelName, '') AS LabelName
			,ISNULL(l.ColorCode, '') AS ColorCode
			,o.OrderNo AS OrderNo
			,au.FirstName + ' ' + au.LastName AS SalesmanName
			,c.CustomerId AS CustomerId
			,ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'') AS CustomerName
			,c.PhoneNumber AS PhoneNumber
			,ROUND(ISNULL(o.AmountBeforeGST, 0), 0) AS ProductAmount
			,ROUND(ISNULL(o.CGSTAmount, 0), 0) + ROUND(ISNULL(o.SGSTAmount, 0), 0) AS TaxAmount
			,ROUND(ISNULL(o.TotalAmt, 0), 0) AS TotalAmount
			,o.Status AS OrderStatus
			,FORMAT(o.CreatedDate,'dd/MM/yyyy') AS InquiryDate
			,FORMAT(o.ApprovedDate,'dd/MM/yyyy') AS OrderDate
			,FORMAT(o.DeliveryDate, 'dd/MM/yyyy') AS DeliveryDate
			,CAST(CASE WHEN sh.OrderId IS NOT NULL THEN 1 ELSE 0 END AS BIT)AS IsStockOnHold
			,ISNULL(la.LocationName, '') AS LocationName
			,COUNT(1) OVER() AS TotalCount
		FROM dbo.Orders o WITH (NOLOCK)
		INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
		INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId
		LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = o.LabelId
			AND l.TenantId = o.TenantId
		LEFT JOIN(SELECT DISTINCT soh.OrderId
					FROM StockOnHold soh WITH (NOLOCK)
					WHERE soh.IsStockOnHold = 1
					AND DATEADD(DAY, CAST(soh.TimePeriod AS INT), CAST(soh.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
				) AS sh ON sh.OrderId = o.OrderId 
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = o.LocationID
			AND la.TenantID = o.TenantId
			AND la.IsDeleted = 0
		WHERE o.TenantId = @TenantID
		AND o.Status <> 9 -- Is Deleted
		AND (@CustomerId IS NULL OR c.CustomerId = @CustomerId)
		
	END TRY
	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
		,@ErrorSeverity = ERROR_SEVERITY()
		,@ErrorState = ERROR_STATE()

		RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
	END CATCH
END

GO

