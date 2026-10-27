/*
Exec ReportCategoryWiseSales
 @TenantId = 1
,@OrderType = 1
,@CategoryId = NULL
,@StartDate = '2024-01-01'
,@EndDate = '2024-02-28'
,@PageSize  = 500
,@PageIndex  = 1
,@SortBy = 'TotalSales'
,@SortOrder = 'DESC'
*/
CREATE PROC [dbo].[ReportCategoryWiseSales] (
	@TenantId INT
	,@OrderType INT = NULL
	,@CategoryId BIGINT = NULL  -- This Filter will not work as expected beacause Fabrics data is also added to ensure consistency across all reports
	,@StartDate DATE = NULL
	,@EndDate DATE = NULL
	,@PageSize INT = 50
	,@PageIndex INT = 1
	,@SortBy VARCHAR(50) = 'CategoryName'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @ProductSubjecTypeID INT
			,@FabricSubjectTypeID INT
			,@PolishSubjectTypeID INT;
		DECLARE @IsBeforeGSTFlag BIT = 0;

		SELECT @ProductSubjecTypeID = st.SubjectTypeId
		FROM SubjectTypes AS st WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND st.TenantId = @TenantId

		SELECT @FabricSubjectTypeID = st.SubjectTypeId
		FROM SubjectTypes AS st WITH (NOLOCK)
		WHERE SubjectTypeName = 'Fabrics'
			AND st.TenantId = @TenantId

		SELECT @PolishSubjectTypeID = st.SubjectTypeId
		FROM SubjectTypes AS st WITH (NOLOCK)
		WHERE SubjectTypeName = 'Polish'
			AND st.TenantId = @TenantId

		SELECT @IsBeforeGSTFlag = IsBeforeGST
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantId

		IF (@IsBeforeGSTFlag = 1)
		BEGIN
			WITH SalesReportByCategory
			AS (
				SELECT c.CategoryName AS CategoryName
					,c.CategoryId AS CategoryId
					,SUM(osi.Quantity) AS QtySold
					,SUM(osi.AmountBeforeGST) AS TotalSales
				FROM Orders o WITH (NOLOCK)
				INNER JOIN OrderSetItems osi WITH (NOLOCK) ON o.OrderId = osi.OrderId
					AND osi.isdeleted = 0
				INNER JOIN SubjectTypes st WITH (NOLOCK) ON osi.SubjectTypeId = st.SubjectTypeId
					AND st.IsDeleted = 0
					AND st.TenantId = @TenantId
				INNER JOIN Products p WITH (NOLOCK) ON osi.SubjectId = p.ProductId
					AND p.TenantId = @TenantId
				INNER JOIN Categories c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
					AND c.TenantId = @TenantId
					AND c.IsDeleted = 0
				WHERE osi.SubjectTypeId = @ProductSubjecTypeID
					AND o.STATUS IN (
							2
							,3
							,4
							,5
						)
					AND o.TenantId = @TenantId
					AND (
						(@OrderType = - 1)
						OR (o.OrderType = @OrderType)
						)
					AND (
						@StartDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) >= @StartDate
						)
					AND (
						@EndDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) <= @EndDate
						)
					AND (
						@CategoryId IS NULL
						OR c.CategoryId = @CategoryId
						)
				GROUP BY c.CategoryName
					,c.CategoryId
				
				UNION ALL
				
				SELECT CMP.CompanyName AS CategoryName
					,CMP.CompanyId AS CategoryId
					,SUM(osi.Quantity) AS QtySold
					,SUM(osi.AmountBeforeGST) AS TotalSales
				FROM Orders o WITH (NOLOCK)
				INNER JOIN OrderSetItems osi WITH (NOLOCK) ON o.OrderId = osi.OrderId
					AND osi.isdeleted = 0
				INNER JOIN SubjectTypes st WITH (NOLOCK) ON osi.SubjectTypeId = st.SubjectTypeId
					AND st.IsDeleted = 0
					AND st.TenantId = @TenantId
				INNER JOIN Fabrics FB WITH (NOLOCK) ON OSI.SubjectId = FB.FabricId
					AND FB.IsDeleted = 0
				INNER JOIN Companies CMP WITH (NOLOCK) ON CMP.CompanyId = FB.CompanyId
					AND CMP.IsDeleted = 0
				WHERE osi.SubjectTypeId = @FabricSubjectTypeID
					AND o.STATUS IN (
							2
							,3
							,4
							,5
						)
					AND o.TenantId = @TenantId
					AND (
						(@OrderType = - 1)
						OR (o.OrderType = @OrderType)
						)
					AND (
						@StartDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) >= @StartDate
						)
					AND (
						@EndDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) <= @EndDate
						)
					--AND (
					--	@CategoryId IS NULL
					--	OR CMP.CompanyId = @CategoryId
					--	)
				GROUP BY CMP.CompanyName
					,CMP.CompanyId
				)
			SELECT CategoryName
				,CategoryId
				,QtySold
				,TotalSales
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM SalesReportByCategory
			ORDER BY CASE 
					WHEN @SortBy = 'CategoryName'
						AND @SortOrder = 'ASC'
						THEN CategoryName
					END
				,CASE 
					WHEN @SortBy = 'CategoryName'
						AND @SortOrder = 'DESC'
						THEN CategoryName
					END DESC
				,CASE 
					WHEN @SortBy = 'QtySold'
						AND @SortOrder = 'ASC'
						THEN QtySold
					END
				,CASE 
					WHEN @SortBy = 'QtySold'
						AND @SortOrder = 'DESC'
						THEN QtySold
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalSales'
						AND @SortOrder = 'ASC'
						THEN TotalSales
					END
				,CASE 
					WHEN @SortBy = 'TotalSales'
						AND @SortOrder = 'DESC'
						THEN TotalSales
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
		END
		ELSE
		BEGIN
			WITH SalesReport
			AS (
				SELECT c.CategoryName AS CategoryName
					,c.CategoryId AS CategoryId
					,SUM(osi.Quantity) AS QtySold
					,SUM(osi.TotalAmount) AS TotalSales
				FROM Orders o
				INNER JOIN OrderSetItems osi WITH (NOLOCK) ON o.OrderId = osi.OrderId
					AND osi.isdeleted = 0
				INNER JOIN SubjectTypes st WITH (NOLOCK) ON osi.SubjectTypeId = st.SubjectTypeId
					AND st.IsDeleted = 0
					AND st.TenantId = @TenantId
				INNER JOIN Products p WITH (NOLOCK) ON osi.SubjectId = p.ProductId
					AND p.TenantId = @TenantId
				INNER JOIN Categories c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
					AND c.TenantId = @TenantId
					AND c.IsDeleted = 0
				WHERE osi.SubjectTypeId = @ProductSubjecTypeID
					AND o.STATUS IN (
							2
							,3
							,4
							,5
						)
					AND o.TenantId = @TenantId
					AND (
						(@OrderType = - 1)
						OR (o.OrderType = @OrderType)
						)
					AND (
						@StartDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) >= @StartDate
						)
					AND (
						@EndDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) <= @EndDate
						)
					AND (
						@CategoryId IS NULL
						OR c.CategoryId = @CategoryId
						)
				GROUP BY c.CategoryName
					,c.CategoryId
				
				UNION ALL
				
				SELECT CMP.CompanyName AS CategoryName
					,CMP.CompanyId AS CategoryId
					,SUM(osi.Quantity) AS QtySold
					,SUM(osi.TotalAmount) AS TotalSales
				FROM Orders o
				INNER JOIN OrderSetItems osi WITH (NOLOCK) ON o.OrderId = osi.OrderId
					AND osi.isdeleted = 0
				INNER JOIN SubjectTypes st WITH (NOLOCK) ON osi.SubjectTypeId = st.SubjectTypeId
					AND st.IsDeleted = 0
					AND st.TenantId = @TenantId
				INNER JOIN Fabrics FB WITH (NOLOCK) ON OSI.SubjectId = FB.FabricId
					AND FB.IsDeleted = 0
				INNER JOIN Companies CMP WITH (NOLOCK) ON CMP.CompanyId = FB.CompanyId
					AND CMP.IsDeleted = 0
				WHERE osi.SubjectTypeId = @FabricSubjectTypeID
						AND o.STATUS IN (
							2
							,3
							,4
							,5
						)
					AND o.TenantId = @TenantId
					AND (
						(@OrderType = - 1)
						OR (o.OrderType = @OrderType)
						)
					AND (
						@StartDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) >= @StartDate
						)
					AND (
						@EndDate IS NULL
						OR CONVERT(DATE, o.ApprovedDate) <= @EndDate
						)
					--AND (
					--	@CategoryId IS NULL
					--	OR CMP.CompanyId = @CategoryId
					--	)
				GROUP BY CMP.CompanyName
					,CMP.CompanyId
				)
			SELECT CategoryName
				,CategoryId
				,QtySold
				,TotalSales
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM SalesReport
			ORDER BY CASE 
					WHEN @SortBy = 'CategoryName'
						AND @SortOrder = 'ASC'
						THEN CategoryName
					END
				,CASE 
					WHEN @SortBy = 'CategoryName'
						AND @SortOrder = 'DESC'
						THEN CategoryName
					END DESC
				,CASE 
					WHEN @SortBy = 'QtySold'
						AND @SortOrder = 'ASC'
						THEN QtySold
					END
				,CASE 
					WHEN @SortBy = 'QtySold'
						AND @SortOrder = 'DESC'
						THEN QtySold
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalSales'
						AND @SortOrder = 'ASC'
						THEN TotalSales
					END
				,CASE 
					WHEN @SortBy = 'TotalSales'
						AND @SortOrder = 'DESC'
						THEN TotalSales
					END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY
		END
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				)
	END CATCH
END

GO

