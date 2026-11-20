/*
	EXEC dbo.ListPORawMaterialByVendor
		@TenantId = 125
	   ,@VendorId = 1
	   ,@Search = ''
*/
CREATE     PROC [dbo].[ListPORawMaterialByVendor]
(
	@TenantId BIGINT
	,@VendorId BIGINT
	,@Search VARCHAR(50) = NULL
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT rw.RawMaterialId
		,rw.Title AS RawMaterialTitle
		,rw.ImagePath AS RawMaterialImage
		,rw.UnitPrice AS VendorRawMaterialPrice
	FROM RawMaterials rw WITH (NOLOCK)
	INNER JOIN Vendors v WITH (NOLOCK) ON v.VendorId = rw.VendorId
		AND v.TenantId = rw.TenantId
	WHERE rw.TenantId = @TenantId
	AND rw.IsDeleted = 0
	AND rw.VendorId = @VendorId
	AND (@Search IS NULL OR @Search = '' OR rw.Title LIKE '%' + @Search + '%')
	ORDER BY 2

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

