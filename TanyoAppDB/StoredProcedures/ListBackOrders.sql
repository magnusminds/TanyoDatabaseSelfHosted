

/*
	EXEC dbo.ListBackOrders
		@TenantId = 88
		,@VendorId = -1
		,@Status = -1
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE   PROC [dbo].[ListBackOrders]
(
	@TenantId INT
   ,@VendorId INT = -1
   ,@Status INT = -1
   ,@FromDate DATETIME = NULL
   ,@ToDate DATETIME = NULL
   ,@PageIndex INT = 1
   ,@PageSize INT = 50
)
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT bi.ID 
		,PONumber 
		,bi.VendorID 
		,CASE WHEN t.TenantId IS NULL THEN v.VendorName ELSE ISNULL(t.FirstName, '') + ' ' + ISNULL(t.LastName, '') + ' - ' + ISNULL(t.TenantName, '') END AS VendorName
		,bi.TenantID 
		,ToTenantID 
		,bi.Status 
		,ISNULL(au.FirstName,'') + ' ' + ISNULL(au.LastName,'') AS CreatedBy 
		,bi.CreatedDate 
		,ISNULL(uau.FirstName,'') + ' ' + ISNULL(uau.LastName,'') AS UpdatedBy 
		,bi.UpdatedDate
		,(SELECT COUNT(1) 
			FROM BackInquiriesItems bii WITH (NOLOCK)
			WHERE bii.BackInquiryID = bi.ID
			) AS TotalProducts
		,latestComment.Comment AS Comment
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM BackInquiries bi WITH (NOLOCK)
	LEFT JOIN Tenants t WITH (NOLOCK) ON bi.ToTenantID = t.TenantId
	LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = bi.CreatedBy
	LEFT JOIN dbo.AspNetUsers uau WITH (NOLOCK) ON uau.UserId = bi.UpdatedBy
	LEFT JOIN Vendors v WITH (NOLOCK) ON v.VendorId = bi.VendorID
		AND v.TenantId = @TenantId
	OUTER APPLY
	(
	SELECT TOP 1 Comment 
	FROM BackInquiriesComments bic WITH (NOLOCK)
	WHERE bic.BackInquiryId = bi.ID
	ORDER BY bic.CreatedUTCDate DESC
	) latestComment
	WHERE bi.TenantID = @TenantId
	AND (@VendorId = -1 OR bi.VendorID = @VendorId)
	AND (@Status = -1 OR bi.Status = @Status)
	AND (@FromDate IS NULL OR CAST(bi.CreatedUTCDate AS DATE) >= CAST(@FromDate AS DATE))
    AND (@ToDate IS NULL OR CAST(bi.CreatedUTCDate AS DATE) <= CAST(@ToDate AS DATE))
	ORDER BY bi.Id DESC
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

