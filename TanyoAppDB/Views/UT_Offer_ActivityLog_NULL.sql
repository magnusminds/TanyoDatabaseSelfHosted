-- SELECT * FROM [dbo].[UT_Offer_ActivityLog_NULL]

CREATE VIEW [dbo].[UT_Offer_ActivityLog_NULL]
WITH ENCRYPTION
AS
    SELECT
        'ActivityLogs - Description IS NULL' AS TableName,
        st.TenantId,
        COUNT(1) AS TotalCount
    FROM ActivityLogs al WITH (NOLOCK)
    INNER JOIN SubjectTypes st WITH (NOLOCK)
        ON al.SubjectTypeId = st.SubjectTypeId
    WHERE st.SubjectTypeName = 'Offer'
        AND al.Description IS NULL
    GROUP BY st.TenantId
    HAVING COUNT(1) > 0;

GO