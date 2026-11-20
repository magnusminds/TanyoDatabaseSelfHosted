/*
	EXEC [dbo].[ReportLeadsMissingFollowUp]
		@TenantId = 2
		,@CustomerId = NULL
		,@Notes = NULL
		,@FromDate = NULL
		,@ToDate = NULL
		,@PageIndex = 1
		,@PageSize = 100
		,@SortBy = 'CustomerName'
		,@SortOrder = 'ASC'
*/
CREATE PROCEDURE [dbo].[ReportLeadsMissingFollowUp] (
	@TenantId BIGINT
	,@CustomerId BIGINT = NULL
	,@Notes NVARCHAR(MAX) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy NVARCHAR(50) = 'CustomerName'
	,@SortOrder NVARCHAR(4) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @Today DATE = CAST(GETDATE() AS DATE);
	DECLARE @DateRange DATE = DATEADD(DAY, - 10, @Today);

	SELECT ISNULL(C.FirstName, '') + ' ' + ISNULL(C.LastName, '') AS CustomerName
		,ISNULL(L.InquiryFor, '') AS InquiryFor
		,ISNULL(L.Notes, '') AS Notes
		,F.FollowUpDate AS FollowUpDate
		,AU.FirstName + ' ' + ISNULL(AU.LastName, '') AS UpdatedBy
		,L.UpdatedDate
		,COUNT(*) OVER() AS TotalCount
	FROM Leads L WITH (NOLOCK)
	OUTER APPLY (
		SELECT TOP 1 F1.FollowUpDate
			,F1.FollowUpComment
		FROM FollowUpLeads F1 WITH (NOLOCK)
		WHERE F1.LeadId = L.LeadId
			AND F1.FollowUpDate BETWEEN @DateRange
				AND @Today
		ORDER BY F1.FollowUpDate DESC
		) F
	LEFT JOIN Customers C WITH (NOLOCK) ON C.CustomerId = L.CustomerId
	LEFT JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = L.UpdatedBy
	WHERE (
			(
				F.FollowUpDate IS NULL
				AND L.LastContactedDate < @DateRange
				)
			--OR (F.FollowUpDate < @DateRange)
			OR (
				F.FollowUpDate < @Today
				AND NOT EXISTS (
					SELECT 1
					FROM LeadComments LC WITH (NOLOCK)
					WHERE LC.LeadId = L.LeadId
						AND CAST(LC.CreatedDate AS DATE) >= F.FollowUpDate
					)
				)
			)
		AND L.STATUS IN (
			0
			,1
			,2
			,3
			)
		AND L.TenantId = @TenantId
		AND (
			@Notes IS NULL
			OR L.Notes LIKE '%' + @Notes + '%'
			)
		AND (
			@CustomerId IS NULL
			OR L.CustomerId =  @CustomerId 
			)
		AND (
			@FromDate IS NULL
			OR L.CreatedDate >= @FromDate
			)
		AND (
			@ToDate IS NULL
			OR L.CreatedDate <= @ToDate
			)
	ORDER BY CASE 
			WHEN @SortBy = 'CustomerName'
				AND @SortOrder = 'ASC'
				THEN ISNULL(C.FirstName, '') + ' ' + ISNULL(C.LastName, '')
			END ASC
		,CASE 
			WHEN @SortBy = 'CustomerName'
				AND @SortOrder = 'DESC'
				THEN ISNULL(C.FirstName, '') + ' ' + ISNULL(C.LastName, '')
			END DESC
		,CASE 
			WHEN @SortBy = 'InquiryFor'
				AND @SortOrder = 'ASC'
				THEN L.InquiryFor
			END ASC
		,CASE 
			WHEN @SortBy = 'InquiryFor'
				AND @SortOrder = 'DESC'
				THEN L.InquiryFor
			END DESC
		,CASE 
			WHEN @SortBy = 'FollowUpDate'
				AND @SortOrder = 'ASC'
				THEN F.FollowUpDate
			END ASC
		,CASE 
			WHEN @SortBy = 'FollowUpDate'
				AND @SortOrder = 'DESC'
				THEN F.FollowUpDate
			END DESC
		,CASE 
			WHEN @SortBy = 'UpdatedBy'
				AND @SortOrder = 'ASC'
				THEN AU.FirstName + ' ' + ISNULL(AU.LastName, '')
			END ASC
		,CASE 
			WHEN @SortBy = 'UpdatedBy'
				AND @SortOrder = 'DESC'
				THEN AU.FirstName + ' ' + ISNULL(AU.LastName, '')
			END DESC
		,CASE 
			WHEN @SortBy = 'UpdatedDate'
				AND @SortOrder = 'ASC'
				THEN L.UpdatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'UpdatedDate'
				AND @SortOrder = 'DESC'
				THEN L.UpdatedDate
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

