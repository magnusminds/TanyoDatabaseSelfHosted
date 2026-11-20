--Author		: kishan kalena
--Create date	: 08-09-2023
--Description	: Report - Inward Value
-- =============================================
/*
 EXEC ReportProductsWithoutImage
	@TenantId = 1
	,@CategoryId = NULL
	,@ProductTitle = NULL
	,@ModelNo = NULL
	,@PageIndex = 1
	,@PageSize = 100
	,@SortBy = 'ProductTitle'
	,@SortOrder = 'asc'
*/

CREATE   PROCEDURE [dbo].[ReportProductsWithoutImage] (
	@TenantId INT
	,@CategoryId BIGINT = NULL
	,@ModelNo VARCHAR(50) = NULL
	,@ProductTitle VARCHAR(50) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'CategoryName'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;
	DECLARE @ProductSubjectTypeId INT;
	BEGIN TRY
	
	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId
		AND IsDeleted = 0
	SELECT 	
		P.ProductId AS 'ProductId'
		,P.ProductTitle AS 'ProductTitle'
		,P.ModelNo AS 'ModelNo'
		,cat.CategoryName AS 'CategoryName'
		,cat.CategoryId AS 'CategoryId'
		,CAST(ISNULL(ia.Quantity, 0) AS NUMERIC(18,2)) AS InStock
		,CAST(ISNULL((
				SELECT ISNULL(SUM(os.Quantity), 0)
				FROM dbo.Orders AS o WITH (NOLOCK)
				INNER JOIN dbo.OrderSetItems AS os WITH (NOLOCK) ON os.OrderId = o.OrderId
				WHERE p.ProductId = os.SubjectId
					AND os.IsDeleted = 0
					AND o.TenantId = @TenantId
					AND o.STATUS in (0,1)
					AND os.SubjectTypeId = @ProductSubjectTypeId
				), 0) AS NUMERIC(18,2)) AS Inquiry
		,CAST(ISNULL((
				SELECT SUM(os.Quantity)
				FROM dbo.Orders AS o WITH (NOLOCK)
				INNER JOIN dbo.OrderSetItems AS os WITH (NOLOCK) ON os.OrderId = o.OrderId
					AND os.IsDeleted = 0
					AND os.ItemStatus = 2
					AND os.SubjectId = p.ProductId
				WHERE o.TenantId = @TenantId
					AND o.STATUS > 2
					AND o.STATUS NOT IN (8,9)
				), 0) AS NUMERIC(18,2)) AS ReadyToDelivered
		,CAST(ISNULL((
				SELECT SUM(SOH.Quantity) AS TotalQuntity
				FROM OrderSetItems AS osi WITH (NOLOCK)
				INNER JOIN StockOnHold AS soh WITH (NOLOCK) ON soh.ORDERSETITEMID = osi.ORDERSETITEMID
					AND SOH.IsStockOnHold = 1
					AND soh.ProductId = p.ProductId
					AND DATEADD(DAY, CAST(SOH.TimePeriod AS INT), CAST(soh.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
				INNER JOIN Orders AS o WITH (NOLOCK) ON o.OrderId = soh.OrderId AND o.STATUS = 0
				WHERE osi.IsDeleted = 0
					AND osi.IsQuantityOnHold = 1
				GROUP BY OSI.SubjectId
				), 0) AS NUMERIC(18,2)) AS OnHold
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
				from Products as p WITH (NOLOCK)
				INNER JOIN Categories as cat WITH (NOLOCK) on p.CategoryId = cat.CategoryId
				--INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
				LEFT JOIN ProductQuantities ia WITH (NOLOCK) ON p.ProductId = ia.ProductId
				--LEFT JOIN StockOnHold sh WITH (NOLOCK) ON p.ProductId = sh.ProductId
				--AND sh.IsStockOnHold = 1
				--AND sh.ProductId = P.ProductId
		WHERE cat.IsDeleted = 0 
				AND P.TenantId = @TenantId
				AND P.Status != 3
				AND (ISNULL(@ModelNo, '') = '' OR p.ModelNo LIKE  '%' + @ModelNo + + '%' )
				AND (ISNULL(@CategoryId, - 1) = - 1 OR p.CategoryId = @CategoryId)
				AND (ISNULL(@ProductTitle, '') = '' OR p.ProductTitle LIKE  '%' + @ProductTitle + '%')
				AND Not exists(
					  select 1
					  from ProductImages pr
					  where p.ProductId = pr.ProductId
					  AND pr.IsVideo = 0
				)
		ORDER BY 
				CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle	END ASC
				,CASE WHEN @SortBy = 'ProductTitle'	AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC
				,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN p.ModelNo END ASC
				,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN p.ModelNo END DESC 
				,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN cat.CategoryName END ASC
				,CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN cat.CategoryName END DESC 
				OFFSET(@PageIndex - 1) * @PageSize ROWS
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

