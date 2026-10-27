/*  
EXEC GetPOProductById  
 @POProductId = 40661  
 ,@TenantId = 2  
*/
CREATE PROC [dbo].[GetPOProductById] (
	@POProductId BIGINT
	,@TenantId BIGINT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		DROP TABLE IF EXISTS #LookupValue

		DECLARE @VendorId BIGINT;
		DECLARE @VendorTenantId INT

		SELECT @VendorId = p.VendorId
		FROM dbo.POProducts p WITH (NOLOCK)
		WHERE p.POProductId = @POProductId
			AND p.TenantId = @TenantId
			AND p.IsDeleted = 0;

		SELECT @VendorTenantId = VendorTenantID
		FROM Vendors WITH (NOLOCK)
		WHERE VendorId = @VendorId

		SELECT LKV.*
		INTO #LookupValue
		FROM Lookups LK WITH (NOLOCK)
		INNER JOIN LookupValues LKV ON LK.LookupId = LKV.LookupId
		WHERE LK.TenantId = @TenantId
			AND LK.IsDeleted = 0
			AND LKV.IsDeleted = 0
			AND LK.LookupName = 'ProductCustomLabel'
			AND LKV.LookupValueName IN (
				'SQFT in BOX'
				,'Pieces in BOX'
				,'Weight in BOX'
				)

		SELECT p.POProductId
			,p.VendorId
			,v.VendorName
			,CAST(CASE 
					WHEN ISNULL(v.VendorTenantID, 0) > 0
						AND ISNULL(v.AcceptRejectStatus, 0) = 1
						THEN 1
					ELSE 0
					END AS BIT) AS IsVendorUsingTanyo
			,p.PONumber
			,p.OrderDate
			,p.Status
			,CASE 
				WHEN p.Status = 1
					THEN 'Pending'
				WHEN p.Status = 2
					THEN 'Approved'
				WHEN p.Status = 3
					THEN 'Cancelled'
				WHEN p.Status = 4
					THEN 'Completed'
				WHEN p.Status = 5
					THEN 'MaterialReady'
				ELSE ''
				END AS StatusName
			,MAX(p.TotalAmount) AS TotalAmount
			,SUM(ISNULL(POP.ReceivedAmount, 0)) AS ReceivedAmount
			,MAX(p.TotalAmount) - SUM(ISNULL(POP.ReceivedAmount, 0)) AS RemainingAmount
			,P.ExpectedDeliveryDate
			,ISNULL((
					SELECT i.POProductItemId
						,i.ProductId
						,prd.ProductTitle
						,prd.ModelNo
						,prd.CoverImage
						,CASE 
							WHEN prd.Status = 1
								THEN CAST(1 AS BIT)
							WHEN prd.Status = 2
								THEN CAST(0 AS BIT)
							ELSE NULL
							END AS IsPublished
						,i.VendorModelNo
						,i.Quantity
						,i.UnitPrice AS VendorProductPrice
						,i.Status
						,CASE 
							WHEN i.Status = 1
								THEN 'Pending'
							WHEN i.Status = 2
								THEN 'Approved'
							WHEN i.Status = 3
								THEN 'Cancelled'
							WHEN i.Status = 4
								THEN 'Completed'
							WHEN i.Status = 5
								THEN 'MaterialReady'
							ELSE ''
							END AS ItemStatusName
						,i.TotalPrice
						,i.Remarks
						,CAST(CASE 
								WHEN EXISTS (
										SELECT 1
										FROM Products pt WITH (NOLOCK)
										WHERE PT.TenantId = @VendorTenantId
											AND PT.ModelNo = PVM.VendorModelNo
											AND PT.Status = 1
										)
									THEN 1
								ELSE 0
								END AS BIT) AS IsVenodrProductActive
						,CAST(CASE 
								WHEN CT.CategoryTypeId = 2
									THEN 1
								ELSE 0
								END AS BIT) AS IsFabric
						,i.OrderSetItemId
						,i.Width
						,i.Height
						,i.Depth
						,i.Diameter
						,ISNULL((
								SELECT pia.POProductItemsAttachmentId
									,pia.POProductItemId
									,pia.FileURL
									,pia.IsImage
								FROM POProductItemsAttachments pia WITH (NOLOCK)
								WHERE pia.POProductItemId = i.POProductItemId
									AND pia.IsDeleted = 0
								FOR JSON PATH
								), '[]') AS POProductItemAttachments
						,CT.IsSellByPerSQFT
						,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) AS NUMERIC(18, 2)) AS SQFTinBOX
						,CAST(ISNULL(PCF_AGG.SQFTinBOXValue, 0) * I.Quantity AS NUMERIC(18, 2)) AS TotalSQFT
						,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) AS NUMERIC(18, 2)) AS PiecesinBOX
						,CAST(ISNULL(PCF_AGG.PiecesinBOXValue, 0) * I.Quantity AS NUMERIC(18, 2)) AS TotalPieces
						,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) AS NUMERIC(18, 2)) AS WeightinBOX
						,CAST(ISNULL(PCF_AGG.WeightinBOXValue, 0) * I.Quantity AS NUMERIC(18, 2)) AS TotalWeight
						,CAST(CASE 
								WHEN PCF_AGG.SQFTinBOXValue IS NOT NULL
									THEN ISNULL(PVM.VendorProductPrice, 0)
								ELSE 0
								END AS NUMERIC(18, 2)) AS PerSQFTRate
						,i.TentativePOItemPickupDate
						,i.VendorOrderSetItemId
						,i.AmountBeforeGST
						,i.TotalAmount
						,i.CGSTAmount
						,i.SGSTAmount
						,i.IGSTAmount
						,i.IsInterState
						,CAST(ISNULL(i.GST, 0) AS NUMERIC(18, 2)) AS GST
						,i.ParentPOProductItemId
						,i.IsAddOn
						,CT.IsManufacturing
					FROM dbo.POProductItems i WITH (NOLOCK)
					INNER JOIN Products prd WITH (NOLOCK) ON prd.ProductId = i.ProductId
						AND prd.TenantId = @TenantId
					INNER JOIN Categories CT WITH (NOLOCK) ON CT.CategoryId = PRD.CategoryId
					LEFT JOIN ProductVendorMapping pvm WITH (NOLOCK) ON pvm.ProductId = i.ProductId
						AND pvm.VendorId = @VendorId
						AND pvm.IsDeleted = 0
					OUTER APPLY (
						SELECT MAX(CASE 
									WHEN LKV.LookupValueName = 'SQFT in BOX'
										THEN CAST(PCF.CustomValue AS NUMERIC(18, 2))
									END) AS SQFTinBOXValue
							,MAX(CASE 
									WHEN LKV.LookupValueName = 'Pieces in BOX'
										THEN CAST(PCF.CustomValue AS NUMERIC(18, 2))
									END) AS PiecesinBOXValue
							,MAX(CASE 
									WHEN LKV.LookupValueName = 'Weight in BOX'
										THEN CAST(PCF.CustomValue AS NUMERIC(18, 2))
									END) AS WeightinBOXValue
						FROM ProductCustomFields PCF
						INNER JOIN #LookupValue LKV ON PCF.LookupValueId = LKV.LookupValueId
						WHERE PCF.ProductId = i.ProductId
							AND PCF.IsDeleted = 0
						) PCF_AGG
					WHERE i.POProductId = @POProductId
					FOR JSON PATH
						,INCLUDE_NULL_VALUES
					), '[]') AS POProductItems
			,p.IsSyncWithTally
			,o.OrderNo
			,p.OrderId
			,NULLIF(LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))), '') AS CustomerName
			,p.TentativePOPickupDate
			,p.VendorOrderId
			,p.GSTType
			,p.AmountBeforeGST
			,p.CGSTAmount
			,p.SGSTAmount
			,p.IGSTAmount
			,p.IsInterState
		FROM dbo.POProducts p WITH (NOLOCK)
		INNER JOIN dbo.Vendors v WITH (NOLOCK) ON p.VendorId = v.VendorId
		LEFT JOIN dbo.POProductPayment POP WITH (NOLOCK) ON POP.POProductId = p.POProductId
			AND POP.IsDeleted = 0
			AND POP.PaymentStatus = 1
		LEFT JOIN dbo.Orders o WITH (NOLOCK) ON p.OrderId = o.OrderId
		LEFT JOIN dbo.Customers c WITH (NOLOCK) ON o.CustomerID = c.CustomerId
		WHERE p.POProductId = @POProductId
			AND p.TenantId = @TenantId
			AND p.IsDeleted = 0
		GROUP BY p.POProductId
			,p.VendorId
			,v.VendorName
			,p.PONumber
			,p.OrderDate
			,p.Status
			,P.ExpectedDeliveryDate
			,p.IsSyncWithTally
			,o.OrderNo
			,p.OrderId
			,NULLIF(LTRIM(RTRIM(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''))), '')
			,p.TentativePOPickupDate
			,p.VendorOrderId
			,v.AcceptRejectStatus
			,v.VendorTenantID
			,p.GSTType
			,p.AmountBeforeGST
			,p.CGSTAmount
			,p.SGSTAmount
			,p.IGSTAmount
			,p.IsInterState;
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX)

		SET @ObjectName = OBJECT_NAME(@@PROCID)
		SET @ErrorMsg = ERROR_MESSAGE()

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg
	END CATCH
END

GO

