/*
EXEC [dbo].[GetProductVariant]
	@ProductId = 161
	,@ProductVariantId = NULL
	,@PageIndex  = 1
	,@PageSize = 50
	,@SortBy  = 'CreatedDate'
	,@SortOrder = 'ASC'
*/

CREATE PROCEDURE [dbo].[GetProductVariant]
(
	@ProductId INT
	,@ProductVariantId INT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 50
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @Tmp_ProductVariant AS TABLE
		(
			Id INT IDENTITY(1,1)
			,ProductVariantId INT
			,TenantID INT
		)
		INSERT INTO @Tmp_ProductVariant
		(
			ProductVariantId
			,TenantID
		)
		SELECT DISTINCT ProductVariantId, TenantID
		FROM Products WITH (NOLOCK)
		WHERE ProductId = @ProductId

		SELECT CAST(pv.ProductId AS BIGINT) AS ProductId
			,p.ProductTitle
			,p.ModelNo
			,p.CostPrice
			,p.RetailerPrice
			,p.WholesalerPrice
			,p.Status AS IsPublish
			,ISNULL(p.CoverImage,'') AS CoverImage
			,CAST(0 AS BIT) AS IsDeleted
		FROM ProductVariants pv WITH (NOLOCK)
		INNER JOIN @Tmp_ProductVariant tpv ON tpv.ProductVariantId = pv.ProductVariantId
		INNER JOIN Products p WITH (NOLOCK) ON P.ProductId = pv.ProductId
			AND p.TenantId = tpv.TenantID
		--LEFT JOIN ProductImages pis WITH (NOLOCK) ON pis.ProductId = p.ProductId
		--	AND IsCover = 1
		WHERE pv.ProductId <> @ProductId
			AND p.Status = 1 -- Published products only
		
	ORDER BY
		CASE
			WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductId END
			,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN p.ProductId END DESC
			,CASE WHEN @SortBy = 'CreatedDate' AND @SortOrder = 'ASC' THEN pv.CreatedDate END
			,CASE WHEN @SortBy = 'CreatedDate' AND @SortOrder = 'DESC' THEN pv.CreatedDate END DESC
	OFFSET (@PageIndex - 1) * @PageSize ROWS
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

