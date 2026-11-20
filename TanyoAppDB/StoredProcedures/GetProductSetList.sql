/*
EXEC GetProductSetList
 @TenantId = 2
 ,@SetName = NULL
 ,@FromDate = NULL
 ,@ToDate = NULL
*/

CREATE   PROCEDURE [dbo].[GetProductSetList] (
	@TenantId INT 
	,@SetName VARCHAR (510) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy NVARCHAR(50) = 'ProductCount'
	,@SortOrder NVARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DECLARE @FromDt DATETIMEOFFSET
		,@ToDt DATETIMEOFFSET

	SET @FromDt = CAST(@FromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
	SET @ToDt = CAST(@ToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

	SELECT PS.ProductSetId
		,PS.SetName
		,PS.Description
		,PS.QRImage
		,PS.SetImage 
		,PS.TenantId
		,PS.IsDeleted
		,CASE 
			WHEN AUU.FirstName IS NULL 
			THEN CONCAT (AUC.FirstName,' ',AUC.LastName)
			ELSE CONCAT ( AUU.FirstName,' ',AUU.LastName) END AS LastModifiedBy
		,ISNULL(PS.UpdatedDate,PS.CreatedDate) AS LastModifiedDate
		,ISNULL(COUNT(PSI.ProductSetItemId), 0) AS ProductCount
		,COUNT(*) OVER() AS TotalCount
	FROM ProductSets PS WITH (NOLOCK)
	INNER JOIN AspNetUsers AUC WITH (NOLOCK) ON AUC.UserId = PS.CreatedBy
	LEFT JOIN AspNetUsers AUU WITH (NOLOCK) ON AUU.UserId = PS.UpdatedBy
	LEFT JOIN ProductSetItems PSI WITH (NOLOCK) ON PSI.ProductSetId = PS.ProductSetId
	WHERE PS.IsDeleted = 0
		AND PS.TenantId = @TenantId
		AND (
			@SetName IS NULL
			OR PS.SetName LIKE '%' + @SetName + '%'
			)
		AND (
			(
				@FromDate IS NULL
				OR @ToDate IS NULL
				)
			OR ISNULL(PS.UpdatedDate,PS.CreatedDate) BETWEEN @FromDt
				AND @ToDt
			)
	GROUP BY PS.ProductSetId
		,PS.SetName
		,PS.Description
		,PS.QRImage
		,PS.SetImage 
		,AUC.FirstName
		,AUC.LastName
		,AUU.FirstName
		,AUU.LastName
		,PS.TenantId
		,PS.IsDeleted
		,PS.CreatedBy
		,PS.CreatedDate
		,PS.UpdatedBy
		,PS.UpdatedDate
	ORDER BY CASE 
			WHEN @SortBy = 'SetName'
				AND @SortOrder = 'ASC'
				THEN PS.SetName
			END ASC
		,CASE 
			WHEN @SortBy = 'SetName'
				AND @SortOrder = 'DESC'
				THEN PS.SetName
			END DESC
		,CASE 
			WHEN @SortBy = 'ProductCount'
				AND @SortOrder = 'ASC'
				THEN ISNULL(COUNT(PSI.ProductSetItemId), 0)
			END ASC
		,CASE 
			WHEN @SortBy = 'ProductCount'
				AND @SortOrder = 'DESC'
				THEN ISNULL(COUNT(PSI.ProductSetItemId), 0)
			END DESC
		,CASE 
			WHEN @SortBy = 'LastModifiedDate'
				AND @SortOrder = 'ASC'
				THEN ISNULL(PS.UpdatedDate,PS.CreatedDate)
			END ASC
		,CASE 
			WHEN @SortBy = 'LastModifiedDate'
				AND @SortOrder = 'DESC'
				THEN ISNULL(PS.UpdatedDate,PS.CreatedDate)
			END DESC		
		,CASE 
			WHEN @SortBy = 'LastModifiedBy'
				AND @SortOrder = 'ASC'
				THEN CASE 
					WHEN AUU.FirstName IS NULL 
					THEN CONCAT (AUC.FirstName,' ',AUC.LastName)
					ELSE CONCAT ( AUU.FirstName,' ',AUU.LastName)
				END
			END ASC
		,CASE 
			WHEN @SortBy = 'LastModifiedBy'
				AND @SortOrder = 'DESC'
				THEN CASE 
					WHEN AUU.FirstName IS NULL 
					THEN CONCAT (AUC.FirstName,' ',AUC.LastName)
					ELSE CONCAT ( AUU.FirstName,' ',AUU.LastName)
				END
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

