/*
EXEC GetManufacturingWorkOrders
    @TenantId = 2
    ,@UserId = 4279 
    ,@ManufacturingOrderNo = NULL
    ,@OrderNo = NULL
    ,@ProductTitleOrModelNo = NULL
    ,@Status = NULL
    ,@PageIndex = 1
    ,@PageSize = 20
    ,@SortBy = 'ManufacturingOrderNo'
    ,@SortOrder = 'DESC'
*/
CREATE   PROCEDURE [dbo].[GetManufacturingWorkOrders]
(
    @TenantId BIGINT,
    @UserId BIGINT,
    @ManufacturingOrderNo VARCHAR(100) = NULL,
    @OrderNo VARCHAR(100) = NULL,
    @ProductTitleOrModelNo VARCHAR(200) = NULL,
    @Status INT = NULL,
    @PageIndex INT = 1,
    @PageSize INT = 20,
    @SortBy VARCHAR(50) = 'ManufacturingOrderNo',
    @SortOrder VARCHAR(4) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    DECLARE @Offset INT = (@PageIndex - 1) * @PageSize;

    SELECT 
        MWO.ManufacturingWorkOrderId
        ,OSI.DeliveryNo AS ManufacturingOrderNo
        ,O.OrderNo
        ,O.OrderId
        ,PT.ProductTitle
        ,PT.ModelNo
        ,PT.ProductId
        ,PT.CoverImage AS ProductImage
        ,C.CategoryName
        ,MWO.Status
        ,COUNT(*) OVER() AS TotalCount
    FROM ManufacturingWorkOrders MWO WITH (NOLOCK)
    INNER JOIN OrderSetItems OSI WITH (NOLOCK)
        ON MWO.OrderSetItemId = OSI.OrderSetItemId
    INNER JOIN Orders O WITH (NOLOCK)
        ON MWO.OrderId = O.OrderId
    INNER JOIN Products PT WITH (NOLOCK)
        ON OSI.SubjectId = PT.ProductId
    LEFT JOIN Categories C WITH (NOLOCK)
        ON PT.CategoryId = C.CategoryId
    WHERE 
        O.TenantId = @TenantId
        AND O.status = 3
        AND ISNULL(MWO.IsDeleted,0) = 0
        -- Filters
        AND (
            @ManufacturingOrderNo IS NULL 
            OR OSI.DeliveryNo LIKE '%' + @ManufacturingOrderNo + '%'
        )
        AND (
            @OrderNo IS NULL 
            OR O.OrderNo LIKE '%' + @OrderNo + '%'
        )
        AND (
            @ProductTitleOrModelNo IS NULL
            OR PT.ProductTitle LIKE '%' + @ProductTitleOrModelNo + '%'
            OR PT.ModelNo LIKE '%' + @ProductTitleOrModelNo + '%'
        )
        AND (
            @Status IS NULL 
            OR MWO.Status = @Status
        )

    ORDER BY
        CASE WHEN @SortBy = 'ManufacturingOrderNo' AND @SortOrder = 'ASC' THEN OSI.DeliveryNo END ASC,
        CASE WHEN @SortBy = 'ManufacturingOrderNo' AND @SortOrder = 'DESC' THEN OSI.DeliveryNo END DESC,

        CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'ASC' THEN O.OrderNo END ASC,
        CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'DESC' THEN O.OrderNo END DESC,

        CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'ASC' THEN PT.ProductTitle END ASC,
        CASE WHEN @SortBy = 'ProductTitle' AND @SortOrder = 'DESC' THEN PT.ProductTitle END DESC,

        CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'ASC' THEN PT.ModelNo END ASC,
        CASE WHEN @SortBy = 'ModelNo' AND @SortOrder = 'DESC' THEN PT.ModelNo END DESC,

        CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'ASC' THEN C.CategoryName END ASC,
        CASE WHEN @SortBy = 'CategoryName' AND @SortOrder = 'DESC' THEN C.CategoryName END DESC,

        CASE WHEN @SortBy = 'Status' AND @SortOrder = 'ASC' THEN MWO.Status END ASC,
        CASE WHEN @SortBy = 'Status' AND @SortOrder = 'DESC' THEN MWO.Status END DESC,

        -- Default sorting
        MWO.UpdatedDate DESC

    OFFSET @Offset ROWS FETCH NEXT @PageSize ROWS ONLY;


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

