CREATE PROCEDURE [dbo].[GetOrderDetails_V1] (
	@TenantId INT
	,@OrderId BIGINT
	,@RoleId NVARCHAR(36)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DECLARE @ProductSubjectTypeId INT;
		DECLARE @PolishSubjectTypeId INT;
		DECLARE @FabricSubjectTypeId INT;
		DECLARE @IsWholesaler BIT = 0;

		SELECT @ProductSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE TenantId = @TenantId
			AND SubjectTypeName = 'Products';

		SELECT @PolishSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE TenantId = @TenantId
			AND SubjectTypeName = 'Polish';

		SELECT @FabricSubjectTypeId = SubjectTypeId
		FROM SubjectTypes
		WHERE TenantId = @TenantId
			AND SubjectTypeName = 'Fabrics';

		IF EXISTS (
				SELECT 1
				FROM AspNetRoleClaims WITH (NOLOCK)
				WHERE RoleId = @RoleId
					AND ClaimValue IN (
						'Permissions.App.Order.WholeselerPrice'
						,'Permissions.General.Order.WholeselerPrice'
						)
				)
		BEGIN
			SET @IsWholesaler = 1
		END

		-- Temporary table to hold the final result for OrderSetItems  
		DECLARE @OrderSetItemsResult TABLE (
			OrderSetItemId BIGINT
			,OrderId BIGINT
			,OrderSetId BIGINT
			,SubjectTypeId INT
			,SubjectId BIGINT
			,ProductImage NVARCHAR(MAX)
			,Width DECIMAL(18, 2)
			,Height DECIMAL(18, 2)
			,Depth DECIMAL(18, 2)
			,Quantity DECIMAL(18, 2)
			,UnitPrice DECIMAL(18, 2)
			,DiscountPrice DECIMAL(18, 2)
			,TotalAmount DECIMAL(18, 2)
			,Comment NVARCHAR(MAX)
			,MakingStatus INT
			,ReceiveDate DATETIME
			,ProvidedMaterial NVARCHAR(MAX)
			,ParentOrderSetItemId BIGINT
			,PerUnitPrice DECIMAL(18, 2)
			,SubjectTypeName NVARCHAR(255)
			,OfferId BIGINT
			,InstantUnitPrice DECIMAL(18, 2)
			,InstantHeight DECIMAL(18, 2)
			,InstantWidth DECIMAL(18, 2)
			,InstantDepth DECIMAL(18, 2)
			,InstantDiameter DECIMAL(18, 2)
			,InstantCostPrice DECIMAL(18, 2)
			,Offerpercentage INT
			,OriginalUnitPrice DECIMAL
			,UnitPriceWithoutOffer DECIMAL
			,ProductTitle VARCHAR(200)
			,ModelNo VARCHAR(100)
			,CostPrice DECIMAL
			,MaxDiscount DECIMAL
			,ReceivedDate DATETIMEOFFSET NULL
			,ReceivedMaterial DECIMAL(18, 2)
			,ReceivedFrom VARCHAR(200)
			,RecievedComment VARCHAR(200)
			,ReceivedBy BIGINT
			,ReceivedByName VARCHAR(200)
			,GrossTotal NUMERIC(18, 2)
			,UnitSalePrice NUMERIC(18, 2)
			,Diameter DECIMAL(18, 2)
			,IsSellByPerSQFT BIT
			,MRP NUMERIC(18, 2)
			);
		-- Temp Table to hold the ParentOrderSetItems  
		DECLARE @ParentSetItems TABLE (
			ParentOrderSetItemId INT
			,OrderSetItemId INT
			,SubjectTypeId INT
			,OfferId INT
			,Offerpercentage INT
			,OriginalUnitPrice DECIMAL(18, 2)
			,InstantCostPrice DECIMAL(18, 2)
			,UnitPriceWithoutOffer DECIMAL(18, 2)
			,SubjectId INT
			,MaxDiscount DECIMAL(18, 2)
			);
		-- Temp Table to hold the Set Item Images  
		DECLARE @OrderSetItemImage TABLE (
			OrderSetItemImageId BIGINT
			,OrderSetItemId BIGINT
			,FileType VARCHAR(200)
			,DrawImage VARCHAR(MAX)
			,FileImageURL VARCHAR(MAX)
			,AudioURL VARCHAR(MAX)
			,FileURL VARCHAR(MAX)
			,CreatedBy INT
			,CreatedDate DATETIMEOFFSET
			,CreatedUTCDate DATETIME
			);

		INSERT INTO @ParentSetItems
		SELECT OSI.ParentOrderSetItemId
			,OSI.OrderSetItemId
			,OSI.SubjectTypeId
			,OSI.OfferId
			,0
			,0
			,OSI.InstantCostPrice
			,0
			,OSI.SubjectId
			,0
		FROM OrderSetItems OSI
		INNER JOIN OrderSets OS ON OSI.OrderSetId = OS.OrderSetId
			AND os.IsDeleted = 0
		INNER JOIN Orders O ON OSI.OrderId = O.OrderId
		WHERE O.TenantId = @TenantId
			AND (OSI.ParentOrderSetItemId IS NULL)
			AND osi.OrderId = @OrderId
			AND osi.IsDeleted = 0
		ORDER BY OSI.OrderSetItemId

		DECLARE @TempAddOnsItems TABLE (
			OrderSetItemId BIGINT
			,OrderId BIGINT
			,OrderSetId BIGINT
			,SubjectTypeId INT
			,SubjectId BIGINT
			,ProductImage NVARCHAR(MAX)
			,Width DECIMAL(18, 2)
			,Height DECIMAL(18, 2)
			,Depth DECIMAL(18, 2)
			,Quantity DECIMAL(18, 2)
			,UnitPrice DECIMAL(18, 2)
			,DiscountPrice DECIMAL(18, 2)
			,TotalAmount DECIMAL(18, 2)
			,Comment NVARCHAR(MAX)
			,MakingStatus INT
			,ReceiveDate DATETIME
			,ProvidedMaterial NVARCHAR(MAX)
			,ParentOrderSetItemId BIGINT
			,PerUnitPrice DECIMAL(18, 2)
			,SubjectTypeName NVARCHAR(255)
			,OfferId BIGINT
			,InstantUnitPrice DECIMAL(18, 2)
			,InstantHeight DECIMAL(18, 2)
			,InstantWidth DECIMAL(18, 2)
			,InstantDepth DECIMAL(18, 2)
			,InstantDiameter DECIMAL(18, 2)
			,InstantCostPrice DECIMAL(18, 2)
			,Offerpercentage INT
			,OriginalUnitPrice DECIMAL
			,UnitPriceWithoutOffer DECIMAL
			,ProductTitle VARCHAR(200)
			,ModelNo VARCHAR(100)
			,CostPrice DECIMAL
			,MaxDiscount DECIMAL
			,GrossTotal NUMERIC(18, 2)
			,Diameter DECIMAL(18, 2)
			,UnitSalePrice NUMERIC(18, 2)
			,IsSellByPerSQFT BIT
			,MRP NUMERIC(18, 2)
			);
		-- Temporary table to hold the final result for Summary  
		DECLARE @TempSummaryTable TABLE (
			GrossTotal DECIMAL(18, 2)
			,Discount DECIMAL(18, 2)
			,AdvanceAmount DECIMAL(18, 2)
			,LumpsumDiscount DECIMAL(18, 2)
			,DeliveryCharges DECIMAL(18, 2)
			,DeliveryCharge DECIMAL(18, 2)
			,RoundOff DECIMAL(18, 2)
			,DeliveryAmountCollectionType INT
			,DeliveryAmount DECIMAL(18, 2)
			,TotalAmount DECIMAL(18, 2)
			,TotalAmt DECIMAL(18, 2)
			,AmountBeforeGST DECIMAL(18, 2)
			,SGSTAmount DECIMAL(18, 2)
			,CGSTAmount DECIMAL(18, 2)
			,IsAutoManufacture BIT
			,FinalTotal DECIMAL(18, 2)
			,DeliveryExtraPaymentAmount DECIMAL(18, 2)
			,ColorCode VARCHAR(50)
			,LabelName VARCHAR(100)
			,FeedBackComments VARCHAR(MAX)
			,FeedbackValue DECIMAL(18, 2)
			,FeedbackRoundValue INT
			,TentativeDeliveryDate DATETIME
			);
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

		INSERT INTO @OrderSetItemsResult
		SELECT osi.OrderSetItemId
			,osi.OrderId
			,osi.OrderSetId
			,osi.SubjectTypeId
			,osi.SubjectId
			,ISNULL(osi.ProductImage, '/images/No-coverimage.png') AS ProductImage
			,osi.Width
			,osi.Height
			,osi.Depth
			,osi.Quantity
			,osi.UnitPrice AS UnitPrice
			,osi.DiscountPrice
			,CASE 
				WHEN o.GSTType = 1
					THEN ROUND(osi.AmountBeforeGST, 0, 1)
				ELSE ROUND(osi.TotalAmount, 0, 1)
				END AS TotalAmount
			,osi.Comment
			,osi.ItemStatus AS MakingStatus
			,osi.ReceiveDate
			,osi.ProvidedMaterial
			,osi.ParentOrderSetItemId
			,ROUND(osi.UnitPrice - ROUND((osi.UnitPrice * osi.DiscountPrice) / 100, 2), 0, 1) AS PerUnitPrice
			,st.SubjectTypeName
			,osi.OfferId
			,osi.InstantUnitPrice
			,osi.InstantHeight
			,osi.InstantWidth
			,osi.InstantDepth
			,osi.InstantDiameter
			,osi.InstantCostPrice
			,osi.OfferPercentage
			,0
			,0
			,''
			,''
			,0
			,0
			,NULL
			,0
			,''
			,''
			,0
			,''
			,osi.GrossTotal
			,osi.UnitSalePrice
			,osi.Diameter
			,0 -- IsSellByPerSQFT (Default 0)
			,osi.MRP
		FROM OrderSetItems osi
		INNER JOIN SubjectTypes st ON osi.SubjectTypeId = st.SubjectTypeId
		INNER JOIN OrderSets OS ON osi.OrderSetId = OS.OrderSetId
			AND os.IsDeleted = 0
		INNER JOIN Orders O ON O.OrderId = OSI.OrderId
		WHERE O.OrderId = @OrderId
			AND osi.IsDeleted = 0

		-- Subject Types Calculations  
		-- Update if has Offers & It is Product Type  
		UPDATE r
		SET r.UnitPriceWithoutOffer = CASE 
				WHEN r.InstantCostPrice IS NOT NULL
					THEN r.MRP
						--THEN dbo.GetUnitPriceWithoutOfferFormat(@TenantId, c.CategoryName, r.SubjectId, r.InstantCostPrice, r.Width, r.Height, r.Depth, r.InstantWidth, r.InstantHeight, r.InstantDepth, (
						--			SELECT TOP 1 AmountRoundMultiple
						--			FROM Tenants
						--			WHERE TenantId = @TenantId
						--			), r.Quantity)
				ELSE NULL
				END
			--,r.OriginalUnitPrice = dbo.CalculateFinalCostPrice(r.SubjectId, 0, 0, -- 0 for Customer Type Retailer & 1 for Wholesaler  
			--	@RoleId, @TenantId, p.CategoryId)
			,r.OriginalUnitPrice = CASE 
				WHEN @IsWholesaler = 1
					THEN P.WholesalerPrice
				ELSE P.RetailerPrice
				END
			,r.ProductTitle = p.ProductTitle
			,r.ModelNo = p.ModelNo
			,r.CostPrice = r.InstantCostPrice --dbo.GetProductCostPriceByDimension(p.ProductId, r.Width, r.Height, r.Depth)
			,r.MaxDiscount = c.MaxDiscount
			,r.IsSellByPerSQFT = ISNULL(c.IsSellByPerSQFT, 0)
		FROM @OrderSetItemsResult r
		INNER JOIN Products p ON r.SubjectId = p.ProductId
		INNER JOIN Categories c ON p.CategoryId = c.CategoryId
		LEFT JOIN Offers o ON r.OfferId = o.OfferId
		WHERE r.SubjectTypeId = @ProductSubjectTypeId;

		-- Update if it is Polish Type  
		UPDATE r
		SET r.ProductTitle = p.Title
			,r.ModelNo = p.ModelNo
			,r.CostPrice = p.UnitPrice
			,r.SubjectTypeName = 'Polish'
		FROM @OrderSetItemsResult r
		INNER JOIN Polish p ON r.SubjectId = p.PolishId
		LEFT JOIN Offers o ON r.OfferId = o.OfferId
		WHERE r.SubjectTypeId = @PolishSubjectTypeId;

		-- Update if it is Fabrics Type  
		UPDATE r
		SET r.ProductTitle = f.Title
			,r.ModelNo = f.ModelNo
			,r.CostPrice = f.UnitPrice
			,r.SubjectTypeName = 'Fabrics'
			,r.MaxDiscount = c.MaxDiscount
		FROM @OrderSetItemsResult r
		INNER JOIN Fabrics f ON r.SubjectId = f.FabricId
		INNER JOIN Companies c ON f.CompanyId = c.CompanyId
		LEFT JOIN Offers o ON r.OfferId = o.OfferId
		WHERE r.SubjectTypeId = @FabricSubjectTypeId;

		-- Order SetItems Receivables Logic  
		UPDATE R
		SET R.ReceivedDate = OSIR.ReceivedDate
			,R.ReceivedMaterial = OSIR.ProvidedMaterial
			,R.ReceivedFrom = OSIR.ReceivedFrom
			,R.RecievedComment = OSIR.Comment
			,R.ReceivedBy = OSIR.ReceivedBy
			,R.ReceivedByName = U.FirstName + U.LastName
		FROM @OrderSetItemsResult R
		INNER JOIN OrderSetItemReceivables OSIR ON R.OrderSetItemId = OSIR.OrderSetItemId
		INNER JOIN AspNetUsers U ON R.ReceivedBy = U.Userid

		-- Order Set Item Image Logic  
		INSERT INTO @OrderSetItemImage
		SELECT OSII.OrderSetItemImageId
			,R.OrderSetItemId
			,OSII.FileType
			,OSII.DrawImage
			,(
				CASE 
					WHEN OSII.FileType = 'Image'
						THEN OSII.FileURL
					ELSE NULL
					END
				) AS FileImageURL
			,(
				CASE 
					WHEN OSII.FileType = 'Audio'
						THEN OSII.FileURL
					ELSE NULL
					END
				) AS AudioURL
			,FileURL
			,CreatedBy
			,CreatedDate
			,CreatedUTCDate
		FROM OrderSetItemImages OSII
		INNER JOIN @OrderSetItemsResult R ON R.OrderSetItemId = OSII.OrderSetItemId

		-- Insert AddOns Items  
		INSERT INTO @TempAddOnsItems
		SELECT R.OrderSetItemId
			,R.OrderId
			,R.OrderSetId
			,R.SubjectTypeId
			,R.SubjectId
			,R.ProductImage
			,R.Width
			,R.Height
			,R.Depth
			,R.Quantity
			,R.UnitPrice
			,R.DiscountPrice
			,R.TotalAmount
			,R.Comment
			,R.MakingStatus
			,R.ReceiveDate
			,R.ProvidedMaterial
			,R.ParentOrderSetItemId
			,R.PerUnitPrice
			,R.SubjectTypeName
			,R.OfferId
			,R.InstantUnitPrice
			,R.InstantHeight
			,R.InstantWidth
			,R.InstantDepth
			,R.InstantDiameter
			,R.InstantCostPrice
			,R.Offerpercentage
			,R.OriginalUnitPrice
			,R.UnitPriceWithoutOffer
			,R.ProductTitle
			,R.ModelNo
			,R.CostPrice
			,R.MaxDiscount
			,R.GrossTotal
			,R.Diameter
			,R.UnitSalePrice
			,R.IsSellByPerSQFT
			,R.MRP
		FROM @OrderSetItemsResult R
		INNER JOIN @ParentSetItems PR ON PR.OrderSetItemId = R.ParentOrderSetItemId
		WHERE R.ParentOrderSetItemId IS NOT NULL
			OR R.ParentOrderSetItemId > 0

		-- Item AddOns Logic   
		--If Product Type & has offers  
		UPDATE R
		SET -- R.Offerpercentage = O.OfferPercentage
			--,R.OriginalUnitPrice = dbo.CalculateFinalCostPrice(r.SubjectId, 0, 0 -- 0 for Customer Type Retailer & 1 for Wholesaler  
			--	, @RoleId, @TenantId, 0)
			r.OriginalUnitPrice = CASE 
				WHEN @IsWholesaler = 1
					THEN P.WholesalerPrice
				ELSE P.RetailerPrice
				END
			,r.UnitPriceWithoutOffer = r.MRP
		--,r.UnitPriceWithoutOffer = dbo.GetUnitPriceWithoutOfferFormat(@TenantId, c.CategoryName, r.SubjectId, r.InstantCostPrice, r.Width, r.Height, r.Depth, r.InstantWidth, r.InstantHeight, r.InstantDepth, (
		--		SELECT TOP 1 AmountRoundMultiple
		--		FROM Tenants
		--		WHERE TenantId = @TenantId
		--		), r.Quantity)
		FROM @TempAddOnsItems R
		INNER JOIN @ParentSetItems PR ON PR.ParentOrderSetItemId = R.OrderSetItemId
		INNER JOIN Products P ON P.ProductId = R.SubjectId
		INNER JOIN Categories C ON P.CategoryId = C.CategoryId
		LEFT JOIN Offers O ON R.OfferId = O.OfferId
		WHERE R.SubjectTypeId = @ProductSubjectTypeId
			AND R.OfferId IS NOT NULL
			--AND R.OfferId != 0  
			AND R.ParentOrderSetItemId IS NULL
			OR R.ParentOrderSetItemId = 0

		--If has no Offers  
		UPDATE R
		SET R.MaxDiscount = c.MaxDiscount
		FROM @TempAddOnsItems R
		INNER JOIN @ParentSetItems PR ON PR.ParentOrderSetItemId = R.OrderSetItemId
		INNER JOIN Products P ON P.ProductId = R.SubjectId
		INNER JOIN Categories C ON P.CategoryId = C.CategoryId
		WHERE R.SubjectTypeId = @ProductSubjectTypeId
			AND (
				R.OfferId IS NULL
				OR R.OfferId = 0
				)
			AND R.ParentOrderSetItemId IS NULL
			OR R.ParentOrderSetItemId = 0

		--If Fabric Type  
		UPDATE R
		SET R.MaxDiscount = C.MaxDiscount
		FROM @TempAddOnsItems R
		INNER JOIN @ParentSetItems PR ON PR.ParentOrderSetItemId = R.OrderSetItemId
		INNER JOIN Fabrics F ON R.SubjectId = F.FabricId
		INNER JOIN Companies C ON C.CompanyId = F.CompanyId
		WHERE R.SubjectTypeId = @FabricSubjectTypeId
			AND R.ParentOrderSetItemId IS NULL
			OR R.ParentOrderSetItemId = 0;

		-- Get Summary Details & Insert into temp table  
		DECLARE @FeedbackValue DECIMAL(18, 2) = NULL

		SELECT @FeedbackValue = ROUND(CASE 
					WHEN COUNT(FO.FeedbackValue) > 0
						THEN SUM(FO.FeedbackValue) * 1.0 / COUNT(FO.FeedbackValue)
					ELSE 0
					END, 2)
		FROM FeedbackOrders FO
		WHERE OrderId = @OrderId

		--GROUP BY FO.OrderId  
		INSERT INTO @TempSummaryTable
		SELECT O.GrossTotal
			,O.Discount
			,O.AdvanceAmount
			,O.LumpsumDiscount
			,O.DeliveryCharges
			,O.DeliveryCharge
			,(ISNULL(O.TotalAmt, 0) - (ISNULL(O.AmountBeforeGST, 0) + ISNULL(O.CGSTAmount, 0) + ISNULL(O.SGSTAmount, 0))) AS RoundOff
			,O.DeliveryAmountCollectionType
			,O.DeliveryAmount
			,O.TotalAmount
			,O.TotalAmt
			,O.AmountBeforeGST
			,O.SGSTAmount
			,O.CGSTAmount
			,T.IsAutoManufacture
			,ROUND(CASE 
					WHEN ISNULL(O.GrossTotal, 0) > 0
						THEN ISNULL(O.GrossTotal, 0) + 0.5 -- Add 0.5 for positive numbers  
					WHEN ISNULL(O.GrossTotal, 0) < 0
						THEN ISNULL(O.GrossTotal, 0) - 0.5 -- Subtract 0.5 for negative numbers  
					ELSE 0
					END, 0) AS FinalTotal
			,(
				CASE 
					WHEN O.DeliveryAmount IS NULL
						THEN 0
					WHEN (
							O.DeliveryAmountCollectionType IS NOT NULL
							AND O.DeliveryAmountCollectionType = 2
							)
						OR (
							O.DeliveryCharge IS NOT NULL
							AND O.DeliveryCharge <> 3
							)
						THEN 0
					ELSE ISNULL(O.DeliveryAmount, 0)
					END
				) AS DeliveryExtraPaymentAmount
			,(
				CASE 
					WHEN L.ColorCode IS NULL
						THEN ''
					ELSE L.ColorCode
					END
				) AS ColorCode
			,(
				CASE 
					WHEN L.LabelName IS NULL
						THEN ''
					ELSE L.LabelName
					END
				) AS LabelName
			,FC.Comment AS FeedBackComments
			,ISNULL(@FeedbackValue, 0) AS FeedbackValue
			,CASE 
				WHEN ISNULL(@FeedbackValue, 0) >= 0
					AND ISNULL(@FeedbackValue, 0) < 1
					THEN 0
				WHEN ISNULL(@FeedbackValue, 0) >= 1
					AND ISNULL(@FeedbackValue, 0) < 2
					THEN 1
				WHEN ISNULL(@FeedbackValue, 0) >= 2
					AND ISNULL(@FeedbackValue, 0) < 3
					THEN 2
				WHEN ISNULL(@FeedbackValue, 0) >= 3
					AND ISNULL(@FeedbackValue, 0) < 4
					THEN 3
				WHEN ISNULL(@FeedbackValue, 0) >= 4
					AND ISNULL(@FeedbackValue, 0) < 5
					THEN 4
				ELSE 5
				END AS FeedbackRoundValue
			,TentativeDeliveryDate
		FROM Orders O
		INNER JOIN Tenants T ON O.TenantId = T.TenantId
		LEFT JOIN Labels L ON L.LabelId = O.LabelId
		LEFT JOIN FeedbackComments FC ON FC.OrderId = O.OrderId
		WHERE T.TenantId = @TenantId
			AND O.OrderId = @OrderId

		-- 1. Get Order JSON  
		SELECT @OrderJson = ISNULL((
					SELECT O.OrderId
						,O.OrderNo
						,O.InquiryLastUpdatedDate
						,O.AmountBeforeGST
						,O.CreatedDate
						,O.GSTType
						,O.TentativeDeliveryDate
						,O.DeliveryAmountCollectionType
						,O.Status
						,O.IsSyncWithTally
					FROM Orders O
					WHERE O.OrderId = @OrderId
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
					INNER JOIN Orders O ON O.CustomerId = C.CustomerId
					WHERE O.OrderId = @OrderId
					FOR JSON PATH
						,WITHOUT_ARRAY_WRAPPER
					), 'null');

		-- 3. Get Summary JSON  
		SELECT @SummaryJson = ISNULL((
					SELECT *
					FROM @TempSummaryTable
					--SELECT OSI.GrossTotal, OSI.Discount, OSI.TotalAmount, OSI.DeliveryDate, O.TentativeDeliveryDate,   
					--                 O.AdvanceAmount, O.DeliveryCharge, O.LumpsumDiscount, O.DeliveryAmountCollectionType,   
					--                 O.DeliveryAmount FROM Orders O   
					-- INNER JOIN OrderSets OS ON O.OrderId = OS.OrderId  
					-- INNER JOIN OrderSetItems OSI ON O.OrderId = OSI.OrderId AND OS.OrderSetId = OSI.OrderSetId  
					-- WHERE O.OrderId = @OrderId  
					FOR JSON PATH
						,WITHOUT_ARRAY_WRAPPER
					), 'NULL');

		-- 4. Get OrderSetItems JSON  
		SELECT @OrderSetItemsJson = ISNULL((
					SELECT *
					FROM @OrderSetItemsResult
					FOR JSON PATH
						--,WITHOUT_ARRAY_WRAPPER  
					), '[]' -- Return an empty array if no address is found  
			);

		-- 5. Get Tenant JSON  
		SELECT @TenantJson = ISNULL((
					SELECT *
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
					INNER JOIN Orders O ON OA.OrderId = O.OrderId
					INNER JOIN CustomerAddresses CA ON CA.CustomerAddressId = OA.CustomerAddressId
					WHERE OA.OrderId = @OrderId
					FOR JSON PATH
					), '[]' -- Return an empty array if no address is found  
			);

		-- 7. Get OrderSets JSON  
		SELECT @OrderSetsJson = ISNULL((
					SELECT OS.OrderSetId
						,OS.OrderId
						,OS.SetName
						,OS.CreatedBy
						,OS.CreatedDate
						,OS.CreatedUTCDate
						,OS.UpdatedBy
						,OS.UpdatedDate
						,OS.UpdatedUTCDate
						,OS.IsDeleted
					FROM OrderSets OS
					INNER JOIN Orders O ON OS.OrderId = O.OrderId
					WHERE O.OrderId = @OrderId
						AND OS.IsDeleted = 0
					FOR JSON PATH
						,WITHOUT_ARRAY_WRAPPER
					), 'null');

		-- 8. Get AddOns JSON  
		SELECT @AddOnsJson = (
				CASE 
					WHEN (
							SELECT COUNT(*)
							FROM @TempAddOnsItems
							) = 0
						THEN NULL
					ELSE (
							SELECT *
							FROM @TempAddOnsItems
							FOR JSON PATH
								,WITHOUT_ARRAY_WRAPPER
							)
					END
				);

		SELECT @ItemImagesJson = (
				CASE 
					WHEN (
							SELECT COUNT(*)
							FROM @OrderSetItemImage
							) = 0
						THEN NULL
					ELSE (
							SELECT *
							FROM @OrderSetItemImage
							FOR JSON PATH
								,WITHOUT_ARRAY_WRAPPER
							)
					END
				);

		-- Combine all JSON objects into a single result
		SET @jsonResult = CONCAT (
				'{ "Order": '
				,@OrderJson
				,', "Customer": '
				,@CustomerJson
				,', "Summary": '
				,@SummaryJson
				,', "OrderSetItems": '
				,@OrderSetItemsJson
				,', "Tenant": '
				,@TenantJson
				,', "OrderAddress": '
				,@OrderAddressJson
				,', "OrderSets": ['
				,@OrderSetsJson
				,'], "AddOnItems":' + '['
				,ISNULL(@AddOnsJson, '')
				,'' + ']' + ', "ItemImages":' + '['
				,ISNULL(@ItemImagesJson, '')
				,'' + ']' + '}'
				);

		-- Return the combined JSON result  
		SELECT @jsonResult AS JsonResult;
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

