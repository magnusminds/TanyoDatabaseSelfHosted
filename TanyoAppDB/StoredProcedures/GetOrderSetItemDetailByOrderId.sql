/*    
 EXEC [dbo].[GetOrderSetItemDetailByOrderId]    
  @TenantId = 2    
  ,@OrderId = 63077    
*/
CREATE PROCEDURE [dbo].[GetOrderSetItemDetailByOrderId] (
	@TenantId INT
	,@OrderId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		DECLARE @ReceivedAmount NUMERIC(18, 2)
			,@InteriorCommission NUMERIC(18, 2)
			,@TotalSetAmount NUMERIC(18, 2)
			,@dt DATE = CAST(GETDATE() AS DATE)
			,@IsAllowDiscount BIT
		DECLARE @OrderSetTotalAmount TABLE (
			OrderSetId BIGINT
			,TotalSetAmount NUMERIC(18, 0)
			)

		SELECT @IsAllowDiscount = IsAllowDiscount
		FROM TenantConfigurations
		WHERE TenantId = @TenantId

		INSERT INTO @OrderSetTotalAmount (
			OrderSetId
			,TotalSetAmount
			)
		SELECT OrderSetId
			,SUM(ISNULL(TotalAmount, 0)) AS TotalSetAmount
		FROM OrderSetItems WITH (NOLOCK)
		WHERE OrderId = @OrderId
			AND IsDeleted = 0
		GROUP BY OrderSetId

		SELECT OS.OrderSetId
			,OS.SetName
			,ostm.TotalSetAmount AS TotalSetAmount
			,OSI.OrderSetItemId
			,OSI.SubjectTypeId
			,SUB.SubjectTypeName
			,OSI.SubjectId
			,OSI.ProductImage AS ProductImage
			,OSI.Width
			,OSI.Height
			,OSI.Depth
			,OSI.Diameter
			,OSI.Quantity
			,ISNULL(PT.ProductTitle, '') AS ProductTitle
			,ISNULL(PT.ModelNo, '') AS ModelNo
			,ISNULL(PT.HSNNo, '') AS HSNNo
			,OSI.CostPrice
			,OSI.UnitPrice
			,OSI.DiscountPrice
			,OSI.Discount
			,CASE 
				WHEN OSI.UnitPrice = 0
					THEN 0
				ELSE (ISNULL(OSI.Discount, 0) / OSI.UnitPrice) * 100
				END AS DiscountPercentage
			,OSI.GrossTotal
			,OSI.TotalAmount
			,OSI.Comment
			,OSI.ReceiveDate
			,OSI.ProvidedMaterial
			,ISNULL(CT.IsManufacturing, 0) AS IsManufacturing
			,OSI.ItemStatus
			--,OSI.OfferId    
			,CASE 
				WHEN @IsAllowDiscount = 1
					THEN OSI.OfferId
				ELSE NULL
				END AS OfferId
			--,ISNULL(OSI.OfferPercentage, 0) AS OfferPercentage    
			,CASE 
				WHEN @IsAllowDiscount = 1
					THEN ISNULL(OSI.OfferPercentage, 0)
				ELSE NULL
				END AS OfferPercentage
			--,OFS.OfferTitle    
			,CASE 
				WHEN @IsAllowDiscount = 1
					THEN OFS.OfferTitle
				ELSE NULL
				END AS OfferTitle
			,OSI.MRP
			,OSI.ParentOrderSetItemId
			,CAST(CASE 
					WHEN CT.CategoryTypeId = 2
						THEN CT.CategoryId
					ELSE 0
					END AS BIGINT) AS CompanyId
			,CONCAT (
				'in '
				,TRIM(CT.CategoryName)
				) AS CompanyName
			,CT.CategoryId AS CategoryId
			,NULLIF(CONCAT (
					'in '
					,LTRIM(RTRIM(CT.CategoryName))
					), 'in ') AS CategoryName
			,CAST(CASE 
					WHEN CT.CategoryTypeId = 2
						THEN 1
					ELSE 0
					END AS BIT) AS IsFabric
			,CT.CategoryTypeId
			,OSI.ProductImage AS FabricImageUrl
			,OSI.InstantUnitPrice
			,OSI.InstantCostPrice
			,OSI.InstantWidth
			,OSI.InstantHeight
			,OSI.InstantDepth
			,OSI.InstantDiameter
			,CASE 
				WHEN OSI.ParentOrderSetItemId IS NULL
					THEN 0
				ELSE 1
				END AS IsAddOn
			,OSI.AmountBeforeGST
			,OSI.CGSTAmount
			,OSI.SGSTAmount
			,ISNULL(CT.MaxDiscount, 0) AS MaxDiscount
			,SOH.StockOnHoldId AS HoldStockId
			,SOH.HoldUptoDate AS HoldStockRemainingTime
			,SOH.IsStockOnHold
			,ISNULL(CT.IsSellByPerSQFT, 0) AS IsSellByPerSQFT
			,CASE 
				WHEN CT.CategoryTypeId = 2
					THEN - 1
				ELSE 0
				END AS OrderSetItemTypeId
			,OSI.UnitSalePrice
			-- ,CAST(0 AS BIGINT) AS VendorId    
			-- ,'' AS VendorName    
			-- ,CAST(1 AS BIT) AS VendorGSTType    
			,VendorDetails.VendorId AS VendorId
			,VendorDetails.VendorName AS VendorName
			,VendorDetails.GSTType AS VendorGSTType
			,POP.POProductId AS POId
			,POP.PONumber
			,POP.IsOrderItemLevelPO
			,CAST(ISNULL(CT.GST, 18) AS NUMERIC(18, 2)) AS CategoryGST
			,CAST(CASE 
					WHEN LTRIM(RTRIM(ISNULL(TN.STATE, ''))) = ''
						THEN 0
					WHEN LTRIM(RTRIM(ISNULL(VendorDetails.VendorState, ''))) = ''
						THEN 0
					WHEN LTRIM(RTRIM(TN.STATE)) <> LTRIM(RTRIM(VendorDetails.VendorState))
						THEN 1
					ELSE 0
					END AS BIT) AS IsVendorInterState
		--  ,CAST(0 AS BIT) AS IsVendorInterState    
		FROM OrderSets OS WITH (NOLOCK)
		INNER JOIN @OrderSetTotalAmount ostm ON ostm.OrderSetId = OS.OrderSetId
		INNER JOIN OrderSetItems OSI WITH (NOLOCK) ON OSI.OrderSetId = OS.OrderSetId
			AND OSI.OrderId = @OrderId
			AND OSI.IsDeleted = 0
		INNER JOIN Products PT WITH (NOLOCK) ON osi.SubjectId = PT.ProductId
			AND PT.TenantId = @TenantId
		INNER JOIN Categories CT WITH (NOLOCK) ON PT.CategoryId = CT.CategoryId
		INNER JOIN Tenants TN WITH (NOLOCK) ON TN.TenantId = @TenantId
		INNER JOIN SubjectTypes SUB WITH (NOLOCK) ON OSI.SubjectTypeId = SUB.SubjectTypeId
		LEFT JOIN Offers OFS WITH (NOLOCK) ON OSI.OfferId = OFS.OfferId
		LEFT JOIN StockOnHold SOH WITH (NOLOCK) ON SOH.OrderSetItemId = OSI.OrderSetItemId
			AND SOH.IsStockOnHold = 1
			AND OSI.IsQuantityOnHold = 1
			AND SOH.HoldUptoDate > @dt
		--OUTER APPLY (    
		-- SELECT TOP 1 POPI.ProductId    
		--  ,POP.POProductId    
		--  ,POP.PONumber    
		-- FROM POProductItems POPI WITH (NOLOCK)    
		-- INNER JOIN POProducts POP WITH (NOLOCK) ON POPI.POProductId = POP.POProductId    
		--  AND POP.IsDeleted = 0    
		--  AND POP.Status = 2    
		-- WHERE popi.ProductId = osi.SubjectId    
		-- ORDER BY POP.OrderDate    
		-- ) AS POP    
		OUTER APPLY (
			SELECT TOP 1 POPI.ProductId
				,POP.POProductId
				,POP.PONumber
				,CAST(CASE 
						WHEN ISNULL(POPI.OrderSetItemId, 0) <> 0
							AND POPI.OrderSetItemId = OSI.OrderSetItemId
							THEN 1
						ELSE 0
						END AS BIT) AS IsOrderItemLevelPO
			FROM POProductItems POPI WITH (NOLOCK)
			INNER JOIN POProducts POP WITH (NOLOCK) ON POPI.POProductId = POP.POProductId
				AND POP.IsDeleted = 0
				AND POP.Status IN (
					1
					,2
					,4
					,5
					)
				AND POP.TenantId = @TenantId
			WHERE POPI.ProductId = OSI.SubjectId
				AND (
					-- Exact sales order item-level PO
					POPI.OrderSetItemId = OSI.OrderSetItemId
					OR
					-- Generic PO item
					(
						ISNULL(POPI.OrderSetItemId, 0) = 0
						AND POP.Status <> 4
						)
					)
			ORDER BY CASE 
					WHEN ISNULL(POPI.OrderSetItemId, 0) <> 0
						AND POPI.OrderSetItemId = OSI.OrderSetItemId
						THEN 1
					ELSE 2
					END
				,POP.OrderDate ASC
				,POP.POProductId ASC
			) AS POP
		OUTER APPLY (
			SELECT TOP 1 V.VendorId
				,V.VendorName
				,V.GSTType
				,VA.STATE AS VendorState
			FROM ProductVendorMapping PVM WITH (NOLOCK)
			INNER JOIN Vendors V WITH (NOLOCK) ON PVM.VendorId = V.VendorId
			LEFT JOIN VendorAddresses VA WITH (NOLOCK) ON VA.VendorId = V.VendorId
				AND VA.IsDeleted = 0
			WHERE PVM.ProductId = PT.ProductId
			ORDER BY PVM.IsDefault DESC
				,PVM.ProductVendorMappingId ASC
			) VendorDetails
		WHERE OS.OrderId = @OrderId
			AND OS.IsDeleted = 0
		ORDER BY OSI.OrderSetItemId
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

