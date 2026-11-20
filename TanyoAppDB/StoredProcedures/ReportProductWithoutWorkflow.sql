-- =============================================
-- Author		: MagnusMinds
-- Create date	: 06-09-2023
-- Description	: Report - Product without Workflow
-- =============================================
/*
	EXEC [dbo].[ReportProductWithoutWorkflow] 
		@TenantId = 7
		,@ProductTitle = NULL
		,@ModelNo = NULL
		,@CategoryID = NULL
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'ProductTitle'
		,@SortOrder = 'ASC'
*/
CREATE PROCEDURE [dbo].[ReportProductWithoutWorkflow] (
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
		SELECT p.ProductTitle
			,p.ModelNo
			,c.CategoryName
			,p.ProductId
			,c.CategoryId
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM [dbo].[Products] AS p WITH (NOLOCK)
		INNER JOIN [dbo].[Categories] AS c WITH (NOLOCK) ON p.CategoryId = c.CategoryId
		LEFT JOIN [dbo].[ProductWorkflows] AS pw WITH (NOLOCK) ON p.ProductId = pw.ProductID
		WHERE p.TenantId = @TenantId
			AND p.Status in (0,1,2) --not included deleted
			AND c.IsManufacturing = 1
			AND pw.ProductWorkflowID IS NULL
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
		GROUP BY c.CategoryName
			,p.ProductTitle
			,p.ModelNo
			,p.ProductId
			,c.CategoryId
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

