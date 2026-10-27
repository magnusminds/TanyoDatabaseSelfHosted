CREATE PROCEDURE [dbo].[ListPORawMaterials] 
	 @TenantID BIGINT
	,@VendorId BIGINT = NULL
	,@PONumber VARCHAR(100) = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@Status VARCHAR(100) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy VARCHAR(50) = 'OrderDate'
	,@SortOrder VARCHAR(10) = 'DESC'
	,@PaymentStatus VARCHAR(32) = NULL
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
			;

		WITH PaymentCTE
		AS (
			SELECT p.PORawMaterialId
				,SUM(CASE 
						WHEN p.PaymentStatus = 1
							AND p.IsDeleted = 0
							THEN ISNULL(p.ReceivedAmount, 0)
						ELSE 0
						END) AS AdvanceAmount
			FROM [dbo].[PORawMaterialPayment] p
			GROUP BY p.PORawMaterialId
			)
			,Base
		AS (
			SELECT rm.PORawMaterialId
				,rm.PONumber
				,rm.OrderDate
				,rm.VendorId
				,ISNULL(v.VendorName, '') AS VendorName
				,ISNULL(v.VendorCode, '') AS VendorCode
				,rm.Status
				,ISNULL(rm.TotalAmount, 0) AS TotalAmount
				,ISNULL(p.AdvanceAmount, 0) AS AdvanceAmount
				,ISNULL(rm.TotalAmount, 0) - ISNULL(p.AdvanceAmount, 0) AS RemainingAmount
				,CASE 
					WHEN ISNULL(rm.TotalAmount, 0) <= 0
						THEN 'Unpaid'
					WHEN ISNULL(p.AdvanceAmount, 0) >= ISNULL(rm.TotalAmount, 0)
						THEN 'Paid'
					WHEN ISNULL(p.AdvanceAmount, 0) > 0
						THEN 'Partially Paid'
					ELSE 'Unpaid'
					END AS PaymentStatus
				,CASE rm.Status
					WHEN 1
						THEN 'Pending'
					WHEN 2
						THEN 'Approved'
					WHEN 3
						THEN 'Cancelled'
					WHEN 4
						THEN 'Completed'
					WHEN 5
						THEN 'Material Ready'
					ELSE ''
					END AS StatusName
				,(
					SELECT COUNT(*)
					FROM [dbo].[PORawMaterialItems] i
					WHERE i.PORawMaterialId = rm.PORawMaterialId
					) AS TotalPORawMaterialItems
				,LTRIM(RTRIM(ISNULL(COALESCE(u1.FirstName + ' ' + u1.LastName, u1.UserName, u2.FirstName + ' ' + u2.LastName, u2.UserName), ''))) AS LastModifiedBy
				,COALESCE(rm.UpdatedDate, rm.CreatedDate) AS LastModifiedDate
			FROM [dbo].[PORawMaterials] rm
			LEFT JOIN [dbo].[Vendors] v ON v.VendorId = rm.VendorId
			LEFT JOIN PaymentCTE p ON p.PORawMaterialId = rm.PORawMaterialId
			LEFT JOIN [dbo].[AspNetUsers] u1 ON u1.UserId = rm.UpdatedBy
			LEFT JOIN [dbo].[AspNetUsers] u2 ON u2.UserId = rm.CreatedBy
			WHERE rm.TenantId = @TenantID
				AND rm.IsDeleted = 0
				AND (
					@VendorId IS NULL
					OR rm.VendorId = @VendorId
					)
				AND (
					@PONumber IS NULL
					OR rm.PONumber LIKE '%' + @PONumber + '%'
					)
				AND (
					@OrderFromDate IS NULL
					OR CAST(rm.OrderDate AS DATE) >= @OrderFromDate
					)
				AND (
					@OrderToDate IS NULL
					OR CAST(rm.OrderDate AS DATE) <= @OrderToDate
					)
				AND (
					@Status IS NULL
					OR rm.Status IN (
						SELECT CAST(RTRIM(LTRIM(value)) AS INT)
						FROM STRING_SPLIT(@Status, ',')
						WHERE RTRIM(LTRIM(value)) <> ''
						)
					)
				AND (
					@PaymentStatus IS NULL
					OR (
						CASE 
							WHEN ISNULL(rm.TotalAmount, 0) <= 0
								THEN 'Unpaid'
							WHEN ISNULL(p.AdvanceAmount, 0) >= ISNULL(rm.TotalAmount, 0)
								THEN 'Paid'
							WHEN ISNULL(p.AdvanceAmount, 0) > 0
								THEN 'Partially Paid'
							ELSE 'Unpaid'
							END
						) = @PaymentStatus
					)
			)
			,Ranked
		AS (
			SELECT b.*
				,ROW_NUMBER() OVER (
					ORDER BY CASE 
							WHEN @SortBy = 'PONumber'
								AND UPPER(@SortOrder) = 'ASC'
								THEN b.PONumber
							END ASC
						,CASE 
							WHEN @SortBy = 'PONumber'
								AND UPPER(@SortOrder) = 'DESC'
								THEN b.PONumber
							END DESC
						,CASE 
							WHEN @SortBy = 'VendorName'
								AND UPPER(@SortOrder) = 'ASC'
								THEN b.VendorName
							END ASC
						,CASE 
							WHEN @SortBy = 'VendorName'
								AND UPPER(@SortOrder) = 'DESC'
								THEN b.VendorName
							END DESC
						,CASE 
							WHEN @SortBy = 'Status'
								AND UPPER(@SortOrder) = 'ASC'
								THEN b.Status
							END ASC
						,CASE 
							WHEN @SortBy = 'Status'
								AND UPPER(@SortOrder) = 'DESC'
								THEN b.Status
							END DESC
						,CASE 
							WHEN @SortBy = 'LastModifiedBy'
								AND UPPER(@SortOrder) = 'ASC'
								THEN b.LastModifiedBy
							END ASC
						,CASE 
							WHEN @SortBy = 'LastModifiedBy'
								AND UPPER(@SortOrder) = 'DESC'
								THEN b.LastModifiedBy
							END DESC
						,CASE 
							WHEN @SortBy = 'LastModifiedDate'
								AND UPPER(@SortOrder) = 'ASC'
								THEN b.LastModifiedDate
							END ASC
						,CASE 
							WHEN @SortBy = 'LastModifiedDate'
								AND UPPER(@SortOrder) = 'DESC'
								THEN b.LastModifiedDate
							END DESC
						,CASE 
							WHEN @SortBy = 'OrderDate'
								AND UPPER(@SortOrder) = 'ASC'
								THEN b.OrderDate
							END ASC
						,CASE 
							WHEN @SortBy = 'OrderDate'
								AND UPPER(@SortOrder) = 'DESC'
								THEN b.OrderDate
							END DESC
					) AS RowNum
				,COUNT(*) OVER () AS TotalCount
			FROM Base b
			)
		SELECT PORawMaterialId
			,PONumber
			,OrderDate
			,VendorId
			,VendorName
			,VendorCode
			,Status
			,StatusName
			,TotalAmount
			,AdvanceAmount
			,RemainingAmount
			,PaymentStatus
			,TotalPORawMaterialItems
			,LastModifiedBy
			,LastModifiedDate
			,TotalCount
		FROM Ranked
		WHERE RowNum > ((@PageIndex - 1) * @PageSize)
			AND RowNum <= (@PageIndex * @PageSize)
		ORDER BY RowNum;
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

