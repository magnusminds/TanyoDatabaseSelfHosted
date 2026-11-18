/*

EXEC [AutoCreatePO]
	@TenantId = 2
	,@VendorId = 8
	,@UserId = 4449
	,@OrderId = 8
	,@OrderSetItemId = 10



*/


CREATE   PROCEDURE [dbo].[zAutoCreatePO] (
	@TenantId BIGINT
	,@VendorId BIGINT
	,@UserId BIGINT
	,@OrderId BIGINT
	,@OrderSetItemId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @dt DATETIME = GETDATE()
		,@POProductItems NVARCHAR(MAX)
		,@POProductId BIGINT
		,@OrderNo VARCHAR(100)
		,@SubjectTypeId INT,
		 @ErrorMessage VARCHAR(128);

	SELECT @OrderNo = OrderNo
	FROM Orders WITH (NOLOCK)
	WHERE OrderId = @OrderId
		AND TenantId = @TenantId;

	DECLARE @TempPOItems TABLE (
		ProductId BIGINT
		,VendorModelNo NVARCHAR(200)
		,Quantity DECIMAL(18, 2)
		,UnitPrice DECIMAL(18, 2)
		,ExpectedDeliveryDate DATETIME
		,STATUS INT
		,Remarks NVARCHAR(500)
		);

	INSERT INTO @TempPOItems
	SELECT P.ProductId
		,PVM.VendorModelNo
		,OSI.Quantity
		,OSI.UnitPrice
		,DATEADD(DAY, 7, @dt) AS ExpectedDeliveryDate
		,0 AS STATUS
		,'' AS Remarks
	FROM OrderSetItems OSI WITH (NOLOCK)
	INNER JOIN Orders ORD WITH (NOLOCK) ON ORD.OrderId = OSI.OrderId
	INNER JOIN Products P WITH (NOLOCK) ON P.ProductId = OSI.SubjectId
	INNER JOIN ProductVendorMapping PVM WITH (NOLOCK) ON PVM.ProductId = P.ProductId
	INNER JOIN Vendors V WITH (NOLOCK) ON V.VendorId = PVM.VendorId
	INNER JOIN Categories CT WITH (NOLOCK) ON CT.CategoryId = P.CategoryId
	WHERE OSI.OrderSetItemId = @OrderSetItemId
		AND OSI.OrderId = @OrderId
		AND ORD.TenantId = @TenantId
		AND V.VendorId = @VendorId
		AND ISNULL(CT.IsManufacturing, 0) = 0;

	IF NOT EXISTS (
			SELECT 1
			FROM @TempPOItems
			)
	BEGIN
		SET @ErrorMessage = 'No eligible products found for auto PO creation.'
		SELECT @ErrorMessage AS ErrorMessage;

		RETURN;
	END

	SELECT @POProductItems = (
			SELECT ProductId
				,VendorModelNo
				,Quantity
				,UnitPrice
				,ExpectedDeliveryDate
				,STATUS
				,Remarks
			FROM @TempPOItems
			FOR JSON PATH
			);

	DECLARE @TempInsertedPOs TABLE (
		POProductId BIGINT
		,VendorId BIGINT
		);

	INSERT INTO @TempInsertedPOs (
		POProductId
		,VendorId
		)
	EXEC [dbo].[SavePOProducts] @POProductId = 0
		,@TenantId = @TenantId
		,@VendorId = @VendorId
		,@OrderDate = @dt
		,@Status = 0
		,@UserId = @UserId
		,@POProductItems = @POProductItems;

	SELECT TOP 1 @POProductId = POProductId
	FROM @TempInsertedPOs;

	SELECT @SubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE TenantId = @TenantId
		AND SubjectTypeName = 'POProducts'
		AND IsDeleted = 0

	IF (@POProductId IS NOT NULL)
	BEGIN
		INSERT INTO Comments (
			SubjectTypeId
			,SubjectId
			,Comment
			,STATUS
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
			)
		VALUES (
			@SubjectTypeId
			,@POProductId
			,CONCAT (
				'PO has been generated for OrderNo: '
				,@OrderNo
				)
			,0
			,@UserId
			,GETDATE()
			,GETUTCDATE()
			);

		SELECT CONCAT (
				'PO created successfully for OrderNo '
				,@OrderNo
				,' with POProductId: '
				,@POProductId
				);
	END
	ELSE
	BEGIN
		
		SET @ErrorMessage = 'PO creation failed via SavePOProducts.'
		
		SELECT @ErrorMessage AS ErrorMessage;
	END
END

GO

