/*
	EXEC dbo.Report_ListShareProduct_V2
		@TenantId = 102,
        @SharedBy = NULL,
        @FromDate = NULL,
        @ToDate = NULL,
        @PageIndex = 1,
        @PageSize = 50,
        @SortBy = 'SharedDate',
        @SortOrder = 'DESC'
*/
CREATE   PROC [dbo].[zReport_ListShareProduct_V2] 
(
	@TenantId INT
	,@SharedBy INT = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(100) = 'SharedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		WITH SharedData
		AS (
			SELECT b.Id AS BatchId
				,ISNULL(b.UpdatedDate, b.CreatedDate) AS SharedDate
				,au.FirstName + ' ' + au.LastName + CASE 
					WHEN au.IsDeleted = 1
						THEN ' (Inactive)'
					ELSE ''
					END AS SharedBy
				,COUNT(DISTINCT bd.ProductId) AS TotalProducts
				,COUNT(DISTINCT bd.CustomerId) AS TotalCustomers
				,COUNT(1) OVER () AS TotalCount
			FROM dbo.ProductShareBatch b WITH (NOLOCK)
			INNER JOIN dbo.ProductShareBatchDetail bd WITH (NOLOCK) ON bd.BatchId = b.Id
			INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = b.CreatedBy
			WHERE bd.TenantId = @TenantId
				AND (
					@SharedBy IS NULL
					OR b.CreatedBy = @SharedBy
					)
				AND (
					@FromDate IS NULL
					OR b.CreatedDate >= @FromDate
					)
				AND (
					@ToDate IS NULL
					OR b.CreatedDate < DATEADD(DAY, 1, @ToDate)
					)
			GROUP BY 
				b.Id
				,au.FirstName
				,au.LastName
				,au.IsDeleted
				,ISNULL(b.UpdatedDate, b.CreatedDate)
			)
		SELECT *
		FROM SharedData
		ORDER BY
			-- SharedBy
			CASE WHEN @SortBy = 'SharedBy' AND @SortOrder = 'ASC' THEN SharedBy END ASC
			,CASE WHEN @SortBy = 'SharedBy' AND @SortOrder = 'DESC' THEN SharedBy END DESC
			
			-- SharedDate
			,CASE WHEN @SortBy = 'SharedDate' AND @SortOrder = 'ASC' THEN SharedDate END ASC
			,CASE WHEN @SortBy = 'SharedDate' AND @SortOrder = 'DESC' THEN SharedDate END DESC
			
			-- TotalProducts
			,CASE WHEN @SortBy = 'TotalProducts' AND @SortOrder = 'ASC' THEN TotalProducts END ASC
			,CASE WHEN @SortBy = 'TotalProducts' AND @SortOrder = 'DESC' THEN TotalProducts END DESC
			
			-- TotalCustomers
			,CASE WHEN @SortBy = 'TotalCustomers' AND @SortOrder = 'ASC' THEN TotalCustomers END ASC
			,CASE WHEN @SortBy = 'TotalCustomers' AND @SortOrder = 'DESC' THEN TotalCustomers END DESC
			
			-- Default fallback sort
			,SharedDate DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
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

