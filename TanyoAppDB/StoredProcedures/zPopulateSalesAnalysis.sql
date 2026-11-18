--EXEC PopulateSalesAnalysis 1
CREATE PROCEDURE [dbo].[zPopulateSalesAnalysis]
	@TenantID INT = 1
WITH ENCRYPTION
AS
	BEGIN
		
		TRUNCATE TABLE SalesAnalysis ;

		INSERT INTO SalesAnalysis ([Date],[TenantID],[TenantName],[SalesmanName],[CustomerName],[ProductName],[Quantity],[Amount],[OrderStatus]) 
		SELECT
			CAST(o.CreatedDate AS DATE) AS ConvertedDate, 
			o.TenantId,
			t.TenantName,
			u.LastName + ' ' + u.FirstName AS SalesmanName,
			ISNULL(c1.LastName,'') + ' ' + c1.FirstName AS CustomerName,
			p.ProductTitle AS ProductName,
			osi.Quantity,
			osi.UnitPrice,
			CASE 
				WHEN o.Status = 0 THEN  'Pending' 
				WHEN o.Status > 0 THEN  'Confirmed' 
			END AS Status  
		FROM Orders o
		INNER JOIN OrderSetItems osi ON osi.OrderId=o.OrderId
		INNER JOIN  SubjectTypes st ON st.SubjectTypeId=osi.SubjectTypeId
		INNER JOIN Products p ON  p.ProductId = osi.SubjectId
		INNER JOIN Customers c1 ON c1.CustomerId = o.CustomerID
		INNER JOIN Tenants t ON t.TenantId=o.TenantId
		INNER JOIN AspNetUsers u ON u.UserId = o.SalesmanId
		WHERE 
		st.SubjectTypeName = 'Products'
		and o.Status NOT IN(6,8,9)
		AND (@TenantID IS NULL OR o.TenantID = @TenantID)
		ORDER BY o.CreatedDate
	END

GO

