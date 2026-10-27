/*
EXEC SearchProductsAndFabrics
	@TenantId = 2
	,@Search = 'Dex'
	,@IsAddOn =1
	,@IsFabric =NULL
	,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
*/
CREATE PROCEDURE [dbo].[SearchProductsAndFabrics] (
	@TenantId INT
	,@Search VARCHAR(1024)
	,@IsAddOn BIT
	,@IsFabric BIT = NULL
	,@RoleId NVARCHAR(100)
	)
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		-- Wholesaler visibility permission check
		DECLARE @HasWholesalerPermission BIT = 0

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.WholeselerPrice'
						,'Permissions.General.Order.WholeselerPrice'
						)
				)
			SET @HasWholesalerPermission = 1

		SELECT PT.ProductId AS Id
			,PT.ProductTitle AS Title
			,PT.ModelNo AS Number
			,CONCAT (
				'in '
				,CT.CategoryName
				) AS [Type]
			,ST.SubjectTypeId
			,CAST(CASE 
					WHEN CT.CategoryTypeId = 2
						THEN 1
					ELSE 0
					END AS BIT) AS IsFabric
			,PT.CoverImage AS CoverImage
		FROM Products PT WITH (NOLOCK)
		INNER JOIN Categories CT WITH (NOLOCK) ON PT.CategoryId = CT.CategoryId
		INNER JOIN SubjectTypes ST WITH (NOLOCK) ON ST.TenantId = PT.TenantId
			AND ST.SubjectTypeName = 'Products'
		WHERE PT.Status = 1
			AND PT.TenantId = @TenantId
			AND (
				@IsFabric IS NULL
				--OR (
				--	CT.CategoryTypeId = 1
				--	AND @IsFabric = 0
				--	)
				OR (
					CT.CategoryTypeId = 2
					AND @IsFabric = 1
					)
				)
			AND (
				PT.ProductTitle LIKE '%' + @Search + '%'
				OR PT.ModelNo LIKE '%' + @Search + '%'
				OR CT.CategoryName LIKE '%' + @Search + '%'
				)
			AND (
				@IsAddOn = 0
				OR CT.IsVisibleInAddOn = @IsAddOn
				)
			AND (
				PT.IsVisibleToWholesalers = 0
				OR (
					PT.IsVisibleToWholesalers = 1
					AND @HasWholesalerPermission = 1
					)
				);
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

