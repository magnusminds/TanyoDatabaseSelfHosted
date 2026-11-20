/*
	EXEC [dbo].[ReportLaborbyContractor] 
		@TenantId = 2
		,@FromDate  = '2025-10-01'
		,@ToDate = '2025-12-29'
		,@ContractorID = -1
		,@PageIndex = 1
		,@PageSize = 500
		,@SortBy = 'NotificationType'
		,@SortOrder = 'DESC'
*/
CREATE   PROCEDURE [dbo].[ReportLaborbyContractor] (
	@TenantId INT
	,@FromDate DATE
	,@ToDate DATE
	,@ContractorID INT = - 1
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'CompletionDate'
	,@SortOrder VARCHAR(50) = 'ASC'
	,@OrderNo VARCHAR(50) = NULL
	,@ProductName VARCHAR(150) = NULL
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
			AND st.IsDeleted = 0;

		WITH LaborbyContractor
		AS (
			SELECT TRIM(au.FirstName) + ' ' + TRIM(au.LastName) AS ContractorName
				,au.UserId AS ContractorId
				,o.OrderId
				,o.OrderNo
				,p.ProductTitle AS ProductName
				,CONVERT(DATETIMEOFFSET, omw.CompletionDate) AS CompletionDate
				,CAST(SUM(osi.Quantity) AS INT) AS Quantity
				,CAST(MIN(omw.LabourCharge) AS NUMERIC(18, 2)) AS Price
				,CAST(SUM(omw.LabourCharge * osi.Quantity) AS NUMERIC(18, 2)) AS Amount
			FROM dbo.ManufacturingWorkflows mw WITH (NOLOCK)
			INNER JOIN dbo.ManufacturingWorkflowMapping mwm WITH (NOLOCK) ON mwm.ManufacturingWorkflowId = mw.ManufacturingWorkflowId
				AND mwm.IsDeleted = 0
			INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = mwm.ManufacturingUserId
			INNER JOIN dbo.OrderManufacturingWorkflows omw WITH (NOLOCK) ON omw.ManufacturingWorkflowId = mw.ManufacturingWorkflowId
				AND omw.ManufacturingStatus = 2
				AND omw.ContractorUserID = au.UserId
			INNER JOIN dbo.Orders o WITH (NOLOCK) ON o.OrderId = omw.OrderId
				AND o.TenantId = @TenantId
				AND o.STATUS <> 9
			INNER JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderSetItemId = omw.OrderSetItemId
				AND osi.OrderId = o.OrderId
				AND osi.SubjectTypeId = @ProductSubjectTypeId
				AND osi.IsDeleted = 0
			INNER JOIN Products p WITH (NOLOCK) ON p.ProductId = osi.SubjectId
			WHERE mw.TenantId = @TenantId
				AND mw.IsDeleted = 0
				AND omw.CompletionDate BETWEEN @FromDate
					AND @ToDate
				AND (
					@ProductName IS NULL
					OR (
						P.ProductTitle LIKE '%' + @ProductName + '%'
						OR P.ModelNo LIKE '%' + @ProductName + '%'
						)
					)
				AND (
					@ContractorID = - 1
					OR @ContractorID IS NULL
					OR omw.ContractorUserID = @ContractorID
					)
				AND (
					@OrderNo IS NULL
					OR o.OrderNo LIKE '%' + @OrderNo + '%'
					)
			GROUP BY TRIM(au.FirstName) + ' ' + TRIM(au.LastName)
				,omw.CompletionDate
				,au.UserId
				,p.ProductId
				,p.ProductTitle
				,o.OrderId
				,o.OrderNo
			)
		SELECT *
			,CAST(SUM(Amount) OVER () AS NUMERIC(18, 2)) AS FinalTotalAmount
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM LaborbyContractor
		ORDER BY CASE 
				WHEN @SortBy = 'ContractorName'
					AND @SortOrder = 'ASC'
					THEN ContractorName
				END ASC
			,CASE 
				WHEN @SortBy = 'ContractorName'
					AND @SortOrder = 'DESC'
					THEN ContractorName
				END DESC
			,CASE 
				WHEN @SortBy = 'CompletionDate'
					AND @SortOrder = 'DESC'
					THEN CompletionDate
				END DESC
			,CASE 
				WHEN @SortBy = 'CompletionDate'
					AND @SortOrder = 'ASC'
					THEN CompletionDate
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductName'
					AND @SortOrder = 'DESC'
					THEN ProductName
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductName'
					AND @SortOrder = 'ASC'
					THEN ProductName
				END ASC
			,CASE 
				WHEN @SortBy = 'Quantity'
					AND @SortOrder = 'DESC'
					THEN Quantity
				END DESC
			,CASE 
				WHEN @SortBy = 'Quantity'
					AND @SortOrder = 'ASC'
					THEN Quantity
				END ASC
			,CASE 
				WHEN @SortBy = 'Price'
					AND @SortOrder = 'DESC'
					THEN Price
				END DESC
			,CASE 
				WHEN @SortBy = 'Price'
					AND @SortOrder = 'ASC'
					THEN Price
				END ASC
			,CASE 
				WHEN @SortBy = 'Amount'
					AND @SortOrder = 'DESC'
					THEN Amount
				END DESC
			,CASE 
				WHEN @SortBy = 'Amount'
					AND @SortOrder = 'ASC'
					THEN Amount
				END ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

