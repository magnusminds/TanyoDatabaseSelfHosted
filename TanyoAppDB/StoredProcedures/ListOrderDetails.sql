CREATE PROC [dbo].[ListOrderDetails] (
	@TenantID BIGINT
	,@OrderNo VARCHAR(20) = NULL
	,@SalesmanId BIGINT = NULL
	,@CustomerName VARCHAR(100) = NULL
	,@RefferedBy BIGINT = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@OrderType SMALLINT = NULL
	,@InquiryFromDate DATE = NULL
	,@InquiryToDate DATE = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@DeliveryFromDate DATE = NULL
	,@DeliveryToDate DATE = NULL
	,@Tags BIGINT = NULL
	,@Status VARCHAR(50) = NULL
	,@LocationID VARCHAR(500) = NULL
	,@toPrice INT = NULL
	,@fromPrice INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'OrderDate'
	,@SortOrder VARCHAR(10) = 'ASC'
	,@IsStockOnHold BIT = NULL
	,@IsArchive BIT = NULL
	,@RoleId NVARCHAR(MAX) = NULL
	,@UserId INT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT @OrderNo = NULLIF(LTRIM(RTRIM(@OrderNo)), '')

		SELECT @SalesmanId = NULLIF(@SalesmanId, - 1)

		SELECT @CustomerName = NULLIF(LTRIM(RTRIM(@CustomerName)), '')

		SELECT @RefferedBy = NULLIF(@RefferedBy, - 1)

		SELECT @PhoneNumber = NULLIF(LTRIM(RTRIM(@PhoneNumber)), '')

		SELECT @OrderType = NULLIF(@OrderType, - 1)

		SELECT @Status = NULLIF(LTRIM(RTRIM(@Status)), '')

		SELECT @LocationID = NULLIF(LTRIM(RTRIM(@LocationID)), '')

		SELECT @fromPrice = NULLIF(@fromPrice, - 1)

		SELECT @toPrice = NULLIF(@toPrice, - 1)

		DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL
			,@OrderToDateTime DATETIMEOFFSET = NULL
			,@InquiryFromDateTime DATETIME = NULL
			,@InquiryToDateTime DATETIME = NULL
			,@DeliveryFromDateTime DATETIMEOFFSET = NULL
			,@DeliveryToDateTime DATETIMEOFFSET = NULL
			,@SelectQuery NVARCHAR(MAX) = NULL
			,@WhereCondition NVARCHAR(MAX) = NULL
			,@OrderByQuery NVARCHAR(MAX) = NULL
			,@Query NVARCHAR(MAX) = NULL
			,@TenantGSTType BIT = 0
			,@HasWholesalerPrice BIT = 0
			,@IsAdmin BIT = 0
			,@SupperAccess BIT = 0
			,@params NVARCHAR(max) = N'@TenantId BIGINT,@SalesmanId BIGINT, @CustomerName VARCHAR(100),
								@RefferedBy BIGINT, @OrderNo VARCHAR(100), @PhoneNumber VARCHAR(16), 
								@OrderType SMALLINT ,@InquiryFromDateTime DATETIME ,@InquiryToDateTime  DATETIME, 
								@OrderFromDateTime DATETIMEOFFSET ,@OrderToDateTime DATETIMEOFFSET ,@DeliveryFromDateTime DATETIMEOFFSET, 
								@DeliveryToDateTime DATETIMEOFFSET ,@Tags BIGINT ,@Status VARCHAR(50),
								@LocationID VARCHAR(500) ,@toPrice INT ,@fromPrice INT 
								,@IsStockOnHold BIT,@IsArchive BIT,@TenantGSTType BIT,@IsAdmin BIT,@SupperAccess BIT,@UserId INT  OUTPUT';

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
				END

		SELECT @IsAdmin = CASE 
				WHEN EXISTS (
						SELECT 1
						FROM AspNetRoleClaims WITH (NOLOCK)
						WHERE RoleId = @RoleId
							AND ClaimValue IN (
								'Permissions.App.Order.Approve'
								,'Permissions.General.Order.Approve'
								)
						)
					THEN 1
				ELSE 0
				END

		SELECT @SupperAccess = CASE 
				WHEN EXISTS (
						SELECT 1
						FROM AspNetRoleClaims WITH (NOLOCK)
						WHERE RoleId = @RoleId
							AND ClaimValue IN (
								'Permissions.App.Order.SuperAccess'
								,'Permissions.General.Order.SuperAccess'
								)
						)
					THEN 1
				ELSE 0
				END

		SELECT @TenantGSTType = GSTType
		FROM Tenants WITH (NOLOCK)
		WHERE TenantId = @TenantID;

		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'
			,@InquiryFromDateTime = CAST(@InquiryFromDate AS VARCHAR(10)) + ' 00:00:00.001'
			,@InquiryToDateTime = CAST(@InquiryToDate AS VARCHAR(10)) + ' 23:59:59.999'
			,@DeliveryFromDateTime = CAST(@DeliveryFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@DeliveryToDateTime = CAST(@DeliveryToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30';

		SELECT @SelectQuery = 
			'SELECT o.OrderId
			,ISNULL(o.LabelId, 0) AS LabelID
			,ISNULL(l.LabelName, '''') AS LabelName
			,ISNULL(l.ColorCode, '''') AS ColorCode
			,o.OrderNo AS OrderNo
			,au.FirstName + '' '' + au.LastName + CASE 
				WHEN au.IsDeleted = 1
					THEN '' (Inactive) ''
				ELSE ''''
				END AS SalesmanName
			,c.CustomerId AS CustomerId
			,ISNULL(c.FirstName, '''') + '' '' + ISNULL(c.LastName, '''') AS CustomerName
			,c.PhoneNumber AS PhoneNumber
			,c.CustomerTypeId
			,ROUND(ISNULL(o.AmountBeforeGST, 0), 0) AS ProductAmount
			,ROUND(ISNULL(o.CGSTAmount, 0), 0) + ROUND(ISNULL(o.SGSTAmount, 0), 0) AS TaxAmount
			,ROUND(ISNULL(o.TotalAmt, 0), 0) AS TotalAmount
			,o.Status AS OrderStatus
			,FORMAT(o.CreatedDate, '' dd/MM/yyyy '') AS InquiryDate
			,FORMAT(o.ApprovedDate, '' dd/MM/yyyy '') AS OrderDate
			,FORMAT(o.DeliveryDate, '' dd/MM/yyyy '') AS DeliveryDate
			,CAST(CASE 
					WHEN sh.OrderId IS NOT NULL
						THEN 1
					ELSE 0
					END AS BIT) AS IsStockOnHold
			,ISNULL(la.LocationName, '''') AS LocationName
			,COUNT(1) OVER () AS TotalCount
		FROM dbo.Orders o WITH (NOLOCK)
		INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
		INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId
		LEFT JOIN dbo.Labels l WITH (NOLOCK) ON l.LabelId = o.LabelId
			AND l.TenantId = o.TenantId
		LEFT JOIN (
			SELECT DISTINCT soh.OrderId
			FROM StockOnHold soh WITH (NOLOCK)
			WHERE soh.IsStockOnHold = 1
				AND DATEADD(DAY, CAST(soh.TimePeriod AS INT), CAST(soh.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
			) AS sh ON sh.OrderId = o.OrderId
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = o.LocationID
			AND la.TenantID = o.TenantId
			AND la.IsDeleted = 0'
			;

		SELECT @WhereCondition = ' WHERE o.TenantId = @TenantId AND o.Status <> 9';

		IF @OrderNo IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.OrderNo LIKE ''%'' + @OrderNo + ''%''';

		IF @SalesmanId IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.SalesmanId = @SalesmanId'

		IF @CustomerName IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND (ISNULL(c.FirstName,'''') + '' '' + ISNULL(c.LastName,'''')) LIKE ''%'' + @CustomerName + ''%''';

		IF @RefferedBy IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.RefferedBy = @RefferedBy'

		IF @PhoneNumber IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND (c.PhoneNumber LIKE ''%'' + @PhoneNumber + ''%'' OR c.AltPhoneNumber LIKE ''%'' + @PhoneNumber + ''%'')';

		IF @OrderType IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.OrderType = @OrderType'

		IF @InquiryFromDate IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.CreatedDate >= @InquiryFromDateTime '

		IF @InquiryToDate IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.CreatedDate <= @InquiryToDateTime'

		IF @OrderFromDate IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.ApprovedDate >= @OrderFromDateTime'

		IF @OrderToDate IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.ApprovedDate <= @OrderToDateTime'

		IF @DeliveryFromDate IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.DeliveryDate >= @DeliveryFromDateTime'

		IF @DeliveryToDate IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.DeliveryDate <= @DeliveryToDateTime '

		IF @Tags IS NULL
			SET @WhereCondition = @WhereCondition;
		ELSE IF @Tags = 0
			SET @WhereCondition = @WhereCondition + ' AND (o.LabelId IS NULL OR o.LabelId = 0)';
		ELSE IF @Tags <> - 1
			SET @WhereCondition = @WhereCondition + ' AND o.LabelId = @Tags'

		IF @Status IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.Status IN (SELECT value FROM  STRING_SPLIT(@Status, '',''))';

		IF @LocationID IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.LocationID IN (SELECT value FROM STRING_SPLIT(@LocationID, '',''))';

		IF @fromPrice IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND (CASE WHEN  @TenantGSTType = 1 THEN ROUND(ISNULL(o.AmountBeforeGST, 0), 0) ELSE ROUND(ISNULL(o.TotalAmt, 0), 0) END) >= @fromPrice'

		IF @toPrice IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND (CASE WHEN @TenantGSTType = 1 THEN ROUND(ISNULL(o.AmountBeforeGST, 0), 0) ELSE ROUND(ISNULL(o.TotalAmt, 0), 0) END) <= @toPrice'

		IF @IsStockOnHold IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND (CAST(CASE WHEN sh.OrderId IS NOT NULL THEN 1 ELSE 0 END AS BIT)) = @IsStockOnHold';

		IF @IsArchive IS NOT NULL
			SET @WhereCondition = @WhereCondition + ' AND o.IsArchive = @IsArchive'
		SET @WhereCondition = @WhereCondition + '
		AND (
			@IsAdmin = 1
			OR (
				@SupperAccess = 1
				AND (
					@OrderType IS NULL
					OR o.OrderType = @OrderType
				)
			)
			OR (
				o.SalesmanId = @UserId
				AND (
					@OrderType IS NULL
					OR o.OrderType = @OrderType
				)
			)
		)';
		SET @OrderByQuery = ' ORDER BY ';

		IF @SortBy = 'OrderNo'
			SET @OrderByQuery = @OrderByQuery + 'o.OrderNo';
		ELSE IF @SortBy = 'SalesmanName'
			SET @OrderByQuery = @OrderByQuery + '(au.FirstName + '' '' + au.LastName)';
		ELSE IF @SortBy = 'CustomerName'
			SET @OrderByQuery = @OrderByQuery + '(c.FirstName + '' '' + c.LastName)';
		ELSE IF @SortBy = 'PhoneNumber'
			SET @OrderByQuery = @OrderByQuery + 'ISNULL(c.PhoneNumber, '''')';
		ELSE IF @SortBy = 'TotalAmount'
			SET @OrderByQuery = @OrderByQuery + 'o.TotalAmt';
		ELSE IF @SortBy = 'OrderStatus'
			SET @OrderByQuery = @OrderByQuery + 'o.Status';
		ELSE IF @SortBy = 'InquiryDate'
			SET @OrderByQuery = @OrderByQuery + 'o.CreatedDate';
		ELSE IF @SortBy = 'OrderDate'
			SET @OrderByQuery = @OrderByQuery + 'o.ApprovedDate';
		ELSE IF @SortBy = 'DeliveryDate'
			SET @OrderByQuery = @OrderByQuery + 'o.DeliveryDate';
		ELSE IF @SortBy = 'LocationName'
			SET @OrderByQuery = @OrderByQuery + 'la.LocationName';
		ELSE IF @SortBy = 'OrderProductAmount'
			SET @OrderByQuery = @OrderByQuery + 'ROUND(ISNULL(o.AmountBeforeGST, 0), 0)';
		ELSE IF @SortBy = 'TaxAmount'
			SET @OrderByQuery = @OrderByQuery + '(ROUND(ISNULL(o.CGSTAmount, 0), 0) + ROUND(ISNULL(o.SGSTAmount, 0), 0))';
		ELSE
			SET @OrderByQuery = @OrderByQuery + 'o.ApprovedDate';

		IF @SortOrder = 'ASC'
			SET @OrderByQuery = @OrderByQuery + ' ASC ';
		ELSE IF @SortOrder = 'DESC'
			SET @OrderByQuery = @OrderByQuery + ' DESC ';
		SET @OrderByQuery = @OrderByQuery + ' OFFSET (' + CAST(@PageIndex AS VARCHAR(20)) + ' - 1) * ' + CAST(@PageSize AS VARCHAR(20)) + ' ROWS FETCH NEXT ' + CAST(@PageSize AS VARCHAR(20)) + ' ROWS ONLY';

		SELECT @Query = @SelectQuery + @WhereCondition + @OrderByQuery;

		EXEC sp_executesql @Query
			,@params
			,@TenantId = @TenantId
			,@SalesmanId = @SalesmanId
			,@CustomerName = @CustomerName
			,@OrderNo = @OrderNo
			,@PhoneNumber = @PhoneNumber
			,@RefferedBy = @RefferedBy
			,@OrderType = @OrderType
			,@InquiryFromDateTime = @InquiryFromDateTime
			,@InquiryToDateTime = @InquiryToDateTime
			,@OrderFromDateTime = @OrderFromDateTime
			,@OrderToDateTime = @OrderToDateTime
			,@DeliveryFromDateTime = @DeliveryFromDateTime
			,@DeliveryToDateTime = @DeliveryToDateTime
			,@Tags = @Tags
			,@Status = @Status
			,@LocationID = @LocationID
			,@toPrice = @toPrice
			,@fromPrice = @fromPrice
			,@IsStockOnHold = @IsStockOnHold
			,@IsArchive = @IsArchive
			,@TenantGSTType = @TenantGSTType
			,@IsAdmin = @IsAdmin
			,@SupperAccess = @SupperAccess
			,@UserId = @UserId;
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

