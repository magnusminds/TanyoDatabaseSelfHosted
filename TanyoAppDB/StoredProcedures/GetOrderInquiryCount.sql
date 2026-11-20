/*
	EXEC GetOrderInquiryCount
		@TenantId = 2
		,@InquiryOption = 1
		,@LocationID = NULL
*/
CREATE PROC [dbo].[GetOrderInquiryCount] (
	@TenantId INT
	,@InquiryOption BIGINT
	,@LocationID BIGINT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @Year DATE;

		BEGIN
			SET @Year = DATEADD(month, - 12, GETDATE() - 1);
		END

		IF @InquiryOption = 1
		BEGIN
			SELECT COUNT(1) AS InquiryCount
				,FORMAT(o.CreatedDate, 'MMM-yyyy') AS 'LabelName'
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,NULL AS 'LabelId'
				,SUM(COUNT(1)) OVER () AS TotalInquiryCount
			FROM Orders o WITH (NOLOCK)
			INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.CreatedBy = u.UserId
			WHERE o.TenantId = @TenantId
				AND o.STATUS = 0
				AND o.IsArchive = 0
				AND o.CreatedDate >= @Year
				AND (
					@LocationID IS NULL
					OR (
						@LocationID = '-1'
						OR o.LocationID = @LocationID
						)
					)
			GROUP BY FORMAT(o.CreatedDate, 'MMM-yyyy')
				,MONTH(o.CreatedDate)
			ORDER BY MONTH(o.CreatedDate) DESC;
		END
		ELSE IF @InquiryOption = 2
		BEGIN
			SELECT COUNT(1) AS InquiryCount
				,ISNULL(l.LabelName, 'Not Assign Priority') AS 'LabelName'
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,CAST(l.LabelId AS INT) AS 'LabelId'
				,SUM(COUNT(1)) OVER () AS TotalInquiryCount
			FROM Orders o WITH (NOLOCK)
			INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.SalesmanId = u.UserId
			LEFT JOIN Labels l WITH (NOLOCK) ON o.LabelId = l.LabelId
			WHERE o.TenantId = @TenantId
				AND o.STATUS = 0
				AND o.IsArchive = 0
				AND (
					@LocationID IS NULL
					OR (
						@LocationID = '-1'
						OR o.LocationID = @LocationID
						)
					)
			GROUP BY o.LabelId
				,l.LabelName
				,l.LabelId
			ORDER BY InquiryCount DESC;
		END
		ELSE IF @InquiryOption = 3
		BEGIN
			SELECT COUNT(1) AS InquiryCount
				,CONCAT (
					u.FirstName
					,' '
					,u.LastName
					) + CASE 
					WHEN u.IsDeleted = 1
						THEN ' (Inactive)'
					ELSE ''
					END AS 'LabelName'
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				,u.UserId AS 'LabelId'
				,SUM(COUNT(1)) OVER () AS TotalInquiryCount
			FROM Orders o WITH (NOLOCK)
			INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			INNER JOIN AspNetUsers u WITH (NOLOCK) ON o.SalesmanId = u.UserId
			LEFT JOIN Labels l WITH (NOLOCK) ON o.LabelId = l.LabelId
			WHERE o.TenantId = @TenantId
				AND o.STATUS = 0
				AND o.IsArchive = 0
				AND (
					@LocationID IS NULL
					OR (
						@LocationID = '-1'
						OR o.LocationID = @LocationID
						)
					)
			GROUP BY u.FirstName
				,u.LastName
				,u.IsDeleted
				,u.UserId
			ORDER BY InquiryCount DESC;
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

