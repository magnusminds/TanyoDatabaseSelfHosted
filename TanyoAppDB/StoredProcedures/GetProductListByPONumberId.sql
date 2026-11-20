/*
	EXEC [dbo].[GetProductListByPONumberId]
	@TenantId = 103,
    @PONumberId = 312,
    @PageIndex = 1,
    @PageSize = 100,
    @SortBy = NULL,
    @SortOrder = NULL;
*/
CREATE   PROCEDURE [dbo].[GetProductListByPONumberId]
(
	@TenantId INT
    ,@PONumberId BIGINT
    ,@PageIndex INT = 1
    ,@PageSize INT = 10
    ,@SortBy NVARCHAR(100) = 'Title'
    ,@SortOrder NVARCHAR(4) = 'ASC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    IF @SortBy IS NULL SET @SortBy = 'Title';
    IF @SortOrder IS NULL SET @SortOrder = 'ASC';

	BEGIN TRY

		-- 1. Get PONumber from BackInquiries
		DECLARE @PONumber NVARCHAR(100);
		SELECT @PONumber = PONumber 
		FROM BackInquiries 
		WHERE ID = @PONumberId
		AND TenantID = @TenantId;

		IF @PONumber IS NULL
		BEGIN
			SELECT NULL AS Id, NULL AS Title, NULL AS Number, NULL AS Quantity, 0 AS TotalCount
			RETURN;
		END

		-- 2. Get InwardIds for this PO (non-deleted)
		;WITH InwardBase AS (
			SELECT ie.InwardId
			FROM InwardEntry ie
			WHERE ie.PONumber = @PONumber AND ie.IsDeleted = 0
		),
		-- 3. Inward Quantities per Product
		InwardedQty AS (
			SELECT ide.ProductId, SUM(ide.Quantity) AS TotalInwardQty
			FROM InwardDetailsEntry ide
			INNER JOIN InwardBase ib ON ide.InwardId = ib.InwardId
			WHERE ide.IsDeleted = 0
			GROUP BY ide.ProductId
		),
		-- 4. Final product list (filtered)
		ProductList AS (
			SELECT 
				p.ProductId AS Id,
				p.ProductTitle AS Title,
				p.ModelNo AS Number,
				CAST(
					CASE 
						WHEN iq.TotalInwardQty IS NULL THEN bii.Qty
						ELSE bii.Qty - iq.TotalInwardQty
					END AS INT
				) AS Quantity
			FROM BackInquiriesItems bii
			INNER JOIN Products p ON p.ProductId = bii.ProductID
			LEFT JOIN InwardedQty iq ON iq.ProductId = bii.ProductID
			WHERE bii.BackInquiryID = @PONumberId
			  AND p.Status = 1  -- Published
			  AND (iq.TotalInwardQty IS NULL OR bii.Qty - iq.TotalInwardQty > 0)
		)

		-- 5. Select with pagination + total count
		SELECT 
			Id,
			Title,
			Number,
			Quantity,
			(SELECT COUNT(*) FROM ProductList) AS TotalCount
		FROM ProductList
		ORDER BY 
			CASE WHEN @SortBy = 'Title' AND @SortOrder = 'ASC' THEN Title END ASC,
			CASE WHEN @SortBy = 'Title' AND @SortOrder = 'DESC' THEN Title END DESC,
			CASE WHEN @SortBy = 'Number' AND @SortOrder = 'ASC' THEN Number END ASC,
			CASE WHEN @SortBy = 'Number' AND @SortOrder = 'DESC' THEN Number END DESC,
			CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'ASC' THEN Quantity END ASC,
			CASE WHEN @SortBy = 'Quantity' AND @SortOrder = 'DESC' THEN Quantity END DESC
		OFFSET (@PageIndex - 1) * @PageSize ROWS
		FETCH NEXT @PageSize ROWS ONLY;
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

