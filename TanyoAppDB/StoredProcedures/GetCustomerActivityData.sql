/*
EXEC dbo.GetCustomerActivityData
	@TenantId = 2
	,@CustomerID = 1
	,@PageIndex = 1
	,@PageSize = 25
	,@SortBy = 'CreatedDate'
	,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[GetCustomerActivityData] (
	@TenantId INT
	,@CustomerId BIGINT
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @CustomerSubjectTypeId BIGINT;

	SELECT @CustomerSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Customers'
		AND TenantId = @TenantId;

	SELECT AL.ActivityLogID
		,AL.SubjectTypeId
		,AL.SubjectId
		,AL.Description
		,AL.Action
		,AL.CreatedBy
		,CONCAT (
			AU.FirstName
			,' '
			,AU.LastName
			) AS CreatedByName
		,AL.CreatedDate
		,AL.CreatedUTCDate
		,COUNT(*) OVER () AS TotalCount
	FROM ActivityLogs AL WITH (NOLOCK)
	INNER JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = AL.CreatedBy
		AND AU.IsDeleted = 0
	WHERE AL.SubjectTypeId = @CustomerSubjectTypeId
		AND (AL.SubjectId = @CustomerId)
	ORDER BY CASE 
			WHEN @SortBy = 'CreatedDate'
				AND @SortOrder = 'ASC'
				THEN AL.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'CreatedDate'
				AND @SortOrder = 'DESC'
				THEN AL.CreatedDate
			END DESC
		,CASE 
			WHEN @SortBy = 'CreatedByName'
				AND @SortOrder = 'ASC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						)
			END ASC
		,CASE 
			WHEN @SortBy = 'CreatedByName'
				AND @SortOrder = 'DESC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						)
			END DESC
		,CASE 
			WHEN @SortBy = 'Action'
				AND @SortOrder = 'ASC'
				THEN AL.Action
			END ASC
		,CASE 
			WHEN @SortBy = 'Action'
				AND @SortOrder = 'DESC'
				THEN AL.Action
			END DESC
		,CASE 
			WHEN @SortBy = 'Description'
				AND @SortOrder = 'ASC'
				THEN AL.Description
			END ASC
		,CASE 
			WHEN @SortBy = 'Description'
				AND @SortOrder = 'DESC'
				THEN AL.Description
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

