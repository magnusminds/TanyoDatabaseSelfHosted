CREATE PROCEDURE [dbo].[ReportInquiriesWithoutAddress] (
	@TenantID BIGINT
	,@OrderNo VARCHAR(20) = NULL
	,@SalesmanId BIGINT = NULL
	,@CustomerName VARCHAR(100) = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@InquiryFromDate DATE = NULL
	,@InquiryToDate DATE = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@DeliveryFromDate DATE = NULL
	,@DeliveryToDate DATE = NULL
	,@Status VARCHAR(50) = NULL
	,@LocationID VARCHAR(500) = NULL
	,@toPrice INT = NULL
	,@fromPrice INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'OrderDate'
	,@SortOrder VARCHAR(10) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL
		,@OrderToDateTime DATETIMEOFFSET = NULL
		,@InquiryFromDateTime DATETIME = NULL
		,@InquiryToDateTime DATETIME = NULL
		,@DeliveryFromDateTime DATETIMEOFFSET = NULL
		,@DeliveryToDateTime DATETIMEOFFSET = NULL
	DECLARE @TenantGSTType BIT = 0;

	SELECT @TenantGSTType = GSTType
	FROM Tenants
	WHERE TenantId = @TenantID

	BEGIN TRY
		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'
			,@InquiryFromDateTime = CAST(@InquiryFromDate AS VARCHAR(10)) + ' 00:00:00.001'
			,@InquiryToDateTime = CAST(@InquiryToDate AS VARCHAR(10)) + ' 23:59:59.999'
			,@DeliveryFromDateTime = CAST(@DeliveryFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@DeliveryToDateTime = CAST(@DeliveryToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		SELECT o.OrderId
			,o.OrderNo AS OrderNo
			--,au.UserId  
			,au.FirstName + ' ' + au.LastName + CASE 
				WHEN au.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS SalesmanName
			,c.CustomerId AS CustomerId
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,c.PhoneNumber AS PhoneNumber
			,ROUND(ISNULL(o.TotalAmt, 0), 0) AS TotalAmount
			--,(CASE WHEN @TenantGSTType = 1 THEN ROUND(ISNULL(o.AmountBeforeGST, 0), 0) ELSE ROUND(ISNULL(o.TotalAmt, 0), 0)END) AS TotalAmount  
			,o.Status AS OrderStatus
			,FORMAT(o.CreatedDate, 'dd/MM/yyyy') AS InquiryDate
			,FORMAT(o.ApprovedDate, 'dd/MM/yyyy') AS OrderDate
			,FORMAT(o.DeliveryDate, 'dd/MM/yyyy') AS DeliveryDate
			,ISNULL(la.LocationName, '') AS LocationName
			,COUNT(1) OVER () AS TotalCount
		FROM dbo.Orders o WITH (NOLOCK)
		INNER JOIN dbo.OrderStatus os WITH (NOLOCK) ON o.Status = os.StatusEnumId
			AND os.TenantId = @TenantID
			AND os.Type = 'Order'
		INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
		INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = o.LocationID
			AND la.TenantID = o.TenantId
			AND la.IsDeleted = 0
		WHERE o.TenantId = @TenantID
			AND o.Status <> 9 -- Is Deleted  
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@SalesmanId IS NULL
				OR o.SalesmanId = @SalesmanId
				)
			AND (
				@CustomerName IS NULL
				OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@PhoneNumber IS NULL
				OR (
					c.PhoneNumber LIKE '%' + @PhoneNumber + '%'
					OR c.AltPhoneNumber LIKE '%' + @PhoneNumber + '%'
					)
				)
			AND (
				@InquiryFromDate IS NULL
				OR o.CreatedDate >= @InquiryFromDateTime
				)
			AND (
				@InquiryToDate IS NULL
				OR o.CreatedDate <= @InquiryToDateTime
				)
			AND (
				@OrderFromDate IS NULL
				OR o.ApprovedDate >= @OrderFromDateTime
				)
			AND (
				@OrderToDate IS NULL
				OR o.ApprovedDate <= @OrderToDateTime
				)
			AND (
				@DeliveryFromDate IS NULL
				OR o.DeliveryDate >= @DeliveryFromDateTime
				)
			AND (
				@DeliveryToDate IS NULL
				OR o.DeliveryDate <= @DeliveryToDateTime
				)
			AND (
				@Status IS NULL
				OR o.Status IN (
					SELECT value
					FROM STRING_SPLIT(@Status, ',')
					)
				)
			AND o.Status >= 2
			AND (
				@LocationID IS NULL
				OR o.LocationID IN (
					SELECT value
					FROM STRING_SPLIT(@LocationID, ',')
					)
				)
			AND (
				(
					@FromPrice IS NULL
					OR @FromPrice = - 1
					OR (
						CASE 
							WHEN @TenantGSTType = 1
								THEN ROUND(ISNULL(o.AmountBeforeGST, 0), 0)
							ELSE ROUND(ISNULL(o.TotalAmt, 0), 0)
							END
						) >= @FromPrice
					)
				)
			AND (
				(
					@ToPrice IS NULL
					OR @ToPrice = - 1
					OR (
						CASE 
							WHEN @TenantGSTType = 1
								THEN ROUND(ISNULL(o.AmountBeforeGST, 0), 0)
							ELSE ROUND(ISNULL(o.TotalAmt, 0), 0)
							END
						) <= @ToPrice
					)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN O.OrderNo
				END
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN O.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'ASC'
					THEN (au.FirstName + ' ' + au.LastName)
				END
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'DESC'
					THEN (au.FirstName + ' ' + au.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))
				END
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))
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
				WHEN @SortBy = 'TotalAmount'
					AND @SortOrder = 'ASC'
					THEN ROUND(ISNULL(o.TotalAmt, 0), 0)
				END
			,CASE 
				WHEN @SortBy = 'TotalAmount'
					AND @SortOrder = 'DESC'
					THEN ROUND(ISNULL(o.TotalAmt, 0), 0)
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderStatus'
					AND @SortOrder = 'ASC'
					THEN os.StatusLabel
				END
			,CASE 
				WHEN @SortBy = 'OrderStatus'
					AND @SortOrder = 'DESC'
					THEN os.StatusLabel
				END DESC
			,CASE 
				WHEN @SortBy = 'InquiryDate'
					AND @SortOrder = 'ASC'
					THEN o.CreatedDate
				END
			,CASE 
				WHEN @SortBy = 'InquiryDate'
					AND @SortOrder = 'DESC'
					THEN o.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.DeliveryDate
				END
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.DeliveryDate
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

