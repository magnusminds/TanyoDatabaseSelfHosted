/*
EXEC dbo.GetArchiveOrdersByOrderId 
	 @OrderId = 98
        ,@TenantId = 125
        ,@PageIndex = 1
        ,@PageSize = 10
        ,@SortBy = 'VersionId'
        ,@SortOrder = 'asc'
*/
CREATE   PROCEDURE [dbo].[GetArchiveOrdersByOrderId]
(
	@TenantId INT
	,@OrderId BIGINT
	,@PageIndex INT = 1
	,@PageSize INT = 100
    ,@SortBy VARCHAR(50) = 'VersionId'
	,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	DECLARE @Archive_OrderId BIGINT
	DECLARE @UpdatedDate DATE;

	SELECT TOP (1) @Archive_OrderId = a.Archive_OrderId,
		@UpdatedDate = ISNULL(UpdatedDate,InquiryLastUpdatedDate)
	FROM Archive_Orders a WITH (NOLOCK)
	WHERE TenantId = @TenantId
		AND OrderId = @OrderId
	ORDER BY Archive_OrderId ASC

	SELECT @UpdatedDate = DATEADD(d,1, @UpdatedDate)
	
	

	DECLARE @tmpArchive_Orders AS TABLE
	(
		VersionId BIGINT
		,ProductAmount NUMERIC(18,2)
		,Discount NUMERIC(18,2)
		,TotalGSTAmount NUMERIC(18,2)
		,TotalAmount NUMERIC(18,2)
		,GrossTotal NUMERIC(18,2)
		,UpdatedDate datetimeoffset
		,OrderId BIGINT
		,OrderNo VARCHAR(20)
		,TenantId INT
		,CreatedDate datetimeoffset
		,OrderType smallint
		,CreatedBy BIGINT
		,SalesmanId BIGINT
		,ArchiveOrderDate datetimeoffset
	)

	INSERT INTO @tmpArchive_Orders
	(
		VersionId
		,ProductAmount
		,Discount
		,TotalGSTAmount
		,TotalAmount
		,GrossTotal
		,UpdatedDate
		,OrderId
		,OrderNo
		,TenantId
		,CreatedDate
		,OrderType
		,CreatedBy
		,SalesmanId
		,ArchiveOrderDate
	)
	SELECT VersionId
        ,AmountBeforeGST
        ,ROUND(Discount, 0)
        ,CGSTAmount + SGSTAmount
        ,TotalAmount
        ,GrossTotal
        ,UpdatedDate
        ,OrderId
		,OrderNo
        ,TenantId
        ,CreatedDate
        ,OrderType
		,CreatedBy
		,SalesmanId
		,ArchiveOrderDate
	FROM Archive_Orders WITH (NOLOCK)
	WHERE Archive_OrderId = @Archive_OrderId
	UNION ALL
	SELECT VersionId
        ,AmountBeforeGST
        ,ROUND(Discount, 0)
        ,CGSTAmount + SGSTAmount
        ,TotalAmount
        ,GrossTotal
        ,UpdatedDate
        ,OrderId
		,OrderNo
        ,TenantId
        ,CreatedDate
        ,OrderType
		,CreatedBy
		,SalesmanId
		,ArchiveOrderDate
	FROM Archive_Orders WITH (NOLOCK)
	WHERE TenantId = @TenantId
		AND OrderId = @OrderId
		AND ISNULL(UpdatedDate,InquiryLastUpdatedDate) >= @UpdatedDate

	SELECT VersionId
        ,ProductAmount
        ,Discount
        ,TotalGSTAmount
        ,TotalAmount
        ,GrossTotal
        ,ISNULL(aspnetUser.FirstName + ' ' + ISNULL(aspnetUser.LastName, ''), '') AS LastModifyBy
        ,ArchiveOrderDate AS UpdatedDate
        ,OrderId
		,OrderNo
        ,TenantId
		,ISNULL(SalesmanUser.FirstName + ' ' + ISNULL(SalesmanUser.LastName, '') + CASE WHEN SalesmanUser.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END, '') AS CreatedName
        ,CreatedDate
        ,OrderType
		,ArchiveOrderDate
        ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM @tmpArchive_Orders ao
	LEFT JOIN AspNetUsers aspnetUser WITH (NOLOCK) ON ao.CreatedBy = aspnetUser.UserId
    LEFT JOIN AspNetUsers SalesmanUser WITH (NOLOCK) ON ao.SalesmanId = SalesmanUser.UserId
	ORDER BY CASE WHEN @SortBy = 'VersionId' AND @SortOrder = 'ASC' THEN ao.VersionId END ASC
			,CASE WHEN @SortBy = 'VersionId' AND @SortOrder = 'DESC' THEN ao.VersionId END DESC
    OFFSET(@PageIndex - 1) * @PageSize ROWS
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

