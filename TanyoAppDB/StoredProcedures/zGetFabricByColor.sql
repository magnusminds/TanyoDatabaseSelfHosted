/*
	EXEC [dbo].[GetFabricByColor]
		@TenantId  = 1
		,@RED  = 60
		,@GREEN  = 112
		,@BLUE  = 109
		,@PageIndex  = 1
		,@PageSize  = 100
		,@SortBy  = 'ModelNo'
		,@SortOrder  = 'ASC'
*/
CREATE PROCEDURE [dbo].[zGetFabricByColor]
(
	 @TenantId INT
	,@RED INT
	,@GREEN INT
	,@BLUE INT
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

	BEGIN TRY
		
		SELECT fb.[FabricId]
			,fb.[Title]
			,fb.[ModelNo]
			,fb.[UnitPrice]
			,fb.[ImagePath]
			,c.CompanyName
			,lv.LookupValueName AS UnitName
			,fb.[GST]
			,fb.[ImageColorCode]
			-- Calculate the color difference (distance) between the given color and database color
			,CASE WHEN fb.[ImageColorCode] IS NOT NULL THEN
				SQRT(POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 3) AS INT) - @RED, 2) +  -- Red difference
					POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 2) AS INT) - @GREEN, 2) + -- Green difference
					POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 1) AS INT) - @BLUE, 2))   -- Blue difference
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
		-- Add sorting by the color difference or other columns as required
		ORDER BY CASE 
					WHEN fb.[ImageColorCode] IS NOT NULL THEN
						SQRT(POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 3) AS INT) - @RED, 2) +  
								POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 2) AS INT) - @GREEN, 2) + 
								POWER(CAST(PARSENAME(REPLACE(fb.[ImageColorCode], ',', '.'), 1) AS INT) - @BLUE, 2))
					ELSE @MaxColorDifference
				END
			,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN fb.[ModelNo] END
			,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN fb.[ModelNo] END DESC
			,CASE WHEN @SortBy = 'Title' AND @SortOrder = 'ASC' THEN fb.[Title] END
			,CASE WHEN @SortBy = 'Title' AND @SortOrder = 'DESC' THEN fb.[Title] END DESC
			,CASE WHEN @SortBy = 'CompanyName' AND @SortOrder = 'ASC' THEN c.[CompanyName] END
			,CASE WHEN @SortBy = 'CompanyName' AND @SortOrder = 'DESC' THEN c.[CompanyName] END DESC
		OFFSET(@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY;
	END TRY
	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState)
	END CATCH
END

GO

