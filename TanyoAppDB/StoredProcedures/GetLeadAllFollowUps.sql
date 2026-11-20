/*
    EXEC GetLeadAllFollowUps
        @TenantId = 2
        ,@FromDate = NULL
        ,@ToDate = NULL
        ,@CustomerId = 1
        ,@LeadId = NULL
*/
CREATE   PROCEDURE [dbo].[GetLeadAllFollowUps]
(
    @TenantId INT
    ,@FromDate DATE = NULL
    ,@ToDate DATE = NULL
    ,@CustomerId BIGINT = NULL
    ,@LeadId BIGINT = NULL
)
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
    SELECT @ToDate = DATEADD(DAY, 1, @ToDate)

    ;WITH RankedFollowUps AS (
        SELECT l.LeadId
            ,l.CustomerId
            ,ISNULL(ISNULL(c.FirstName,'') + ' ' + ISNULL(c.LastName,''), ISNULL(l.FirstName,'') + ' ' + ISNULL(l.LastName,'')) AS CustomerName
            ,CONVERT(VARCHAR(50),f.CreatedDate, 101)
		        + '<BR> ' 
		        + ISNULL(CONVERT(VARCHAR(50),f.FollowUpDate, 101),'')
		        + '<BR> ' 
		        + ISNULL(f.FollowUpComment,'') as Followup
            ,REPLACE(l.InquiryFor, ',', ',<BR>') AS InquiryFor
            ,l.Notes AS Notes
            ,ROW_NUMBER() OVER (PARTITION BY l.LeadId ORDER BY f.CreatedDate DESC) AS rn
        FROM Leads l WITH (NOLOCK)
        INNER JOIN FollowUpLeads f WITH (NOLOCK) ON f.LeadId = l.LeadId
        LEFT JOIN Customers c WITH (NOLOCK) ON c.CustomerId = l.CustomerId
        WHERE l.TenantId = @TenantId
        AND (@FromDate IS NULL OR f.CreatedDate >= @FromDate)
        AND (@ToDate IS NULL OR f.CreatedDate < @ToDate)
        AND (@LeadId IS NULL OR l.LeadId = @LeadId)
        AND (@CustomerId IS NULL OR c.CustomerId = @CustomerId)
    ),
    PivotDates AS (
        SELECT LeadId, CustomerId, CustomerName, Notes, InquiryFor, 
               [1] AS FollowUpDetail1,
               [2] AS FollowUpDetail2,
               [3] AS FollowUpDetail3,
               [4] AS FollowUpDetail4,
               [5] AS FollowUpDetail5,
               [6] AS FollowUpDetail6,
               [7] AS FollowUpDetail7,
               [8] AS FollowUpDetail8,
               [9] AS FollowUpDetail9,
               [10] AS FollowUpDetail10
        FROM (
            SELECT LeadId, CustomerId, CustomerName, rn, Followup, Notes, InquiryFor
            FROM RankedFollowUps
        ) src
        PIVOT (
            MAX(Followup) FOR rn IN ([1], [2], [3], [4], [5], [6], [7], [8], [9], [10])
        ) fdate
	)
    SELECT LeadId
        ,CustomerName
        ,Notes
        ,InquiryFor
        ,FollowUpDetail1
        ,FollowUpDetail2
        ,FollowUpDetail3
        ,FollowUpDetail4
        ,FollowUpDetail5
        ,FollowUpDetail6
        ,FollowUpDetail7
        ,FollowUpDetail8
        ,FollowUpDetail9
        ,FollowUpDetail10
    FROM PivotDates
    ORDER BY 1 DESC

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

