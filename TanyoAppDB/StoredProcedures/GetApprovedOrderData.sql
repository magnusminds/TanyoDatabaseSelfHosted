/*    
 EXEC [dbo].[GetApprovedOrderData]    
  @TenantID = 2    
  ,@CurrentUserId = 4279    
  ,@OrderNo = NULL    
  ,@CustomerName = null    
  ,@SalesmanName = NULL    
  ,@OrderFromDate = null    
  ,@OrderToDate = null    
  ,@OrderType = NULL    
  ,@CategoryId = null    
  ,@DeliveryFromDate = null    
  ,@DeliveryToDate = null    
  ,@ApprovedFromDate = NULL    
  ,@ApprovedToDate = NULL    
  ,@PageIndex = 1    
  ,@PageSize = 25    
  ,@SortBy = 'CustomerName'    
  ,@SortOrder = 'ASC'    
*/
CREATE PROCEDURE [dbo].[GetApprovedOrderData] (
	@TenantId INT 
	,@CurrentUserId INT
	,@OrderNo NVARCHAR(20) = NULL
	,@CustomerName NVARCHAR(255) = NULL
	,@SalesmanName INT = NULL
	,@OrderFromDate DATE = NULL
	,@OrderToDate DATE = NULL
	,@OrderType SMALLINT = NULL
	,@CategoryId BIGINT
	,@DeliveryFromDate DATETIME = NULL
	,@DeliveryToDate DATETIME = NULL
	,@ApprovedFromDate DATE = NULL
	,@ApprovedToDate DATE = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'TentativeDeliveryDate'
	,@SortOrder VARCHAR(50) = 'DESC'
	,@ProductTitle VARCHAR(150) = NULL
	,@ModelNo VARCHAR(150) = NULL
	,@RoleId NVARCHAR(MAX) = NULL
	,@UserId INT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @OrderFromDateTime DATETIMEOFFSET = NULL
			,@OrderToDateTime DATETIMEOFFSET = NULL
			,@IsAdmin BIT = 0
			,@SupperAccess BIT = 0

		SELECT @OrderFromDateTime = CAST(@OrderFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderToDateTime = CAST(@OrderToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		DECLARE @OrderApprovedFromDateTime DATETIMEOFFSET = NULL
			,@OrderApprovedToDateTime DATETIMEOFFSET = NULL

		SELECT @OrderApprovedFromDateTime = CAST(@ApprovedFromDate AS VARCHAR(10)) + ' 00:00:00.0000001 +5:30'
			,@OrderApprovedToDateTime = CAST(@ApprovedToDate AS VARCHAR(10)) + ' 23:59:59.9999999 +5:30'

		--Get ProductSubjectTypeId, PolishSubjectTypeId, FabricSubjectTypeId      
		DECLARE @ProductSubjectTypeId INT
			,@PolishSubjectTypeId INT
			,@FabricSubjectTypeId INT;

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = @TenantId;

		SELECT @PolishSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Polish'
			AND TenantId = @TenantId;

		SELECT @FabricSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Fabrics'
			AND TenantId = @TenantId;

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

		SELECT os.OrderId
			,o.OrderNo
			,ISNULL(cat.CategoryName, '') AS CategoryName
			,ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,CASE 
				WHEN os.SubjectTypeId = @ProductSubjectTypeId
					THEN ISNULL(p.ModelNo, '')
				ELSE ''
				END AS ModelNo
			,CASE 
				WHEN os.SubjectTypeId = @ProductSubjectTypeId
					THEN ISNULL(p.ProductTitle, '')
				WHEN os.SubjectTypeId = @PolishSubjectTypeId
					THEN ISNULL(pl.Title, '')
				WHEN os.SubjectTypeId = @FabricSubjectTypeId
					THEN ISNULL(f.Title, '')
				ELSE ''
				END AS ProductTitle
			,os.OrderSetItemId
			,@CurrentUserId AS UserId
			,o.TentativeDeliveryDate
			,o.ApprovedDate
			,o.CreatedDate AS OrderDate
			,ISNULL(u.FirstName + ' ' + u.LastName, '') + CASE 
				WHEN u.IsDeleted = 1
					THEN ' (Inactive)'
				ELSE ''
				END AS CreatedByName
			,os.DeliveryDate
			,o.CreatedBy AS CreatedBy
			,o.OrderType
			,os.Quantity AS Quantity
			,ISNULL(os.DeliveryComment, '') AS DeliveryComment
			,cat.CategoryId
			,os.SubjectId AS SubjectId
			,COUNT(1) OVER () AS TotalCount
		FROM OrderSetItems os
		INNER JOIN Orders o ON os.OrderId = o.OrderId
		LEFT JOIN Customers c ON c.CustomerId = o.CustomerID
		LEFT JOIN AspNetUsers u ON o.CreatedBy = u.UserId
		LEFT JOIN Products p ON os.SubjectId = p.ProductId
			AND os.SubjectTypeId = @ProductSubjectTypeId
		LEFT JOIN Polish pl ON os.SubjectId = pl.PolishId
			AND os.SubjectTypeId = @PolishSubjectTypeId
		LEFT JOIN Fabrics f ON os.SubjectId = f.FabricId
			AND os.SubjectTypeId = @FabricSubjectTypeId
		LEFT JOIN Categories cat ON p.CategoryId = cat.CategoryId
		WHERE o.Tenantid = @TenantId
			AND os.ParentOrderSetItemId IS NULL
			AND o.Status = 2
			AND (
				@OrderNo IS NULL
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@CustomerName IS NULL
				OR (c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@SalesmanName IS NULL
				OR O.SalesmanId = @SalesmanName
				)
			AND (
				@CategoryId IS NULL
				OR cat.CategoryId = @CategoryId
				)
			AND (
				@OrderType IS NULL
				OR o.OrderType = @OrderType
				)
			AND (
				@OrderFromDate IS NULL
				OR (o.ApprovedDate) >= @OrderFromDateTime
				)
			AND (
				@OrderToDate IS NULL
				OR (o.ApprovedDate) <= @OrderToDateTime
				)
			AND (
				(
					@DeliveryFromDate IS NULL
					AND @DeliveryToDate IS NULL
					)
				OR (
					os.DeliveryDate BETWEEN ISNULL(@DeliveryFromDate, os.DeliveryDate)
						AND ISNULL(@DeliveryToDate, os.DeliveryDate)
					)
				)
			AND (
				@ProductTitle IS NULL
				OR (
					(
						os.SubjectTypeId = @ProductSubjectTypeId
						AND p.ProductTitle LIKE '%' + @ProductTitle + '%'
						)
					OR (
						os.SubjectTypeId = @PolishSubjectTypeId
						AND pl.Title LIKE '%' + @ProductTitle + '%'
						)
					OR (
						os.SubjectTypeId = @FabricSubjectTypeId
						AND f.Title LIKE '%' + @ProductTitle + '%'
						)
					)
				)
			AND (
				@ModelNo IS NULL
				OR (
					(
						os.SubjectTypeId = @ProductSubjectTypeId
						AND p.ModelNo LIKE '%' + @ModelNo + '%'
						)
					)
				)
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
			)
		ORDER BY CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN OrderNo
				END
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN OrderNo
				END DESC
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'ASC'
					THEN (u.FirstName + ' ' + u.LastName)
				END
			,CASE 
				WHEN @SortBy = 'SalesmanName'
					AND @SortOrder = 'DESC'
					THEN (u.FirstName + ' ' + u.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN (c.FirstName + ' ' + ISNULL(c.LastName, ''))
				END
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN (c.FirstName + ' ' + ISNULL(c.LastName, ''))
				END DESC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ModelNo
							ELSE ''
							END
				END ASC
			,CASE 
				WHEN @SortBy = 'ModelNo'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ModelNo
							ELSE ''
							END
				END DESC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'ASC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ProductTitle
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pl.Title
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.Title
							ELSE ''
							END
				END ASC
			,CASE 
				WHEN @SortBy = 'ProductTitle'
					AND @SortOrder = 'DESC'
					THEN CASE 
							WHEN os.SubjectTypeId = @ProductSubjectTypeId
								THEN p.ProductTitle
							WHEN os.SubjectTypeId = @PolishSubjectTypeId
								THEN pl.Title
							WHEN os.SubjectTypeId = @FabricSubjectTypeId
								THEN f.Title
							ELSE ''
							END
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDateReadyToDelivered'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END
			,CASE 
				WHEN @SortBy = 'OrderDateReadyToDelivered'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'ASC'
					THEN o.CreatedDate
				END
			,CASE 
				WHEN @SortBy = 'OrderDate'
					AND @SortOrder = 'DESC'
					THEN o.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'ASC'
					THEN o.ApprovedDate
				END
			,CASE 
				WHEN @SortBy = 'ApprovedDate'
					AND @SortOrder = 'DESC'
					THEN o.ApprovedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'ASC'
					THEN os.DeliveryDate
				END
			,CASE 
				WHEN @SortBy = 'DeliveryDate'
					AND @SortOrder = 'DESC'
					THEN os.DeliveryDate
				END DESC
			,CASE 
				WHEN @SortBy = 'DeliveryComment'
					AND @SortOrder = 'ASC'
					THEN ISNULL(os.DeliveryComment, '')
				END
			,CASE 
				WHEN @SortBy = 'DeliveryComment'
					AND @SortOrder = 'DESC'
					THEN ISNULL(os.DeliveryComment, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'ASC'
					THEN o.TentativeDeliveryDate
				END
			,CASE 
				WHEN @SortBy = 'TentativeDeliveryDate'
					AND @SortOrder = 'DESC'
					THEN o.TentativeDeliveryDate
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ObjectName VARCHAR(500)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()
			,@ObjectName = OBJECT_NAME(@@PROCID)

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage;

	END CATCH
END

GO

