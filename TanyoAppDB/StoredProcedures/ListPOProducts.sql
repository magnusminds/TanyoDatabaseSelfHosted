/*
EXEC ListPOProducts
 @TenantId = 2
 ,@VendorId = NULL
 ,@PONumber = NULL
 ,@OrderFromDate = NULL
 ,@OrderToDate = NULL
 ,@Status = NULL
 ,@PageIndex = 1
 ,@PageSize = 20
 ,@SortBy = 'Status'
 ,@SortOrder = 'DESC'
 ,@PaymentStatus = NULL
 ,@OrderNo = NULL
 ,@CustomerName = NULL
 ,@TagId = NULL
*/
CREATE PROC [dbo].[ListPOProducts] (
	@TenantId BIGINT
	,@VendorId BIGINT = NULL
	,@PONumber VARCHAR(50) = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@Status VARCHAR(MAX) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy NVARCHAR(50) = 'OrderDate'
	,@SortOrder NVARCHAR(4) = 'DESC'
	,@PaymentStatus VARCHAR(32) = NULL
	,@OrderNo VARCHAR(50) = NULL
	,@CustomerName VARCHAR(200) = NULL
	,@TagId BIGINT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		IF OBJECT_ID('tempdb..#ItemCounts') IS NOT NULL
			DROP TABLE #ItemCounts;

		IF OBJECT_ID('tempdb..#PaymentTotals') IS NOT NULL
			DROP TABLE #PaymentTotals;

		IF OBJECT_ID('tempdb..#POProduct') IS NOT NULL
			DROP TABLE #POProduct;

		SELECT POProductId
			,COUNT(*) AS TotalItems
		INTO #ItemCounts
		FROM POProductItems WITH (NOLOCK)
		GROUP BY POProductId;

		SELECT POProductId
			,SUM(ReceivedAmount) AS TotalPaid
		INTO #PaymentTotals
		FROM POProductPayment WITH (NOLOCK)
		WHERE IsDeleted = 0
			AND PaymentStatus = 1
		GROUP BY POProductId;

		CREATE TABLE #POProduct (
			POProductId BIGINT
			,VendorName VARCHAR(150)
			,PONumber VARCHAR(50)
			,OrderDate DATETIME
			,Status INT
			,TotalPOProductItems INT
			,LastModifiedBy VARCHAR(200)
			,LastModifiedDate [datetimeoffset](7)
			,StatusName VARCHAR(32)
			,TotalAmount DECIMAL(18, 2)
			,AdvanceAmount DECIMAL(18, 2)
			,RemainingAmount DECIMAL(18, 2)
			,PaymentStatus VARCHAR(32)
			,VendorCode VARCHAR(6)
			,ExpectedDeliveryDate DATE
			,OrderNo VARCHAR(32) NULL
			,OrderId BIGINT NULL
			,CustomerName VARCHAR(200) NULL
			,LabelId BIGINT NULL
			,ColorCode VARCHAR(50) NULL
			,LabelName VARCHAR(150) NULL
			);

		INSERT INTO #POProduct (
			POProductId
			,VendorName
			,PONumber
			,OrderDate
			,Status
			,TotalPOProductItems
			,LastModifiedBy
			,LastModifiedDate
			,StatusName
			,TotalAmount
			,AdvanceAmount
			,RemainingAmount
			,PaymentStatus
			,VendorCode
			,ExpectedDeliveryDate
			,OrderNo
			,OrderId
			,CustomerName
			,LabelId
			,ColorCode
			,LabelName
			)
		SELECT p.POProductId
			,v.VendorName
			,p.PONumber
			,p.OrderDate
			,p.Status
			,ISNULL(i.TotalItems, 0)
			,ISNULL(uUpdated.FirstName + ' ' + uUpdated.LastName, uCreated.FirstName + ' ' + uCreated.LastName)
			,ISNULL(p.UpdatedDate, p.CreatedDate)
			,CASE p.Status
				WHEN 1
					THEN 'Pending'
				WHEN 2
					THEN 'Approved'
				WHEN 3
					THEN 'Cancelled'
				WHEN 4
					THEN 'Completed'
				WHEN 5
					THEN 'MaterialReady'
				ELSE ''
				END
			,ROUND(p.TotalAmount, 0)
			,ISNULL(pay.TotalPaid, 0)
			,ROUND(p.TotalAmount - ISNULL(pay.TotalPaid, 0), 0)
			,CASE 
				WHEN ISNULL(pay.TotalPaid, 0) = 0
					THEN 'Unpaid'
				WHEN pay.TotalPaid < p.TotalAmount
					THEN 'Partially Paid'
				ELSE 'Paid'
				END
			,v.VendorCode
			,P.ExpectedDeliveryDate
			,o.OrderNo
			,p.OrderId
			,NULLIF(LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))), '') AS CustomerName
			,p.LabelId
			,lb.ColorCode
			,lb.LabelName
		FROM POProducts p WITH (NOLOCK)
		INNER JOIN Vendors v WITH (NOLOCK) ON p.VendorId = v.VendorId
		LEFT JOIN #ItemCounts i ON i.POProductId = p.POProductId
		LEFT JOIN #PaymentTotals pay ON pay.POProductId = p.POProductId
		LEFT JOIN AspNetUsers uCreated WITH (NOLOCK) ON p.CreatedBy = uCreated.UserId
		LEFT JOIN AspNetUsers uUpdated WITH (NOLOCK) ON p.UpdatedBy = uUpdated.UserId
		LEFT JOIN Orders o WITH (NOLOCK) ON p.OrderId = o.OrderId
		LEFT JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
		LEFT JOIN Labels lb WITH (NOLOCK) ON p.LabelId = lb.LabelId
			AND lb.IsDeleted = 0
		WHERE p.IsDeleted = 0
			AND p.TenantId = @TenantId
			AND (
				@VendorId IS NULL
				OR p.VendorId = @VendorId
				)
			AND (
				@PONumber IS NULL
				OR p.PONumber LIKE '%' + @PONumber + '%'
				)
			AND (
				@OrderFromDate IS NULL
				OR p.OrderDate >= @OrderFromDate
				)
			AND (
				@OrderToDate IS NULL
				OR p.OrderDate <= @OrderToDate
				)
			AND (
				ISNULL(@Status, '') = ''
				OR p.Status IN (
					SELECT TRY_CAST(LTRIM(RTRIM(value)) AS INT)
					FROM STRING_SPLIT(@Status, ',')
					WHERE TRY_CAST(LTRIM(RTRIM(value)) AS INT) IS NOT NULL
					)
				)
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@CustomerName IS NULL
				OR LTRIM(RTRIM(@CustomerName)) = ''
				OR ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') LIKE '%' + @CustomerName + '%'
				)
			AND (
				@TagId IS NULL
				OR (
					@TagId = 0
					AND p.LabelId IS NULL
					)
				OR p.LabelId = @TagId
				)

		SELECT POProductId
			,VendorName
			,PONumber
			,OrderDate
			,Status
			,TotalPOProductItems
			,LastModifiedBy
			,LastModifiedDate
			,StatusName
			,TotalAmount
			,AdvanceAmount
			,RemainingAmount
			,PaymentStatus
			,VendorCode
			,ExpectedDeliveryDate
			,OrderNo
			,OrderId
			,CustomerName
			,LabelId
			,ColorCode
			,LabelName
			,COUNT(*) OVER () AS TotalCount
		FROM #POProduct
		WHERE (
				@PaymentStatus IS NULL
				OR PaymentStatus = @PaymentStatus
				)
		ORDER BY CASE 
				WHEN @SortBy = 'VendorName'
					AND @SortOrder = 'ASC'
					THEN VendorName
				END ASC
			,CASE 
				WHEN @SortBy = 'VendorName'
					AND @SortOrder = 'DESC'
					THEN VendorName
				END DESC
			,CASE 
				WHEN @SortBy = 'PONumber'
					AND @SortOrder = 'ASC'
					THEN PONumber
				END ASC
			,CASE 
				WHEN @SortBy = 'PONumber'
					AND @SortOrder = 'DESC'
					THEN PONumber
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN OrderDate
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN OrderDate
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedBy'
					AND @SortOrder = 'ASC'
					THEN LastModifiedBy
				END ASC
			,CASE 
				WHEN @SortBy = 'LastModifiedBy'
					AND @SortOrder = 'DESC'
					THEN LastModifiedBy
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedDate'
					AND @SortOrder = 'ASC'
					THEN LastModifiedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'LastModifiedDate'
					AND @SortOrder = 'DESC'
					THEN LastModifiedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'ASC'
					THEN Status
				END ASC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'DESC'
					THEN Status
				END DESC
			,CASE 
				WHEN @SortBy = 'VendorCode'
					AND @SortOrder = 'ASC'
					THEN VendorCode
				END ASC
			,CASE 
				WHEN @SortBy = 'VendorCode'
					AND @SortOrder = 'DESC'
					THEN VendorCode
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN OrderNo
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;;
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

