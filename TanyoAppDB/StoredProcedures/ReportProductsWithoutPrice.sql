/*  --Author  : kishan kalena 
--Create date : 08-09-2023  
--Description : ReportProductsWithoutPrice  
-- =============================================     
--EXEC ReportProductsWithoutPrice   @TenantId = 24   ,@CategoryId = NULL   ,@ProductTitle = null   ,@ModelNo = NULL   ,@PageIndex = 1   ,@PageSize = 25   ,@SortBy = 'CategoryName'   ,@SortOrder = 'asc'  */
CREATE PROCEDURE [dbo].[ReportProductsWithoutPrice] (
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

	DECLARE @ProductSubjectTypeId INT;

	BEGIN TRY
		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId
			AND IsDeleted = 0

		SELECT P.ProductId AS 'ProductId'
			,p.CoverImage AS 'CoverImage'
			,P.ProductTitle AS 'ProductTitle'
			,P.ModelNo AS 'ModelNo'
			,cat.CategoryName AS 'CategoryName'
			,cat.CategoryId AS 'CategoryId'
			,0.0 AS InStock
			,0.0 AS Inquiry
			,0.0 AS ReadyToDelivered
			,0.0 AS OnHold
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM Products AS p WITH (NOLOCK)
		INNER JOIN Categories AS cat WITH (NOLOCK) ON p.CategoryId = cat.CategoryId
		WHERE cat.IsDeleted = 0
			AND P.TenantId = @TenantId
			AND (
				p.RetailerPrice = 0
				OR p.RetailerPrice IS NULL
				)
			AND P.STATUS != 3
			AND (
				ISNULL(@ModelNo, '') = ''
				OR p.ModelNo LIKE '%' + @ModelNo + + '%'
				)
			AND (
				ISNULL(@CategoryId, - 1) = - 1
				OR p.CategoryId = @CategoryId
				)
			AND (
				ISNULL(@ProductTitle, '') = ''
				OR p.ProductTitle LIKE '%' + @ProductTitle + '%'
				)
		ORDER BY CASE 
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
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'ASC'
					THEN cat.CategoryName
				END ASC
			,CASE 
				WHEN @SortBy = 'CategoryName'
					AND @SortOrder = 'DESC'
					THEN cat.CategoryName
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
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

