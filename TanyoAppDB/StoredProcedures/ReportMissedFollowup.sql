/*  
====================================================================  
Missed Follow-up Report  
====================================================================  

EXEC [dbo].[ReportMissedFollowup]
    ,@TenantId = 2
    ,@FromDate = '2026-04-01'
    ,@ToDate = '2026-04-30'
    ,@OrderNo = NULL
    ,@CustomerId = NULL
    ,@SalesmanId = NULL
    ,@PageIndex = 1
    ,@PageSize = 50
    ,@SortBy = 'FollowUpDate'
    ,@SortOrder = 'DESC'

====================================================================  
*/

CREATE PROCEDURE [dbo].[ReportMissedFollowup]
(
    @TenantId INT
    ,@FromDate DATETIME
    ,@ToDate DATETIME
    ,@OrderNo VARCHAR(100) = NULL
    ,@CustomerId BIGINT = NULL
    ,@SalesmanId BIGINT = NULL
    ,@PageIndex INT = 1
    ,@PageSize INT = 50
    ,@SortBy VARCHAR(50) = 'FollowUpDate'
    ,@SortOrder VARCHAR(50) = 'DESC'
)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;

    BEGIN TRY

        ;WITH LatestFollowUp AS (
            SELECT 
                FO.*
                ,ROW_NUMBER() OVER (PARTITION BY FO.OrderId ORDER BY FO.FollowUpDate DESC) AS RN
            FROM FollowUpOrders FO
        )
        ,AllActivity AS (
            -- Comments / Remarks
            SELECT 
                OC.OrderId
                ,OC.CreatedDate AS ActivityDate
            FROM OrderComments OC
            WHERE ISNULL(OC.Comments, '') <> '' 
               OR ISNULL(OC.Remarks, '') <> ''

            UNION ALL

            -- Attachments
            SELECT 
                OA.OrderId
                ,OA.CreatedDate
            FROM OrderAttachments OA
            WHERE OA.FileType IN ('Audio','Image')
        )

        SELECT 
            O.OrderNo
            ,O.OrderId
            ,O.Status AS OrderStatus
            ,LA.LastCommentDate
            ,FO.FollowUpDate
            ,FO.FollowUpComment
            ,ROUND(O.AmountBeforeGST, 0) AS InquiryAmount
            ,C.FirstName + ' ' + ISNULL(C.LastName, '') AS CustomerName
            ,C.CustomerId
            ,AU.FirstName + ' ' + ISNULL(AU.LastName, '') 
                + CASE WHEN AU.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END AS SalesmanName
            ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
        FROM LatestFollowUp FO WITH(NOLOCK)
        INNER JOIN Orders O WITH(NOLOCK)
            ON FO.OrderId = O.OrderId
            AND FO.RN = 1
        INNER JOIN Customers C WITH(NOLOCK)
            ON O.CustomerID = C.CustomerId
        LEFT JOIN AspNetUsers AU WITH(NOLOCK)
            ON O.SalesmanId = AU.UserId
        -- 🔹 Last activity BEFORE follow-up
        OUTER APPLY (
            SELECT MAX(A.ActivityDate) AS LastCommentDate
            FROM AllActivity A WITH(NOLOCK)
            WHERE A.OrderId = FO.OrderId
              AND A.ActivityDate < FO.FollowUpDate
        ) LA
        WHERE 
            O.TenantId = @TenantId
            AND O.Status <> 9

            -- Date filter
            AND CAST(FO.FollowUpDate AS DATE) BETWEEN CAST(@FromDate AS DATE)
                AND CAST(@ToDate AS DATE)

            -- Only past follow-ups
            AND FO.FollowUpDate < GETDATE()

            -- ❗ Missed logic
            AND NOT EXISTS (
                SELECT 1
                FROM AllActivity A
                WHERE A.OrderId = FO.OrderId
                  AND A.ActivityDate >= FO.FollowUpDate
            )

            -- Filters
            AND (
                ISNULL(@OrderNo, '') = ''
                OR O.OrderNo LIKE '%' + @OrderNo + '%'
            )
            AND (
                ISNULL(@CustomerId, 0) = 0
                OR C.CustomerId = @CustomerId
            )
            AND (
                ISNULL(@SalesmanId, 0) = 0
                OR AU.UserId = @SalesmanId
            )

        ORDER BY 
            CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'ASC' THEN O.OrderNo END ASC,
            CASE WHEN @SortBy = 'OrderNo' AND @SortOrder = 'DESC' THEN O.OrderNo END DESC,

            CASE WHEN @SortBy = 'OrderStatus' AND @SortOrder = 'ASC' THEN O.Status END ASC,
            CASE WHEN @SortBy = 'OrderStatus' AND @SortOrder = 'DESC' THEN O.Status END DESC,

            CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN (C.FirstName + ' ' + ISNULL(C.LastName, '')) END ASC,
            CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN (C.FirstName + ' ' + ISNULL(C.LastName, '')) END DESC,

            CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'ASC' THEN 
                AU.FirstName + ' ' + ISNULL(AU.LastName, '') 
                + CASE WHEN AU.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END
            END ASC,
            CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'DESC' THEN 
                AU.FirstName + ' ' + ISNULL(AU.LastName, '') 
                + CASE WHEN AU.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END
            END DESC,

            CASE WHEN @SortBy = 'InquiryAmount' AND @SortOrder = 'ASC' THEN O.AmountBeforeGST END ASC,
            CASE WHEN @SortBy = 'InquiryAmount' AND @SortOrder = 'DESC' THEN O.AmountBeforeGST END DESC,

            CASE WHEN @SortBy = 'LastCommentDate' AND @SortOrder = 'ASC' THEN LA.LastCommentDate END ASC,
            CASE WHEN @SortBy = 'LastCommentDate' AND @SortOrder = 'DESC' THEN LA.LastCommentDate END DESC,

            CASE WHEN @SortBy = 'FollowUpDate' AND @SortOrder = 'ASC' THEN FO.FollowUpDate END ASC,
            CASE WHEN @SortBy = 'FollowUpDate' AND @SortOrder = 'DESC' THEN FO.FollowUpDate END DESC

        OFFSET(@PageIndex - 1) * @PageSize ROWS
        FETCH NEXT @PageSize ROWS ONLY;

    END TRY

    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000)
        DECLARE @ErrorSeverity INT
        DECLARE @ErrorState INT

        SELECT 
            @ErrorMessage = ERROR_MESSAGE()
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

