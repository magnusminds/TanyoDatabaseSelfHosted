/*    
	EXEC [dbo].[GetFabricByColor_V2]
		@TenantId = 2
		,@RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'
		,@RED = 255
		,@GREEN = 41
		,@BLUE = 177
		,@TITLE = ''
		,@MODELNO = ''
		,@COMPANYID = 0
		,@PriceFrom = NULL
		,@PriceTo = NULL
		,@PageIndex = 1
		,@PageSize = 40
		,@SortBy = 'Price'
		,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[GetFabricByColor_V2] (
	@TenantId INT = 1
	,@RoleId NVARCHAR(50)
	,@RED INT
	,@GREEN INT
	,@BLUE INT
	,@TITLE VARCHAR(150)
	,@MODELNO VARCHAR(50)
	,@COMPANYID INT
	,@PriceFrom DECIMAL(18, 2) = NULL
	,@PriceTo DECIMAL(18, 2) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = ''
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	-- Max possible color difference (when ImageColorCode is NULL)    
	DECLARE @MaxColorDifference FLOAT = 441.67 --SQRT(POWER(255, 2) + POWER(255, 2) + POWER(255, 2)); -- ≈ 441.67
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

	BEGIN TRY
		SELECT fb.[FabricId]
			,fb.[Title]
			,fb.[ModelNo]
			,CASE 
				WHEN @HasWholesalerPrice = 1
					THEN fb.WholesalerPrice
				ELSE fb.RetailerPrice
				END AS [UnitPrice]
			,fb.[ImagePath]
			,c.CompanyName
			,c.CompanyId
			,lv.LookupValueName AS UnitName
			,fb.[GST]
			,fb.[ImageColorCode]
			,CASE 
				WHEN @HasWholesalerPrice = 1
					THEN fb.WholesalerPrice
				ELSE fb.RetailerPrice
				END AS [FabricPrice]
			,CASE 
				WHEN fb.[ImageColorCode] IS NOT NULL
					THEN SQRT(POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 3) AS INT) - @RED, 2) + -- Red difference
							POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 2) AS INT) - @GREEN, 2) + -- Green difference
							POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 1) AS INT) - @BLUE, 2)) -- Blue difference
				ELSE @MaxColorDifference -- Maximum color difference if ImageColorCode is NULL  
				END AS ColorDifference
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
			AND (
				ISNULL(@TITLE, '') = ''
				OR fb.Title LIKE '%' + @TITLE + '%'
				)
			AND (
				ISNULL(@MODELNO, '') = ''
				OR fb.ModelNo LIKE '%' + @MODELNO + '%'
				)
			AND (
				@COMPANYID = 0
				OR fb.CompanyId = @COMPANYID
				)
			AND (
				@PriceFrom IS NULL
				OR (
					CASE 
						WHEN @HasWholesalerPrice = 1
							THEN fb.WholesalerPrice
						ELSE fb.RetailerPrice
						END
					) >= @PriceFrom
				)
			AND (
				@PriceTo IS NULL
				OR (
					CASE 
						WHEN @HasWholesalerPrice = 1
							THEN fb.WholesalerPrice
						ELSE fb.RetailerPrice
						END
					) <= @PriceTo
				)
		ORDER BY CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN fb.[ModelNo]
				END
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN fb.[ModelNo]
				END DESC
			,CASE 
				WHEN @SortBy = 'Title'
					AND @SortOrder = 'ASC'
					THEN fb.[Title]
				END
			,CASE 
				WHEN @SortBy = 'Title'
					AND @SortOrder = 'DESC'
					THEN fb.[Title]
				END DESC
			,CASE 
				WHEN @SortBy = 'CompanyName'
					AND @SortOrder = 'ASC'
					THEN c.[CompanyName]
				END
			,CASE 
				WHEN @SortBy = 'CompanyName'
					AND @SortOrder = 'DESC'
					THEN c.[CompanyName]
				END DESC
			,CASE 
				WHEN @SortBy = 'Price'
					AND @SortOrder = 'ASC'
					THEN (
							CASE 
								WHEN @HasWholesalerPrice = 1
									THEN fb.WholesalerPrice
								ELSE fb.RetailerPrice
								END
							)
				END
			,CASE 
				WHEN @SortBy = 'Price'
					AND @SortOrder = 'DESC'
					THEN (
							CASE 
								WHEN @HasWholesalerPrice = 1
									THEN fb.WholesalerPrice
								ELSE fb.RetailerPrice
								END
							)
				END DESC
			,CASE 
				WHEN fb.[ImageColorCode] IS NOT NULL
					THEN SQRT(POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 3) AS INT) - @RED, 2) + POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 2) AS INT) - @GREEN, 2) + POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 1) AS INT) - @BLUE, 2))
				ELSE @MaxColorDifference
				END OFFSET(@PageIndex - 1) * @PageSize ROWS

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

