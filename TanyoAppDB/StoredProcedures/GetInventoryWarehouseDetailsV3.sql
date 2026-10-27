/*
    EXEC [dbo].[GetInventoryWarehouseDetailsV3] 
        @ProductId = 402955
        ,@WarehouseId = 10280
*/
CREATE PROCEDURE [dbo].[GetInventoryWarehouseDetailsV3] 
	 @ProductId BIGINT
	,@WarehouseId BIGINT = NULL
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		DECLARE @ReadyToDeliver NUMERIC(18, 2) = 0
			,@ProductSubjectTypeId INT = 0
			,@dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
			,@OnHoldCnt NUMERIC(18, 2) = 0
			,@ApprovedQuantities NUMERIC(18, 2) = 0
			,@InStock NUMERIC(18, 2) = 0
			,@FinalTotal NUMERIC(18, 2) = 0
			,@WarehouseDetailsJson NVARCHAR(MAX);

		DROP TABLE IF EXISTS #Result;

			CREATE TABLE #Result (
				ID INT IDENTITY(1, 1)
				,SequenceNo INT
				,SequenceValue VARCHAR(255)
				,Quantity NUMERIC(18, 2)
				,WarehouseDetailsJson NVARCHAR(MAX) NULL
				,IsTotal BIT DEFAULT 0
				);

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE SubjectTypeName = 'Products'
			AND TenantId = (
				SELECT TenantId
				FROM Products WITH (NOLOCK)
				WHERE ProductId = @ProductId
				)
			AND IsDeleted = 0;

		SELECT @InStock = ISNULL(Quantity, 0)
		FROM ProductQuantities WITH (NOLOCK)
		WHERE ProductId = @ProductId;

		SELECT @ReadyToDeliver = ISNULL(SUM(os.Quantity), 0)
		FROM dbo.Orders o WITH (NOLOCK)
		INNER JOIN dbo.OrderSetItems os WITH (NOLOCK) ON os.OrderId = o.OrderId
		WHERE os.IsDeleted = 0
			AND os.SubjectId = @ProductId
			AND os.SubjectTypeId = @ProductSubjectTypeId
			AND o.Status = 3
			AND os.ItemStatus = 2;

		SELECT @ApprovedQuantities = ISNULL(SUM(os.Quantity), 0)
		FROM dbo.Orders o WITH (NOLOCK)
		INNER JOIN dbo.OrderSetItems os WITH (NOLOCK) ON os.OrderId = o.OrderId
		WHERE os.IsDeleted = 0
			AND os.SubjectId = @ProductId
			AND os.SubjectTypeId = @ProductSubjectTypeId
			AND (
				o.Status = 2
				OR (
					o.Status = 3
					AND os.ItemStatus IN (
						0
						,1
						,4
						)
					)
				);

		/*
            Item Status:
            0 = ReadyToManufacturing
            1 = Manufacturing
            2 = ReadyToDeliver
            3 = Delivered
            4 = Pending
        */
		SELECT @OnHoldCnt = ISNULL(SUM(vi.Quantity), 0)
		FROM vw_HoldItems vi WITH (NOLOCK)
		WHERE vi.SubjectId = @ProductId
			AND vi.HoldUptoDate > @dt;

		SET @FinalTotal = ISNULL(@InStock, 0) + ISNULL(@OnHoldCnt, 0) + ISNULL(@ApprovedQuantities, 0) + ISNULL(@ReadyToDeliver, 0);

		SELECT @WarehouseDetailsJson = (
				SELECT ROW_NUMBER() OVER (
						ORDER BY W.Name
						) AS SequenceNo
					,W.Id AS WarehouseId
					,W.Name AS WarehouseName
					,PW.Quantity AS Quantity
				FROM ProductQuantitiesByWarehouse PW WITH (NOLOCK)
				INNER JOIN Warehouse W WITH (NOLOCK) ON PW.WarehouseId = W.Id
				WHERE PW.ProductId = @ProductId
					AND (
						@WarehouseId IS NULL
						OR @WarehouseId = - 1
						OR PW.WarehouseId = @WarehouseId
						)
				ORDER BY W.Name
				FOR JSON PATH
				);

		INSERT INTO #Result (
			SequenceNo
			,SequenceValue
			,Quantity
			,WarehouseDetailsJson
			,IsTotal
			)
		VALUES 
			(1,'Saleable Quantities',ISNULL(@InStock, 0),NULL,0)
			,(2,'On Hold Quantities',ISNULL(@OnHoldCnt, 0),NULL,0)
			,(3,'Approved Quantities',ISNULL(@ApprovedQuantities, 0),NULL,0)
			,(4,'Ready To Deliver Quantities',ISNULL(@ReadyToDeliver, 0),NULL,0)
			,(5,'Total In Stock Quantities',ISNULL(@FinalTotal, 0),@WarehouseDetailsJson,1);

		SELECT r.SequenceNo
			,r.SequenceValue
			,r.Quantity
			,r.WarehouseDetailsJson
			,r.IsTotal
		FROM #Result r
		ORDER BY r.SequenceNo;

		DROP TABLE #Result;
	END TRY

	BEGIN CATCH
		IF OBJECT_ID('tempdb..#Result') IS NOT NULL
			DROP TABLE #Result;

		DECLARE @ObjectName VARCHAR(400)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END

GO

