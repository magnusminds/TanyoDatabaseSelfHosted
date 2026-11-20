/*
	EXEC GetCatalogueAndSetQRProductList
		@ProductTitle = NULL
		,@TenantId = 2
        ,@WidthOperator = '<='
        ,@Width = 10
*/
CREATE PROCEDURE [dbo].[GetCatalogueAndSetQRProductList] (
	@ProductTitle NVARCHAR(200) = NULL
	,@CategoryId INT = 0
	,@TenantId INT
	,@WidthOperator VARCHAR(2) = NULL
	,@Width DECIMAL(18,2) = NULL
	,@HeightOperator VARCHAR(2) = NULL
	,@Height DECIMAL(18,2) = NULL
	,@DepthOperator VARCHAR(2) = NULL
	,@Depth DECIMAL(18,2) = NULL
	,@DiameterOperator VARCHAR(2) = NULL
	,@Diameter DECIMAL(18,2) = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT PT.ProductId 
		,PT.ProductTitle 
		,PT.ModelNo
		,CASE 
			WHEN C.CategoryTypeId = 2 
				THEN 1 
				ELSE 0 
			END AS IsFabric
		,C.CategoryName 
		,PT.CoverImage AS ProductImage
		,PQT.Quantity AS InStock
		,CAST(1 AS NUMERIC(18,2)) AS Quantity --Default Qty passed for Product Set
	FROM Products PT WITH (NOLOCK)
	INNER JOIN Categories C WITH (NOLOCK) ON C.CategoryId = PT.CategoryId
	INNER JOIN ProductQuantities PQT  WITH (NOLOCK) ON PQT.ProductId = PT.ProductId
	WHERE PT.STATUS = 1
	AND PT.TenantId = @TenantId
	AND (
		@CategoryId = 0
		OR PT.CategoryId = @CategoryId
		)
	AND (
		ISNULL(@ProductTitle,'') = '' 
		OR PT.ProductTitle LIKE '%' + @ProductTitle + '%'
		OR PT.ModelNo LIKE '%' + @ProductTitle + '%'
		)
	AND (
            @Width IS NULL
            OR (
                @WidthOperator = '=' AND PT.Width = @Width
            )
            OR (
                @WidthOperator = '>=' AND PT.Width >= @Width
            )
            OR (
                @WidthOperator = '<=' AND PT.Width <= @Width
            )
        )
    AND (
            @Height IS NULL
            OR (
                @HeightOperator = '=' AND PT.Height = @Height
            )
            OR (
                @HeightOperator = '>=' AND PT.Height >= @Height
            )
            OR (
                @HeightOperator = '<=' AND PT.Height <= @Height
            )
        )
    AND (
            @Depth IS NULL
            OR (
                @DepthOperator = '=' AND PT.Depth = @Depth
            )
            OR (
                @DepthOperator = '>=' AND PT.Depth >= @Depth
            )
            OR (
                @DepthOperator = '<=' AND PT.Depth <= @Depth
            )
        )
    AND (
            @Diameter IS NULL
            OR (
                @DiameterOperator = '=' AND PT.Diameter = @Diameter
            )
            OR (
                @DiameterOperator = '>=' AND PT.Diameter >= @Diameter
            )
            OR (
                @DiameterOperator = '<=' AND PT.Diameter <= @Diameter
            )
        )
	ORDER BY PT.ProductTitle

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

