/*
	EXEC dbo.GetFabricCatalog
		@TenantId = 2
		,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
*/
CREATE PROC [dbo].[GetFabricCatalog] (
	@TenantId BIGINT
	,@RoleId NVARCHAR(50)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @HasWholesalerPrice BIT = 0

		IF (
				@RoleId IS NOT NULL
				AND @RoleId <> ''
				)
		BEGIN
			SELECT @HasWholesalerPrice = CASE 
					WHEN EXISTS (
							SELECT 1
							FROM AspNetRoleClaims WITH (NOLOCK)
							WHERE RoleId = @RoleId
								AND ClaimValue IN (
									'Permissions.App.Order.WholeselerPrice'
									,'Permissions.General.Order.WholeselerPrice'
									)
							)
						THEN 1
					ELSE 0
					END;
		END

		SELECT fb.[FabricId]
			,fb.[Title]
			,fb.[ModelNo]
			,c.CompanyId
			,c.CompanyName
			,lv.LookupValueName AS UnitName
			,CASE 
				WHEN @HasWholesalerPrice = 1
					THEN fb.WholesalerPrice
				ELSE fb.RetailerPrice
				END AS [UnitPrice]
			,fb.[ImagePath]
			,fb.[GST]
			,fb.[ImageColorCode]
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM [dbo].[Fabrics] fb WITH (NOLOCK)
		INNER JOIN dbo.Companies c WITH (NOLOCK) ON c.CompanyId = fb.CompanyId
			AND c.TenantId = fb.TenantId
		INNER JOIN dbo.LookupValues lv WITH (NOLOCK) ON lv.LookupValueId = fb.UnitId
		INNER JOIN dbo.Lookups l WITH (NOLOCK) ON l.LookupId = lv.LookupId
			AND l.TenantId = @TenantId
			AND l.LookupName = 'Unit'
		WHERE fb.[TenantId] = @TenantId
			AND fb.IsDeleted = 0
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

