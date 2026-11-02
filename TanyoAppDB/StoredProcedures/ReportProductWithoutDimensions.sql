
/*
EXEC [dbo].[ReportProductWithoutDimensions]
	@TenantId = 1
	,@CategoryId = 7 
	,@Status = NULL
	,@PageIndex = 1
	,@PageSize = 50
	,@SortBy = 'Status'
	,@SortOrder = 'DESC'
*/


CREATE PROCEDURE [dbo].[ReportProductWithoutDimensions] (
	@TenantId INT
	,@CategoryId BIGINT = NULL
	,@Status INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'CategoryName'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT c.CategoryId
			,c.CategoryName
			,p.ProductId
			,p.ProductTitle
			,p.ModelNo
			,ISNULL(p.Width, 0) AS Width
			,ISNULL(p.Height, 0) AS Height
			,ISNULL(p.Depth, 0) AS Depth
			,ISNULL(p.Diameter, 0) AS Diameter
			,p.DimensionUnitId
			,CASE WHEN p.STATUS = 0 THEN 2 ELSE p.Status END AS [Status]
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM Products p WITH (NOLOCK)
		INNER JOIN Categories c WITH (NOLOCK) ON c.CategoryId = p.CategoryId
			AND c.IsDeleted = 0
			AND c.TenantId = @TenantId
		WHERE (
				p.Width IN (1.0,0.0)
				OR p.Height IN (1.0,0.0)
				)
			AND p.TenantId = @TenantId
			AND (
				@CategoryId IS NULL OR p.CategoryId = @CategoryId
				)
			AND (
					( @Status IS NULL AND p.Status <> 3 )
					OR (@Status=2 AND p.Status IN (0,2)) 
					OR (p.Status = @Status)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN c.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN c.CategoryName
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN p.ProductTitle
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN p.ProductTitle
				END DESC
			,CASE 
				WHEN @SortBy = 'CategoryId'
					AND @SortOrder = 'ASC'
					THEN p.CategoryId
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryId'
					AND @SortOrder = 'DESC'
					THEN p.CategoryId
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductId'
					AND @SortOrder = 'ASC'
					THEN p.ProductId
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductId'
					AND @SortOrder = 'DESC'
					THEN p.ProductId
				END DESC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN p.ModelNo
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN p.ModelNo
				END DESC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'ASC'
					THEN CASE WHEN p.STATUS = 0 THEN 2 ELSE p.Status END
				END ASC
			,CASE 
				WHEN @SortBy = 'Status'
					AND @SortOrder = 'DESC'
					THEN CASE WHEN p.STATUS = 0 THEN 2 ELSE p.Status END
				END DESC
		OFFSET(@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
	END CATCH
END

GO

