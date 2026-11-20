-- =============================================    
-- Author  : MagnusMinds 
-- Create date : 02-04-2024
-- Description : Report - Customer By Visit And Order 
-- =============================================    
/*    

 EXEC ReportGetCustomerByVisitAndOrder
	@TenantId = 1
	,@FromVisitCount = NULL
	,@ToVisitCount = NULL
	,@FromOrderAmount = NULL
	,@ToOrderAmount = NULL
	,@PageIndex = 1
	,@PageSize = 5000
	,@SortBy = 'QuotationValue'
	,@SortOrder = 'asc'

*/
CREATE   PROCEDURE [dbo].[ReportGetCustomerByVisitAndOrder] (
	@TenantId INT
	,@CustomerId INT = NULL
	,@FromVisitCount INT = NULL
	,@ToVisitCount INT = NULL
	,@FromOrderAmount INT = NULL
	,@ToOrderAmount INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'CustomerName'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @IsBeforeGSTFlag BIT = 0;

		SELECT @IsBeforeGSTFlag = IsBeforeGST
		FROM Tenants
		WHERE TenantId = @TenantId

		DROP TABLE IF EXISTS #CustomerVisitOrder
		CREATE TABLE #CustomerVisitOrder (
			CustomerVisitOrderId BIGINT IDENTITY(1, 1) PRIMARY KEY
			,CustomerId BIGINT NOT NULL
			,CustomerName VARCHAR(100) NOT NULL
			,NumberOfVisits INT NOT NULL
			,NumberOfQuotations INT NOT NULL
			,QuotationValue BIGINT NOT NULL
			)

		IF (@IsBeforeGSTFlag = 1)
		BEGIN
			INSERT INTO #CustomerVisitOrder (
				CustomerId
				,CustomerName
				,NumberOfVisits
				,NumberOfQuotations
				,QuotationValue
				)
			SELECT c.CustomerId
				,c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
				,(
					SELECT COUNT(CustomerId)
					FROM CustomerVisits AS cv
					WHERE c.CustomerId = cv.CustomerId
					) AS NumberOfVisits
				,COUNT(o.CustomerID) AS NumberOfQuotations
				,ROUND(SUM(AmountBeforeGST + IIF(DeliveryAmountCollectionType = 1, ISNULL(DeliveryAmount, 0), 0) - (ISNULL(o.LumpsumDiscount, 0))), 0) AS QuotationValue
			FROM [dbo].[Customers] AS c WITH (NOLOCK)
			INNER JOIN [dbo].[Orders] AS o WITH (NOLOCK) ON c.CustomerId = o.CustomerId
				AND o.TenantId = @TenantId
				AND c.CustomerTypeId = 1
				AND o.STATUS IN (
					2
					,3
					,4
					,5
					)
			WHERE c.IsDeleted = 0
				AND c.TenantId = @TenantId
			GROUP BY c.CustomerId
				,c.FirstName
				,c.LastName

			SELECT CustomerId
				,CustomerName
				,NumberOfVisits
				,NumberOfQuotations
				,QuotationValue
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM #CustomerVisitOrder AS cvo WITH (NOLOCK)
			WHERE (
					@FromVisitCount IS NULL
					OR cvo.NumberOfVisits >= @FromVisitCount
					)
				AND (
					@ToVisitCount IS NULL
					OR cvo.NumberOfVisits <= @ToVisitCount
					)
				AND (
					@FromOrderAmount IS NULL
					OR cvo.QuotationValue >= @FromOrderAmount
					)
				AND (
					@ToOrderAmount IS NULL
					OR cvo.QuotationValue <= @ToOrderAmount
					)
				AND (
					@CustomerId IS NULL
					OR cvo.CustomerId = @CustomerId
					)
			ORDER BY CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN cvo.CustomerName
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN cvo.CustomerName
					END DESC
				,CASE 
					WHEN @SortBy = 'NumberOfVisits'
						AND @SortOrder = 'ASC'
						THEN cvo.NumberOfVisits
					END ASC
				,CASE 
					WHEN @SortBy = 'NumberOfVisits'
						AND @SortOrder = 'DESC'
						THEN cvo.NumberOfVisits
					END DESC
				,CASE 
					WHEN @SortBy = 'NumberOfQuotations'
						AND @SortOrder = 'ASC'
						THEN cvo.NumberOfQuotations
					END ASC
				,CASE 
					WHEN @SortBy = 'NumberOfQuotations'
						AND @SortOrder = 'DESC'
						THEN cvo.NumberOfQuotations
					END DESC
				,CASE 
					WHEN @SortBy = 'QuotationValue'
						AND @SortOrder = 'ASC'
						THEN cvo.QuotationValue
					END ASC
				,CASE 
					WHEN @SortBy = 'QuotationValue'
						AND @SortOrder = 'DESC'
						THEN cvo.QuotationValue
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
		END
		ELSE
		BEGIN

			INSERT INTO #CustomerVisitOrder (
				CustomerId
				,CustomerName
				,NumberOfVisits
				,NumberOfQuotations
				,QuotationValue
				)
			SELECT c.CustomerId
				,c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
				,(
					SELECT COUNT(CustomerId)
					FROM CustomerVisits AS cv
					WHERE c.CustomerId = cv.CustomerId
					) AS NumberOfVisits
				,COUNT(o.CustomerID) AS NumberOfQuotations
				,ROUND(SUM(TotalAmt + IIF(DeliveryAmountCollectionType = 1, ISNULL(DeliveryAmount, 0), 0) - (ISNULL(o.LumpsumDiscount, 0))), 0) AS QuotationValue
			FROM [dbo].[Customers] AS c WITH (NOLOCK)
			INNER JOIN [dbo].[Orders] AS o WITH (NOLOCK) ON c.CustomerId = o.CustomerId
				AND o.TenantId = @TenantId
				AND c.CustomerTypeId = 1
				AND o.STATUS IN (
					2
					,3
					,4
					,5
					)
			WHERE c.IsDeleted = 0
				AND c.TenantId = @TenantId
			GROUP BY c.CustomerId
				,c.FirstName
				,c.LastName

			SELECT CustomerId
				,CustomerName
				,NumberOfVisits
				,NumberOfQuotations
				,QuotationValue
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM #CustomerVisitOrder AS cvo WITH (NOLOCK)
			WHERE (
					@FromVisitCount IS NULL
					OR cvo.NumberOfVisits >= @FromVisitCount
					)
				AND (
					@ToVisitCount IS NULL
					OR cvo.NumberOfVisits <= @ToVisitCount
					)
				AND (
					@FromOrderAmount IS NULL
					OR cvo.QuotationValue >= @FromOrderAmount
					)
				AND (
					@ToOrderAmount IS NULL
					OR cvo.QuotationValue <= @ToOrderAmount
					)
				AND (
					@CustomerId IS NULL
					OR cvo.CustomerId = @CustomerId
					)
			ORDER BY CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN cvo.CustomerName
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN cvo.CustomerName
					END DESC
				,CASE 
					WHEN @SortBy = 'NumberOfVisits'
						AND @SortOrder = 'ASC'
						THEN cvo.NumberOfVisits
					END ASC
				,CASE 
					WHEN @SortBy = 'NumberOfVisits'
						AND @SortOrder = 'DESC'
						THEN cvo.NumberOfVisits
					END DESC
				,CASE 
					WHEN @SortBy = 'NumberOfQuotations'
						AND @SortOrder = 'ASC'
						THEN cvo.NumberOfQuotations
					END ASC
				,CASE 
					WHEN @SortBy = 'NumberOfQuotations'
						AND @SortOrder = 'DESC'
						THEN cvo.NumberOfQuotations
					END DESC
				,CASE 
					WHEN @SortBy = 'QuotationValue'
						AND @SortOrder = 'ASC'
						THEN cvo.QuotationValue
					END ASC
				,CASE 
					WHEN @SortBy = 'QuotationValue'
						AND @SortOrder = 'DESC'
						THEN cvo.QuotationValue
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
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

