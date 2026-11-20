/*

	EXEC CalculateLumpsumDiscount
		@OrderId = 41503
		,@LumpsumAmount = 10000
		,@TenantId = 125
		,@AppType = NULL
*/
CREATE PROCEDURE [dbo].[CalculateLumpsumDiscount] (
	@OrderId BIGINT
	,@LumpsumAmount DECIMAL(18, 2)
	,@TenantId INT
	,@AppType VARCHAR(128)
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	DROP TABLE

	IF EXISTS #OrderItems;
		DECLARE @OrderTotalAmount DECIMAL(18, 2)
			,@ProductSubjectTypeId INT
			,@FabricSubjectTypeId INT;

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products'
		AND TenantId = @TenantId;

	SELECT @FabricSubjectTypeId = SubjectTypeId
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Fabrics'
		AND TenantId = @TenantId;

	SELECT osi.OrderSetItemId
		,OSI.OrderId
		,OSI.SubjectId
		,OSI.SubjectTypeId
		,ISNULL(PT.CoverImage, FB.ImagePath) AS ProductImage
		,OSI.GrossTotal
		,OSI.InstantWidth AS Width
		,OSI.InstantHeight AS Height
		,OSI.InstantDepth AS Depth
		,OSI.Quantity
		,CASE 
			WHEN osi.SubjectTypeId = @ProductSubjectTypeId
				THEN PT.ProductTitle
			WHEN osi.SubjectTypeId = @FabricSubjectTypeId
				THEN FB.Title
			ELSE ''
			END AS [ProductTitle]
		,CASE 
			WHEN osi.SubjectTypeId = @ProductSubjectTypeId
				THEN PT.ModelNo
			WHEN osi.SubjectTypeId = @FabricSubjectTypeId
				THEN FB.ModelNo
			ELSE ''
			END AS ModelNo
		,OSI.UnitPrice
		,OSI.TotalAmount
		,OSI.DiscountPrice
		,OSI.ParentOrderSetItemId
		,CASE 
			WHEN osi.SubjectTypeId = @ProductSubjectTypeId
				THEN CT.MaxDiscount
			WHEN osi.SubjectTypeId = @FabricSubjectTypeId
				THEN C.MaxDiscount
			END AS MaxDiscount
	INTO #OrderItems
	FROM OrderSetItems osi WITH (NOLOCK)
	LEFT JOIN Products PT WITH (NOLOCK) ON OSI.SubjectId = PT.ProductId
		AND OSI.SubjectTypeId = @ProductSubjectTypeId
	LEFT JOIN Categories CT WITH (NOLOCK) ON CT.CategoryId = PT.CategoryId
	LEFT JOIN Fabrics FB WITH (NOLOCK) ON OSI.SubjectId = FB.FabricId
		AND OSI.SubjectTypeId = @FabricSubjectTypeId
	LEFT JOIN Companies C WITH (NOLOCK) ON C.CompanyId = FB.CompanyId
	WHERE osi.OrderId = @OrderId
		AND osi.IsDeleted = 0

	ALTER TABLE #OrderItems ADD EstimatedDiscountAmount DECIMAL(18, 6)
		,DiscountPercentage DECIMAL(18, 6)
		,NewDiscountPercentage DECIMAL(18, 2)
		,NewAmountPrice DECIMAL(18, 2)

	--AND osi.ParentOrderSetItemId IS NULL
	SELECT @OrderTotalAmount = SUM(TotalAmount)
	FROM #OrderItems;

	IF @LumpsumAmount > ISNULL(@OrderTotalAmount, 0)
	BEGIN
		SELECT *
			,'Lumpsum discount amount exceeds order amount' AS [Message]
			,0 AS [Status]
		FROM #OrderItems

		RETURN;
	END

	UPDATE oi
	SET EstimatedDiscountAmount = ((oi.TotalAmount * @LumpsumAmount) / NULLIF(@OrderTotalAmount,0)) / NULLIF(oi.Quantity,0)
		,DiscountPercentage = (100 * (((oi.TotalAmount * @LumpsumAmount) / NULLIF(@OrderTotalAmount,0)) / NULLIF(oi.Quantity,0))) / NULLIF(oi.UnitPrice,0)
	FROM #OrderItems oi;

	UPDATE oi
	SET NewDiscountPercentage = ROUND(oi.DiscountPrice + ROUND(oi.DiscountPercentage, 2), 2)
		,NewAmountPrice = ROUND(oi.GrossTotal - ROUND((oi.GrossTotal * (oi.DiscountPrice + ROUND(oi.DiscountPercentage, 2)) / 100), 2), 0)
	FROM #OrderItems oi;

	SELECT OrderSetItemId	
		   ,OrderId	
		   ,SubjectId	
		   ,SubjectTypeId	
		   ,ProductImage	
		   ,GrossTotal	
		   ,Width	
		   ,Height	
		   ,Depth	
		   ,Quantity	
		   ,ProductTitle	
		   ,ModelNo	
		   ,UnitPrice	
		   ,TotalAmount	
		   ,DiscountPrice	
		   ,ParentOrderSetItemId	
		   ,MaxDiscount	
		   ,EstimatedDiscountAmount	
		   ,ISNULL(DiscountPercentage,DiscountPrice) AS	DiscountPercentage
		   ,ISNULL(NewDiscountPercentage,0) NewDiscountPercentage	
		   ,ISNULL(NewAmountPrice,GrossTotal) NewAmountPrice
		,CASE 
			WHEN NewDiscountPercentage > MaxDiscount
				AND @AppType = 'App'
				THEN 'The maximum discount you can apply is ' + CAST(MaxDiscount AS VARCHAR(128)) + ' %.'
			ELSE NULL --'The applied discount is valid '
			END AS [Message]
		,CASE 
			WHEN NewDiscountPercentage > MaxDiscount
				AND @AppType = 'App'
				THEN 0
			ELSE 1
			END AS STATUS
	FROM #OrderItems
	ORDER BY OrderSetItemId;

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

