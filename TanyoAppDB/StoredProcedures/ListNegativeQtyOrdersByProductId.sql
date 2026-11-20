/*
    EXEC [dbo].[ListNegativeQtyOrdersByProductId]
        @TenantId = 2
        ,@ProductId = 1217
        ,@PageIndex = 1
        ,@PageSize = 25
        ,@SortBy = 'DeliveryDate'
        ,@SortOrder = 'ASC'
*/
CREATE   PROC [dbo].[ListNegativeQtyOrdersByProductId]
(
    @TenantId INT
    ,@ProductId BIGINT
    ,@PageIndex INT = 1
    ,@PageSize INT = 25
    ,@SortBy VARCHAR(50) = 'DeliveryDate'
    ,@SortOrder VARCHAR(10) = 'ASC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        DECLARE @SubjectTypeId INT;

        SELECT @SubjectTypeId = st.SubjectTypeId
        FROM SubjectTypes st WITH (NOLOCK)
        WHERE st.TenantId = @TenantId
          AND st.SubjectTypeName = 'Products';

        ;WITH OrderSummary AS
        (
            SELECT 
                o.OrderId
                ,o.OrderNo
                ,ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,'') AS CustomerName
                ,au.FirstName + ' ' + au.LastName + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName
                ,o.Status AS OrderStatus
                ,FORMAT(o.ApprovedDate,'dd/MM/yyyy') AS OrderDate
                ,FORMAT(o.TentativeDeliveryDate,'dd/MM/yyyy') AS DeliveryDate
                ,SUM(ISNULL(osi.Quantity, 0)) AS Quantity
            FROM dbo.Orders o WITH (NOLOCK)
            INNER JOIN dbo.Customers c WITH (NOLOCK) ON c.CustomerId = o.CustomerID
            INNER JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = o.SalesmanId
            INNER JOIN dbo.OrderSetItems osi WITH (NOLOCK) ON osi.OrderId = o.OrderId
                AND osi.SubjectTypeId = @SubjectTypeId
            WHERE o.TenantId = @TenantId
            AND o.Status IN (2,3,4,7)  -- Approved, InProgress, Completed, MaterialReceive
            AND osi.SubjectId = @ProductId
            AND osi.IsDeleted = 0
            GROUP BY o.OrderId
                ,o.OrderNo
                ,c.FirstName
                ,c.LastName
                ,au.FirstName
                ,au.LastName 
                ,au.IsDeleted
                ,o.Status
                ,o.ApprovedDate
                ,o.TentativeDeliveryDate
        )
        SELECT *
            ,COUNT(1) OVER() AS TotalCount
        FROM OrderSummary
        ORDER BY CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'ASC' THEN OrderNo END
            ,CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'DESC' THEN OrderNo END DESC
            ,CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN CustomerName END
            ,CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN CustomerName END DESC
            ,CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'ASC' THEN SalesmanName END
            ,CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'DESC' THEN SalesmanName END DESC
            ,CASE WHEN @SortBy = 'OrderStatus' AND @SortOrder = 'ASC' THEN OrderStatus END
            ,CASE WHEN @SortBy = 'OrderStatus' AND @SortOrder = 'DESC' THEN OrderStatus END DESC
            ,CASE WHEN @SortBy = 'OrderDate' AND @SortOrder = 'ASC' THEN OrderDate END
            ,CASE WHEN @SortBy = 'OrderDate' AND @SortOrder = 'DESC' THEN OrderDate END DESC
            ,CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'ASC' THEN Quantity END
            ,CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'DESC' THEN Quantity END DESC
            ,CASE WHEN @SortBy = 'DeliveryDate' AND @SortOrder = 'ASC' THEN DeliveryDate END
            ,CASE WHEN @SortBy = 'DeliveryDate' AND @SortOrder = 'DESC' THEN DeliveryDate END DESC
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

