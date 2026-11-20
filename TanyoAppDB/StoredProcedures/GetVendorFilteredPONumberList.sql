/*
	EXEC [dbo].[GetVendorFilteredPONumberList]
		@TenantId = 103
		,@VendorId = 68
		,@PONumber = NULL
		,@PageIndex = 1 
        ,@PageSize = 105 
        ,@SortBy = NULL
        ,@SortOrder= NULL
*/

CREATE   PROCEDURE [dbo].[GetVendorFilteredPONumberList]
	@TenantId INT,
    @VendorId BIGINT,
    @PONumber NVARCHAR(100) = NULL,
    @PageIndex INT = 1,
    @PageSize INT = 50,
    @SortBy VARCHAR(100) = 'PONumber',
    @SortOrder VARCHAR(50) = 'DESC'
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    -- Default fallback
    IF @SortBy IS NULL SET @SortBy = 'PONumber';
    IF @SortOrder IS NULL SET @SortOrder = 'DESC';

	BEGIN TRY
		-- Use table variable instead of temp tables
		DECLARE @FilteredPOs TABLE (
			ID BIGINT,
			PONumber NVARCHAR(100)
		);

		-- Insert only those PO numbers where NOT all products are fully inwarded
		INSERT INTO @FilteredPOs (ID, PONumber)
		SELECT DISTINCT bi.ID, bi.PONumber
		FROM BackInquiries bi
		INNER JOIN BackInquiriesItems bii ON bi.ID = bii.BackInquiryID
		LEFT JOIN (
			SELECT 
				ie.PONumber,
				ide.ProductId,
				SUM(ide.Quantity) AS TotalInwardQty
			FROM InwardEntry ie
			INNER JOIN InwardDetailsEntry ide ON ie.InwardId = ide.InwardId
			WHERE ie.IsDeleted = 0
			GROUP BY ie.PONumber, ide.ProductId
		) AS inward ON inward.PONumber = bi.PONumber AND inward.ProductId = bii.ProductID
		WHERE bi.VendorId = @VendorId
		  AND bi.TenantID = @TenantId
		  AND LTRIM(RTRIM(bi.PONumber)) <> ''
		  AND (bi.Status = 0 OR bi.Status = 3)
		  AND (
			  inward.TotalInwardQty IS NULL 
			  OR inward.TotalInwardQty < bii.Qty
		  )
		  AND (
			  @PONumber IS NULL 
			  OR LTRIM(RTRIM(LOWER(bi.PONumber))) LIKE '%' + LTRIM(RTRIM(LOWER(@PONumber))) + '%'
		  );

		-- Apply pagination and sorting
		SELECT 
			ID,
			PONumber,
			(SELECT COUNT(1) FROM @FilteredPOs) AS TotalCount
		FROM @FilteredPOs
		ORDER BY 
			CASE WHEN @SortBy = 'PONumber' AND @SortOrder = 'ASC' THEN PONumber END ASC,
			CASE WHEN @SortBy = 'PONumber' AND @SortOrder = 'DESC' THEN PONumber END DESC
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

