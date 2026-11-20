CREATE   PROCEDURE [dbo].[ReportOrderSummaryFromLeads] (
	@TenantId BIGINT
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@SalesmanId BIGINT = NULL
	,@ProductCategory VARCHAR(MAX) = NULL
	,@LeadStatus INT = NULL
	,@LeadSourceId BIGINT = NULL
	,@HasOrder BIT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy NVARCHAR(50) = 'OrderCount'
	,@SortOrder NVARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SELECT L.CreatedDate AS LeadCreatedDate
		,CONCAT (
			C.FirstName
			,' '
			,ISNULL(C.LastName, '')
			) AS CustomerName
		,C.PhoneNumber AS CustomerContactNumber
		,CONCAT (
			AU.FirstName
			,' '
			,ISNULL(AU.LastName, '')
			) AS SalesmanName
		,ISNULL(L.InquiryFor, '') ProductCategory
		,L.STATUS AS CurrentLeadStatus
		,ISNULL(OC.OrderCount, 0) AS OrderCount
		,F.FollowUpDate
		,L.LeadSourceId
		,ISNULL(LKV.LookupValueName, ISNULL(L.Other, 'Other')) AS LeadSourceName
		,CASE 
			WHEN ISNULL(OC.OrderCount, 0) = 0
				THEN 0
			ELSE 1
			END AS HasOrder
		,C.CustomerId
		,COUNT(*) OVER () AS TotalCount
	FROM [dbo].[Leads] L WITH (NOLOCK)
	LEFT JOIN Customers C WITH (NOLOCK) ON C.CustomerId = L.CustomerId
		AND C.IsDeleted = 0
	LEFT JOIN AspNetUsers AU WITH (NOLOCK) ON AU.UserId = L.SalesmanId
	LEFT JOIN LookupValues LKV WITH (NOLOCK) ON L.LeadSourceId = LKV.LookupValueId
	OUTER APPLY (
		SELECT COUNT(ORD.OrderId) AS OrderCount
		FROM Orders ORD WITH (NOLOCK)
		WHERE L.CustomerId = ORD.CustomerID
			AND ORD.STATUS <> 9
			AND CAST(ORD.CreatedDate AS DATE) >= CAST(L.CreatedDate AS DATE)
		GROUP BY ORD.CustomerID --,ORD.SalesmanId 
		) OC
	OUTER APPLY (
		SELECT TOP 1 FLC.FollowUpDate
		FROM FollowUpLeads FLC WITH (NOLOCK)
		WHERE FLC.LeadId = L.LeadId
		ORDER BY FLC.FollowUpDate DESC
		) F
	WHERE L.TenantId = @TenantId
		AND L.STATUS <> 6
		AND (
			(
				@FromDate IS NULL
				AND @ToDate IS NULL
				)
			OR CAST(L.CreatedDate AS DATE) BETWEEN @FromDate
				AND @ToDate
			)
		AND (
			@SalesmanId IS NULL
			OR L.SalesmanId = @SalesmanId
			)
		AND (
			@ProductCategory IS NULL
			OR EXISTS (
				SELECT 1
				FROM STRING_SPLIT(L.InquiryFor, ',') s
				WHERE LTRIM(RTRIM(s.value)) = @ProductCategory
				)
			)
		AND (
			@LeadStatus IS NULL
			OR L.STATUS = @LeadStatus
			)
		AND (
			@LeadSourceId IS NULL
			OR L.LeadSourceId = @LeadSourceId
			)
		AND (
			@HasOrder IS NULL
			OR CASE 
				WHEN ISNULL(OC.OrderCount, 0) = 0
					THEN 0
				ELSE 1
				END = @HasOrder
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
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'ASC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,ISNULL(AU.LastName, '')
						)
			END ASC
		,CASE 
			WHEN @SortBy = 'SalesmanName'
				AND @SortOrder = 'DESC'
				THEN CONCAT (
						AU.FirstName
						,' '
						,ISNULL(AU.LastName, '')
						)
			END DESC
		,CASE 
			WHEN @SortBy = 'OrderCount'
				AND @SortOrder = 'ASC'
				THEN ISNULL(OC.OrderCount, 0)
			END ASC
		,CASE 
			WHEN @SortBy = 'OrderCount'
				AND @SortOrder = 'DESC'
				THEN ISNULL(OC.OrderCount, 0)
			END DESC
		,CASE 
			WHEN @SortBy = 'CustomerContactNumber'
				AND @SortOrder = 'ASC'
				THEN C.PhoneNumber
			END ASC
		,CASE 
			WHEN @SortBy = 'CustomerContactNumber'
				AND @SortOrder = 'DESC'
				THEN C.PhoneNumber
			END DESC
		,CASE 
			WHEN @SortBy = 'LeadCreatedDate'
				AND @SortOrder = 'ASC'
				THEN L.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'LeadCreatedDate'
				AND @SortOrder = 'DESC'
				THEN L.CreatedDate
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
			WHEN @SortBy = 'LeadSourceName'
				AND @SortOrder = 'ASC'
				THEN ISNULL(LKV.LookupValueName, 'Other')
			END ASC
		,CASE 
			WHEN @SortBy = 'LeadSourceName'
				AND @SortOrder = 'DESC'
				THEN ISNULL(LKV.LookupValueName, 'Other')
			END DESC
		,CASE 
			WHEN @SortBy = 'CurrentLeadStatus'
				AND @SortOrder = 'ASC'
				THEN L.STATUS
			END ASC
		,CASE 
			WHEN @SortBy = 'CurrentLeadStatus'
				AND @SortOrder = 'DESC'
				THEN L.STATUS
			END DESC
		,CASE 
			WHEN @SortBy = 'ProductCategory'
				AND @SortOrder = 'ASC'
				THEN ISNULL(L.InquiryFor, '')
			END ASC
		,CASE 
			WHEN @SortBy = 'ProductCategory'
				AND @SortOrder = 'DESC'
				THEN ISNULL(L.InquiryFor, '')
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

