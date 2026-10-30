/*
	EXEC RPT_GetOrderPaymentDue
		@TenantId = 2
		,@ApprovedFromDate = '2022-01-01'
		,@ApprovedToDate = '2027-01-01'
		,@OrderStatus = NULL
		,@PageNumber = 1
		,@PageSize = 50
		,@SortBy = 'ApprovedDate'
		,@SortOrder = 'DESC'
		,@UserId = NULL
		
*/
CREATE OR ALTER PROCEDURE [dbo].[RPT_GetOrderPaymentDue] (
	 @TenantId INT
	,@ApprovedFromDate DATE
	,@ApprovedToDate DATE
	,@OrderStatus VARCHAR(200) = NULL
	--,@PaymentDueStatus TINYINT = NULL
	,@PageNumber INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'ApprovedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	,@UserId INT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @ApprovedFromDateTime DATETIMEOFFSET = NULL
		   ,@ApprovedToDateTime DATETIMEOFFSET = NULL
		   ,@HasSuperAccess BIT = 0

	SELECT @ApprovedFromDateTime = CAST(@ApprovedFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
		  ,@ApprovedToDateTime = CAST(@ApprovedToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

	IF @UserId IS NOT NULL AND @UserId > 0
	BEGIN
		IF EXISTS (
			SELECT 1
			FROM dbo.AspNetUsers u WITH (NOLOCK)
			INNER JOIN dbo.AspNetUserRoles ur WITH (NOLOCK) ON ur.UserId = u.Id
			INNER JOIN dbo.AspNetRoleClaims rc WITH (NOLOCK) ON rc.RoleId = ur.RoleId
			WHERE u.UserId = @UserId
				AND u.IsDeleted = 0
				AND rc.ClaimValue IN (
					'Permissions.App.Order.SuperAccess'
					,'Permissions.General.Order.SuperAccess'
				)
		)
			SET @HasSuperAccess = 1;
	END
	ELSE
	BEGIN
		SET @HasSuperAccess = 1;
	END

	BEGIN TRY
		SELECT o.OrderId
			,o.OrderNo
			,o.CustomerID AS CustomerId
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,c.PhoneNumber
			,o.ApprovedDate
			,CASE 
				WHEN o.Status = 5
					THEN o.DeliveryDate
				ELSE o.TentativeDeliveryDate
				END AS DeliveryDate
			,o.Status AS OrderStatus
			,os.Status AS OrderStatusName
			,o.TotalAmt AS InvoiceAmount
			,ISNULL(o.AdvanceAmount, 0) AS PaymentReceived
			,(o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) AS PaymentDueAmount
			,CASE 
				-- 1. Check if completely Paid first
				WHEN (o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) = 0
					THEN 1
						-- 2. Check if No Advance has been paid (Fully Due) next
				WHEN ISNULL(o.AdvanceAmount, 0) = 0
					THEN 3
						-- 3. Anything else greater than 0 must be a partial payment
				WHEN (o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) > 0
					THEN 2
				END AS PaymentCollectionStatus
			,CASE 
				-- 1. Check if completely Paid first
				WHEN (o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) = 0
					THEN 'Paid'
						-- 2. Check if No Advance has been paid (Fully Due) next
				WHEN ISNULL(o.AdvanceAmount, 0) = 0
					THEN 'Unpaid'
						-- 3. Anything else greater than 0 must be a partial payment
				WHEN (o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) > 0
					THEN 'Partial Paid'
				END AS PaymentCollectionStatusName
			,COUNT(1) OVER () AS TotalOrdersCount
			,SUM(o.TotalAmt) OVER () AS TotalInvoiceAmount
			,SUM(ISNULL(o.AdvanceAmount, 0)) OVER () AS TotalPaymentReceivedAmount
			,SUM(o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) OVER () AS TotalPaymentDueAmount
		FROM Orders o WITH (NOLOCK)
		INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
		INNER JOIN OrderStatus os WITH (NOLOCK) ON os.StatusEnumId = o.Status
			AND os.TenantId = @TenantId
			AND os.Type = 'Order'
		WHERE o.TenantId = @TenantId
			AND (
				@OrderStatus IS NULL
				OR o.Status IN (
					SELECT value
					FROM string_split(@OrderStatus, ',')
					)
				)
			AND o.ApprovedDate BETWEEN @ApprovedFromDateTime
				AND @ApprovedToDateTime
			AND o.Status <> 9
			AND (o.TotalAmt - ISNULL(o.AdvanceAmount, 0)) > 0
			AND (
				@HasSuperAccess = 1
				OR o.SalesmanId = @UserId
				OR (o.SalesmanId IS NULL AND o.CreatedBy = @UserId)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.DeliveryDate
				END ASC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.DeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderStatus'
					AND @SortOrder = 'ASC'
					THEN o.Status
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderStatus'
					AND @SortOrder = 'DESC'
					THEN o.Status
				END DESC
			,CASE 
				WHEN @SortBy = 'InvoiceAmount'
					AND @SortOrder = 'ASC'
					THEN o.TotalAmt
				END ASC
			,CASE 
				WHEN @SortBy = 'InvoiceAmount'
					AND @SortOrder = 'DESC'
					THEN o.TotalAmt
				END DESC
			,CASE 
				WHEN @SortBy = 'PaymentDueAmount'
					AND @SortOrder = 'ASC'
					THEN (o.TotalAmt - ISNULL(o.AdvanceAmount, 0))
				END ASC
			,CASE 
				WHEN @SortBy = 'PaymentDueAmount'
					AND @SortOrder = 'DESC'
					THEN (o.TotalAmt - ISNULL(o.AdvanceAmount, 0))
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
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN o.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN o.OrderNo
				END DESC OFFSET(@PageNumber - 1) * @PageSize ROWS

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
