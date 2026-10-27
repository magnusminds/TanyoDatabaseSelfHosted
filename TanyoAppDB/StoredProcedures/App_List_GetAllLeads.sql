CREATE
  PROCEDURE [dbo].[App_List_GetAllLeads]
(
    @TenantId               INT,
    @CurrentUserId          BIGINT,
    @RoleId                 NVARCHAR(100),
    @CustomerName           VARCHAR(200) = NULL,
    @StatusId               INT = NULL,
    @SalesmanId             BIGINT = NULL,
    @PhoneNumber            VARCHAR(50) = NULL,
    @InquiryFromDate        DATE = NULL,
    @InquiryToDate          DATE = NULL,
    @FollowUpFromDate       DATE = NULL,
    @FollowUpToDate         DATE = NULL,
    @PageNumber              INT = 1,
    @PageSize                INT = 25,
    @SortColumn             VARCHAR(50) = 'UpdatedDate',
    @SortDirection          VARCHAR(4) = 'DESC',
    @LeadSourceId           BIGINT = NULL,
    @CustomerId             BIGINT = NULL,
    @LeadNumber             VARCHAR(15) = NULL,
    @PriorityId             INT = NULL,
    @BuyingRangeValueId     BIGINT = NULL
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    BEGIN TRY

        /* ============================================================
           Normalize parameters
           ============================================================ */

        SET @CustomerName = NULLIF(LTRIM(RTRIM(@CustomerName)), '');
        SET @PhoneNumber = NULLIF(LTRIM(RTRIM(@PhoneNumber)), '');
        SET @LeadNumber = NULLIF(LTRIM(RTRIM(@LeadNumber)), '');
        SET @SortColumn = NULLIF(LTRIM(RTRIM(@SortColumn)), '');

        IF @PageNumber IS NULL OR @PageNumber < 1
            SET @PageNumber = 1;

        IF @PageSize IS NULL OR @PageSize < 1
            SET @PageSize = 25;

        IF @PageSize > 500
            SET @PageSize = 500;

        SET @SortDirection =
            CASE
                WHEN UPPER(@SortDirection) = 'ASC'
                    THEN 'ASC'
                ELSE 'DESC'
            END;


        /* ============================================================
           Role permissions
           ============================================================ */

        DECLARE
            @IsAdmin BIT = 0,
            @HasSuperAccess BIT = 0;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.AspNetRoles WITH (NOLOCK)
            WHERE Id = @RoleId
              AND [Name] = 'Administrator_' + CONVERT(VARCHAR(20), @TenantId)
        )
        BEGIN
            SET @IsAdmin = 1;
        END;

        IF EXISTS
        (
            SELECT 1
            FROM dbo.AspNetRoleClaims WITH (NOLOCK)
            WHERE RoleId = @RoleId
              AND ClaimValue = 'Permissions.App.Lead.SuperAccess'
        )
        BEGIN
            SET @HasSuperAccess = 1;
        END;


        /* ============================================================
           User locations

           Primary key gives us a clustered index on LocationID.
           ============================================================ */

        DROP TABLE IF EXISTS #UserLocations;

        CREATE TABLE #UserLocations
        (
            LocationID BIGINT NOT NULL PRIMARY KEY CLUSTERED
        );

        INSERT INTO #UserLocations
        (
            LocationID
        )
        SELECT DISTINCT
            LocationID
        FROM dbo.LocationUserMapping WITH (NOLOCK)
        WHERE UserID = @CurrentUserId;


        /* ============================================================
           Safe ORDER BY expression

           Only predefined expressions are allowed into dynamic SQL.
           Filter values are always passed as parameters.
           ============================================================ */

        DECLARE @OrderByExpression NVARCHAR(1000);

        SET @OrderByExpression =
            CASE @SortColumn

                WHEN 'Priority'
                    THEN N'l.Priority'

                WHEN 'InquiryDate'
                    THEN N'l.CreatedDate'

                WHEN 'Status'
                    THEN N'l.Status'

                WHEN 'CustomerName'
                    THEN N'
                        ISNULL
                        (
                            NULLIF
                            (
                                CONCAT(cust.FirstName, '' '', cust.LastName),
                                '' ''
                            ),
                            CONCAT(l.FirstName, '' '', l.LastName)
                        )'

                WHEN 'PhoneNumber'
                    THEN N'ISNULL(cust.PhoneNumber, l.PhoneNumber)'

                WHEN 'Salesman'
                    THEN N'CONCAT(u.FirstName, '' '', u.LastName)'

                WHEN 'FollowUpDate'
                    THEN N'fu.FollowUpDate'

                WHEN 'LeadSourceName'
                    THEN N'
                        ISNULL
                        (
                            LKV.LookupValueName,
                            ISNULL(l.Other, ''Other'')
                        )'

                WHEN 'LeadNumber'
                    THEN N'l.LeadNumber'

                WHEN 'UpdatedDate'
                    THEN N'ISNULL(l.UpdatedDate, l.CreatedDate)'

                ELSE
                    N'ISNULL(l.UpdatedDate, l.CreatedDate)'

            END;


        /* ============================================================
           Dynamic SQL
           ============================================================ */

        DECLARE
            @SQL NVARCHAR(MAX),
            @Params NVARCHAR(MAX);


        /* ============================================================
           Base query

           Only mandatory filters are placed here.
           ============================================================ */

        SET @SQL = N'
SELECT
      l.LeadId
    , l.Notes AS Inquiry
    , l.InquiryAbout
    , l.InquiryFor
    , l.RefferedBy

    , ISNULL(custRef.FirstName, '''')
      +
      CASE
          WHEN custRef.LastName IS NULL
               OR custRef.LastName = ''''
              THEN ''''
          ELSE '' '' + custRef.LastName
      END AS RefferedByName

    , ISNULL(cust.FirstName, l.FirstName) AS FirstName
    , ISNULL(cust.LastName, l.LastName) AS LastName

    , ISNULL
      (
          NULLIF
          (
              CONCAT(cust.FirstName, '' '', cust.LastName),
              '' ''
          ),
          CONCAT(l.FirstName, '' '', l.LastName)
      ) AS CustomerName

    , l.Priority
    , lbl.LabelName AS PriorityLabel
    , lbl.ColorCode AS PriorityColorCode

    , l.CreatedDate AS InquiryDate
    , l.LastContactedDate
    , l.CreatedBy
    , l.SalesmanId AS Salesman
    , l.Status
    , l.Other

    , ISNULL(cust.PhoneNumber, l.PhoneNumber) AS PhoneNumber
    , cust.EmailId AS Email

    , CONCAT(u.FirstName, '' '', u.LastName) AS SalesmanName

    , l.LocationID

    , fu.FollowUpDate
    , fu.FollowUpComment AS FollowUpLastComment

    , l.LeadSourceId

    , COUNT(1) OVER () AS TotalCount

    , 0 AS RowNum

    , ISNULL
      (
          LKV.LookupValueName,
          ISNULL(l.Other, ''Other'')
      ) AS LeadSourceName

    , l.CustomerId
    , l.LeadNumber
    , u.IsDeleted AS IsSalesmanDeleted

    , BUY.LookupValueName AS BuyingRangeValue
    , l.BuyingRangeValueId

    , l.AlternateMobileNumber
    , l.InquiryAreaRequirement
    , l.AlternateSalesmanId
    , l.ClientMeetingStageId
    , l.ArchitectMeetingStageId
    , l.LeadType

FROM dbo.Leads AS l WITH (NOLOCK)
INNER JOIN dbo.Customers AS cust WITH (NOLOCK)
    ON cust.CustomerId = l.CustomerId
   AND cust.TenantId = @TenantId

LEFT JOIN dbo.LookupValues AS LKV WITH (NOLOCK)
    ON LKV.LookupValueId = l.LeadSourceId

LEFT JOIN dbo.Labels AS lbl WITH (NOLOCK)
    ON lbl.LabelId = l.Priority
   AND lbl.TenantId = @TenantId

LEFT JOIN dbo.AspNetUsers AS u WITH (NOLOCK)
    ON u.UserId = l.SalesmanId


LEFT JOIN dbo.Customers AS custRef WITH (NOLOCK)
    ON custRef.CustomerId = cust.RefferedBy
   AND custRef.TenantId = @TenantId

LEFT JOIN dbo.LookupValues AS BUY WITH (NOLOCK)
    ON BUY.LookupValueId = l.BuyingRangeValueId

OUTER APPLY
(
    SELECT TOP (1)
          f.FollowUpDate
        , f.FollowUpComment
    FROM dbo.FollowUpLeads AS f WITH (NOLOCK)
    WHERE f.LeadId = l.LeadId
    ORDER BY
          f.FollowUpDate DESC
        , f.FollowUpLeadId DESC
) AS fu

WHERE
    l.TenantId = @TenantId

AND EXISTS
(
    SELECT 1
    FROM #UserLocations AS ul
    WHERE ul.LocationID = l.LocationID
)
';


        /* ============================================================
           Status filter

           NULL  -> exclude statuses 5 and 6
           Value -> return only requested status
           ============================================================ */

        IF @StatusId IS NULL
        BEGIN
            SET @SQL += N'
AND l.Status NOT IN (5, 6)';
        END
        ELSE
        BEGIN
            SET @SQL += N'
AND l.Status = @StatusId';
        END;


        /* ============================================================
           Security filter

           Admin / SuperAccess:
               Can see all salesmen.

           Normal user:
               Can only see own leads.
           ============================================================ */

        IF @IsAdmin = 0
           AND @HasSuperAccess = 0
        BEGIN
            SET @SQL += N'
AND l.SalesmanId = @CurrentUserId';
        END;


        /* ============================================================
           Optional filters
           ============================================================ */

        IF @CustomerName IS NOT NULL
        BEGIN
            SET @SQL += N'
AND
(
    ISNULL
    (
        NULLIF
        (
            CONCAT(cust.FirstName, '' '', cust.LastName),
            '' ''
        ),
        CONCAT(l.FirstName, '' '', l.LastName)
    ) LIKE ''%'' + @CustomerName + ''%''
)';
        END;


        IF @SalesmanId IS NOT NULL
           AND @SalesmanId <> -1
        BEGIN
            SET @SQL += N'
AND l.SalesmanId = @SalesmanId';
        END;


        IF @PhoneNumber IS NOT NULL
        BEGIN
            SET @SQL += N'
AND ISNULL(cust.PhoneNumber, l.PhoneNumber)
    LIKE ''%'' + @PhoneNumber + ''%''';
        END;


        IF @InquiryFromDate IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.CreatedDate >= @InquiryFromDate';
        END;


        IF @InquiryToDate IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.CreatedDate < DATEADD(DAY, 1, @InquiryToDate)';
        END;


        IF @FollowUpFromDate IS NOT NULL
        BEGIN
            SET @SQL += N'
AND fu.FollowUpDate >= @FollowUpFromDate';
        END;


        IF @FollowUpToDate IS NOT NULL
        BEGIN
            SET @SQL += N'
AND fu.FollowUpDate < DATEADD(DAY, 1, @FollowUpToDate)';
        END;


        IF @LeadSourceId IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.LeadSourceId = @LeadSourceId';
        END;


        IF @CustomerId IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.CustomerId = @CustomerId';
        END;


        IF @LeadNumber IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.LeadNumber LIKE ''%'' + @LeadNumber + ''%''';
        END;


        IF @PriorityId IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.Priority = @PriorityId';
        END;


        IF @BuyingRangeValueId IS NOT NULL
        BEGIN
            SET @SQL += N'
AND l.BuyingRangeValueId = @BuyingRangeValueId';
        END;


        /* ============================================================
           Ordering + Pagination

           LeadId is used as a deterministic tie-breaker.
           ============================================================ */

        SET @SQL += N'

ORDER BY
      ' + @OrderByExpression + N' ' + @SortDirection + N'
    , l.LeadId DESC

OFFSET
    (@PageNumber - 1) * @PageSize ROWS

FETCH NEXT
    @PageSize ROWS ONLY
;
';


        /* ============================================================
           Parameters
           ============================================================ */

        SET @Params = N'
              @TenantId               INT
            , @CurrentUserId          BIGINT
            , @IsAdmin                BIT
            , @HasSuperAccess         BIT
            , @CustomerName           VARCHAR(200)
            , @StatusId               INT
            , @SalesmanId             BIGINT
            , @PhoneNumber            VARCHAR(50)
            , @InquiryFromDate        DATE
            , @InquiryToDate          DATE
            , @FollowUpFromDate       DATE
            , @FollowUpToDate         DATE
            , @LeadSourceId           BIGINT
            , @CustomerId             BIGINT
            , @LeadNumber             VARCHAR(15)
            , @PriorityId             INT
            , @BuyingRangeValueId     BIGINT
            , @PageNumber             INT
            , @PageSize               INT
';


        /* ============================================================
           Execute
           ============================================================ */

        EXEC sys.sp_executesql
              @SQL
            , @Params
            , @TenantId = @TenantId
            , @CurrentUserId = @CurrentUserId
            , @IsAdmin = @IsAdmin
            , @HasSuperAccess = @HasSuperAccess
            , @CustomerName = @CustomerName
            , @StatusId = @StatusId
            , @SalesmanId = @SalesmanId
            , @PhoneNumber = @PhoneNumber
            , @InquiryFromDate = @InquiryFromDate
            , @InquiryToDate = @InquiryToDate
            , @FollowUpFromDate = @FollowUpFromDate
            , @FollowUpToDate = @FollowUpToDate
            , @LeadSourceId = @LeadSourceId
            , @CustomerId = @CustomerId
            , @LeadNumber = @LeadNumber
            , @PriorityId = @PriorityId
            , @BuyingRangeValueId = @BuyingRangeValueId
            , @PageNumber = @PageNumber
            , @PageSize = @PageSize;


        DROP TABLE #UserLocations;

    END TRY

    BEGIN CATCH

        IF OBJECT_ID('tempdb..#UserLocations') IS NOT NULL
            DROP TABLE #UserLocations;

        DECLARE
            @ObjectName VARCHAR(500) = OBJECT_NAME(@@PROCID),
            @ErrorMsg VARCHAR(MAX) = ERROR_MESSAGE();

        EXEC dbo.SaveDBErrorLog
              @ObjectName = @ObjectName
            , @ErrorMsg = @ErrorMsg;

        THROW;

    END CATCH
END

GO

