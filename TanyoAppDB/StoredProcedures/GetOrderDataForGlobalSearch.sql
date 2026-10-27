
/*  
  EXEC [dbo].[GetOrderDataForGlobalSearch]  
    @SearchText = 'test',  
    @TenantID = 1207  
*/
CREATE PROCEDURE [dbo].[GetOrderDataForGlobalSearch] (
	@SearchText VARCHAR(200)
	,@TenantID BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		IF @SearchText IS NULL
			OR LTRIM(RTRIM(@SearchText)) = ''
		BEGIN
			SELECT NULL AS OrderId
				,NULL AS OrderNo
				,NULL AS CustomerName
				,NULL AS Status
				,NULL AS PhoneNumber
				,NULL AS OrderType
				,NULL AS OrderStatusLabel
				,NULL AS CreatedDate
				,NULL AS ApprovedDate
				,NULL AS DeliveryDate
			WHERE 1 = 0;

			RETURN;
		END

		SELECT TOP 25 o.OrderId
			,o.OrderNo
			,c.FirstName + ' ' + ISNULL(c.LastName, '') AS CustomerName
			,o.Status
			,c.PhoneNumber
			,o.OrderType
			,os.StatusLabel AS OrderStatusLabel
			,o.CreatedDate
			,o.ApprovedDate
			,o.DeliveryDate
		FROM Orders o WITH (NOLOCK)
		INNER JOIN Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
		INNER JOIN OrderStatus os WITH (NOLOCK) ON o.Status = os.StatusEnumId
			AND os.TenantId = @TenantID
		WHERE o.TenantId = @TenantID
			AND os.Type = 'Order'
			AND o.Status <> 9
			AND (
				o.OrderNo LIKE '%' + @SearchText + '%'
				OR c.PhoneNumber LIKE '%' + @SearchText + '%'
				OR c.FirstName LIKE '%' + @SearchText + '%'
				OR ISNULL(c.LastName, '') LIKE '%' + @SearchText + '%'
				OR CONCAT (
					c.FirstName
					,' '
					,ISNULL(c.LastName, '')
					) LIKE '%' + @SearchText + '%'
				)
		ORDER BY c.FirstName + ' ' + c.LastName;
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg NVARCHAR(4000);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

