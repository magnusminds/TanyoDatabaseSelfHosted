/*  
	EXEC [dbo].[ReleaseStockOnHold]
*/
CREATE PROCEDURE [dbo].[ReleaseStockOnHold] 
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON

	BEGIN TRY
	DECLARE @NowUTC DATETIME = GETUTCDATE();
	DECLARE @NowUTCOffset DATETIMEOFFSET = SYSDATETIMEOFFSET();
	DECLARE @UserId BIGINT = 0
	,@Inc INT = 1
	,@Cnt INT = 1
	,@OrderSetItemId BIGINT
	,@OrderId BIGINT

	SELECT @UserId  = UserId 
	FROM AspNetUsers WITH (NOLOCK)
	WHERE Id IN (
				SELECT TOP(1) UserId 
				FROM AspNetUserRoles WITH (NOLOCK)
				WHERE RoleId IN (
								SELECT Id 
								FROM AspNetRoles WITH (NOLOCK)
								WHERE name LIKE '%sys%'
								)
				)

	SELECT SOH.StockOnHoldId
		,SOH.ProductId
		,SOH.Quantity
		,SOH.OrderId
		,SOH.OrderSetItemId
		,SOH.TimePeriod
		,SOH.CreatedUTCDate
		,ORD.TenantId
		,ORD.OrderNo
		,ROW_NUMBER() OVER(ORDER BY SOH.OrderSetItemId) AS Id
	INTO #Expired
	FROM StockOnHold SOH WITH (NOLOCK)
	INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetItemId = SOH.OrderSetItemId
		AND OSI.IsDeleted = 0
	INNER JOIN Orders ORD WITH (NOLOCK) ON ORD.OrderId = SOH.OrderId
		AND ORD.STATUS <> 9
	WHERE soh.IsStockOnHold = 1
		AND CAST(DATEADD(DAY,CAST(SOH.TimePeriod AS INT),SOH.CreatedUTCDate) AS DATE) = CAST( @NowUTC AS date)
	
	select @Cnt = COUNT(Id)
	from #Expired 
	

	WHILE @Inc <= @Cnt
	BEGIN
		
		set @OrderSetItemId = 0
		set @OrderId = 0

		SELECT @OrderSetItemId = OrderSetItemId
		,@OrderId = OrderId
		FROM #Expired
		WHERE Id = @Inc;

		EXEC [ReleaseStockOnHoldByOrderSetItemId]
		@OrderSetItemId = @OrderSetItemId
		,@OrderId = @OrderId
		,@UserId = @UserId
		
		SET @Inc = @Inc + 1
	END


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

