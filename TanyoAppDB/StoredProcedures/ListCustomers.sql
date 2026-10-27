/*
 EXEC [dbo].[ListCustomers]
  @TenantID = 1207,
  @CustomerName = NULL, @PhoneNumber = NULL, @FromDate = NULL, @ToDate = NULL,
  @RefferedBy = NULL, @SalesmanID = NULL, @SmartAddressSearch = NULL, @Tags = NULL,
  @LocationID = NULL, @IsSubscribe = NULL, @PageIndex = 1, @PageSize = 25,
  @SortBy = 'LastModifiedOn', @SortOrder = 'DESC', @ProfessionId = NULL,
  -- App grid (Dashboard Customers tile) optional params; NULL = legacy Admin behavior:
  @CustomerTypes = '1,2', @CreatedBy = NULL, @TagsCsv = '5,9'
*/
CREATE PROC [dbo].[ListCustomers] (
	@TenantID INT
	,@CustomerName VARCHAR(100) = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@FromDate DATE = NULL
	,@ToDate DATE = NULL
	,@RefferedBy BIGINT = NULL
	,@SalesmanID BIGINT = NULL
	,@SmartAddressSearch VARCHAR(100) = NULL
	,@Tags BIGINT = NULL
	,@LocationID VARCHAR(500) = NULL
	,@IsSubscribe BIT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'LastModifiedOn'
	,@SortOrder VARCHAR(10) = 'DESC'
	,@ProfessionId INT = NULL
	,@CustomerTypes VARCHAR(20) = NULL -- App grid: CSV of CustomerTypeId (1=Customer, 2=Interior); NULL = legacy Admin behavior (Customers only)
	,@CreatedBy VARCHAR(200) = NULL -- App grid: free-text contains search on creator full name
	,@TagsCsv VARCHAR(200) = NULL -- App grid: CSV of LabelId; NULL = legacy @Tags applies
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @SQL NVARCHAR(MAX)
			,@SortSQL NVARCHAR(MAX)
			,@FilterSQL NVARCHAR(MAX)
			,@PageSQL NVARCHAR(MAX)
			,@LookupId INT = NULL
			,@FromDateTime DATETIMEOFFSET = NULL
			,@ToDateTime DATETIMEOFFSET = NULL
			,@params NVARCHAR(max) = N'@TenantId BIGINT,@CustomerName VARCHAR(100),@PhoneNumber VARCHAR(16),
       @FromDateTime DATETIMEOFFSET,@ToDateTime DATETIMEOFFSET ,@RefferedBy BIGINT, @SalesmanId BIGINT,
       @SmartAddressSearch VARCHAR(100),@Tags BIGINT,@LocationID VARCHAR(500),
       @IsSubscribe BIT,@ProfessionId INT,@LookupId INT OUTPUT,
       @CustomerTypes VARCHAR(20),@CreatedBy VARCHAR(200),@TagsCsv VARCHAR(200)';

		SELECT @FromDateTime = CAST(@FromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@ToDateTime = CAST(@ToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		SELECT @LookupId = LookupId
		FROM Lookups
		WHERE TenantId = @TenantId
			AND LookupName LIKE '%Profession%';

		SET @LookupId = ISNULL(@LookupId, 0);
		SET @SQL = N'SELECT
            CAST(c.CustomerID AS BIGINT) as CustomerID,
            CAST(ISNULL(c.LabelId, 0) AS BIGINT) AS LabelID,
            ISNULL(l.LabelName, '''') AS LabelName,
            ISNULL(l.ColorCode, '''') AS ColorCode,
            ISNULL(c.FirstName, '''') + '' '' + ISNULL(c.LastName, '''') AS CustomerName,
   ISNULL(ref.FirstName + '' '' + ISNULL(ref.LastName, ''''), '''') AS RefferedBy,
            ISNULL(c.EmailId, '''') AS EmailAddress,
            c.PhoneNumber,
   c.IsSubscribe as IsSubscribe,
            ' + CASE 
				WHEN @TenantID <> 120
					THEN 'au.FirstName + '' '' + au.LastName'
				END + 
			' AS Salesman,
            ISNULL(ca.Area,'''') AS Area,
   ISNULL(ca.ZipCode, '''') AS Pincode,
            ISNULL(la.LocationName, '''') AS LocationName,
            --(SELECT COUNT(*) FROM dbo.CustomerVisits v WHERE v.CustomerId = c.CustomerID) AS Visits,
            --(SELECT COUNT(*) FROM dbo.Orders o WHERE o.CustomerId = c.CustomerID) AS Orders,
   CAST((SELECT COUNT(1) FROM dbo.CustomerVisits v WITH (NOLOCK) WHERE v.CustomerId = c.CustomerID) AS INT) AS Visits,
   CAST((SELECT COUNT(1) FROM dbo.Orders o WITH (NOLOCK) WHERE o.CustomerId = c.CustomerID AND o.status <> 9) AS INT) AS Orders,
   ISNULL(lv.LookupId,0) AS ProfessionId,
   ISNULL(lv.LookupValueName, '''') AS ProfessionName,
   FORMAT(ISNULL(c.UpdatedDate, c.CreatedDate), ''dd/MM/yyyy hh:mm tt'') AS LastModifiedOn,
            CAST(c.CustomerTypeId AS INT) AS CustomerTypeId,
            CASE c.CustomerTypeId WHEN 2 THEN ''Interior'' ELSE ''Customer'' END AS CustomerType,
            ISNULL(cu.FirstName, '''') + '' '' + ISNULL(cu.LastName, '''') AS CreatedByName,
            CAST(COUNT(1) OVER (PARTITION BY 1) AS BIGINT) AS TotalCount
  FROM dbo.Customers c WITH (NOLOCK)
  ' 
			+ CASE 
				WHEN @TenantID <> 120
					THEN 'INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = c.CreatedBy'
				END + 
			'
  LEFT JOIN dbo.AspNetUsers auu WITH (NOLOCK) ON auu.UserId = c.UpdatedBy
  LEFT JOIN dbo.AspNetUsers cu WITH (NOLOCK) ON cu.UserId = c.CreatedBy
  LEFT JOIN dbo.Customers ref WITH (NOLOCK) ON ref.CustomerId = c.RefferedBy
  LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = c.LabelId
   AND l.TenantId = c.TenantId
   AND l.IsDeleted = 0
  LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = c.LocationID
   AND la.TenantID = c.TenantId
   AND la.IsDeleted = 0
  LEFT JOIN dbo.CustomerAddresses ca WITH(NOLOCK) ON ca.CustomerId = c.CustomerId
   AND ca.IsDeleted = 0
   AND ca.IsDefault = 1
  LEFT JOIN dbo.LookupValues lv WITH(NOLOCK) ON lv.LookupValueId = c.ProfessionId
   AND lv.IsDeleted = 0
   --AND lv.LookupId = @LookupId
   AND (@LookupId = 0 OR lv.LookupId = @LookupId)
  WHERE c.TenantId = @TenantID
     AND ( ( @CustomerTypes IS NULL AND c.CustomerTypeId = 1 ) -- Customers (legacy Admin default)
        OR ( @CustomerTypes IS NOT NULL AND c.CustomerTypeId IN (SELECT value FROM STRING_SPLIT(@CustomerTypes, '','')) AND c.CustomerTypeId IN (1,2) ) ) -- App grid: Customer/Interior, never Wholesaler
          AND c.IsDeleted = 0'
			;
		SET @FilterSQL = '';

		IF @CustomerName IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND (ISNULL(c.FirstName,'''') + '' '' + ISNULL(c.LastName,'''')) LIKE ''%'' + @CustomerName + ''%''';

		IF @PhoneNumber IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND (c.PhoneNumber LIKE ''%'' + @PhoneNumber + ''%'' OR c.AltPhoneNumber LIKE ''%'' + @PhoneNumber + ''%'')';

		IF @FromDateTime IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND ISNULL(c.UpdatedDate, c.CreatedDate) >= @FromDateTime';

		IF @ToDateTime IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND ISNULL(c.UpdatedDate, c.CreatedDate) <= @ToDateTime';

		IF NULLIF(@RefferedBy, - 1) IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.RefferedBy = @RefferedBy'

		IF @SalesmanID IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.CreatedBy = @SalesmanID'

		IF @CreatedBy IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND (ISNULL(cu.FirstName,'''') + '' '' + ISNULL(cu.LastName,'''')) LIKE ''%'' + @CreatedBy + ''%'''

		IF @Tags IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.LabelId = @Tags'

		IF @TagsCsv IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.LabelId IN (SELECT value FROM STRING_SPLIT(@TagsCsv, '',''))'

		IF @SmartAddressSearch IS NOT NULL
		BEGIN
			SET @FilterSQL = @FilterSQL + ' AND EXISTS (
   SELECT 1
   FROM dbo.CustomerAddresses ca
   WHERE ca.CustomerId = c.CustomerId
   AND (
    ca.Street1 LIKE ''%'' + @SmartAddressSearch + ''%'' OR
    ca.Street2 LIKE ''%'' + @SmartAddressSearch + ''%'' OR
    ca.Landmark LIKE ''%'' + @SmartAddressSearch + ''%'' OR
    ca.Area LIKE ''%'' + @SmartAddressSearch + ''%'' OR
    ca.City LIKE ''%'' + @SmartAddressSearch + ''%'' OR
    ca.State LIKE ''%'' + @SmartAddressSearch + ''%'' OR
    ca.ZipCode LIKE ''%'' + @SmartAddressSearch + ''%''
   )
  )'
		END

		IF @LocationID IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.LocationID IN (SELECT value FROM STRING_SPLIT(@LocationID, '',''))';

		IF @IsSubscribe IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.IsSubscribe = @IsSubscribe';

		IF @ProfessionId IS NOT NULL
			SET @FilterSQL = @FilterSQL + ' AND c.ProfessionId = @ProfessionId';
		SET @SortSQL = ' ORDER BY ';

		IF @SortBy = 'CustomerName'
			SET @SortSQL = @SortSQL + 'CustomerName ';
		ELSE IF @SortBy = 'EmailAddress'
			SET @SortSQL = @SortSQL + 'EmailAddress ';
		ELSE IF @SortBy = 'RefferedBy'
			SET @SortSQL = @SortSQL + 'RefferedBy ';
		ELSE IF @SortBy = 'PhoneNumber'
			SET @SortSQL = @SortSQL + 'PhoneNumber ';
		ELSE IF @SortBy = 'Salesman'
			SET @SortSQL = @SortSQL + 'Salesman ';
		ELSE IF @SortBy = 'CreatedBy'
			SET @SortSQL = @SortSQL + 'CreatedByName ';
		ELSE IF @SortBy = 'LastModifiedOn'
			SET @SortSQL = @SortSQL + 'ISNULL(c.UpdatedDate, c.CreatedDate) ';
		ELSE IF @SortBy = 'Area'
			SET @SortSQL = @SortSQL + 'Area ';
		ELSE IF @SortBy = 'Pincode'
			SET @SortSQL = @SortSQL + 'Pincode ';
		ELSE IF @SortBy = 'LocationName'
			SET @SortSQL = @SortSQL + 'LocationName ';
		ELSE IF @SortBy = 'Profession'
			SET @SortSQL = @SortSQL + 'ProfessionName ';

		IF @SortOrder = 'ASC'
			SET @SortSQL = @SortSQL + 'ASC ';
		ELSE IF @SortOrder = 'DESC'
			SET @SortSQL = @SortSQL + 'DESC ';
		SET @PageSQL = ' OFFSET ' + CAST((@PageIndex - 1) * @PageSize AS VARCHAR(20)) + ' ROWS FETCH NEXT ' + CAST(@PageSize AS VARCHAR(20)) + ' ROWS ONLY';
		SET @SQL = @SQL + @FilterSQL + @SortSQL + @PageSQL;

		EXEC sp_executesql @SQL
			,@params
			,@TenantID = @TenantID
			,@CustomerName = @CustomerName
			,@PhoneNumber = @PhoneNumber
			,@FromDateTime = @FromDateTime
			,@ToDateTime = @ToDateTime
			,@RefferedBy = @RefferedBy
			,@SalesmanID = @SalesmanID
			,@SmartAddressSearch = @SmartAddressSearch
			,@Tags = @Tags
			,@LocationID = @LocationID
			,@IsSubscribe = @IsSubscribe
			,@ProfessionId = @ProfessionId
			,@LookupId = @LookupId
			,@CustomerTypes = @CustomerTypes
			,@CreatedBy = @CreatedBy
			,@TagsCsv = @TagsCsv
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

