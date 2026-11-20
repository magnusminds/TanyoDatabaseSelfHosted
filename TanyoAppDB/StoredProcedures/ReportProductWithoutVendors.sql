-- =============================================
-- Author		: MagnusMinds
-- Create date	: 06-11-2024
-- Description	: Report - Product without vendors
-- =============================================
/*
	EXEC [dbo].[ReportProductWithoutVendors] 
		@TenantId = 2
		,@ProductTitle = NULL
		,@ModelNo = 'SC-0003'
		,@CategoryID = NULL
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'ProductTitle'
		,@SortOrder = 'ASC'
*/
CREATE   PROCEDURE [dbo].[ReportProductWithoutVendors] (
	@TenantId INT
	,@ProductTitle VARCHAR(50) = NULL
	,@ModelNo VARCHAR(50) = NULL
	,@CategoryID INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'ProductTitle'
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
				,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			FROM [dbo].[Products] AS p WITH (NOLOCK)
			INNER JOIN [dbo].[Categories] AS c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
				AND c.IsDeleted = 0
			LEFT JOIN ProductVendorMapping As pvm WITH (NOLOCK) ON  p.ProductId = pvm.ProductId
			WHERE p.TenantId = @TenantId
			AND p.Status <> 3
			AND pvm.ProductId IS NULL
			AND (
				ISNULL(@ProductTitle, '') = ''
				OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
				)
			AND (
				ISNULL(@CategoryID, '') = ''
				OR c.CategoryId = @CategoryID
				)
			AND (
				ISNULL(@ModelNo, '') = ''
				OR p.ModelNo LIKE '%' + @ModelNo + '%'
				)
			ORDER BY CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle END ASC
				,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC
				,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN p.ModelNo END DESC
				,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN p.ModelNo END ASC
				,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN c.CategoryName END DESC
				,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN c.CategoryName END ASC 
		OFFSET(@PageIndex - 1) * @PageSize ROWS
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

