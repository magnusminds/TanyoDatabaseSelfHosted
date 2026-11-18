/*
	DECLARE @OrderVersionId int = 2;
	DECLARE @TenantId int = 1;
	DECLARE @OrderId bigint = CAST(81036 AS bigint);
	DECLARE @RoleId nvarchar = '0FC94370-F8D9-4AAD-8314-98140AEDE101';

	EXEC GetArchiveOrderDetails_V1 @OrderVersionId, @TenantId, @OrderId, @RoleId
*/
CREATE PROCEDURE [dbo].[zGetArchiveOrderDetails_V1]
(
	@OrderVersionId INT
	,@TenantId INT
	,@OrderId BIGINT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @OrderJson NVARCHAR(MAX) = '';
	DECLARE @CustomerJson NVARCHAR(MAX) = '';
	DECLARE @SummaryJson NVARCHAR(MAX) = '';
	DECLARE @TenantJson NVARCHAR(MAX) = '';
	DECLARE @OrderAddressJson NVARCHAR(MAX) = '';
	DECLARE @OrderSetsJson NVARCHAR(MAX) = '';
	DECLARE @OrderSetItemsJson NVARCHAR(MAX) = '';
	DECLARE @AddOnsJson NVARCHAR(MAX) = '';
	DECLARE @ItemImagesJson NVARCHAR(MAX) = '';
	DECLARE @jsonResult NVARCHAR(MAX);

	DECLARE @ProductSubjectTypeId INT;
	DECLARE @PolishSubjectTypeId INT;
	DECLARE @FabricSubjectTypeId INT;
	DECLARE @UnitName VARCHAR(20);

	;With Cte AS
	(
		SELECT SubjectTypeName ,SubjectTypeId
		FROM SubjectTypes WITH (NOLOCK)
		WHERE TenantId = @TenantId
		AND SubjectTypeName IN ('Products','Polish','Fabrics')
	)
	SELECT @ProductSubjectTypeId = (SELECT TOP (1) SubjectTypeId FROM Cte WHERE SubjectTypeName = 'Products')
		,@PolishSubjectTypeId = (SELECT TOP (1) SubjectTypeId FROM Cte WHERE SubjectTypeName = 'Polish')
		,@FabricSubjectTypeId = (SELECT TOP (1) SubjectTypeId FROM Cte WHERE SubjectTypeName = 'Fabrics')	
	
	--SELECT @ProductSubjectTypeId,@PolishSubjectTypeId,@FabricSubjectTypeId
	DECLARE @OrderSetItemImage TABLE(
	OrderSetItemImageId BIGINT
	,OrderSetItemId BIGINT
	,FileType VARCHAR(200)
	,DrawImage VARCHAR
	,FileImageURL VARCHAR(200)
	,AudioURL VARCHAR(200)
	,FileURL VARCHAR(200)
	,CreatedBy INT
	,CreatedDate DATETIMEOFFSET
	,CreatedUTCDate DATETIME
	);

	DECLARE @TmpArchiveOrders AS TABLE
		(
			ID INT IDENTITY(1,1) PRIMARY KEY
			,OrderId BIGINT
			,CustomerId bigint
			,OrderNo varchar(20) 
			,InquiryLastUpdatedDate datetimeoffset
			,AmountBeforeGST NUMERIC(18,2)
			,CreatedDate datetimeoffset
			,GSTType BIT
			,GrossTotal NUMERIC(18,2)
			,Discount NUMERIC(18,2)
			,TotalAmount NUMERIC(18,0)
			,LumpsumDiscount NUMERIC(18,2)
			,DeliveryCharge tinyint
			,AdvanceAmount NUMERIC(18,2)
			,TentativeDeliveryDate DATE
			,PayableAmount NUMERIC(18,2)
		)

	DECLARE @tmpOrderSetItem AS TABLE
	(
		Id INT IDENTITY PRIMARY KEY
		,OrderSetId BIGINT
		,OrderSetItemId BIGINT
		,parentOrderSetItemId BIGINT
		,ProductName VARCHAR(150)
		,ModelNo VARCHAR(20)
		,UnitPrice NUMERIC(18,2)
		,Quantity NUMERIC(18,2)
		,DiscountPrice NUMERIC(18,2)
		,TotalAmount NUMERIC(18,2)
		,InstantHeight NUMERIC(5,2)
		,InstantWidth NUMERIC(5,2)
		,InstantDepth NUMERIC(5,2)
	)

	;With Cte AS(
				SELECT osi.OrderSetId
					,osi.OrderSetItemId
					,osi.ParentOrderSetItemId
					,p.ProductTitle As ProductName
					,p.ModelNo
					,osi.UnitPrice
					,osi.Quantity
					,osi.DiscountPrice
					,osi.TotalAmount
					,osi.InstantHeight
					,osi.InstantWidth
					,osi.InstantDepth
				FROM Archive_OrderSetItems osi
				INNER JOIN Products p ON p.ProductId = osi.SubjectId
				WHERE osi.OrderId = @OrderId
					AND osi.VersionId = @OrderVersionId
					AND osi.SubjectTypeId = @ProductSubjectTypeId
					AND osi.IsDeleted = 0
				UNION ALL
				SELECT osi.OrderSetId
					,osi.OrderSetItemId
					,osi.ParentOrderSetItemId
					,p.Title As ProductName
					,p.ModelNo
					,osi.UnitPrice
					,osi.Quantity
					,osi.DiscountPrice
					,osi.TotalAmount
					,osi.InstantHeight
					,osi.InstantWidth
					,osi.InstantDepth
				FROM Archive_OrderSetItems osi
				INNER JOIN Fabrics p ON p.FabricId = osi.SubjectId
				WHERE osi.OrderId = @OrderId
					AND osi.VersionId = @OrderVersionId
					AND osi.SubjectTypeId = @FabricSubjectTypeId
					AND osi.IsDeleted = 0
				UNION ALL
				SELECT osi.OrderSetId
					,osi.OrderSetItemId
					,osi.ParentOrderSetItemId
					,p.Title As ProductName
					,p.ModelNo
					,osi.UnitPrice
					,osi.Quantity
					,osi.DiscountPrice
					,osi.TotalAmount
					,osi.InstantHeight
					,osi.InstantWidth
					,osi.InstantDepth
				FROM Archive_OrderSetItems osi
				INNER JOIN Polish p ON p.PolishId = osi.SubjectId
				WHERE osi.OrderId = @OrderId
					AND osi.VersionId = @OrderVersionId
					AND osi.SubjectTypeId = @PolishSubjectTypeId
					AND osi.IsDeleted = 0
			)
		INSERT INTO @tmpOrderSetItem
		(
			OrderSetId
			,OrderSetItemId
			,parentOrderSetItemId
			,ProductName
			,ModelNo
			,UnitPrice
			,Quantity
			,DiscountPrice
			,TotalAmount
			,InstantHeight
			,InstantWidth
			,InstantDepth
		)
		SELECT osi.OrderSetId
			,osi.OrderSetItemId
			,osi.ParentOrderSetItemId
			,osi.ProductName
			,osi.ModelNo
			,osi.UnitPrice
			,osi.Quantity
			,osi.DiscountPrice
			,osi.TotalAmount
			,osi.InstantHeight
			,osi.InstantWidth
			,osi.InstantDepth
		FROM Cte osi
		INNER JOIN Archive_OrderSets os ON os.OrderSetId = osi.OrderSetId
		INNER JOIN Archive_Orders o ON o.OrderId = os.OrderId
			AND o.VersionId = os.VersionId
		INNER JOIN Customers C ON c.CustomerId = o.CustomerID
		WHERE o.VersionId = @OrderVersionId

		INSERT INTO @OrderSetItemImage
		SELECT 
		OSII.OrderSetItemImageId
		,R.OrderSetItemId
		,OSII.FileType
		,OSII.DrawImage
		,(CASE WHEN OSII.FileType = 'Image' THEN OSII.FileURL ELSE NULL END) AS FileImageURL
		,(CASE WHEN OSII.FileType = 'Audio' THEN OSII.FileURL ELSE NULL END) AS AudioURL
		,FileURL
		,CreatedBy
		,CreatedDate
		,CreatedUTCDate
		FROM OrderSetItemImages OSII
		INNER JOIN @tmpOrderSetItem R ON R.OrderSetItemId = OSII.OrderSetItemId

		
		INSERT INTO @TmpArchiveOrders
		(
			OrderId
			,CustomerId 
			,OrderNo 
			,InquiryLastUpdatedDate 
			,AmountBeforeGST
			,CreatedDate
			,GSTType
			,GrossTotal
			,Discount
			,TotalAmount
			,LumpsumDiscount
			,DeliveryCharge
			,AdvanceAmount
			,TentativeDeliveryDate
			,PayableAmount
		)
		SELECT OrderId
			,CustomerId 
			,OrderNo 
			,InquiryLastUpdatedDate 
			,AmountBeforeGST
			,CreatedDate
			,GSTType
			,GrossTotal
			,Discount
			,TotalAmount
			,LumpsumDiscount
			,DeliveryCharge
			,AdvanceAmount
			,TentativeDeliveryDate
			,TotalAmt AS PayableAmount
		FROM Archive_Orders
		WHERE OrderId = @OrderId
			AND VersionId = @OrderVersionId
	
	-- 1. Get Order JSON
	SELECT @OrderJson = ISNULL((
				SELECT @OrderVersionId AS VersionId
					,O.OrderId
					,O.OrderNo
					,O.InquiryLastUpdatedDate
					,O.AmountBeforeGST
					,O.CreatedDate
					,O.GSTType
				FROM @TmpArchiveOrders O
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				), 'null');

	-- 2. Get Customer JSON
	SELECT @CustomerJson = ISNULL((
				SELECT C.CustomerId
					,C.FirstName + ' ' + C.LastName AS CustomerName
					,C.PhoneNumber
					,C.EmailId
				FROM Customers C
				INNER JOIN @TmpArchiveOrders O ON O.CustomerId = C.CustomerId
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				), 'null');

	-- 3. Get Summary JSON
	SELECT @SummaryJson = ISNULL((
				SELECT GrossTotal
					,Discount
					,TotalAmount
					,LumpsumDiscount
					,DeliveryCharge
					,AdvanceAmount
					,TentativeDeliveryDate
					,PayableAmount
				FROM @TmpArchiveOrders
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				), 'null');

	-- 4. Get OrderSetItems JSON
	SELECT @OrderSetItemsJson = ISNULL((
				SELECT *
				FROM @tmpOrderSetItem
				WHERE parentOrderSetItemId IS NULL
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				), '[]' -- Return an empty array if no address is found
		);

	-- 5. Get Tenant JSON
	SELECT @TenantJson = ISNULL((
				SELECT TenantId
					,TenantName
					,FirstName
					,LastName
					,EmailId
					,PhoneNumber
					,LogoPath
					,StreetAddress1
					,StreetAddress2
					,Landmark
					,City
					,State
					,Pincode
				FROM Tenants
				WHERE TenantId = @TenantId
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				), 'null');

	-- 6. Get Order Address JSON
	SELECT @OrderAddressJson = ISNULL((
				SELECT OA.FirstName
					,OA.LastName
					,OA.AddressType
					,(CA.Street1 + ' ' + CA.Street2 + ' ' + CA.Landmark + ' ' + CA.Area + ' ' + CA.City + ' ' + CA.STATE + ' ' + CA.ZipCode) AS Address
				FROM OrderAddresses OA
				INNER JOIN @TmpArchiveOrders O ON OA.OrderId = O.OrderId
				INNER JOIN CustomerAddresses CA ON CA.CustomerAddressId = OA.CustomerAddressId
				FOR JSON PATH
				), '[]' -- Return an empty array if no address is found
		);

	-- 7. Get OrderSets JSON
	SELECT @OrderSetsJson = ISNULL((
				SELECT OS.VersionId
					,OS.OrderSetId
					,OS.OrderId
					,OS.SetName
					,OS.CreatedBy
					,OS.CreatedDate
					,OS.CreatedUTCDate
					,OS.UpdatedBy
					,OS.UpdatedDate
					,OS.UpdatedUTCDate
					,OS.IsDeleted
				FROM Archive_OrderSets OS
				INNER JOIN @TmpArchiveOrders O ON OS.OrderId = O.OrderId
				WHERE Os.VersionId = @OrderVersionId
				FOR JSON PATH
					,WITHOUT_ARRAY_WRAPPER
				), 'null');

    -- 8. Get AddOns JSON
	SELECT @AddOnsJson = (CASE WHEN (SELECT COUNT(*) FROM @tmpOrderSetItem WHERE parentOrderSetItemId IS NOT NULL) = 0 THEN NULL ELSE (SELECT * FROM @tmpOrderSetItem WHERE parentOrderSetItemId IS NOT NULL FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END);

	SELECT @ItemImagesJson = (CASE WHEN (SELECT COUNT(*) FROM @OrderSetItemImage) = 0 THEN NULL ELSE (SELECT * FROM @OrderSetItemImage FOR JSON PATH, WITHOUT_ARRAY_WRAPPER) END);

	-- Combine all JSON objects into a single result  
	SET @jsonResult = CONCAT (
			'{ "ArchiveOrder": ',@OrderJson,
			', "Customer": ',@CustomerJson,
			', "Summary": ',@SummaryJson,
			', "ArchiveOrderSetItems": [',@OrderSetItemsJson,
			'], "Tenant": ',@TenantJson,
			', "OrderAddress": ',@OrderAddressJson,
			', "ArchiveOrderSets": [',@OrderSetsJson,
			'], "ArchiveAddOnItems":' + ISNULL(@AddOnsJson, '['), @AddOnsJson,
			'' + ISNULL(@AddOnsJson, ']') + 
			', "ItemImages":' + ISNULL(@ItemImagesJson, '['), @ItemImagesJson,
			'' + ISNULL(@ItemImagesJson, ']') + 
			'}'
			);

	-- Return the combined JSON result
	SELECT @jsonResult AS JsonResult;
END

GO

