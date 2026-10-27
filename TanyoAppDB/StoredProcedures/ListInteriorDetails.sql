CREATE PROC [dbo].[ListInteriorDetails] (
	@TenantId BIGINT
	,@InteriorName VARCHAR(100) = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@SmartAddressSearch VARCHAR(100) = NULL
	,@LocationID VARCHAR(500) = NULL
	,@IsSubscribe BIT
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'LastModifiedOn'
	,@SortOrder VARCHAR(10) = 'DESC'
	,@Salesman BIGINT = NULL
	,@Tags BIGINT = NULL
	,@ProfessionId INT = NULL
	,@RefferedBy BIGINT = NULL
	,@SpecializedInId BIGINT = NULL
	,@ArchitectCategoryId INT = NULL
	,@ArchitectTypeId INT = NULL
	,@EventId INT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @LookupId INT;
		DECLARE @SpecializedInLookupIds TABLE (Id INT);

		SELECT @LookupId = LookupId
		FROM Lookups
		WHERE TenantId = @TenantId
			AND LookupName LIKE '%Profession%';

		INSERT INTO @SpecializedInLookupIds
		SELECT LookupId
		FROM Lookups
		WHERE TenantId = @TenantId
			AND LookupName LIKE '%Specialized%';

		IF OBJECT_ID('tempdb..#TempInteriors') IS NOT NULL
		BEGIN
			DROP TABLE #TempInteriors
		END

		CREATE TABLE #TempInteriors (
			CustomerId BIGINT
			,InteriorName VARCHAR(100)
			,EmailAddress VARCHAR(100)
			,PhoneNumber VARCHAR(16)
			,Salesman VARCHAR(100)
			,RefferedBy VARCHAR(100)
			,Area VARCHAR(100)
			,Pincode VARCHAR(6)
			,LastModifiedOn VARCHAR(100)
			,LocationName VARCHAR(100)
			,TotalCount BIGINT
			,IsSubscribe BIT
			,LabelName VARCHAR(100)
			,LabelColorCode VARCHAR(20)
			,LabelId BIGINT
			,ProfessionId INT
			,ProfessionName VARCHAR(50)
			,SpecializedInId BIGINT
			,SpecializedInName VARCHAR(50)
			,ArchitectCategoryId INT
			,ArchitectCategoryName VARCHAR(100)
			,ArchitectTypeId INT
			,ArchitectTypeName VARCHAR(100)
			,EventId INT
			,EventName VARCHAR(100)
			);

		INSERT INTO #TempInteriors (
			CustomerId
			,InteriorName
			,EmailAddress
			,PhoneNumber
			,Salesman
			,RefferedBy
			,Area
			,Pincode
			,LastModifiedOn
			,LocationName
			,TotalCount
			,IsSubscribe
			,LabelName
			,LabelColorCode
			,LabelId
			,ProfessionId
			,ProfessionName
			,SpecializedInId
			,SpecializedInName
			,ArchitectCategoryId
			,ArchitectCategoryName
			,ArchitectTypeId
			,ArchitectTypeName
			,EventId
			,EventName
			)
		SELECT c.CustomerId
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS InteriorName
			,ISNULL(c.EmailId, '') AS EmailAddress
			,c.PhoneNumber
			,au.FirstName + ' ' + au.LastName AS Salesman
			,ISNULL(ref.FirstName + ' ' + ISNULL(ref.LastName, ''), '') AS RefferedBy
			,ISNULL(ca.Area, '') AS Area
			,ISNULL(ca.ZipCode, '') AS Pincode
			,FORMAT(ISNULL(c.UpdatedDate, c.CreatedDate), 'dd/MM/yyyy hh:mm tt') AS LastModifiedOn
			,ISNULL(la.LocationName, '') AS LocationName
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
			,c.IsSubscribe AS IsSubscribe
			,ISNULL(lb.LabelName, '') AS LabelName
			,ISNULL(lb.ColorCode, '') AS LabelColorCode
			,c.LabelId
			,ISNULL(lv.LookupValueId, 0) AS ProfessionId
			,ISNULL(lv.LookupValueName, '') AS ProfessionName
			,ISNULL(c.SpecializedInId, 0) AS SpecializedInId -- Pull directly from Customer table
			,ISNULL(lvS.LookupValueName, '') AS SpecializedInName -- Join Name from lookup values
			,ISNULL(c.ArchitectCategoryId, 0) AS ArchitectCategoryId
			,ISNULL(lvAC.LookupValueName, '') AS ArchitectCategoryName
			,ISNULL(c.ArchitectTypeId, 0) AS ArchitectTypeId
			,ISNULL(lvAT.LookupValueName, '') AS ArchitectTypeName
			,ISNULL(c.EventId, 0) AS EventId
			,ISNULL(lvEV.LookupValueName, '') AS EventName
		FROM dbo.Customers c WITH (NOLOCK)
		INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = c.CreatedBy
		LEFT JOIN dbo.AspNetUsers auu WITH (NOLOCK) ON auu.UserId = c.UpdatedBy
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = c.LocationID
		LEFT JOIN dbo.Labels lb WITH (NOLOCK) ON lb.LabelId = c.LabelId
			AND la.TenantID = c.TenantId
			AND la.IsDeleted = 0
		LEFT JOIN dbo.CustomerAddresses ca WITH (NOLOCK) ON ca.CustomerId = c.CustomerId
			AND ca.IsDeleted = 0
			AND ca.IsDefault = 1
		LEFT JOIN dbo.Customers ref WITH (NOLOCK) ON ref.CustomerId = c.RefferedBy
		LEFT JOIN LookupValues lv WITH (NOLOCK) ON lv.LookupValueId = c.ProfessionId
			AND lv.IsDeleted = 0
			AND (
				lv.LookupId = @LookupId
				OR @LookupId IS NULL
				)
		LEFT JOIN LookupValues lvS WITH (NOLOCK) ON lvS.LookupValueId = c.SpecializedInId
			AND lvS.IsDeleted = 0
			AND (
				lvS.LookupId IN (
					SELECT Id
					FROM @SpecializedInLookupIds
					)
				OR NOT EXISTS (
					SELECT 1
					FROM @SpecializedInLookupIds
					)
				)
		LEFT JOIN LookupValues lvAC WITH (NOLOCK) ON lvAC.LookupValueId = c.ArchitectCategoryId
			AND lvAC.IsDeleted = 0
		LEFT JOIN LookupValues lvAT WITH (NOLOCK) ON lvAT.LookupValueId = c.ArchitectTypeId
			AND lvAT.IsDeleted = 0
		LEFT JOIN LookupValues lvEV WITH (NOLOCK) ON lvEV.LookupValueId = c.EventId
			AND lvEV.IsDeleted = 0
		WHERE c.TenantId = @TenantID
			AND c.CustomerTypeId = 2 -- Interiors              
			AND c.IsDeleted = 0
			AND (
				@IsSubscribe IS NULL
				OR c.IsSubscribe = @IsSubscribe
				)
			AND (
				@InteriorName IS NULL
				OR (ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @InteriorName + '%'
				)
			AND (
				@PhoneNumber IS NULL
				OR (
					c.PhoneNumber LIKE '%' + @PhoneNumber + '%'
					OR c.AltPhoneNumber LIKE '%' + @PhoneNumber + '%'
					)
				)
			AND (
				@FromDate IS NULL
				OR (CAST(ISNULL(c.UpdatedDate, c.CreatedDate) AS DATE) >= @FromDate)
				)
			AND (
				@ToDate IS NULL
				OR (CAST(ISNULL(c.UpdatedDate, c.CreatedDate) AS DATE) <= @ToDate)
				)
			AND (
				@ProfessionId IS NULL
				OR c.ProfessionId = @ProfessionId
				)
			AND (
				@SpecializedInId IS NULL
				OR c.SpecializedInId = @SpecializedInId
				)
			AND (
				@ArchitectCategoryId IS NULL
				OR c.ArchitectCategoryId = @ArchitectCategoryId
				)
			AND (
				@ArchitectTypeId IS NULL
				OR c.ArchitectTypeId = @ArchitectTypeId
				)
			AND (
				@EventId IS NULL
				OR c.EventId = @EventId
				)
			AND (
				@SmartAddressSearch IS NULL
				OR EXISTS (
					SELECT 1
					FROM dbo.CustomerAddresses ca2 WITH (NOLOCK)
					WHERE ca2.CustomerId = c.CustomerId
						AND ca2.IsDeleted = 0
						AND (
							ca2.Street1 LIKE '%' + @SmartAddressSearch + '%'
							OR ca2.Street2 LIKE '%' + @SmartAddressSearch + '%'
							OR ca2.Landmark LIKE '%' + @SmartAddressSearch + '%'
							OR ca2.Area LIKE '%' + @SmartAddressSearch + '%'
							OR ca2.City LIKE '%' + @SmartAddressSearch + '%'
							OR ca2.STATE LIKE '%' + @SmartAddressSearch + '%'
							OR ca2.ZipCode LIKE '%' + @SmartAddressSearch + '%'
							)
					)
				)
			AND (
				@LocationID IS NULL
				OR c.LocationID IN (
					SELECT value
					FROM STRING_SPLIT(@LocationID, ',')
					)
				)
			AND (
				@Salesman IS NULL
				OR au.UserId = @Salesman
				)
			AND (
				@Tags IS NULL
				OR c.LabelId = @Tags
				)
			AND (
				@RefferedBy IS NULL
				OR c.RefferedBy = @RefferedBy
				)
		ORDER BY CASE 
				WHEN @SortBy = 'InteriorName'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
				END ASC
			,CASE 
				WHEN @SortBy = 'InteriorName'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'EmailAddress'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.EmailId, '')
				END
			,CASE 
				WHEN @SortBy = 'EmailAddress'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.EmailId, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.PhoneNumber, '')
				END
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.PhoneNumber, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'ASC'
					THEN (au.FirstName + ' ' + au.LastName)
				END
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'DESC'
					THEN (au.FirstName + ' ' + au.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'Area'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ca.Area, '')
				END
			,CASE 
				WHEN @SortBy = 'Area'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ca.Area, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'Pincode'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ca.ZipCode, '')
				END
			,CASE 
				WHEN @SortBy = 'Pincode'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ca.ZipCode, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'LocationName'
					AND @SortOrder = 'ASC'
					THEN la.LocationName
				END
			,CASE 
				WHEN @SortBy = 'LocationName'
					AND @SortOrder = 'DESC'
					THEN la.LocationName
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedOn'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.UpdatedDate, c.CreatedDate)
				END
			,CASE 
				WHEN @SortBy = 'LastModifiedOn'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.UpdatedDate, c.CreatedDate)
				END DESC
			,CASE 
				WHEN @SortBy = 'Profession'
					AND @SortOrder = 'ASC'
					THEN ISNULL(lv.LookupValueName, '')
				END
			,CASE 
				WHEN @SortBy = 'Profession'
					AND @SortOrder = 'DESC'
					THEN ISNULL(lv.LookupValueName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'SpecializedIn'
					AND @SortOrder = 'ASC'
					THEN ISNULL(lvS.LookupValueName, '')
				END
			,CASE 
				WHEN @SortBy = 'SpecializedIn'
					AND @SortOrder = 'DESC'
					THEN ISNULL(lvS.LookupValueName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'ArchitectCategory'
					AND @SortOrder = 'ASC'
					THEN ISNULL(lvAC.LookupValueName, '')
				END
			,CASE 
				WHEN @SortBy = 'ArchitectCategory'
					AND @SortOrder = 'DESC'
					THEN ISNULL(lvAC.LookupValueName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'ArchitectType'
					AND @SortOrder = 'ASC'
					THEN ISNULL(lvAT.LookupValueName, '')
				END
			,CASE 
				WHEN @SortBy = 'ArchitectType'
					AND @SortOrder = 'DESC'
					THEN ISNULL(lvAT.LookupValueName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'Event'
					AND @SortOrder = 'ASC'
					THEN ISNULL(lvEV.LookupValueName, '')
				END
			,CASE 
				WHEN @SortBy = 'Event'
					AND @SortOrder = 'DESC'
					THEN ISNULL(lvEV.LookupValueName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'RefferedBy'
					AND @SortOrder = 'ASC'
					THEN ISNULL(ref.FirstName + ' ' + ISNULL(ref.LastName, ''), '')
				END
			,CASE 
				WHEN @SortBy = 'RefferedBy'
					AND @SortOrder = 'DESC'
					THEN ISNULL(ref.FirstName + ' ' + ISNULL(ref.LastName, ''), '')
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;

		WITH cteVisits
		AS (
			SELECT tc.CustomerId
				,COUNT(cv.CustomerVisitId) AS TotalVisits
			FROM dbo.CustomerVisits cv WITH (NOLOCK)
			INNER JOIN #TempInteriors tc ON tc.CustomerId = cv.CustomerId
			GROUP BY tc.CustomerId
			)
			,cteOrders
		AS (
			SELECT tc.CustomerId
				,COUNT(o.OrderId) AS TotalCreatedOrder
			FROM dbo.Orders o WITH (NOLOCK)
			INNER JOIN #TempInteriors tc ON tc.CustomerId = o.CustomerID
			WHERE o.TenantId = @TenantID
				AND o.Status <> 9
			GROUP BY tc.CustomerId
			)
			,cteOrdersRefer
		AS (
			SELECT tc.CustomerId
				,COUNT(o.OrderId) AS TotalReferredOrder
			FROM dbo.Orders o WITH (NOLOCK)
			INNER JOIN #TempInteriors tc ON tc.CustomerId = o.RefferedBy
			WHERE o.TenantId = @TenantID
				AND o.Status <> 9
			GROUP BY tc.CustomerId
			)
		SELECT c.CustomerId
			,c.InteriorName
			,c.EmailAddress
			,c.PhoneNumber
			,c.Salesman
			,c.RefferedBy
			,c.Area
			,c.Pincode
			,c.LastModifiedOn
			,ISNULL(cv.TotalVisits, 0) AS Visits
			,ISNULL(co.TotalCreatedOrder, 0) AS OrderCreated
			,ISNULL(cor.TotalReferredOrder, 0) AS OrderReferred
			,c.LocationName
			,c.TotalCount
			,c.IsSubscribe
			,c.LabelName
			,c.LabelColorCode AS ColorCode
			,c.LabelId
			,c.ProfessionId
			,c.ProfessionName
			,c.SpecializedInId
			,c.SpecializedInName
			,c.ArchitectCategoryId
			,c.ArchitectCategoryName
			,c.ArchitectTypeId
			,c.ArchitectTypeName
			,c.EventId
			,c.EventName
		FROM #TempInteriors c
		LEFT JOIN cteVisits cv ON cv.CustomerId = c.CustomerId
		LEFT JOIN cteOrders co ON co.CustomerId = c.CustomerId
		LEFT JOIN cteOrdersRefer cor ON cor.CustomerId = c.CustomerId

		IF OBJECT_ID('tempdb..#TempInteriors') IS NOT NULL
		BEGIN
			DROP TABLE #TempInteriors
		END
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				)
	END CATCH
END

GO

