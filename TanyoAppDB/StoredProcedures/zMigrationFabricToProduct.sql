/*
	EXEC [MigrationFabricToProduct]
		@TenantId = 2
*/
CREATE   PROC [dbo].[zMigrationFabricToProduct]
(
	@TenantId INT
)
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;

	DECLARE @NowOffset DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@NowUTC DATETIME = GETUTCDATE()

	BEGIN TRY
		BEGIN TRAN
	
			;With CteDistinctCompany AS
			(
			SELECT ROW_NUMBER() OVER (PARTITION BY CompanyName COLLATE Latin1_General_CS_AS ORDER BY CompanyId ASC) AS Row_Id
							,2 AS CategoryTypeId -- ???? NOT Nullable
							,CompanyName AS CategoryName
							,1 AS IsFixedPrice
							,RSPPercentage AS RSPPercentage
							,WSPPercentage AS WSPPercentage
							,TenantId AS TenantId
							,IsDeleted
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
							,UpdatedBy
							,UpdatedDate
							,UpdatedUTCDate
							,0 AS IsManufacturing
							,1 AS IsVisibleInAddOn
							,5 AS GST
							,MaxDiscount AS MaxDiscount
							,0 AS IsCommissionEnabled
							,NULL AS FriendlyName
							,0 AS IsCommissionEnabledInterior
							,0 AS IsSellByPerSQFT
							,1 AS IsFabric
						FROM Companies
						WHERE TenantId = @TenantId
							AND IsDeleted = 0
						AND NOT EXISTS
						(
							SELECT 1
							FROM Categories CT WITH (NOLOCK)
							WHERE CT.CategoryName COLLATE Latin1_General_CS_AS = Companies.CompanyName COLLATE Latin1_General_CS_AS
							AND CT.TenantId = Companies.TenantId
							AND CT.CategoryTypeId = 2
						)
			)
			INSERT INTO Categories
			(
				CategoryTypeId
				,CategoryName
				,IsFixedPrice
				,RSPPercentage
				,WSPPercentage
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,UpdatedBy
				,UpdatedDate
				,UpdatedUTCDate
				,IsManufacturing
				,IsVisibleInAddOn
				,GST
				,MaxDiscount
				,IsCommissionEnabled
				,FriendlyName
				,IsCommissionEnabledInterior
				,IsSellByPerSQFT
				,IsFabric
			)
			SELECT CategoryTypeId -- ???? NOT Nullable
				,CategoryName
				,IsFixedPrice
				,RSPPercentage
				,WSPPercentage
				,TenantId
				,IsDeleted
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,UpdatedBy
				,UpdatedDate
				,UpdatedUTCDate
				,IsManufacturing
				,IsVisibleInAddOn
				,GST
				,MaxDiscount
				,IsCommissionEnabled
				,FriendlyName
				,IsCommissionEnabledInterior
				,IsSellByPerSQFT
				,IsFabric
			FROM CteDistinctCompany
			WHERE Row_Id = 1

			INSERT INTO Products
			(
				CategoryId
				,ProductTitle
				,ModelNo
				,CostPrice
				,RetailerPrice
				,WholesalerPrice
				,QRImage
				,TenantId
				,STATUS
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				,UpdatedBy
				,UpdatedDate
				,UpdatedUTCDate
			)
			SELECT CT.CategoryId AS CategoryId
				,F.Title AS ProductTitle
				,CONCAT ('FB-',F.ModelNo) AS ModelNo
				,F.UnitPrice AS CostPrice
				,F.RetailerPrice AS RetailerPrice
				,F.WholesalerPrice AS WholesalerPrice
				,NULL AS QRImage
				,F.TenantId AS TenantId
				,CASE WHEN F.IsDeleted = 0 THEN 1 ELSE 3 END AS Status -- ???? Not Nullable
				,F.CreatedBy AS CreatedBy
				,F.CreatedDate AS CreatedDate
				,F.CreatedUTCDate AS CreatedUTCDate
				,F.UpdatedBy AS UpdatedBy
				,F.UpdatedDate AS UpdatedDate
				,F.UpdatedUTCDate AS UpdatedUTCDate
			FROM Fabrics F WITH (NOLOCK)
			INNER JOIN Companies C WITH (NOLOCK) ON C.CompanyId = F.CompanyId
				AND F.TenantId = C.TenantId
			INNER JOIN Categories CT WITH (NOLOCK) ON CT.CategoryName COLLATE Latin1_General_CS_AS = C.CompanyName COLLATE Latin1_General_CS_AS
				AND CT.TenantId = F.TenantId
				AND CT.CategoryTypeId = 2
			WHERE F.TenantId = @TenantId
			AND NOT EXISTS
			(
				SELECT 1
				FROM Products P WITH (NOLOCK)
				WHERE P.ModelNo = CONCAT('FB-',F.ModelNo)
				AND P.TenantId = F.TenantId
			)

			;With CteDistinctCompany
			AS
			(
				SELECT ROW_NUMBER() OVER (PARTITION BY CompanyName COLLATE Latin1_General_CS_AS ORDER BY IsDeleted ASC) AS Row_Id
					,CompanyId
					,CompanyName
					,TenantId
				FROM Companies 
				WHERE TenantId = @TenantId
				AND EXISTS
				(
					SELECT 1
					FROM Categories CT WITH (NOLOCK)
					WHERE CT.CategoryName COLLATE Latin1_General_CS_AS = Companies.CompanyName COLLATE Latin1_General_CS_AS
					AND CT.TenantId = Companies.TenantId
					AND CT.CategoryTypeId = 2
				)
			)
			INSERT INTO ProductImages
						(
							ProductId
							,ImageName
							,IsCover
							,ImagePath
							,CreatedBy
							,CreatedDate
							,CreatedUTCDate
							,ImageColorCode
						)
			SELECT P.ProductId AS ProductId
							,RIGHT(LEFT(F.ImagePath, CHARINDEX('?', F.ImagePath + '?') - 1), CHARINDEX('/', REVERSE(LEFT(F.ImagePath, CHARINDEX('?', F.ImagePath + '?') - 1))) - 1) AS ImageName
							,1 AS IsCover
							,F.ImagePath AS ImagePath
							,F.CreatedBy AS CreatedBy
							,F.CreatedDate AS CreatedDate
							,F.CreatedUTCDate AS CreatedUTCDate
							,F.ImageColorCode
			FROM Products p
			INNER JOIN Categories c ON c.CategoryId = p.CategoryId
				AND c.CategoryTypeId = 2
			INNER JOIN CteDistinctCompany ca ON ca.CompanyName COLLATE Latin1_General_CS_AS = c.CategoryName COLLATE Latin1_General_CS_AS
				AND ca.TenantId = c.TenantId
			INNER JOIN Fabrics f ON CONCAT('FB-',F.ModelNo) = p.ModelNo
				AND f.CompanyId = ca.CompanyId
				AND CASE WHEN F.IsDeleted = 0 THEN 1 ELSE 3 END = p.Status
				AND f.TenantId = @TenantId
				AND f.RetailerPrice = p.RetailerPrice
				AND f.WholesalerPrice = p.WholesalerPrice
			WHERE p.TenantId = @TenantId
				AND ca.Row_Id = 1
				AND F.ImagePath IS NOT NULL 
				AND LTRIM(RTRIM(F.ImagePath)) <> ''
				AND NOT EXISTS
						(
							SELECT 1
							FROM ProductImages PIM WITH (NOLOCK)
							WHERE PIM.ProductId = P.ProductId
							AND PIM.ImagePath = F.ImagePath
						)
			ORDER BY p.ProductId

			INSERT INTO ProductQuantities
			(
				ProductId
				,QuantityDate
				,Quantity
				,LastModifiedBy
				,LastModifiedDate
				,LastModifiedUTCDate
				,MinimumLimit
			)
			SELECT P.ProductId AS ProductId
				,@NowOffset AS QuantityDate
				,0 AS Quantity
				,P.CreatedBy AS LastModifiedBy
				,P.CreatedDate AS LastModifiedDate
				,P.CreatedUTCDate AS LastModifiedUTCDate
				,0 AS MinimumLimit
			FROM Products P
			INNER JOIN Categories C ON C.CategoryId = P.CategoryId
				AND C.CategoryTypeId = 2
			WHERE P.TenantId = @TenantId
			AND NOT EXISTS
			(
				SELECT 1
				FROM ProductQuantities PQT WITH (NOLOCK)
				WHERE PQT.ProductId = P.ProductId
			)

			INSERT INTO ProductQuantitiesByWarehouse
			(
				ProductId
				,WarehouseId
				,QuantityDate
				,Quantity
				,LastModifiedBy
				,LastModifiedDate
				,LastModifiedUTCDate
			)
			SELECT P.ProductId AS ProductId
				,W.Id AS WarehouseId
				,@NowOffset AS QuantityDate
				,0 AS Quantity
				,P.CreatedBy AS LastModifiedBy
				,@NowOffset AS LastModifiedDate
				,@NowUTC AS LastModifiedUTCDate
			FROM Products P
			INNER JOIN Categories C ON C.CategoryId = P.CategoryId
				AND C.CategoryTypeId = 2
			INNER JOIN Warehouse W ON W.TenantId = P.TenantId
				AND W.Name = 'Other'
			WHERE P.TenantId = @TenantId
			AND NOT EXISTS
			(
				SELECT 1
				FROM ProductQuantitiesByWarehouse PQTW WITH (NOLOCK)
				WHERE PQTW.ProductId = P.ProductId
					AND PQTW.WarehouseId = W.Id
			)

			EXEC PopulateProductCoverImage

		COMMIT TRAN
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK

		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (@ErrorMessage,@ErrorSeverity,@ErrorState)
	END CATCH
END

GO

