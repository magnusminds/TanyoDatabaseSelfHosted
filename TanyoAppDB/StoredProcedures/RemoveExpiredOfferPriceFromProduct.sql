-- =============================================  
-- Author  : MagnusMinds  
-- Create date : 02-07-2025  
-- Description : Remove the offer price when the offer is expire
-- =============================================  
/*  
	EXEC [dbo].[RemoveExpiredOfferPriceFromProduct]
*/
CREATE PROCEDURE [dbo].[RemoveExpiredOfferPriceFromProduct]
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
	SET NOCOUNT OFF;

	DECLARE @Date DATE = GETDATE();

	--SELECT p.ProductId
	--	,[dbo].[CalculateTotalOfferAmount](p.RetailerPrice,o.OfferPercentage)
	--	,[dbo].[CalculateTotalOfferAmount](p.WholesalerPrice,o.OfferPercentage)

	UPDATE p
	SET p.RetailOfferPrice = NULL
		,p.WholesalerOfferPrice = NULL
	FROM Products p
	WHERE  (
			p.RetailOfferPrice IS NOT NULL 
			OR
			p.WholesalerOfferPrice IS NOT NULL
		)
		and NOT exists(
		select 1
		from OfferProductMapping opm 
		where opm.ProductId = p.ProductId
		)

	UPDATE p
	SET p.RetailOfferPrice = NULL
		,p.WholesalerOfferPrice = NULL
	FROM Products p
	INNER JOIN OfferProductMapping opm ON opm.ProductId = p.ProductId
	INNER JOIN Offers o ON o.OfferId = opm.OfferId
	WHERE (o.StartDate > @Date
		OR o.EndDate < @Date)
		AND (
			p.RetailOfferPrice IS NOT NULL 
			OR
			p.WholesalerOfferPrice IS NOT NULL
		)


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

