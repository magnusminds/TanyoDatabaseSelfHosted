/*
EXEC [dbo].[GetProducts] 
        @TenantId = 1,
        @CategoryId = NULL,
        @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F', 
        @ProductTitle= NULL, 
        @ModelNo= NULL,
        @PublishStatus= NULL,
        @OfferDataId= NULL, 
        @UpdateFromDate= NULL,
        @UpdateToDate= NULL, 
		@VendorId = NULL,
        @PageIndex = 1, 
        @PageSize = 50, 
        @SortBy = NULL,
        @SortOrder= NULL
*/

CREATE PROCEDURE [dbo].[zGetProducts] (
	@TenantId INT
	,@CategoryId BIGINT = NULL
	,@RoleId VARCHAR(100)
	,@ProductTitle VARCHAR(100) = NULL
	,@ModelNo VARCHAR(100) = NULL
	,@PublishStatus INT = NULL
	,@OfferDataId INT = NULL
	,@UpdateFromDate DATE = NULL
	,@UpdateToDate DATE = NULL
	,@VendorId BIGINT = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = '10'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
		EXEC [dbo].[GetProducts_v1]
		@TenantId = @TenantId 
		,@CategoryId = @CategoryId 
		,@RoleId = @RoleId 
		,@ProductTitle = @ProductTitle 
		,@ModelNo = @ModelNo 
		,@PublishStatus = @PublishStatus 
		,@OfferDataId = @OfferDataId 
		,@UpdateFromDate = @UpdateFromDate 
		,@UpdateToDate= @UpdateToDate
		--,@VendorId=@VendorId 
		,@PageIndex=@PageIndex
		,@PageSize=@PageSize 
		,@SortBy=@SortBy 	
		,@SortOrder=@SortOrder

	RETURN

	--DECLARE @ProductSubjectTypeId INT;
	--DECLARE @dt DATE
	--SELECT @dt = CAST(GETDATE() AS DATE)

	--SELECT @ProductSubjectTypeId = SubjectTypeId
	--FROM SubjectTypes WITH (NOLOCK)
	--WHERE SubjectTypeName = 'Products'
	--	AND TenantId = @TenantId
	--	AND IsDeleted = 0

	--BEGIN TRY

	--	DECLARE @Products AS TABLE (ProductID BIGINT, TotalCount INT)

	--	;with cteOffers as(
	--		SELECT	opm.ProductId, opm.OfferId, ofr.StartDate, ofr.EndDate, ofr.OfferPercentage
	--		FROM	dbo.OfferProductMapping AS opm WITH (NOLOCK) 
	--		INNER JOIN dbo.Offers AS ofr WITH (NOLOCK) ON opm.offerId = ofr.OfferId
	--		WHERE ofr.IsDeleted = 0
	--		AND ofr.TenantId = @TenantId
	--		GROUP BY opm.ProductId, opm.OfferId, ofr.StartDate, ofr.EndDate, ofr.OfferPercentage
	--	)

	--	INSERT INTO @Products(ProductID, TotalCount)
	--	SELECT p.ProductId
 --               ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	--	FROM dbo.Products AS p WITH (NOLOCK)
	--	INNER JOIN dbo.Categories AS t WITH (NOLOCK) ON p.CategoryId = t.CategoryId
	--	--INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
	--	--LEFT JOIN dbo.ProductQuantities AS ia WITH (NOLOCK) ON p.ProductId = ia.ProductId
	--	LEFT JOIN cteOffers ofr ON ofr.ProductId = p.ProductId
	--	WHERE p.TenantId = @TenantId
	--		AND p.STATUS <> 3
	--		AND (
	--			@PublishStatus IS NULL
	--			OR p.STATUS = @PublishStatus
	--			)
	--		AND (
	--			ISNULL(@ModelNo, '') = ''
	--			OR p.ModelNo LIKE  '%' + @ModelNo + + '%'
	--			)
	--		AND (
	--			ISNULL(@CategoryId, - 1) = - 1
	--			OR p.CategoryId = @CategoryId
	--			)
	--		AND (
	--			ISNULL(@ProductTitle, '') = ''
	--			OR p.ProductTitle LIKE  '%' + @ProductTitle + '%'
	--			)
	--		AND (
	--			ISNULL(@OfferDataId, - 1) = - 1
	--			OR ofr.OfferId = @OfferDataId
	--			)
	--		AND (
	--			@UpdateFromDate IS NULL
	--			OR @UpdateToDate IS NULL
	--			OR p.UpdatedDate BETWEEN @UpdateFromDate
	--				AND @UpdateToDate
	--			)
	--		AND (
	--			ISNULL(@VendorId, - 1) = - 1
	--			OR EXISTS (
	--				SELECT pvm.ProductId FROM dbo.ProductVendorMapping AS pvm
	--					WHERE pvm.ProductId = p.ProductId
	--				AND pvm.VendorId = @VendorId )
	--			)
	--	ORDER BY CASE 
	--			WHEN @SortBy = 'CategoryName'
	--				AND @SortOrder = 'ASC'
	--				THEN t.CategoryName
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'CategoryName'
	--				AND @SortOrder = 'DESC'
	--				THEN t.CategoryName
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'ProductTitle'
	--				AND @SortOrder = 'ASC'
	--				THEN p.ProductTitle
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'ProductTitle'
	--				AND @SortOrder = 'DESC'
	--				THEN p.ProductTitle
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'ModelNo'
	--				AND @SortOrder = 'ASC'
	--				THEN p.ModelNo
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'ModelNo'
	--				AND @SortOrder = 'DESC'
	--				THEN p.ModelNo
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'CostPrice'
	--				AND @SortOrder = 'ASC'
	--				THEN ROUND(p.CostPrice, 0)
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'CostPrice'
	--				AND @SortOrder = 'DESC'
	--				THEN ROUND(p.CostPrice, 0)
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'UpdatedDate'
	--				AND @SortOrder = 'ASC'
	--				THEN p.UpdatedDate
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'UpdatedDate'
	--				AND @SortOrder = 'DESC'
	--				THEN p.UpdatedDate
	--			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	--	FETCH NEXT @PageSize ROWS ONLY;

	--	;with cteProductOffer as(
	--		SELECT	opm.ProductId, opm.OfferId, ofr.StartDate, ofr.EndDate, ofr.OfferPercentage, ofr.OfferCode
	--		FROM	dbo.OfferProductMapping AS opm WITH (NOLOCK) 
	--		INNER JOIN dbo.Offers AS ofr WITH (NOLOCK) ON opm.offerId = ofr.OfferId
	--		WHERE ofr.IsDeleted = 0
	--		AND ofr.TenantId = @TenantId
	--		GROUP BY opm.ProductId, opm.OfferId, ofr.StartDate, ofr.EndDate, ofr.OfferPercentage, ofr.OfferCode
	--	)
	--	SELECT p.ProductId
	--		,CAST(CONVERT(BIGINT, t.CategoryId) AS INT) AS CategoryId
	--		,t.CategoryName
 --           ,p.ProductTitle
	--		,pv.VendorName
	--		,ROUND(p.CostPrice, 0) AS CostPrice
	--		,p.WholesalerPrice AS [WholeSalerPrice]
	--		,p.RetailerPrice AS [RetailerPrice]
	--		,CASE 
	--			WHEN ofr.OfferId IS NOT NULL
	--				THEN p.RetailOfferPrice	
	--			ELSE 0
	--			END [OfferPrice]
	--		,p.CoverImage as CoverImage
	--		,p.ModelNo
	--		,p.STATUS
	--		,CASE 
	--			WHEN p.UpdatedBy IS NOT NULL
	--				THEN p.UpdatedBy
	--			ELSE p.CreatedBy
	--			END AS UpdatedBy
	--		,CASE 
	--			WHEN p.UpdatedDate IS NOT NULL
	--				THEN p.UpdatedDate
	--			ELSE p.CreatedDate
	--			END AS CreatedDate
	--		,ofr.OfferId
	--		,ofr.OfferCode as OfferCode
	--		,CASE 
	--			WHEN ofr.OfferId IS NOT NULL 
	--					AND ofr.StartDate <= @dt
	--					AND ofr.EndDate >= @dt
	--				THEN CAST(0 AS BIT)
	--			ELSE CAST(1 AS BIT)
	--		END AS ExpiredOffer
	--		,ISNULL(ia.Quantity, 0) AS InStock
	--		--,0 AS ReadyToDelivered
	--		--,0 AS Inquiry
	--		,ISNULL((SELECT SUM(os.Quantity)
	--			FROM dbo.Orders AS o WITH (NOLOCK) 
	--			INNER JOIN dbo.OrderSetItems AS os WITH (NOLOCK) ON os.OrderId = o.OrderId
	--			WHERE os.ItemStatus = 2
	--				and os.IsDeleted = 0
	--				and o.TenantId = @TenantId
	--						AND o.STATUS > 2
	--						AND o.STATUS NOT IN (
	--							8
	--							,9
	--							)
	--						AND os.IsDeleted != 1
	--						and os.SubjectId = p.ProductId
	--			),0)
	--			AS ReadyToDelivered
	--		,ISNULL((SELECT SUM(os.Quantity)
	--			FROM dbo.Orders AS o WITH (NOLOCK) 
	--			INNER JOIN dbo.OrderSetItems AS os WITH (NOLOCK) ON os.OrderId = o.OrderId
	--			WHERE p.ProductId = os.SubjectId
	--				and os.IsDeleted = 0
	--			and o.TenantId = @TenantId
	--			AND o.STATUS = 0
	--			AND os.IsDeleted != 1
	--			AND o.STATUS != 9
	--			AND os.SubjectTypeId = @ProductSubjectTypeId
	--					),0) AS Inquiry
	--		,ISNULL((SELECT SUM(SOH.Quantity) AS TotalQuntity
	--					FROM OrderSetItems AS Osi WITH (NOLOCK)
	--					INNER JOIN StockOnHold AS Soh WITH (NOLOCK) ON Soh.OrderSetItemId = Osi.OrderSetItemId
	--					INNER JOIN ORDERS AS O WITH (NOLOCK) ON O.OrderId = Soh.OrderId
	--					WHERE Osi.IsDeleted = 0
	--					AND Osi.IsQuantityOnHold = 1
	--					AND Soh.IsStockOnHold = 1
	--					AND DATEADD(DAY, CAST(Soh.TimePeriod AS INT), CAST(Soh.CreatedDate AS DATETIMEOFFSET)) > SYSDATETIMEOFFSET()
	--					AND ProductId = p.ProductId
	--					AND O.Status = 0
	--				Group By SOH.ProductId
	--				),0) AS HoldOnQuantity
	--		,MIN(x.TotalCount) OVER (PARTITION BY 1) AS TotalCount
	--	FROM dbo.Products AS p WITH (NOLOCK)
	--	INNER JOIN @Products x ON x.ProductID = p.ProductId
	--	INNER JOIN dbo.Categories AS t WITH (NOLOCK) ON p.CategoryId = t.CategoryId
	--	INNER JOIN dbo.AspNetUsers AS [as] WITH (NOLOCK) ON p.CreatedBy = [as].UserId
	--	LEFT JOIN dbo.ProductQuantities AS ia WITH (NOLOCK) ON p.ProductId = ia.ProductId
	--	LEFT JOIN cteProductOffer ofr ON ofr.ProductId = p.ProductId
	--	LEFT JOIN (
 --           SELECT p.ProductId,
 --                  STRING_AGG(v.VendorName, ', ') AS VendorName
 --           FROM dbo.ProductVendorMapping AS pvm
 --           INNER JOIN @Products AS p ON p.ProductId = pvm.ProductId
 --           INNER JOIN dbo.Vendors AS v ON pvm.VendorId = v.VendorId
 --           WHERE ((@VendorId IS NULL) OR pvm.VendorId = @VendorId)
 --           GROUP BY p.ProductId
 --       ) AS pv ON p.ProductId = pv.ProductId

	--	ORDER BY CASE 
	--			WHEN @SortBy = 'CategoryName'
	--				AND @SortOrder = 'ASC'
	--				THEN t.CategoryName
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'CategoryName'
	--				AND @SortOrder = 'DESC'
	--				THEN t.CategoryName
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'ProductTitle'
	--				AND @SortOrder = 'ASC'
	--				THEN p.ProductTitle
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'ProductTitle'
	--				AND @SortOrder = 'DESC'
	--				THEN p.ProductTitle
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'ModelNo'
	--				AND @SortOrder = 'ASC'
	--				THEN p.ModelNo
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'ModelNo'
	--				AND @SortOrder = 'DESC'
	--				THEN p.ModelNo
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'CostPrice'
	--				AND @SortOrder = 'ASC'
	--				THEN ROUND(p.CostPrice, 0)
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'CostPrice'
	--				AND @SortOrder = 'DESC'
	--				THEN ROUND(p.CostPrice, 0)
	--			END DESC
	--		,CASE 
	--			WHEN @SortBy = 'UpdatedDate'
	--				AND @SortOrder = 'ASC'
	--				THEN p.UpdatedDate
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'UpdatedDate'
	--				AND @SortOrder = 'DESC'
	--				THEN p.UpdatedDate
	--			END DESC 
	--		,CASE 
	--			WHEN @SortBy = 'VendorName'
	--				AND @SortOrder = 'ASC'
	--				THEN pv.VendorName
	--			END ASC
	--		,CASE 
	--			WHEN @SortBy = 'VendorName'
	--				AND @SortOrder = 'DESC'
	--				THEN pv.VendorName
	--			END DESC
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				)
	END CATCH
END

GO

