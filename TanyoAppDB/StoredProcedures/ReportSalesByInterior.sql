--- =============================================        
--Author  : MagnusMinds -- Create date : 25-09-2024      
--Description : ReportSalesByInterior    
-- =============================================    
/*    
  EXEC ReportSalesByInterior   
   @TenantId = 2
  ,@ReferredBy = null     
  ,@PageSize = 50    
  ,@PageIndex = 1    
  ,@SortBy = 'NoOfOrders'    
  ,@SortOrder = 'DESC' 

*/
CREATE   PROC [dbo].[ReportSalesByInterior] (
	@TenantId INT
	,@ReferredBy int = NULL  
	,@PageSize INT = 50
	,@PageIndex INT = 1
	,@SortBy VARCHAR(50) = 'NoOfOrders'
	,@SortOrder VARCHAR(50) = 'DESC'
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
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

		IF (@IsBeforeGSTFlag = 1)
		BEGIN
			SELECT c.CustomerId AS InteriorId
				,(C.FirstName + ' ' + ISNULL(C.LastName, '')) AS InteriorName
				,C.PhoneNumber AS InteriorNumber
				,ISNULL(cv.NoOfVisits, 0) AS NoOfVisits
				,ISNULL(oi.NoOfOpenInquiries, 0) AS NoOfOpenInquiries
				,CAST(ISNULL(ROUND(oi.AmountOfOpenInquiries, 0), 0) AS DECIMAL) AS AmountOfOpenInquiries
				,ISNULL(o.NoOfOrders, 0) AS NoOfOrders
				,CAST(ISNULL(ROUND(o.AmountOfOrders, 0), 0) AS DECIMAL) AS AmountOfOrders
				,ISNULL(Round(CAST(o.Benefits AS INT),0),0) AS Benefits				
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM Customers c WITH (NOLOCK)
			INNER JOIN
			(
				SELECT o.RefferedBy
					--,ISNULL(SUM(osi.InteriorCommission),0) AS Benefits
					,ISNULL((-1)*CAST(SUM(ROUND(osi.InteriorCommission, 0)) AS INT), 0) AS Benefits
					,COUNT(DISTINCT o.OrderId) AS NoOfOrders
					,SUM(ROUND(osi.AmountBeforeGST, 0)) AS AmountOfOrders
				FROM Orders o WITH (NOLOCK)
				INNER JOIN OrderSetItems osi ON osi.OrderId=o.OrderId
				WHERE o.Status IN (2, 3, 4, 5)
				AND o.TenantId = @TenantId
				AND (@FromDate IS NULL OR CONVERT(DATE, o.ApprovedDate) >= @FromDate)
				AND (@ToDate IS NULL OR CONVERT(DATE, o.ApprovedDate) <= @ToDate)
				GROUP BY o.RefferedBy
			) o ON o.RefferedBy = c.CustomerId
			LEFT JOIN
			(
				SELECT o.RefferedBy
					,SUM(CASE WHEN Status = 0 THEN 1 END) AS NoOfOpenInquiries
					,SUM(CASE WHEN Status = 0 THEN ROUND(o.AmountBeforeGST, 0) END) AS AmountOfOpenInquiries
				FROM Orders o WITH (NOLOCK)
				WHERE o.Status = 0
				AND o.TenantId = @TenantId
				AND (@FromDate IS NULL OR CONVERT(DATE, o.CreatedDate) >= @FromDate)
				AND (@ToDate IS NULL OR CONVERT(DATE, o.CreatedDate) <= @ToDate)
				GROUP BY o.RefferedBy
			) oi ON oi.RefferedBy = c.CustomerId
			LEFT JOIN
			(
				SELECT c.RefferedBy
					,COUNT(1) AS NoOfVisits
				FROM CustomerVisits cv WITH (NOLOCK)
				INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = cv.CustomerId
					AND c.RefferedBy > 0
				WHERE c.IsDeleted = 0
				AND c.CustomerTypeId = 1
				AND c.TenantId = @TenantId
				AND (@FromDate IS NULL OR CONVERT(DATE, cv.CreatedDate) >= @FromDate)
				AND (@ToDate IS NULL OR CONVERT(DATE, cv.CreatedDate) <= @ToDate)
				GROUP BY c.RefferedBy
			) cv ON cv.RefferedBy = c.CustomerId
			WHERE c.CustomerTypeId = 2 -- Interior
			AND (@ReferredBy IS NULL OR c.CustomerId = @ReferredBy)
			AND c.IsDeleted = 0
			AND c.TenantId = @TenantId
			AND (o.NoOfOrders > 0 OR oi.NoOfOpenInquiries > 0)
			ORDER BY CASE 
					WHEN @SortBy = 'InteriorName'
						AND @SortOrder = 'ASC'
						THEN (C.FirstName + ' ' + ISNULL(C.LastName, ''))
					END
				,CASE 
					WHEN @SortBy = 'InteriorName'
						AND @SortOrder = 'DESC'
						THEN (C.FirstName + ' ' + ISNULL(C.LastName, ''))
					END DESC
				,CASE 
					WHEN @SortBy = 'InteriorNumber'
						AND @SortOrder = 'ASC'
						THEN C.PhoneNumber
					END
				,CASE 
					WHEN @SortBy = 'InteriorNumber'
						AND @SortOrder = 'DESC'
						THEN C.PhoneNumber
					END DESC
				,CASE 
					WHEN @SortBy = 'NoOfVisits'
						AND @SortOrder = 'ASC'
						THEN NoOfVisits
					END
				,CASE 
					WHEN @SortBy = 'NoOfVisits'
						AND @SortOrder = 'DESC'
						THEN NoOfVisits
					END DESC
				,CASE 
					WHEN @SortBy = 'AmountOfOpenInquiries'
						AND @SortOrder = 'ASC'
						THEN oi.AmountOfOpenInquiries
					END
				,CASE 
					WHEN @SortBy = 'AmountOfOpenInquiries'
						AND @SortOrder = 'DESC'
						THEN oi.AmountOfOpenInquiries
					END DESC
				,CASE 
					WHEN @SortBy = 'AmountOfOrders'
						AND @SortOrder = 'ASC'
						THEN AmountOfOrders
					END
				,CASE 
					WHEN @SortBy = 'AmountOfOrders'
						AND @SortOrder = 'DESC'
						THEN AmountOfOrders
					END DESC
				,CASE 
					WHEN @SortBy = 'Benefits' 
						AND @SortOrder ='ASC' 
							THEN o.Benefits 
					END ASC  
				,CASE WHEN @SortBy = 'Benefits'
						AND @SortOrder ='DESC' 
							THEN o.Benefits
					END DESC  
			OFFSET(@PageIndex - 1) * @PageSize
			ROWS FETCH NEXT @PageSize ROWS ONLY;
		END
		ELSE
		BEGIN
			SELECT c.CustomerId AS InteriorId
				,(C.FirstName + ' ' + ISNULL(C.LastName, '')) AS InteriorName
				,C.PhoneNumber AS InteriorNumber
				,ISNULL(cv.NoOfVisits, 0) AS NoOfVisits
				,ISNULL(oi.NoOfOpenInquiries, 0) AS NoOfOpenInquiries
				,CAST(ISNULL(ROUND(oi.AmountOfOpenInquiries, 0), 0) AS DECIMAL) AS AmountOfOpenInquiries
				,ISNULL(o.NoOfOrders, 0) AS NoOfOrders
				,CAST(ISNULL(ROUND(o.AmountOfOrders, 0), 0) AS DECIMAL) AS AmountOfOrders
				,ISNULL(Round(CAST(o.Benefits AS INT),0),0) AS Benefits
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM Customers c WITH (NOLOCK)
			INNER JOIN
			(
				SELECT o.RefferedBy
					--,ISNULL(SUM(osi.InteriorCommission),0) AS Benefits
					,ISNULL((-1)*CAST(SUM(ROUND(osi.InteriorCommission, 0)) AS INT), 0) AS Benefits
					,COUNT(DISTINCT o.OrderId) AS NoOfOrders
					,SUM(ROUND(osi.TotalAmount, 0)) AS AmountOfOrders
				FROM Orders o WITH (NOLOCK)
				INNER JOIN OrderSetItems osi ON osi.OrderId=o.OrderId
				WHERE o.Status IN (2, 3, 4, 5)
				AND o.TenantId = @TenantId
				AND (@FromDate IS NULL OR CONVERT(DATE, o.ApprovedDate) >= @FromDate)
				AND (@ToDate IS NULL OR CONVERT(DATE, o.ApprovedDate) <= @ToDate)
				GROUP BY o.RefferedBy
			) o ON o.RefferedBy = c.CustomerId
			LEFT JOIN
			(
				SELECT o.RefferedBy
					,SUM(CASE WHEN Status = 0 THEN 1 END) AS NoOfOpenInquiries
					,SUM(CASE WHEN Status = 0 THEN ROUND(o.TotalAmt, 0) END) AS AmountOfOpenInquiries
				FROM Orders o WITH (NOLOCK)
				WHERE o.Status = 0
				AND o.TenantId = @TenantId
				AND (@FromDate IS NULL OR CONVERT(DATE, o.CreatedDate) >= @FromDate)
				AND (@ToDate IS NULL OR CONVERT(DATE, o.CreatedDate) <= @ToDate)
				GROUP BY o.RefferedBy
			) oi ON oi.RefferedBy = c.CustomerId
			LEFT JOIN
			(
				SELECT c.RefferedBy
					,COUNT(1) AS NoOfVisits
				FROM CustomerVisits cv WITH (NOLOCK)
				INNER JOIN Customers c WITH (NOLOCK) ON c.CustomerId = cv.CustomerId
					AND c.RefferedBy > 0
				WHERE c.IsDeleted = 0
				AND c.CustomerTypeId = 1
				AND c.TenantId = @TenantId
				AND (@FromDate IS NULL OR CONVERT(DATE, cv.CreatedDate) >= @FromDate)
				AND (@ToDate IS NULL OR CONVERT(DATE, cv.CreatedDate) <= @ToDate)
				GROUP BY c.RefferedBy
			) cv ON cv.RefferedBy = c.CustomerId
			WHERE c.CustomerTypeId = 2 -- Interior
			AND (@ReferredBy IS NULL OR c.CustomerId = @ReferredBy)
			AND c.IsDeleted = 0
			AND c.TenantId = @TenantId
			AND (o.NoOfOrders > 0 OR oi.NoOfOpenInquiries > 0)
			ORDER BY CASE 
					WHEN @SortBy = 'InteriorName'
						AND @SortOrder = 'ASC'
						THEN (C.FirstName + ' ' + ISNULL(C.LastName, ''))
					END
				,CASE 
					WHEN @SortBy = 'InteriorName'
						AND @SortOrder = 'DESC'
						THEN (C.FirstName + ' ' + ISNULL(C.LastName, ''))
					END DESC
				,CASE 
					WHEN @SortBy = 'InteriorNumber'
						AND @SortOrder = 'ASC'
						THEN C.PhoneNumber
					END
				,CASE 
					WHEN @SortBy = 'InteriorNumber'
						AND @SortOrder = 'DESC'
						THEN C.PhoneNumber
					END DESC
				,CASE 
					WHEN @SortBy = 'NoOfVisits'
						AND @SortOrder = 'ASC'
						THEN NoOfVisits
					END
				,CASE 
					WHEN @SortBy = 'NoOfVisits'
						AND @SortOrder = 'DESC'
						THEN NoOfVisits
					END DESC
				,CASE 
					WHEN @SortBy = 'AmountOfOpenInquiries'
						AND @SortOrder = 'ASC'
						THEN oi.AmountOfOpenInquiries
					END
				,CASE 
					WHEN @SortBy = 'AmountOfOpenInquiries'
						AND @SortOrder = 'DESC'
						THEN oi.AmountOfOpenInquiries
					END DESC
				,CASE 
					WHEN @SortBy = 'AmountOfOrders'
						AND @SortOrder = 'ASC'
						THEN AmountOfOrders
					END
				,CASE 
					WHEN @SortBy = 'AmountOfOrders'
						AND @SortOrder = 'DESC'
						THEN AmountOfOrders
					END DESC
				,CASE 
					WHEN @SortBy = 'Benefits' 
						AND @SortOrder ='ASC' 
							THEN o.Benefits 
					END ASC  
				,CASE WHEN @SortBy = 'Benefits'
						AND @SortOrder ='DESC' 
							THEN o.Benefits
					END DESC  
			OFFSET(@PageIndex - 1) * @PageSize
			ROWS FETCH NEXT @PageSize ROWS ONLY;
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

