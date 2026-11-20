/*
EXEC dbo.GetOrderActivityData
	@TenantId = 2
	,@OrderId = 1
	,@PageIndex = 1
	,@PageSize = 25
	,@SortBy = 'CreatedDate'
	,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[GetOrderActivityData] (
	@TenantId INT
	,@OrderId BIGINT
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
	DECLARE @OrderSubjectTypeId BIGINT;

	SELECT @OrderSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Orders'
		AND TenantId = @TenantId;

	SELECT AL.ActivityLogID
		,AL.SubjectTypeId
		,AL.SubjectId
		,AL.Description
		,AL.Action
		,AL.CreatedBy
		,CASE 
			WHEN AU.IsDeleted = 1
				THEN CONCAT (
						AU.FirstName
						,' '
						,AU.LastName
						,' (Inactive)'
						)
			ELSE CONCAT (
					AU.FirstName
					,' '
					,AU.LastName
					)
			END AS CreatedByName
		,AL.CreatedDate
		,AL.CreatedUTCDate
		,COUNT(*) OVER () AS TotalCount
	FROM ActivityLogs AL WITH (NOLOCK)
	INNER JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = AL.CreatedBy
	WHERE AL.SubjectTypeId = @OrderSubjectTypeId
		AND EXISTS (
			SELECT 1
			FROM Orders ORD WITH (NOLOCK)
			WHERE AL.SubjectId = ORD.OrderId
				AND ORD.STATUS <> 9
			)
		AND (AL.SubjectId = @OrderId)
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

