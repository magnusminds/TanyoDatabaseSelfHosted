/*
	EXEC dbo.ListProductShareBatches
		@TenantId = 1
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE   PROC [dbo].[ListProductShareBatches]
(
	@TenantId INT
	,@PageIndex INT = 1
	,@PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT b.Id AS BatchId
		,b.BatchNo
		,b.Title
		,MIN(au.FirstName) + ' ' + MIN(au.LastName) AS SharedBy
		,COUNT(DISTINCT bd.ProductId) AS TotalProducts
		,COUNT(DISTINCT bd.CustomerId) AS TotalCustomers
		,ISNULL(b.UpdatedDate, b.CreatedDate) AS LastModifiedOn
		,au.IsActive AS IsSharedByActive
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM dbo.ProductShareBatch b WITH (NOLOCK)
	INNER JOIN dbo.ProductShareBatchDetail bd WITH (NOLOCK) ON bd.BatchId = b.Id
	INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = b.CreatedBy
	WHERE b.TenantId = @TenantId
	GROUP BY b.Id, b.BatchNo, b.Title, ISNULL(b.UpdatedDate, b.CreatedDate), au.IsActive
	ORDER BY ISNULL(b.UpdatedDate, b.CreatedDate) DESC
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

