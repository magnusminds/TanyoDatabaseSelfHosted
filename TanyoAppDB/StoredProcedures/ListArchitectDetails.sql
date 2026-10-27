/*
    EXEC [dbo].[ListArchitectDetails]
        @TenantId = 1207,
        @CustomerName = NULL,
        @PhoneNumber = NULL,
        @FromDate = NULL,
        @ToDate = NULL,
        @IsSubscribe = NULL,
        @SalesmanId = NULL,
        @SmartAddressSearch = NULL,
        @LocationID = NULL,
        @Tags = NULL,
        @ProfessionId = NULL,
        @RefferedBy = NULL,
        @SpecializedInId = NULL,
        @ArchitectCategoryId = NULL,
        @ArchitectTypeId = NULL,
        @EventId = NULL,
        @PageIndex = 1,
        @PageSize = 25,
        @SortBy = 'LastModifiedOn',
        @SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[ListArchitectDetails] (
	@TenantId INT
	,@CustomerName VARCHAR(200) = NULL
	,@PhoneNumber VARCHAR(50) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@IsSubscribe BIT = NULL
	,@SalesmanId BIGINT = NULL
	,@SmartAddressSearch VARCHAR(200) = NULL
	,@LocationID VARCHAR(500) = NULL
	,@Tags BIGINT = NULL
	,@ProfessionId INT = NULL
	,@RefferedBy BIGINT = NULL
	,@SpecializedInId BIGINT = NULL
	,@ArchitectCategoryId INT = NULL
	,@ArchitectTypeId INT = NULL
	,@EventId INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'LastModifiedOn'
	,@SortOrder VARCHAR(10) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @CleanSortBy VARCHAR(50) = UPPER(ISNULL(@SortBy, 'LASTMODIFIEDON'));
		DECLARE @CleanSortOrder VARCHAR(4) = UPPER(ISNULL(@SortOrder, 'DESC'));

		IF @CleanSortOrder NOT IN (
				'ASC'
				,'DESC'
				)
			SET @CleanSortOrder = 'DESC';

		DECLARE @OrderByClause VARCHAR(200) = CASE @CleanSortBy
				WHEN 'ARCHITECTNAME'
					THEN 'ArchitectName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'EMAILADDRESS'
					THEN 'EmailAddress ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'PHONENUMBER'
					THEN 'PhoneNumber ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'SALESMAN'
					THEN 'Salesman ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'REFFEREDBYNAME'
					THEN 'RefferedBy ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'AREA'
					THEN 'Area ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'PINCODE'
					THEN 'Pincode ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'LOCATIONNAME'
					THEN 'LocationName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'PROFESSIONNAME'
					THEN 'ProfessionName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'SPECIALIZEDINNAME'
					THEN 'SpecializedInName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'ARCHITECTCATEGORYNAME'
					THEN 'ArchitectCategoryName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'ARCHITECTTYPENAME'
					THEN 'ArchitectTypeName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'EVENTNAME'
					THEN 'EventName ' + @CleanSortOrder + ', CustomerId DESC'
				WHEN 'LASTMODIFIEDON'
					THEN 'RawLastModifiedOn ' + @CleanSortOrder + ', CustomerId DESC'
				ELSE 'RawLastModifiedOn DESC, CustomerId DESC'
				END;
		DECLARE @OffsetRows INT = (@PageIndex - 1) * @PageSize;
		DECLARE @WhereClause NVARCHAR(MAX) = N'
            WHERE cust.TenantId = @TenantId
              AND cust.IsDeleted = 0
              AND cust.CustomerTypeId = 2';

		IF @CustomerName IS NOT NULL
			SET @WhereClause += N' AND (LTRIM(RTRIM(ISNULL(NULLIF(ISNULL(cust.FirstName, '''') + '' '' + ISNULL(cust.LastName, ''''), '' ''), ISNULL(cust.FirstName, '''')))) LIKE ''%'' + @CustomerName + ''%'')';

		IF @PhoneNumber IS NOT NULL
			SET @WhereClause += N' AND cust.PhoneNumber LIKE ''%'' + @PhoneNumber + ''%''';

		IF @FromDate IS NOT NULL
			SET @WhereClause += N' AND cust.CreatedDate >= @FromDate';

		IF @ToDate IS NOT NULL
			SET @WhereClause += N' AND cust.CreatedDate < DATEADD(DAY, 1, @ToDate)';

		IF @IsSubscribe IS NOT NULL
			SET @WhereClause += N' AND cust.IsSubscribe = @IsSubscribe';

		IF @SalesmanId IS NOT NULL
			SET @WhereClause += N' AND cust.CreatedBy = @SalesmanId';

		IF @Tags IS NOT NULL
			SET @WhereClause += N' AND cust.LabelId = @Tags';

		IF @ProfessionId IS NOT NULL
			SET @WhereClause += N' AND cust.ProfessionId = @ProfessionId';

		IF @RefferedBy IS NOT NULL
			SET @WhereClause += N' AND cust.RefferedBy = @RefferedBy';

		IF @SpecializedInId IS NOT NULL
			SET @WhereClause += N' AND cust.SpecializedInId = @SpecializedInId';

		IF @ArchitectCategoryId IS NOT NULL
			SET @WhereClause += N' AND cust.ArchitectCategoryId = @ArchitectCategoryId';

		IF @ArchitectTypeId IS NOT NULL
			SET @WhereClause += N' AND cust.ArchitectTypeId = @ArchitectTypeId';

		IF @EventId IS NOT NULL
			SET @WhereClause += N' AND cust.EventId = @EventId';

		IF @LocationID IS NOT NULL
			SET @WhereClause += N' AND cust.LocationID IN (SELECT value FROM STRING_SPLIT(@LocationID, '',''))';

		IF @SmartAddressSearch IS NOT NULL
			SET @WhereClause += N' AND EXISTS (
                SELECT 1 FROM dbo.CustomerAddresses sca WITH (NOLOCK)
                WHERE sca.CustomerId = cust.CustomerId AND sca.IsDeleted = 0
                  AND (sca.Area LIKE ''%'' + @SmartAddressSearch + ''%''
                       OR sca.City LIKE ''%'' + @SmartAddressSearch + ''%''
                       OR sca.Street1 LIKE ''%'' + @SmartAddressSearch + ''%''
                       OR sca.ZipCode LIKE ''%'' + @SmartAddressSearch + ''%''
                       OR ISNULL(sca.FullAddress, '''') LIKE ''%'' + @SmartAddressSearch + ''%'')
            )';

		DECLARE @Sql NVARCHAR(MAX) = 
			N'
        WITH PaginatedBase AS
        (
            SELECT 
                cust.CustomerId,
                LTRIM(RTRIM(ISNULL(NULLIF(ISNULL(cust.FirstName, '''') + '' '' + ISNULL(cust.LastName, ''''), '' ''), ISNULL(cust.FirstName, '''')))) AS ArchitectName,
                cust.EmailId AS EmailAddress,
                cust.PhoneNumber AS PhoneNumber,
                ISNULL(au.FirstName + '' '' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN '' (Inactive)'' ELSE '''' END, '''') AS Salesman,
                ISNULL(ref.FirstName + '' '' + ISNULL(ref.LastName, ''''), '''') AS RefferedBy,
                ISNULL(sort_addr.Area, '''') AS Area,
                ISNULL(sort_addr.ZipCode, '''') AS Pincode,
                ISNULL(la.LocationName, '''') AS LocationName,
                ISNULL(prof.LookupValueId, 0) AS ProfessionId,
                ISNULL(prof.LookupValueName, '''') AS ProfessionName,
                ISNULL(spec.LookupValueId, 0) AS SpecializedInId,
                ISNULL(spec.LookupValueName, '''') AS SpecializedInName,
                cust.IsSubscribe,
                ISNULL(lbl.LabelId, 0) AS LabelId,
                ISNULL(lbl.LabelName, '''') AS LabelName,
                ISNULL(lbl.ColorCode, '''') AS ColorCode,
                cust.ArchitectCategoryId,
                ISNULL(cat.LookupValueName, '''') AS ArchitectCategoryName,
                cust.ArchitectTypeId,
                ISNULL(typ.LookupValueName, '''') AS ArchitectTypeName,
                cust.EventId,
                ISNULL(evn.LookupValueName, '''') AS EventName,
                ISNULL(cust.UpdatedDate, cust.CreatedDate) AS RawLastModifiedOn,
                COUNT(1) OVER() AS TotalCount
            FROM dbo.Customers cust WITH (NOLOCK)
            LEFT JOIN dbo.Customers ref WITH (NOLOCK) ON cust.RefferedBy = ref.CustomerId AND ref.TenantId = @TenantId AND ref.IsDeleted = 0
            LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = cust.CreatedBy
            LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = cust.LocationID AND la.TenantId = @TenantId AND la.IsDeleted = 0
            LEFT JOIN dbo.Labels lbl WITH (NOLOCK) ON lbl.LabelId = cust.LabelId AND lbl.TenantId = @TenantId AND lbl.IsDeleted = 0
            LEFT JOIN dbo.LookupValues prof WITH (NOLOCK) ON prof.LookupValueId = cust.ProfessionId AND prof.IsDeleted = 0
            LEFT JOIN dbo.LookupValues spec WITH (NOLOCK) ON spec.LookupValueId = cust.SpecializedInId AND spec.IsDeleted = 0
            LEFT JOIN dbo.LookupValues cat WITH (NOLOCK) ON cat.LookupValueId = cust.ArchitectCategoryId AND cat.IsDeleted = 0
            LEFT JOIN dbo.LookupValues typ WITH (NOLOCK) ON typ.LookupValueId = cust.ArchitectTypeId AND typ.IsDeleted = 0
            LEFT JOIN dbo.LookupValues evn WITH (NOLOCK) ON evn.LookupValueId = cust.EventId AND evn.IsDeleted = 0
            OUTER APPLY (
                SELECT TOP 1 ad.Area, ad.ZipCode 
                FROM dbo.CustomerAddresses ad WITH (NOLOCK) 
                WHERE ad.CustomerId = cust.CustomerId AND ad.IsDeleted = 0 
                ORDER BY ad.IsDefault DESC, ad.CustomerAddressId DESC
            ) sort_addr
            ' 
			+ @WhereClause + N'
            ORDER BY ' + @OrderByClause + 
			N'
            OFFSET @OffsetRows ROWS FETCH NEXT @PageSize ROWS ONLY
        )
        SELECT 
            pb.CustomerId,
            pb.ArchitectName,
            pb.EmailAddress,
            pb.PhoneNumber,
            pb.Salesman,
            pb.RefferedBy,
            pb.Area,
            pb.Pincode,
            pb.LocationName,
            pb.ProfessionId,
            pb.ProfessionName,
            pb.SpecializedInId,
            pb.SpecializedInName,
            ISNULL(vis.VisitCount, 0) AS Visits,
            ISNULL(oc.OrderCount, 0) AS OrderCreated,
            ISNULL(refc.OrderCount, 0) AS OrderReferred,
            pb.IsSubscribe,
            pb.LabelId,
            pb.LabelName,
            pb.ColorCode,
            pb.ArchitectCategoryId,
            pb.ArchitectCategoryName,
            pb.ArchitectTypeId,
            pb.ArchitectTypeName,
            pb.EventId,
            pb.EventName,
            pb.RawLastModifiedOn,
            ISNULL(FORMAT(pb.RawLastModifiedOn, ''dd/MM/yyyy hh:mm tt''), '''') AS LastModifiedOn,
            pb.TotalCount
        FROM PaginatedBase pb
        OUTER APPLY (
            SELECT COUNT(1) AS VisitCount FROM dbo.CustomerVisits cv WITH (NOLOCK) WHERE cv.CustomerId = pb.CustomerId
        ) vis
        OUTER APPLY (
            SELECT COUNT(1) AS OrderCount FROM dbo.Orders o WITH (NOLOCK) WHERE o.CustomerID = pb.CustomerId AND o.TenantId = @TenantId
        ) oc
        OUTER APPLY (
            SELECT COUNT(1) AS OrderCount FROM dbo.Orders o WITH (NOLOCK) WHERE o.RefferedBy = pb.CustomerId AND o.TenantId = @TenantId
        ) refc
        ORDER BY ' 
			+ @OrderByClause + N';';

		EXECUTE sp_executesql @Sql
			,N'@TenantId INT, @CustomerName VARCHAR(200), @PhoneNumber VARCHAR(50), @FromDate DATE, @ToDate DATE, @IsSubscribe BIT, @SalesmanId BIGINT, @SmartAddressSearch VARCHAR(200), @LocationID VARCHAR(500), @Tags BIGINT, @ProfessionId INT, @RefferedBy BIGINT, @SpecializedInId BIGINT, @ArchitectCategoryId INT, @ArchitectTypeId INT, @EventId INT, @OffsetRows INT, @PageSize INT'
			,@TenantId = @TenantId
			,@CustomerName = @CustomerName
			,@PhoneNumber = @PhoneNumber
			,@FromDate = @FromDate
			,@ToDate = @ToDate
			,@IsSubscribe = @IsSubscribe
			,@SalesmanId = @SalesmanId
			,@SmartAddressSearch = @SmartAddressSearch
			,@LocationID = @LocationID
			,@Tags = @Tags
			,@ProfessionId = @ProfessionId
			,@RefferedBy = @RefferedBy
			,@SpecializedInId = @SpecializedInId
			,@ArchitectCategoryId = @ArchitectCategoryId
			,@ArchitectTypeId = @ArchitectTypeId
			,@EventId = @EventId
			,@OffsetRows = @OffsetRows
			,@PageSize = @PageSize;
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500) = OBJECT_NAME(@@PROCID)
			,@ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

