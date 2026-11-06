/*
	EXEC [GetOrderDetailsByOrderId]
		@TenantId = 9
		,@OrderID = 176725
*/
CREATE   PROCEDURE [dbo].[GetOrderDetailsByOrderId]
(
	@TenantId BIGINT
	,@OrderID BIGINT
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	SELECT ORD.OrderId
		,ORD.STATUS
		,ISNULL((
				SELECT OSI.OrderSetItemId
					,OSI.SubjectId AS ProductId
					,PT.ProductTitle
					,PT.ModelNo
					,PT.CoverImage AS ProductImage
					,OSI.Quantity
					,CASE 
						WHEN C.IsManufacturing = 1
							THEN 1
						ELSE 0
						END AS IsManufacturing
					,C.IsInHouseManufacturing
					,(
						SELECT MWF.ManufacturingWorkflowId AS WorkflowId
							,MWF.WorkflowName
							,PWF.ContractorUserID
							,CONCAT (
								ISNULL(UC.FirstName, '')
								,' '
								,ISNULL(UC.LastName, '')
								) AS ContractorName
							,PWF.SupervisorUserID
							,CONCAT (
								ISNULL(US.FirstName, '')
								,' '
								,ISNULL(US.LastName, '')
								) AS SupervisorName
						FROM ProductWorkflows PWF WITH (NOLOCK)
						INNER JOIN ManufacturingWorkflows MWF WITH (NOLOCK) ON PWF.ManufacturingWorkflowId = MWF.ManufacturingWorkflowId
							AND MWF.TenantId = @TenantId
						LEFT JOIN AspNetUsers UC WITH (NOLOCK) ON PWF.ContractorUserID = UC.UserId
						LEFT JOIN AspNetUsers US WITH (NOLOCK) ON PWF.SupervisorUserID = US.UserId
						WHERE PWF.ProductID = OSI.SubjectId
						AND C.IsManufacturing = 1
						ORDER BY PWF.Position
						FOR JSON PATH
					) AS WorkflowDetails
					,(
						SELECT V.VendorId
							,V.VendorName
							,PVMP.IsDefault
						FROM ProductVendorMapping PVMP WITH (NOLOCK)
						INNER JOIN Vendors V WITH (NOLOCK) ON PVMP.VendorId = V.VendorId
						WHERE PVMP.ProductId = OSI.SubjectId
						AND PVMP.IsDeleted = 0
						AND C.IsManufacturing = 0 -- When Product have workflow and vendor mapping than consider only as workflow product
						FOR JSON PATH
					) AS VendorDetails
					
					,JSON_QUERY(
						CASE 
							WHEN C.IsManufacturing = 1 THEN
								(
									SELECT 
										PM.ProductMaterialID,
										RM.Title AS RawMaterialName,

										-- Available Qty
										CAST(ISNULL((
											SELECT SUM(RMI.Inventory)
											FROM RawMaterialInventory RMI WITH (NOLOCK)
											WHERE RMI.RawMaterialId = RM.RawMaterialId
										),0) AS DECIMAL(18,2)) AS AvailableQty,

										-- Required Qty
										CAST((ISNULL(PM.Qty,0) * ISNULL(OSI.Quantity,0)) AS DECIMAL(18,2)) AS RequiredQty

									FROM ProductMaterials PM WITH (NOLOCK)
									INNER JOIN RawMaterials RM WITH (NOLOCK)
										ON PM.SubjectId = RM.RawMaterialId

									WHERE PM.ProductId = OSI.SubjectId

									--------------------------------------------------
									-- ✅ ADD THIS ORDERING
									--------------------------------------------------
									ORDER BY 
										CAST(ISNULL((
											SELECT SUM(RMI.Inventory)
											FROM RawMaterialInventory RMI WITH (NOLOCK)
											WHERE RMI.RawMaterialId = RM.RawMaterialId
										),0) AS DECIMAL(18,2)) ASC

									FOR JSON PATH
								)
							ELSE '[]'
						END
					) AS BOMDetails

				FROM OrderSetItems OSI WITH (NOLOCK)
				INNER JOIN Products PT WITH (NOLOCK) ON OSI.SubjectId = PT.ProductId
				INNER JOIN SubjectTypes ST WITH (NOLOCK) ON OSI.SubjectTypeId = ST.SubjectTypeId
				LEFT JOIN Categories C WITH (NOLOCK) ON PT.CategoryId = C.CategoryId
				WHERE OSI.OrderId = ORD.OrderId
					AND OSI.ParentOrderSetItemId IS NULL
					AND OSI.IsDeleted = 0
					AND ST.SubjectTypeName = 'Products'
				FOR JSON PATH
				), '') AS OrderItemDetails
	FROM Orders ORD WITH (NOLOCK)
	WHERE ORD.TenantId = @TenantId
		AND ORD.OrderId = @OrderID
		AND ORD.STATUS <> 9
		AND ORD.IsArchive = 0;
END

GO

