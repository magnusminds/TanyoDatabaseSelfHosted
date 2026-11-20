-- =============================================
-- Author		: MagnusMinds
-- Create date	: 06-09-2023
-- Description	: Report - Manufacturing Order Status by Contrator
-- =============================================
/*
	EXEC [dbo].[ReportManufacturingStatus]
		@TenantId = 1
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'NotificationType'
		,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[ReportManufacturingStatus] (
	@TenantId INT
	,@ContractorId VARCHAR (MAX) = NULL
	,@ProductId VARCHAR (MAX) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'ModelNo'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT pro.ProductTitle
			,cat.CategoryName
			,pro.ModelNo
			,asi.FirstName + ' ' + asi.LastName AS ContractorName
			,ISNULL(man.WorkflowName, '') AS MfgWorkflow
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM ProductWorkflows AS pw WITH (NOLOCK)
		INNER JOIN [dbo].[AspNetUsers] AS asi WITH (NOLOCK) ON pw.ContractorUserID = asi.UserId
		INNER JOIN [dbo].[Products] AS pro WITH (NOLOCK) ON pw.ProductID = pro.ProductId
		INNER JOIN [dbo].[Categories] AS cat WITH (NOLOCK) ON pro.CategoryId = cat.CategoryId
		LEFT JOIN [dbo].[ManufacturingWorkflows] AS man WITH (NOLOCK) ON pw.ManufacturingWorkflowId = man.ManufacturingWorkflowId
		WHERE pro.TenantId = @TenantId
		AND (@ContractorId IS NULL OR pw.ContractorUserID IN (SELECT value FROM STRING_SPLIT(@ContractorId, ',')))
		AND (@ProductId IS NULL OR pro.ProductId IN (SELECT value FROM STRING_SPLIT(@ProductId, ',')))
		AND cat.IsManufacturing = 1
		ORDER BY CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN pro.ModelNo END ASC
			,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN pro.ModelNo END DESC
			,CASE WHEN @SortBy = 'ProuctTitle' AND @SortOrder = 'ASC' THEN pro.ProductTitle END ASC
			,CASE WHEN @SortBy = 'ProuctTitle' AND @SortOrder = 'DESC' THEN pro.ProductTitle END DESC
			,CASE WHEN @SortBy = 'ProductCategory' AND @SortOrder = 'DESC' THEN cat.CategoryName END DESC
			,CASE WHEN @SortBy = 'ProductCategory' AND @SortOrder = 'ASC' THEN cat.CategoryName END ASC
			,CASE WHEN @SortBy = 'ContractorName' AND @SortOrder = 'DESC' THEN asi.FirstName END DESC
			,CASE WHEN @SortBy = 'ContractorName' AND @SortOrder = 'ASC' THEN asi.FirstName END ASC
			,CASE WHEN @SortBy = 'WorkFlowName' AND @SortOrder = 'DESC' THEN man.WorkflowName END DESC
			,CASE WHEN @SortBy = 'WorkFlowName' AND @SortOrder = 'ASC' THEN man.WorkflowName END ASC
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

