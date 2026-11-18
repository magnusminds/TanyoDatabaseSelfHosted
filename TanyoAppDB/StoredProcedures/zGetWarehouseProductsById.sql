/*
	EXEC [dbo].[GetWarehouseProductsById]
		@TenantId = 103
		,@WarehouseId = 1
		,@ProductTitle = NULL
		,@ModelNo = NULL
		,@Quantity = NULL
		,@PageIndex = 1 
        ,@PageSize = 50 
        ,@SortBy = NULL
        ,@SortOrder= NULL
*/

CREATE   PROCEDURE [dbo].[zGetWarehouseProductsById]
(
	@TenantId INT
	,@WarehouseId BIGINT
	,@ProductTitle VARCHAR(100) = NULL
	,@ModelNo VARCHAR(100) = NULL	
	,@Quantity NUMERIC(18,2) = NULL
	,@PageIndex INT = 1 
    ,@PageSize INT = 50
    ,@SortBy VARCHAR(100) = 'ProductTitle'
    ,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	IF @SortBy IS NULL SET @SortBy = 'ProductTitle';
	IF @SortOrder IS NULL SET @SortOrder = 'DESC';

	BEGIN TRY		
		SELECT
			p.CoverImage AS ProductImage
			,p.ProductTitle
			,p.ModelNo
			,CAST(ISNULL(pq.Quantity, 0) AS NUMERIC(18,2)) AS Quantity
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM dbo.Warehouse AS w WITH (NOLOCK)
		INNER JOIN dbo.InwardDetailsEntry AS ide WITH (NOLOCK) ON w.Id = ide.WarehouseId
		INNER JOIN dbo.Products AS p WITH (NOLOCK) ON ide.ProductId = p.ProductId
		INNER JOIN dbo.ProductQuantities AS pq WITH (NOLOCK) ON p.ProductId = pq.ProductId
		WHERE w.Id = @WarehouseId
			AND w.TenantId = @TenantId
			AND p.STATUS <> 3
			AND (ISNULL(@ModelNo, '') = '' OR p.ModelNo LIKE  '%' + @ModelNo + + '%' )			
			AND (ISNULL(@ProductTitle, '') = '' OR p.ProductTitle LIKE  '%' + @ProductTitle + '%' )
			AND (@Quantity IS NULL OR @Quantity = CAST(ISNULL(pq.Quantity, 0) AS NUMERIC(18,2)))
		ORDER BY CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN p.ProductTitle END ASC
				,CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN p.ProductTitle END DESC
				,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN p.ModelNo END ASC
				,CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN p.ModelNo END DESC
				,CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'ASC' THEN CAST(ISNULL(pq.Quantity, 0) AS INT) END ASC
				,CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'DESC' THEN CAST(ISNULL(pq.Quantity, 0) AS INT) END DESC
		OFFSET(@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState)
	END CATCH
END

GO

