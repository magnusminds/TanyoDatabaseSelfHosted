/*
EXEC dbo.GetOrderTracking
     @TenantId = 1207,
	 @OrderId = 261242,
     @FromDate = '2026-09-01',
     @ToDate = '2026-09-29',
     @PageIndex = 1,
     @PageSize = 10,
     @SortBy = 'CustomerName',
     @SortOrder = 'ASC';
*/
CREATE PROCEDURE [dbo].[GetOrderTracking] (
	@TenantId INT
	,@OrderId BIGINT = NULL
	,@FromDate DATETIME = NULL
	,@ToDate DATETIME = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'OrderNo'
	,@SortOrder VARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT O.OrderTrackId
			,O.TenantId
			,O.ProductId
			,O.Quantity
			,O.OrderId
			,O.OrderNo
			,O.CustomerId
			,O.CustomerName
			,O.LastModifiedBy
			,O.LastModifiedDate
			,O.LastModifiedUtcDate
			,COUNT(1) OVER () AS TotalCount
		FROM dbo.OrderTrack O WITH (NOLOCK)
		WHERE O.TenantId = @TenantId
			AND (
				@OrderId IS NULL
				OR O.OrderId = @OrderId
				)
			AND O.IsDeleted = 0
			AND (
				@FromDate IS NULL
				OR O.LastModifiedDate >= @FromDate
				)
			AND (
				@ToDate IS NULL
				OR O.LastModifiedDate < DATEADD(DAY, 1, @ToDate)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'ProductId'
					AND @SortOrder = 'ASC'
					THEN O.ProductId
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductId'
					AND @SortOrder = 'DESC'
					THEN O.ProductId
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderId'
					AND @SortOrder = 'ASC'
					THEN O.OrderId
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderId'
					AND @SortOrder = 'DESC'
					THEN O.OrderId
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN O.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN O.OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerId'
					AND @SortOrder = 'ASC'
					THEN O.CustomerId
				END ASC
			,CASE 
				WHEN @SortBy = 'CustomerId'
					AND @SortOrder = 'DESC'
					THEN O.CustomerId
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN O.CustomerName
				END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN O.CustomerName
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedDate'
					AND @SortOrder = 'ASC'
					THEN O.LastModifiedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'LastModifiedDate'
					AND @SortOrder = 'DESC'
					THEN O.LastModifiedDate
				END DESC
			,O.LastModifiedDate 
			
		DESC OFFSET(@PageIndex - 1) * @PageSize ROWS
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
END;

GO

