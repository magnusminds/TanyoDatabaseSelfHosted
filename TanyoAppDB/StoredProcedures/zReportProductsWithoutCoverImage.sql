/*
	EXEC ReportProductsWithoutCoverImage
		@TenantId = 1
		,@CategoryId = NULL
		,@ProductTitle = NULL
		,@ModelNo = NULL
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'ProductTitle'
		,@SortOrder = 'ASC'
*/
CREATE   PROCEDURE [dbo].[zReportProductsWithoutCoverImage] (
	@TenantId INT
	,@CategoryId BIGINT = NULL
	,@ModelNo VARCHAR(50) = NULL
	,@ProductTitle VARCHAR(50) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'CategoryName'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	
	BEGIN TRY
		
		DECLARE @ProductSubjectTypeId INT;
		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		SELECT P.ProductId AS 'ProductId'
			,P.ProductTitle AS 'ProductTitle'
			,P.ModelNo AS 'ModelNo'
			,cat.CategoryName AS 'CategoryName'
			,cat.CategoryId AS 'CategoryId'
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM Products p WITH (NOLOCK)
		INNER JOIN Categories cat WITH (NOLOCK) on p.CategoryId = cat.CategoryId
		INNER JOIN ProductImages pm WITH (NOLOCK) ON pm.ProductId = p.ProductId
		WHERE cat.IsDeleted = 0 
		AND P.TenantId = @TenantId
		AND P.Status <> 3
		AND (ISNULL(@ModelNo, '') = '' OR p.ModelNo LIKE  '%' + @ModelNo + + '%' )
		AND (ISNULL(@CategoryId, - 1) = - 1 OR p.CategoryId = @CategoryId)
		AND (ISNULL(@ProductTitle, '') = '' OR p.ProductTitle LIKE  '%' + @ProductTitle + '%')
		AND p.ProductId NOT IN
		(
				SELECT DISTINCT pr.ProductId
				FROM ProductImages pr WITH (NOLOCK)
				INNER JOIN Products p1 WITH (NOLOCK) ON p1.ProductId = pr.ProductId
					AND p1.TenantId = @TenantId
					AND p1.Status <> 3
				WHERE pr.IsCover = 1
		)
		ORDER BY 
			CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle	END ASC
			,CASE WHEN @SortBy = 'ProductTitle'	AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC
			,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN p.ModelNo END ASC
			,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN p.ModelNo END DESC 
			,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN cat.CategoryName END ASC
			,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN cat.CategoryName END DESC 
		OFFSET(@PageIndex - 1) * @PageSize ROWS
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

