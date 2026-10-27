/*
EXEC [dbo].[ListVendors]
     @TenantId  = 1207,
     @VendorName = NULL,
     @VendorEmailId = NULL,
     @VendorPhone = NULL,
     @City = NULL,
     @Handshake = -1,
     @PageIndex = 1,
     @PageSize = 500,
     @SortBy = 'UpdatedDate',
     @SortOrder = 'DESC';
*/
CREATE PROCEDURE [dbo].[ListVendors]
(
     @TenantId      INT
    ,@VendorName    VARCHAR(200) = NULL
    ,@VendorEmailId VARCHAR(200) = NULL
    ,@VendorPhone   VARCHAR(100) = NULL
    ,@City          VARCHAR(200) = NULL
    ,@Handshake     INT = -1
    ,@PageIndex     INT = 1
    ,@PageSize      INT = 25
    ,@SortBy        VARCHAR(50) = 'UpdatedDate'
    ,@SortOrder     VARCHAR(10) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        -- Normalise paging inputs; keep OFFSET non-negative and a sane page size.
        IF (@PageIndex < 1) SET @PageIndex = 1;
        IF (@PageSize IS NULL OR @PageSize < 1) SET @PageSize = 25;
        IF (@SortOrder NOT IN ('ASC', 'DESC')) SET @SortOrder = 'DESC';

        SELECT
             v.VendorId
            ,v.VendorCode
            ,v.VendorName
            ,v.VendorEmailId
            ,v.VendorPhone
            ,v.GST
            ,v.Expense
            ,v.Notes
            ,v.ContactPersonName
            ,v.ContactPersonPhone
            ,v.ContactPersonEmail
            ,addr.City
            ,addr.State
            ,addr.Country
            ,v.Website
            ,v.Status
            ,v.AcceptRejectStatus
            ,v.CreatedDate
            -- Parity with the old projection: the grid's "updatedDate" was coalesce(UpdatedDate, CreatedDate).
            ,ISNULL(v.UpdatedDate, v.CreatedDate) AS UpdatedDate
            ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
        FROM dbo.Vendors AS v WITH (NOLOCK)
        OUTER APPLY
        (
            SELECT TOP 1 va.City, va.State, va.Country
            FROM dbo.VendorAddresses AS va WITH (NOLOCK)
            WHERE va.VendorId = v.VendorId
              AND va.IsDeleted = 0
            ORDER BY va.VendorAddressId DESC
        ) AS addr
        WHERE v.TenantId = @TenantId
          AND v.ReferralCode IS NULL
          AND (@VendorName IS NULL OR LTRIM(RTRIM(@VendorName)) = ''
               OR v.VendorName LIKE '%' + @VendorName + '%'
               OR v.VendorCode LIKE '%' + @VendorName + '%')
          AND (@VendorEmailId IS NULL OR LTRIM(RTRIM(@VendorEmailId)) = ''
               OR v.VendorEmailId LIKE '%' + @VendorEmailId + '%')
          AND (@VendorPhone IS NULL OR LTRIM(RTRIM(@VendorPhone)) = ''
               OR v.VendorPhone LIKE '%' + @VendorPhone + '%')
          AND (@City IS NULL OR LTRIM(RTRIM(@City)) = ''
               OR addr.City LIKE '%' + @City + '%')
          AND (@Handshake NOT IN (1, 2)
               OR (@Handshake = 1 AND v.AcceptRejectStatus = 1)
               OR (@Handshake = 2 AND v.AcceptRejectStatus = 0))
        ORDER BY
             CASE WHEN @SortBy = 'VendorName'    AND @SortOrder = 'ASC'  THEN v.VendorName    END ASC,
             CASE WHEN @SortBy = 'VendorName'    AND @SortOrder = 'DESC' THEN v.VendorName    END DESC,
             CASE WHEN @SortBy = 'VendorEmailId' AND @SortOrder = 'ASC'  THEN v.VendorEmailId END ASC,
             CASE WHEN @SortBy = 'VendorEmailId' AND @SortOrder = 'DESC' THEN v.VendorEmailId END DESC,
             CASE WHEN @SortBy = 'VendorPhone'   AND @SortOrder = 'ASC'  THEN v.VendorPhone   END ASC,
             CASE WHEN @SortBy = 'VendorPhone'   AND @SortOrder = 'DESC' THEN v.VendorPhone   END DESC,
             CASE WHEN @SortBy = 'GST'           AND @SortOrder = 'ASC'  THEN v.GST           END ASC,
             CASE WHEN @SortBy = 'GST'           AND @SortOrder = 'DESC' THEN v.GST           END DESC,
             CASE WHEN @SortBy = 'City'          AND @SortOrder = 'ASC'  THEN addr.City       END ASC,
             CASE WHEN @SortBy = 'City'          AND @SortOrder = 'DESC' THEN addr.City       END DESC,
             CASE WHEN @SortBy = 'State'         AND @SortOrder = 'ASC'  THEN addr.State      END ASC,
             CASE WHEN @SortBy = 'State'         AND @SortOrder = 'DESC' THEN addr.State      END DESC,
             CASE WHEN @SortBy = 'UpdatedDate'   AND @SortOrder = 'ASC'  THEN ISNULL(v.UpdatedDate, v.CreatedDate) END ASC,
             CASE WHEN @SortBy = 'UpdatedDate'   AND @SortOrder = 'DESC' THEN ISNULL(v.UpdatedDate, v.CreatedDate) END DESC,
             CASE WHEN @SortOrder = 'ASC'  THEN ISNULL(v.UpdatedDate, v.CreatedDate) END ASC,
             CASE WHEN @SortOrder = 'DESC' THEN ISNULL(v.UpdatedDate, v.CreatedDate) END DESC
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

