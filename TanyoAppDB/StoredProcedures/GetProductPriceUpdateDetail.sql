CREATE   PROCEDURE [dbo].[GetProductPriceUpdateDetail] (
	@TenantId INT
	,@ProductId BIGINT
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy NVARCHAR(50) = 'UpdatedDate'
	,@SortOrder NVARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT CONCAT (
			AU.FirstName
			,' '
			,AU.LastName
			) AS UserName
		,AL.CreatedDate AS UpdatedDate
		,AL.OldValue
		,AL.NewValue
		,Actions
		,COUNT(*) OVER () AS TotalCount
	FROM AuditLogs AL WITH (NOLOCK)
	INNER JOIN AspNetUsers AU WITH (NOLOCK) ON AL.CreatedBy = AU.UserId
	INNER JOIN UserTenantMapping UTM WITH (NOLOCK) ON AU.UserId = UTM.UserId
		AND UTM.TenantId = @TenantId
	WHERE tablename = 'Product'
		AND FieldName = 'CostPrice'
		AND TableKey = @Productid
	ORDER BY CASE 
			WHEN @SortBy = 'UpdatedDate'
				AND @SortOrder = 'ASC'
				THEN AL.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'UpdatedDate'
				AND @SortOrder = 'DESC'
				THEN AL.CreatedDate
			END DESC
		,CASE 
			WHEN @SortBy = 'UserName'
				AND @SortOrder = 'ASC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						)
			END ASC
		,CASE 
			WHEN @SortBy = 'UserName'
				AND @SortOrder = 'DESC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						)
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

