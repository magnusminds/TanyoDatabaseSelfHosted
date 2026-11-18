/*
	EXEC [dbo].[ReportLaborbyContractor] 
		@TenantId = 5
		,@FromDate  = '1990-10-01'
		,@ToDate = '2025-10-29'
		,@WorkflowID = -1
		,@ContractorID = -1
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'NotificationType'
		,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[zReportLaborbyContractor_V1]
(
    @TenantId INT
    ,@FromDate DATE
    ,@ToDate DATE
    ,@WorkflowID INT = -1
    ,@ContractorID INT = -1
    ,@PageIndex INT = 1
    ,@PageSize INT = 50
    ,@SortBy VARCHAR(50) = 'CompletionDate'
    ,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    
    
    BEGIN TRY
        DECLARE @SubjectTypeId BIGINT
            ,@ProductSubjectTypeId BIGINT

        SELECT @SubjectTypeId = st.SubjectTypeId
        FROM dbo.SubjectTypes st WITH (NOLOCK)
        WHERE st.TenantId = @TenantId
        AND st.SubjectTypeName = 'Labours'
        AND st.IsDeleted = 0

        SELECT @ProductSubjectTypeId = st.SubjectTypeId
        FROM dbo.SubjectTypes st WITH (NOLOCK)
        WHERE st.TenantId = @TenantId
        AND st.SubjectTypeName = 'Products'
        AND st.IsDeleted = 0
        
        SELECT au.FirstName + ' ' + au.LastName AS ContractorName
            ,au.UserId AS ContractorId
            ,'' AS WorkflowName
            ,p.ProductTitle AS ProductName
            ,CONVERT(DATETIMEOFFSET, omw.CompletionDate) AS CompletionDate
            ,COUNT(DISTINCT omw.OrderSetItemId) AS TotalOrders
            ,CAST(SUM(opc.Price*osi.Quantity) AS NUMERIC(18,2)) AS Amount
            ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
        FROM dbo.ManufacturingWorkflows mw WITH (NOLOCK)
        INNER JOIN dbo.ManufacturingWorkflowMapping mwm WITH (NOLOCK) ON mwm.ManufacturingWorkflowId = mw.ManufacturingWorkflowId
            AND mwm.IsDeleted = 0
        INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = mwm.ManufacturingUserId
        INNER JOIN dbo.OrderManufacturingWorkflows omw WITH (NOLOCK) ON omw.ManufacturingWorkflowId = mw.ManufacturingWorkflowId
            AND omw.ManufacturingStatus = 2
            AND omw.ContractorUserID = au.UserId
        INNER JOIN dbo.Orders o WITH (NOLOCK) ON o.OrderId = omw.OrderId
            AND o.TenantId = @TenantId
            AND o.Status <> 9
        INNER JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderSetItemId = omw.OrderSetItemId
            AND osi.OrderId = o.OrderId
            AND osi.SubjectTypeId = @ProductSubjectTypeId
            AND osi.IsDeleted = 0
        INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
        INNER JOIN dbo.ProductLabours pl WITH (NOLOCK) ON pl.ProductId = osi.SubjectId
            AND pl.ManufacturingWorkFlowId = omw.ManufacturingWorkflowId
        INNER JOIN dbo.OrderProductCharges opc WITH (NOLOCK) ON opc.OrderSetItemId = omw.OrderSetItemId
            AND opc.EntityTypeId = @SubjectTypeId
            AND opc.EntityId = pl.ProductLabourId
        WHERE mw.TenantId = @TenantId
        AND mw.IsDeleted = 0
        AND omw.CompletionDate BETWEEN @FromDate
            AND @ToDate
        AND (@ContractorID = -1 OR omw.ContractorUserID = @ContractorID)
        GROUP BY au.FirstName + ' ' + au.LastName
            ,omw.CompletionDate
            ,au.UserId
            ,p.ProductId
            ,p.ProductTitle
        ORDER BY
            CASE WHEN @SortBy = 'ContractorName' AND @SortOrder ='ASC' THEN au.FirstName + ' ' + au.LastName END ASC
            ,CASE WHEN @SortBy = 'ContractorName' AND @SortOrder ='DESC' THEN au.FirstName + ' ' + au.LastName END DESC
            ,CASE WHEN @SortBy = 'CompletionDate' AND @SortOrder ='DESC' THEN omw.CompletionDate END DESC
            ,CASE WHEN @SortBy = 'CompletionDate' AND @SortOrder ='ASC' THEN omw.CompletionDate END ASC
            ,CASE WHEN @SortBy = 'TotalOrders' AND @SortOrder ='DESC' THEN COUNT(DISTINCT omw.OrderSetItemId) END DESC
            ,CASE WHEN @SortBy = 'TotalOrders' AND @SortOrder ='ASC' THEN COUNT(DISTINCT omw.OrderSetItemId) END ASC
            ,CASE WHEN @SortBy = 'Amount' AND @SortOrder ='DESC' THEN SUM(opc.Price) END DESC
            ,CASE WHEN @SortBy = 'Amount' AND @SortOrder ='ASC' THEN SUM(opc.Price) END ASC
            ,CASE WHEN @SortBy = 'ProductName' AND @SortOrder ='DESC' THEN p.ProductTitle END DESC
            ,CASE WHEN @SortBy = 'ProductName' AND @SortOrder ='ASC' THEN p.ProductTitle END ASC
        OFFSET (@PageIndex-1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000)
        DECLARE @ErrorSeverity INT
        DECLARE @ErrorState INT

        SELECT @ErrorMessage = ERROR_MESSAGE()
            , @ErrorSeverity = ERROR_SEVERITY()
            , @ErrorState = ERROR_STATE()

        RAISERROR (@ErrorMessage, @ErrorSeverity, @ErrorState)
    END CATCH;
END

GO

