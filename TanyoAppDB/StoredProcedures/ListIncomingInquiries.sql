

/*
	EXEC dbo.ListIncomingInquiries
		@TenantId = 87
		,@VendorId = -1
		,@Status = -1
		,@PageIndex = 1
		,@PageSize = 50
*/
CREATE   PROC [dbo].[ListIncomingInquiries]
(
	@TenantId INT
	,@VendorId INT = -1
	,@Status INT = -1
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
		,ISNULL(t.FirstName, '') + ' ' + ISNULL(t.LastName, '') + ' - ' + ISNULL(t.TenantName, '') AS VendorName 
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
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM BackInquiries bi WITH (NOLOCK) 
	INNER JOIN Tenants t WITH (NOLOCK) on bi.TenantID = t.TenantId
	LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = bi.CreatedBy
	LEFT JOIN dbo.AspNetUsers uau WITH (NOLOCK) ON uau.UserId = bi.UpdatedBy
	WHERE bi.ToTenantID = @TenantId
	AND (@VendorId = -1 OR bi.VendorID = @VendorId)
	AND (@Status = -1 OR bi.Status = @Status)
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

