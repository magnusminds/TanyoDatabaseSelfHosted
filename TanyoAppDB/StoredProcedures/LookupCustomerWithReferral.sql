/*
 EXEC [dbo].[LookupCustomerWithReferral]
  @Search = '98',
  @TenantId = 1207,
  @IncludeDealers = 1
*/
CREATE   PROCEDURE [dbo].[LookupCustomerWithReferral]
(
    @Search VARCHAR(200),
    @TenantId INT,
    @IncludeDealers BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY
        SELECT
            c.CustomerId,
            RTRIM(LTRIM(c.FirstName + ' ' + ISNULL(c.LastName, ''))) AS FullName,
            c.PhoneNumber,
            c.EmailId,
            c.CustomerTypeId,
            c.RefferedBy,
            ref.CustomerId            AS RefferedCustomerId,
            RTRIM(LTRIM(ref.FirstName + ' ' + ISNULL(ref.LastName, ''))) AS RefferedFullName,
            ref.PhoneNumber           AS RefferedPhoneNumber,
            ref.EmailId               AS RefferedEmailId,
            ref.CustomerTypeId        AS RefferedCustomerTypeId,
            ref.InteriorCommissionPer AS RefferedInteriorCommissionPer
        FROM [dbo].[Customers] c WITH (NOLOCK)
        LEFT JOIN [dbo].[Customers] ref WITH (NOLOCK)
            ON c.RefferedBy = ref.CustomerId AND ref.IsDeleted = 0
        LEFT JOIN [dbo].[Vendors] v WITH (NOLOCK)
            ON v.DealerCustomerId = c.CustomerId AND v.IsDealer = 1 AND v.TenantId = @TenantId
        WHERE c.IsDeleted = 0
          AND c.TenantId = @TenantId
          AND (c.CustomerTypeId IN (1, 2) OR (@IncludeDealers = 1 AND c.CustomerTypeId = 4))
          AND (
              c.PhoneNumber LIKE '%' + @Search + '%'
              OR c.AltPhoneNumber LIKE '%' + @Search + '%'
              OR (c.FirstName + ' ' + ISNULL(c.LastName, '')) LIKE '%' + @Search + '%'
              OR (@IncludeDealers = 1 AND c.CustomerTypeId = 4 AND (
                  v.ContactPersonName LIKE '%' + @Search + '%'
                  OR v.ContactPersonPhone LIKE '%' + @Search + '%'
              ))
          )
        ORDER BY FullName;

    END TRY

    BEGIN CATCH
        DECLARE @ObjectName VARCHAR(500),
                @ErrorMsg VARCHAR(MAX);

        SET @ObjectName = OBJECT_NAME(@@PROCID);
        SET @ErrorMsg = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
            @ObjectName = @ObjectName,
            @ErrorMsg = @ErrorMsg;
    END CATCH
END

GO

