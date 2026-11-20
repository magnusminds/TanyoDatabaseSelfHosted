
/*

EXEC [dbo].[ListManufacturingOrders] 
	@TenantId =2
	,@OrderNo  = NULL
	,@ContractorUserID  = NULL
	,@WorkflowStage  = NULL
	,@DeliveryFromDate  = NULL
	,@DeliveryToDate  = NULL
	,@Status  = NULL
	,@OrderType  = NULL
	,@FromTotalClick  = 0
	,@PageIndex  = 1
	,@PageSize  = 10
	,@SortBy  = 'ManufacturingOrderNumber'
	,@SortOrder  = 'ASC'

*/
CREATE
	

 PROCEDURE [dbo].[ListManufacturingOrders] (
	@TenantId INT
	,@OrderNo VARCHAR(100) = NULL
	,@ContractorUserID INT = NULL
	,@WorkflowStage INT = NULL
	,@DeliveryFromDate DATE = NULL
	,@DeliveryToDate DATE = NULL
	,@Status INT = NULL
	,@OrderType SMALLINT = NULL
	,@FromTotalClick BIT = 0
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy VARCHAR(50) = 'ManufacturingOrderNumber'
	,@SortOrder VARCHAR(4) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF OBJECT_ID('tempdb..#FilteredOrderDetails') IS NOT NULL
		DROP TABLE #FilteredOrderDetails;

	SELECT OMWF.OrderManufacturingWorkflowId
		,ISNULL(osi.DeliveryNo, '') AS ManufacturingOrderNumber
		,OMWF.OrderId
		,ISNULL(o.OrderNo, '') AS OrderNo
		,o.OrderType
		,c.CategoryName
		,p.ProductTitle
		,OMWF.OrderSetItemId
		,p.ProductId
		,p.ModelNo
		,OMWF.ManufacturingWorkflowId AS WorkflowId
		,w.WorkflowName AS WorkflowStage
		,OMWF.ContractorUserID
		,CONCAT (
			ISNULL(uc.FirstName, '')
			,' '
			,ISNULL(uc.LastName, '')
			) AS ContractorName
		,OMWF.SupervisorUserID
		,CONCAT (
			ISNULL(us.FirstName, '')
			,' '
			,ISNULL(us.LastName, '')
			) AS SupervisorName
		,OMWF.ManufacturingStatus
		,o.TentativeDeliveryDate
		,osi.DeliveryDate
		,uc.UserId
		,osi.ItemStatus
	INTO #FilteredOrderDetails
	FROM OrderManufacturingWorkflows OMWF WITH (NOLOCK)
	INNER JOIN Orders O WITH (NOLOCK) ON OMWF.OrderId = o.OrderId
	LEFT JOIN AspNetUsers UC WITH (NOLOCK) ON OMWF.ContractorUserID = uc.UserId
	LEFT JOIN AspNetUsers US WITH (NOLOCK) ON OMWF.SupervisorUserID = us.UserId
	INNER JOIN ManufacturingWorkflows w WITH (NOLOCK) ON OMWF.ManufacturingWorkflowId = w.ManufacturingWorkflowId
	LEFT JOIN OrderSetItems OSI WITH (NOLOCK) ON OMWF.OrderSetItemId = osi.OrderSetItemId
	LEFT JOIN Products P WITH (NOLOCK) ON osi.SubjectId = p.ProductId
	LEFT JOIN Categories C WITH (NOLOCK) ON p.CategoryId = c.CategoryId
	WHERE OMWF.ManufacturingStatus != 2
		AND osi.ItemStatus = 1
		AND o.IsArchive = 0
		AND o.STATUS <> 9
		AND o.TenantId = @TenantId
		AND (
			@OrderNo IS NULL
			OR o.OrderNo LIKE '%' + @OrderNo + '%'
			)
		AND (
			@ContractorUserID IS NULL
			OR uc.UserId = @ContractorUserID
			)
		AND (
			@WorkflowStage IS NULL
			OR OMWF.ManufacturingWorkflowId = @WorkflowStage
			)
		AND (
			@DeliveryFromDate IS NULL
			OR o.TentativeDeliveryDate >= @DeliveryFromDate
			)
		AND (
			@DeliveryToDate IS NULL
			OR o.TentativeDeliveryDate <= @DeliveryToDate
			)
		AND (
			@Status IS NULL
			OR OMWF.ManufacturingStatus = @Status
			)
		AND (
			@OrderType IS NULL
			OR @OrderType = 0
			OR o.OrderType = @OrderType
			)
		AND (
			@FromTotalClick = 0
			OR OMWF.ManufacturingStatus IN (
				0
				,1
				,4
				)
			);

	SELECT OrderManufacturingWorkflowId
		,ManufacturingOrderNumber
		,OrderId
		,OrderNo
		,OrderType
		,CategoryName
		,OrderSetItemId
		,ProductId
		,ProductTitle
		,ModelNo
		,WorkflowId
		,WorkflowStage
		,ContractorUserID
		,ContractorName
		,SupervisorUserID
		,SupervisorName
		,ManufacturingStatus
		,TentativeDeliveryDate
		,DeliveryDate
		,UserId
		,ItemStatus
		,COUNT(*) OVER () AS TotalCount
	FROM #FilteredOrderDetails
	ORDER BY CASE 
			WHEN @SortBy = 'ManufacturingOrderNumber'
				AND @SortOrder = 'ASC'
				THEN ManufacturingOrderNumber
			END ASC
		,CASE 
			WHEN @SortBy = 'ManufacturingOrderNumber'
				AND @SortOrder = 'DESC'
				THEN ManufacturingOrderNumber
			END DESC
		,CASE 
			WHEN @SortBy = 'OrderNo'
				AND @SortOrder = 'ASC'
				THEN OrderNo
			END ASC
		,CASE 
			WHEN @SortBy = 'OrderNo'
				AND @SortOrder = 'DESC'
				THEN OrderNo
			END DESC
		,CASE 
			WHEN @SortBy = 'CategoryName'
				AND @SortOrder = 'ASC'
				THEN CategoryName
			END ASC
		,CASE 
			WHEN @SortBy = 'CategoryName'
				AND @SortOrder = 'DESC'
				THEN CategoryName
			END DESC
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'ASC'
				THEN ProductTitle
			END ASC
		,CASE 
			WHEN @SortBy = 'ProductTitle'
				AND @SortOrder = 'DESC'
				THEN ProductTitle
			END DESC
		,CASE 
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
			WHEN @SortBy = 'SupervisorName'
				AND @SortOrder = 'ASC'
				THEN SupervisorName
			END ASC
		,CASE 
			WHEN @SortBy = 'SupervisorName'
				AND @SortOrder = 'DESC'
				THEN SupervisorName
			END DESC
		,CASE 
			WHEN @SortBy = 'TentativeDeliveryDate'
				AND @SortOrder = 'ASC'
				THEN TentativeDeliveryDate
			END ASC
		,CASE 
			WHEN @SortBy = 'TentativeDeliveryDate'
				AND @SortOrder = 'DESC'
				THEN TentativeDeliveryDate
			END DESC
		,CASE 
			WHEN @SortBy = 'WorkflowStage'
				AND @SortOrder = 'ASC'
				THEN WorkflowStage
			END ASC
		,CASE 
			WHEN @SortBy = 'WorkflowStage'
				AND @SortOrder = 'DESC'
				THEN WorkflowStage
			END DESC
		,CASE 
			WHEN @SortBy = 'Status'
				AND @SortOrder = 'ASC'
				THEN ManufacturingStatus
			END ASC
		,CASE 
			WHEN @SortBy = 'Status'
				AND @SortOrder = 'DESC'
				THEN ManufacturingStatus
			END DESC
		,ManufacturingOrderNumber ASC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

