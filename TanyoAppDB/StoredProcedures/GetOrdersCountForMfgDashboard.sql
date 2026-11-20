/*
	EXEC [dbo].[GetOrdersCountForMfgDashboard] @TenantId = 2
*/
CREATE PROCEDURE [dbo].[GetOrdersCountForMfgDashboard]
    @TenantId BIGINT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    SELECT COUNT(DISTINCT o.OrderId) AS OrderCount
    FROM Orders o WITH(NOLOCK)
    INNER JOIN Customers c WITH(NOLOCK)
        ON o.CustomerID = c.CustomerId 
        AND c.TenantId = @TenantId
		AND c.IsDeleted = 0
    INNER JOIN AspNetUsers u WITH(NOLOCK)
        ON o.CreatedBy = u.UserId
		AND u.IsDeleted = 0
		AND u.IsActive = 1
    WHERE o.TenantId = @TenantId
        AND o.Status = 3

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

