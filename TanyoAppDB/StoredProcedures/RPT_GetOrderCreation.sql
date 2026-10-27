/*
	EXEC RPT_GetOrderCreation
		@TenantId = 2
		,@CreatedFromDate = '2026-07-28'
		,@CreatedToDate = '2026-08-03'
		,@OrderStatus = NULL
		,@UserId = 4528
		,@RoleId = 'B0B236B8-D363-496A-AFA3-9E7A0A621368'
		,@SalesManId = NULL
		,@PageNumber = 1
		,@PageSize = 10000
		,@SortBy = 'CreatedDate'
		,@SortOrder = 'DESC'
*/
CREATE PROCEDURE [dbo].[RPT_GetOrderCreation] (
	@TenantId INT
	,@CreatedFromDate DATE
	,@CreatedToDate DATE
	,@UserId BIGINT
	,@RoleId VARCHAR(100)
	,@SalesManId BIGINT = NULL
	,@OrderStatus VARCHAR(200) = NULL
	,@PageNumber INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @CreatedFromDateTime DATETIMEOFFSET = NULL
		,@CreatedToDateTime DATETIMEOFFSET = NULL
	DECLARE @OrderType SMALLINT = NULL
	DECLARE @IsAdmin BIT = 0
		,@HasSuperAccess BIT = 0;

	SELECT @CreatedFromDateTime = CAST(@CreatedFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
		,@CreatedToDateTime = CAST(@CreatedToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

	DROP TABLE IF EXISTS #TempUserRolesClaims

		CREATE TABLE #TempUserRolesClaims (
			RoleName VARCHAR(100)
			,ClaimValue NVARCHAR(MAX)
			)

	BEGIN TRY
		INSERT INTO #TempUserRolesClaims (
			RoleName
			,ClaimValue
			)
		SELECT ar.Name
			,arc.ClaimValue
		FROM AspNetRoles ar WITH (NOLOCK)
		INNER JOIN AspNetRoleClaims arc WITH (NOLOCK) ON arc.RoleId = ar.Id
		WHERE arc.RoleId = @RoleId

		IF EXISTS (
				SELECT 1
				FROM #TempUserRolesClaims
				WHERE RoleName LIKE '%Administrator%'
				)
		BEGIN
			SET @OrderType = NULL
			SET @IsAdmin = 1
		END
		ELSE IF EXISTS (
				SELECT 1
				FROM #TempUserRolesClaims
				WHERE ClaimValue IN (
						'Permissions.App.Order.SuperAccess'
						,'Permissions.General.Order.SuperAccess'
						)
				)
		BEGIN
			SET @HasSuperAccess = 1;

			IF EXISTS (
					SELECT 1
					FROM #TempUserRolesClaims
					WHERE ClaimValue IN (
							'Permissions.App.Order.WholeselerPrice'
							,'Permissions.General.Order.WholeselerPrice'
							)
					)
			BEGIN
				SET @OrderType = 2
			END
			ELSE
			BEGIN
				SET @OrderType = 1
			END
		END
		ELSE
		BEGIN
			SET @OrderType = 1
		END

		IF (
				@IsAdmin = 1
				AND @SalesManId IS NOT NULL
				)
		BEGIN
			SELECT o.OrderId
				,o.OrderNo
				,CONCAT (
					c.FirstName
					,' '
					,c.LastName
					) AS CustomerName
				,CONCAT (
					a.FirstName
					,' '
					,a.LastName
					) AS SalesmanName
				,o.Status AS OrderStatusId
				,os.Status AS OrderStatusName
				,o.TotalAmt AS TotalAmount
				,o.CreatedDate
				,a.UserId
				,COUNT(*) OVER () AS TotalCount
			FROM Orders AS o WITH (NOLOCK)
			INNER JOIN Customers AS c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			INNER JOIN AspNetUsers AS a WITH (NOLOCK) ON o.SalesmanId = a.UserId
			INNER JOIN OrderStatus os WITH (NOLOCK) ON os.StatusEnumId = o.Status
				AND os.TenantId = @TenantId
				AND os.Type = 'Order'
			WHERE o.TenantId = @TenantId
				AND o.Status <> 9
				AND (
					@OrderType IS NULL
					OR o.OrderType = @OrderType
					)
				AND (
					@OrderStatus IS NULL
					OR o.Status IN (
						SELECT value
						FROM STRING_SPLIT(@OrderStatus, ',')
						)
					)
				AND o.SalesmanId = @SalesManId
				AND (
					@CreatedFromDateTime IS NULL
					OR o.CreatedDate >= @CreatedFromDateTime
					)
				AND (
					@CreatedToDateTime IS NULL
					OR o.CreatedDate <= @CreatedToDateTime
					)
			ORDER BY CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'ASC'
						THEN o.OrderNo
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'DESC'
						THEN o.OrderNo
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN CONCAT (
								c.FirstName
								,' '
								,c.LastName
								)
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN CONCAT (
								c.FirstName
								,' '
								,c.LastName
								)
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'ASC'
						THEN o.TotalAmount
					END ASC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'DESC'
						THEN o.TotalAmount
					END DESC
				,CASE 
					WHEN @SortBy = 'CreatedDate'
						AND @SortOrder = 'ASC'
						THEN o.CreatedDate
					END ASC
				,CASE 
					WHEN @SortBy = 'CreatedDate'
						AND @SortOrder = 'DESC'
						THEN o.CreatedDate
					END DESC
				,CASE 
					WHEN @SortBy = 'SalesmanName'
						AND @SortOrder = 'ASC'
						THEN ISNULL(a.FirstName, '') + ' ' + ISNULL(a.LastName, '')
					END ASC
				,CASE 
					WHEN @SortBy = 'SalesmanName'
						AND @SortOrder = 'DESC'
						THEN ISNULL(a.FirstName, '') + ' ' + ISNULL(a.LastName, '')
					END DESC
				,CASE 
					WHEN @SortBy = 'OrderStatusName'
						AND @SortOrder = 'ASC'
						THEN os.Status
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderStatusName'
						AND @SortOrder = 'DESC'
						THEN os.Status
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
					END DESC OFFSET(@PageNumber - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY;
		END
		ELSE
		BEGIN
			SELECT o.OrderId
				,o.OrderNo
				,CONCAT (
					c.FirstName
					,' '
					,c.LastName
					) AS CustomerName
				,CONCAT (
					a.FirstName
					,' '
					,a.LastName
					) AS SalesmanName
				,o.Status AS OrderStatusId
				,os.Status AS OrderStatusName
				,o.TotalAmt AS TotalAmount
				,o.CreatedDate
				,a.UserId
				,COUNT(*) OVER () AS TotalCount
			FROM Orders AS o WITH (NOLOCK)
			INNER JOIN Customers AS c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
			INNER JOIN AspNetUsers AS a WITH (NOLOCK) ON o.SalesmanId = a.UserId
			INNER JOIN OrderStatus os WITH (NOLOCK) ON os.StatusEnumId = o.Status
				AND os.TenantId = @TenantId
				AND os.Type = 'Order'
			WHERE o.TenantId = @TenantId
				AND o.Status <> 9
				AND (
					@OrderType IS NULL
					OR o.OrderType = @OrderType
					)
				AND (
					@OrderStatus IS NULL
					OR o.Status IN (
						SELECT value
						FROM STRING_SPLIT(@OrderStatus, ',')
						)
					)
				AND (
					@IsAdmin = 1
					OR @HasSuperAccess = 1
					AND o.SalesmanId = @UserId
					)
				AND (
					@CreatedFromDateTime IS NULL
					OR o.CreatedDate >= @CreatedFromDateTime
					)
				AND (
					@CreatedToDateTime IS NULL
					OR o.CreatedDate <= @CreatedToDateTime
					)
			ORDER BY CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'ASC'
						THEN o.OrderNo
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderNo'
						AND @SortOrder = 'DESC'
						THEN o.OrderNo
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN CONCAT (
								c.FirstName
								,' '
								,c.LastName
								)
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN CONCAT (
								c.FirstName
								,' '
								,c.LastName
								)
					END DESC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'ASC'
						THEN o.TotalAmount
					END ASC
				,CASE 
					WHEN @SortBy = 'TotalAmount'
						AND @SortOrder = 'DESC'
						THEN o.TotalAmount
					END DESC
				,CASE 
					WHEN @SortBy = 'CreatedDate'
						AND @SortOrder = 'ASC'
						THEN o.CreatedDate
					END ASC
				,CASE 
					WHEN @SortBy = 'CreatedDate'
						AND @SortOrder = 'DESC'
						THEN o.CreatedDate
					END DESC
				,CASE 
					WHEN @SortBy = 'SalesmanName'
						AND @SortOrder = 'ASC'
						THEN ISNULL(a.FirstName, '') + ' ' + ISNULL(a.LastName, '')
					END ASC
				,CASE 
					WHEN @SortBy = 'SalesmanName'
						AND @SortOrder = 'DESC'
						THEN ISNULL(a.FirstName, '') + ' ' + ISNULL(a.LastName, '')
					END DESC
				,CASE 
					WHEN @SortBy = 'OrderStatusName'
						AND @SortOrder = 'ASC'
						THEN os.Status
					END ASC
				,CASE 
					WHEN @SortBy = 'OrderStatusName'
						AND @SortOrder = 'DESC'
						THEN os.Status
					END DESC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'ASC'
						THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
					END ASC
				,CASE 
					WHEN @SortBy = 'CustomerName'
						AND @SortOrder = 'DESC'
						THEN ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '')
					END DESC OFFSET(@PageNumber - 1) * @PageSize ROWS

			FETCH NEXT @PageSize ROWS ONLY;
		END
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

