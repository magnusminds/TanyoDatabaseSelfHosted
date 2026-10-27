-- =============================================
-- Create date : 2026-06-17
-- Updated     : 2026-06-26 — portal filters + @IsPortal flag
-- Description : Complaint report PDF data with filters, sorting, permissions
-- =============================================
/*
    API example:
    EXEC [dbo].[GetComplainReportPdfData]
        @TenantId = 2,
        @UserId = 1,
        @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F',
        @ComplaintNo = NULL,
        @CustomerName = NULL,
        @OrderNo = NULL,
        @PhoneNo = NULL,
        @Status = NULL,
        @SortBy = 'CreatedDate',
        @SortOrder = 'DESC',
        @ComplainId = 10081,
        @IsFree = NULL,
        @Priority = NULL,
        @SalesmanId = NULL,
        @Address = NULL,
        @IsPortal = 0;

    Portal example:
    EXEC [dbo].[GetComplainReportPdfData]
        @TenantId = 2,
        @UserId = 1,
        @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F',
        @ComplaintNo = NULL,
        @CustomerName = NULL,
        @OrderNo = NULL,
        @PhoneNo = NULL,
        @Status = NULL,
        @SortBy = 'CreatedDate',
        @SortOrder = 'DESC',
        @ComplainId = NULL,
        @IsFree = NULL,
        @Priority = NULL,
        @SalesmanId = NULL,
        @Address = NULL,
        @IsPortal = 1;
*/
CREATE PROCEDURE [dbo].[GetComplainReportPdfData] (
	@TenantId INT
	,@UserId BIGINT
	,@RoleId NVARCHAR(450)
	,@ComplaintNo NVARCHAR(100) = NULL
	,@CustomerName NVARCHAR(200) = NULL
	,@OrderNo NVARCHAR(100) = NULL
	,@PhoneNo NVARCHAR(50) = NULL
	,@Status INT = NULL
	,@SortBy NVARCHAR(50) = N'CreatedDate'
	,@SortOrder NVARCHAR(4) = N'DESC'
	,@ComplainId BIGINT = NULL
	,@IsFree INT = NULL
	,@Priority INT = NULL
	,@SalesmanId BIGINT = NULL
	,@Address NVARCHAR(500) = NULL
	,@IsPortal BIT = 0
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY

	DECLARE @IsAdmin BIT = 0;
	DECLARE @HasListAllOrders BIT = 0;
	DECLARE @HasWholesalerPrice BIT = 0;
	DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

	SELECT @IsAdmin = CASE 
			WHEN r.[Name] IN (N'Administrator')
				THEN 1
			ELSE 0
			END
	FROM [dbo].[AspNetRoles] AS r
	WHERE r.[Id] = @RoleId;

	SELECT @HasListAllOrders = CASE 
			WHEN EXISTS (
					SELECT 1
					FROM [dbo].[AspNetRoleClaims] AS rc
					WHERE rc.[RoleId] = @RoleId
						AND rc.[ClaimType] = N'permission'
						AND rc.[ClaimValue] IN (
							N'Permissions.Portal.Complain.ListAllOrders'
							,N'Permissions.App.Complain.ListAllOrders'
							)
					)
				THEN 1
			ELSE 0
			END
		,@HasWholesalerPrice = CASE 
			WHEN EXISTS (
					SELECT 1
					FROM [dbo].[AspNetRoleClaims] AS rc
					WHERE rc.[RoleId] = @RoleId
						AND rc.[ClaimType] = N'permission'
						AND rc.[ClaimValue] IN (
							N'Permissions.App.Order.WholeselerPrice'
							,N'Permissions.General.Order.WholeselerPrice'
							)
					)
				THEN 1
			ELSE 0
			END;

	SELECT c.ComplainId
		,c.ComplainKey AS ComplainNo
		,c.CreatedDate
		,CONCAT (
			ISNULL(cu.FirstName, N'')
			,N' '
			,ISNULL(cu.LastName, N'')
			) AS CustomerName
		,ISNULL(cu.PhoneNumber, N'') AS PhoneNumber
		,COALESCE(NULLIF(LTRIM(RTRIM(c.Address)), N''), NULLIF(LTRIM(RTRIM(caResolved.FullAddress)), N''), NULLIF(LTRIM(RTRIM(CONCAT (
							ISNULL(caResolved.Street1, N'')
							,N' '
							,ISNULL(caResolved.Street2, N'')
							,N' '
							,ISNULL(caResolved.Landmark, N'')
							,N' '
							,ISNULL(caResolved.Area, N'')
							,N' '
							,ISNULL(caResolved.City, N'')
							,N' '
							,ISNULL(caResolved.[State], N'')
							,N' '
							,ISNULL(caResolved.ZipCode, N'')
							))), N''), N'') AS [Address]
		,ISNULL(c.Title, N'') AS Title
		,ISNULL(c.Description, N'') AS Description
		,c.[Status]
		,latestComment.Comment AS LatestComment
		,latestComment.CreatedDate AS LatestCommentDate
		,ISNULL((
				SELECT a.ImagePath AS [Url]
					,a.ImageType
				FROM [dbo].[ComplainAttachments] AS a
				WHERE a.ComplainId = c.ComplainId
					AND a.ImageType IN (
						2
						,3
						)
					AND ISNULL(LTRIM(RTRIM(a.ImagePath)), N'') <> N''
				FOR JSON PATH
				), N'[]') AS AttachmentsJson
	FROM [dbo].[Complains] AS c
	INNER JOIN [dbo].[Customers] AS cu ON c.CustomerId = cu.CustomerId
	LEFT JOIN [dbo].[Orders] AS o ON c.OrderId = o.OrderId
	OUTER APPLY (
		SELECT TOP (1) cc.Comment
			,cc.CreatedDate
		FROM [dbo].[ComplainComments] AS cc
		WHERE cc.ComplainId = c.ComplainId
			AND ISNULL(LTRIM(RTRIM(cc.Comment)), N'') <> N''
			AND cc.Comment <> N'null'
		ORDER BY cc.CreatedDate DESC
		) AS latestComment
	OUTER APPLY (
		SELECT TOP (1) ca.*
		FROM [dbo].[CustomerAddresses] AS ca
		WHERE ca.CustomerId = c.CustomerId
		ORDER BY CASE 
				WHEN c.CustomerAddressId IS NOT NULL
					AND ca.CustomerAddressId = c.CustomerAddressId
					THEN 0
				ELSE 1
				END
			,CASE 
				WHEN ca.IsDefault = 1
					THEN 0
				ELSE 1
				END
			,ca.CustomerAddressId DESC
		) AS caResolved
	WHERE c.TenantId = @TenantId
		AND c.Status <> 4
		AND (
			@Status IS NULL
			OR @Status <= 0
			OR c.Status = @Status
			)
		AND (
			ISNULL(@ComplaintNo, N'') = N''
			OR c.ComplainKey LIKE N'%' + @ComplaintNo + N'%'
			OR (
				@IsPortal = 1
				AND c.Title LIKE N'%' + @ComplaintNo + N'%'
				)
			)
		AND (
			ISNULL(@CustomerName, N'') = N''
			OR CONCAT (
				ISNULL(cu.FirstName, N'')
				,N' '
				,ISNULL(cu.LastName, N'')
				) LIKE N'%' + @CustomerName + N'%'
			)
		AND (
			ISNULL(@OrderNo, N'') = N''
			OR ISNULL(o.OrderNo, N'') LIKE N'%' + @OrderNo + N'%'
			)
		AND (
			ISNULL(@PhoneNo, N'') = N''
			OR ISNULL(cu.PhoneNumber, N'') LIKE N'%' + @PhoneNo + N'%'
			)
		AND (
			@IsFree IS NULL
			OR @IsFree < 0
			OR CAST(c.IsFree AS INT) = @IsFree
			)
		AND (
			@Priority IS NULL
			OR @Priority <= 0
			OR c.Priority = @Priority
			)
		AND (
			@SalesmanId IS NULL
			OR @SalesmanId <= 0
			OR c.SalesmanId = @SalesmanId
			)
		AND (
			ISNULL(@Address, N'') = N''
			OR ISNULL(c.Address, N'') LIKE N'%' + @Address + N'%'
			)
		AND (
			@IsAdmin = 1
			OR @HasListAllOrders = 1
			OR (
				ISNULL(c.CreatedBy, 0) = @UserId
				AND (
					(
						@HasWholesalerPrice = 1
						AND ISNULL(o.OrderType, 1) = 2
						)
					OR (
						@HasWholesalerPrice = 0
						AND ISNULL(o.OrderType, 1) = 1
						)
					)
				)
			)
		AND (
			@ComplainId IS NULL
			OR c.ComplainId = @ComplainId
			)
	ORDER BY CASE 
			WHEN @SortBy = N'ComplainNo'
				AND @SortOrder = N'ASC'
				THEN c.ComplainKey
			END ASC
		,CASE 
			WHEN @SortBy = N'ComplainNo'
				AND @SortOrder = N'DESC'
				THEN c.ComplainKey
			END DESC
		,CASE 
			WHEN @SortBy = N'CustomerName'
				AND @SortOrder = N'ASC'
				THEN CONCAT (
						ISNULL(cu.FirstName, N'')
						,N' '
						,ISNULL(cu.LastName, N'')
						)
			END ASC
		,CASE 
			WHEN @SortBy = N'CustomerName'
				AND @SortOrder = N'DESC'
				THEN CONCAT (
						ISNULL(cu.FirstName, N'')
						,N' '
						,ISNULL(cu.LastName, N'')
						)
			END DESC
		,CASE 
			WHEN @SortBy = N'PhoneNumber'
				AND @SortOrder = N'ASC'
				THEN ISNULL(cu.PhoneNumber, N'')
			END ASC
		,CASE 
			WHEN @SortBy = N'PhoneNumber'
				AND @SortOrder = N'DESC'
				THEN ISNULL(cu.PhoneNumber, N'')
			END DESC
		,CASE 
			WHEN @SortBy = N'OrderNo'
				AND @SortOrder = N'ASC'
				THEN ISNULL(o.OrderNo, N'')
			END ASC
		,CASE 
			WHEN @SortBy = N'OrderNo'
				AND @SortOrder = N'DESC'
				THEN ISNULL(o.OrderNo, N'')
			END DESC
		,CASE 
			WHEN @SortBy = N'Status'
				AND @SortOrder = N'ASC'
				THEN c.Status
			END ASC
		,CASE 
			WHEN @SortBy = N'Status'
				AND @SortOrder = N'DESC'
				THEN c.Status
			END DESC
		,CASE 
			WHEN @SortBy = N'CreatedDate'
				AND @SortOrder = N'ASC'
				THEN c.CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = N'CreatedDate'
				AND @SortOrder = N'DESC'
				THEN c.CreatedDate
			END DESC
		,c.CreatedDate DESC;
END TRY

	BEGIN CATCH
		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

