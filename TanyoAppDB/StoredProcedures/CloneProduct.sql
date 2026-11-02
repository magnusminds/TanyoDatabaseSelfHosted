CREATE PROCEDURE [dbo].[CloneProduct] (
	@ProductId BIGINT
	,@FromTenantId BIGINT
	,@ToTenantId BIGINT
	,@UserID BIGINT
	,@CategoryId BIGINT = 0
	,@VendorId BIGINT = 0
	,@IsPublished INT = 2
	,@CostPrice DECIMAL(18, 2) = 0
	,@ProductTitle VARCHAR(50) = NULL
	,@ModelNo VARCHAR(50) = NULL
	,@VendorProductPrice DECIMAL(18, 2) = 0
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY

		DECLARE @NewProductId BIGINT
		DECLARE @SubjectTypeId INT
		DECLARE @Date DATETIMEOFFSET = SYSDATETIMEOFFSET()
		DECLARE @UTCDate DATETIME = GETUTCDATE()
		DECLARE @VendorModelNo VARCHAR(100)
		DECLARE @ActivityDescription VARCHAR(MAX)
		 
		BEGIN TRAN CloneProduct		

		IF (@ToTenantId = @FromTenantId)
		BEGIN

			DECLARE @OtherWarehouseId BIGINT

			SELECT @SubjectTypeId = SubjectTypeId
			FROM dbo.SubjectTypes st WITH (NOLOCK)
			WHERE st.TenantId = @FromTenantId
				AND st.SubjectTypeName = 'Products'

			SELECT @OtherWarehouseId = Id
			FROM Warehouse WITH (NOLOCK)
			WHERE TenantId = @FromTenantId
			AND Name = 'Other'

			DECLARE @Counter INT
				,@ExistingModelNo VARCHAR(100)

			SELECT @ExistingModelNo = p.ModelNo
			FROM dbo.Products p WITH (NOLOCK)
			WHERE p.ProductId = @ProductId
			AND p.TenantId = @FromTenantId

			SELECT @Counter =
				ISNULL
				(
					MAX
					(
						TRY_CONVERT
						(
							INT,
							SUBSTRING
							(
								p.ModelNo,
								LEN(@ExistingModelNo + '-COPY-') + 1,
								LEN(p.ModelNo)
							)
						)
					),
					0
				) + 1
			FROM Products p WITH (NOLOCK)
			WHERE p.TenantId = @FromTenantId
			AND p.ModelNo LIKE @ExistingModelNo + '-COPY-%'
			AND TRY_CONVERT
				(
					INT,
					SUBSTRING
					(
						p.ModelNo,
						LEN(@ExistingModelNo + '-COPY-') + 1,
						LEN(p.ModelNo)
					)
				) IS NOT NULL

			IF EXISTS (
					SELECT 1
					FROM dbo.Products p WITH (NOLOCK)
					WHERE ProductId = @ProductId
					)
			BEGIN
				INSERT INTO dbo.Products (
					CategoryId
					,ProductTitle
					,ModelNo
					,Width
					,Height
					,Depth
					,FabricNeeded
					,IsVisibleToWholesalers
					,TotalDaysToPrepare
					,Features
					,Comments
					,CostPrice
					,QRImage
					,TenantId
					,STATUS
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,Diameter
					,DimensionUnitId
					,IsPriceAutoCalculated
					,RetailerPrice
					,WholesalerPrice
					)
				SELECT p.CategoryId
					,p.ProductTitle + ' COPY-' + CAST(@Counter AS VARCHAR(20))
					,CASE 
						WHEN p.ModelNo <> NULL
							OR p.ModelNo <> ''
							THEN p.ModelNo + '-COPY-' + CAST(@Counter AS VARCHAR(20))
						ELSE ''
						END
					,p.Width
					,p.Height
					,p.Depth
					,p.FabricNeeded
					,p.IsVisibleToWholesalers
					,p.TotalDaysToPrepare
					,p.Features
					,p.Comments
					,p.CostPrice
					,NULL
					,p.TenantId
					,@IsPublished
					,@UserID
					,@Date
					,@UTCDate
					,p.Diameter
					,p.DimensionUnitId
					,p.IsPriceAutoCalculated
					,p.RetailerPrice
					,p.WholesalerPrice
				FROM dbo.Products p WITH (NOLOCK)
				WHERE ProductId = @ProductId

				SET @NewProductId = SCOPE_IDENTITY()
			END

			IF (@NewProductId > 0)
			BEGIN
				INSERT INTO dbo.ProductQuantities (
					ProductId
					,QuantityDate
					,Quantity
					,LastModifiedBy
					)
				SELECT @NewProductId
					,@Date
					,0
					,@UserID

				INSERT INTO ProductQuantitiesByWarehouse (
					ProductId
					,WarehouseId
					,QuantityDate
					,Quantity
					,LastModifiedBy
					,LastModifiedDate
					,LastModifiedUTCDate )
				SELECT 
					@NewProductId
					,@OtherWarehouseId
					,@Date
					,0
					,@UserID
					,@Date
					,@UTCDate

				IF EXISTS (
						SELECT 1
						FROM dbo.ProductMaterials pm WITH (NOLOCK)
						WHERE pm.ProductId = @ProductId
						)
				BEGIN
					INSERT INTO dbo.ProductMaterials (
						ProductId
						,SubjectTypeId
						,SubjectId
						,Qty
						,CreatedBy
						,CreatedDate
						,CreatedUTCDate
						)
					SELECT @NewProductId
						,pm.SubjectTypeId
						,pm.SubjectId
						,pm.Qty
						,@UserID
						,@Date
						,@UTCDate
					FROM ProductMaterials pm WITH (NOLOCK)
					WHERE pm.ProductId = @ProductId
				END

				IF EXISTS (
						SELECT 1
						FROM dbo.ProductWorkflows pw WITH (NOLOCK)
						WHERE pw.ProductId = @ProductId
						)
				BEGIN
					INSERT INTO dbo.ProductWorkflows (
						ProductID
						,ManufacturingWorkflowId
						,ContractorUserID
						,SupervisorUserID
						,TentativeDays
						,Position
						,CreatedBy
						,CreatedDate
						,CreatedUTCDate
						,LabourCharge
						)
					SELECT @NewProductId
						,pw.ManufacturingWorkflowId
						,pw.ContractorUserID
						,pw.SupervisorUserID
						,pw.TentativeDays
						,pw.Position
						,@UserID
						,@Date
						,@UTCDate
						,pw.LabourCharge
					FROM ProductWorkflows pw WITH (NOLOCK)
					WHERE ProductID = @ProductId
				END

				-- Activity log via SP (same-tenant clone)
				SELECT @ActivityDescription = 'Product has been copied from ' + p.ProductTitle + ' - ' + p.ModelNo
				FROM dbo.Products p WITH (NOLOCK)
				WHERE p.ProductId = @ProductId;

				EXEC dbo.SaveActivityLog
					@SubjectTypeId  = @SubjectTypeId,
					@SubjectId      = @NewProductId,
					@Description    = @ActivityDescription,
					@Action         = 'CLONE',
					@CreatedBy      = @UserID,
					@CreatedDate    = @Date,
					@CreatedUTCDate = @UTCDate;
			END

			SELECT *
			FROM dbo.Products p WITH (NOLOCK)
			WHERE p.ProductId = @NewProductId
		END
		ELSE
		BEGIN

			DECLARE @WarehouseId BIGINT			

			SELECT @SubjectTypeId = SubjectTypeId
			FROM dbo.SubjectTypes st WITH (NOLOCK)
			WHERE st.TenantId = @FromTenantId
				AND st.SubjectTypeName = 'Products'

			SELECT @WarehouseId = Id
			FROM Warehouse WITH (NOLOCK)
			WHERE TenantId = @ToTenantId
			AND Name = 'Other'

			DECLARE @RetailerPer DECIMAL(18, 2)
			DECLARE @WholesalerPer DECIMAL(18, 2)
			DECLARE @RetailerPrice DECIMAL(18, 2)
			DECLARE @WholesalerPrice DECIMAL(18, 2)
			DECLARE @VendorWholesalerPrice DECIMAL(18, 2)
			DECLARE @VendorNames VARCHAR(MAX)

			SELECT @RetailerPer = RSPPercentage
				,@WholesalerPer = WSPPercentage
			FROM Categories
			WHERE CategoryId = @CategoryId

			SELECT @RetailerPrice = IIF(@CostPrice > 0, @CostPrice + (@CostPrice * @RetailerPer / 100), p.WholesalerPrice)
				,@WholesalerPrice = IIF(@CostPrice > 0, @CostPrice + (@CostPrice * @WholesalerPer / 100), p.WholesalerPrice)
				,@VendorModelNo = ModelNo
				,@VendorWholesalerPrice = p.WholesalerPrice
			FROM dbo.Products p WITH (NOLOCK)
			WHERE ProductId = @ProductId

			SELECT @VendorNames = VendorName from Vendors with(nolock) where VendorId = @VendorId

			PRINT N'different tenant blocks'

			IF EXISTS (
					SELECT 1
					FROM dbo.Products p WITH (NOLOCK)
					WHERE ProductId = @ProductId
					)
			BEGIN
				INSERT INTO dbo.Products (
					CategoryId
					,ProductTitle
					,ModelNo
					,Width
					,Height
					,Depth
					,FabricNeeded
					,IsVisibleToWholesalers
					,TotalDaysToPrepare
					,Features
					,Comments
					,CostPrice
					,TenantId
					,STATUS
					,CreatedBy
					,CreatedDate
					,CreatedUTCDate
					,Diameter
					-- DimensionUnitId is intentionally not copied across tenants: LookupValue ids are per tenant,
					-- so the clone falls back to the default unit label until a user picks one (TAN-4668).
					,RetailerPrice
					,WholesalerPrice
					,VendorProductPrice
					,VendorId
					,VendorNames
					)
				SELECT @CategoryId
					,ISNULL(@ProductTitle, p.ProductTitle)
					,ISNULL(@ModelNo, p.ModelNo)
					,p.Width
					,p.Height
					,p.Depth
					,p.FabricNeeded
					,p.IsVisibleToWholesalers
					,p.TotalDaysToPrepare
					,p.Features
					,p.Comments
					,IIF(@CostPrice > 0, @CostPrice, p.WholesalerPrice) -- AS This the price on which this tenant has bought the product
					,@ToTenantId
					,@IsPublished
					,@UserID
					,@Date
					,@UTCDate
					,p.Diameter
					,@RetailerPrice
					,@WholesalerPrice
					,IIF(@VendorProductPrice > 0, @VendorProductPrice, p.WholesalerPrice)
					,@VendorId
					,@VendorNames
				FROM dbo.Products p WITH (NOLOCK)
				WHERE ProductId = @ProductId

				SET @NewProductId = SCOPE_IDENTITY()
			END

			IF (@NewProductId > 0)
			BEGIN
				INSERT INTO dbo.ProductQuantities (
					ProductId
					,QuantityDate
					,Quantity
					,LastModifiedBy
					)
				SELECT @NewProductId
					,@Date
					,0
					,@UserID

				INSERT INTO ProductQuantitiesByWarehouse (
					ProductId
					,WarehouseId
					,QuantityDate
					,Quantity
					,LastModifiedBy
					,LastModifiedDate
					,LastModifiedUTCDate )
				SELECT 
					@NewProductId
					,@WarehouseId
					,@Date
					,0
					,@UserID
					,@Date
					,@UTCDate

				IF (
						@FromTenantId <> @ToTenantId
						AND @NewProductId > 0
						AND EXISTS (
							SELECT 1 VendorId
							FROM Vendors
							WHERE VendorId = @VendorId
								AND VendorTenantID = @FromTenantId
							)
						)
				BEGIN
					INSERT INTO [dbo].[ProductVendorMapping] (
						[ProductId]
						,[VendorId]
						,[IsDefault]
						,[VendorProductId]
						,[IsDeleted]
						,[CreatedBy]
						,[CreatedDate]
						,[CreatedUTCDate]
						,VendorModelNo
						,VendorProductPrice
						)
					VALUES (
						@NewProductId
						,@VendorId
						,0 ---------- is default-----
						,@ProductId
						,0 -----------Isdeleted
						,@UserID
						,@Date
						,@UTCDate
						,@VendorModelNo
						,@VendorWholesalerPrice
						)
				END

				-- Activity log via SP (cross-tenant clone)
				SET @ActivityDescription = ''
				SELECT @ActivityDescription = 'Product has been copied from ' + p.ProductTitle + ' - ' + p.ModelNo
				FROM dbo.Products p WITH (NOLOCK)
				WHERE p.ProductId = @ProductId;

				EXEC dbo.SaveActivityLog
					@SubjectTypeId  = @SubjectTypeId,
					@SubjectId      = @NewProductId,
					@Description    = @ActivityDescription,
					@Action         = 'CLONE',
					@CreatedBy      = @UserID,
					@CreatedDate    = @Date,
					@CreatedUTCDate = @UTCDate;
			END

			SELECT *
			FROM dbo.Products p WITH (NOLOCK)
			WHERE p.ProductId = @NewProductId
		END

		COMMIT TRAN CloneProduct
	END TRY

	BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK TRAN CloneProduct

		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT
		DECLARE @ObjectName VARCHAR(500)

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

			SET @ObjectName = OBJECT_NAME(@@PROCID); 

			EXEC dbo.SaveDBErrorLog 
			@ObjectName = @ObjectName 
		   ,@ErrorMsg = @ErrorMessage;

	END CATCH
END

GO

