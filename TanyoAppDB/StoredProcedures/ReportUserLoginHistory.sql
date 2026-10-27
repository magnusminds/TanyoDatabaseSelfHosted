-- =====================================================================
-- Report   : User Login History (TAN-4500)
-- Purpose  : Who logged in, when, from which IP and source (PORTAL / APP).
--            One row per login record, scoped to the current tenant.
-- Tenant   : via UserTenantMapping (AspNetUsers has no TenantId column).
-- Sort     : CASE-based dynamic sort, default LoginDateTime desc.
-- NOTE     : Returns ONE uniform result set (TotalCount via COUNT(1) OVER()).
-- =====================================================================
CREATE PROCEDURE [dbo].[ReportUserLoginHistory]
    @TenantId INT,
    @FromDate DATETIME = NULL,
    @ToDate DATETIME = NULL,
    @UserId INT = NULL,
    @Source VARCHAR(20) = NULL,
    @PageIndex INT = 1,
    @PageSize INT = 25,
    @SortBy VARCHAR(50) = 'LoginDateTime',
    @SortOrder VARCHAR(4) = 'desc'
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;
    
    BEGIN TRY
        SELECT ulh.LoginHistoryID                                              AS LoginHistoryID
              ,ISNULL(au.UserName, '')                                         AS UserName
              ,au.Email                                                        AS Email
              ,LTRIM(RTRIM(ISNULL(au.FirstName, '') + ' ' + ISNULL(au.LastName, ''))) AS FullName
              ,ISNULL(REPLACE(ar.Name, '_' + CAST(@TenantId AS VARCHAR(20)), ''), '')  AS RoleName
              ,ulh.LoginDateTime                                               AS LoginDateTime
              ,ulh.IPAddress                                                   AS IPAddress
              ,ulh.UserAgent                                                   AS UserAgent
              ,ISNULL(ulh.Source, 'APP')                                       AS Source
              ,COUNT(1) OVER ()                                                AS TotalCount 
        FROM dbo.UserLoginHistory ulh WITH (NOLOCK)
        INNER JOIN AspNetUsers au WITH (NOLOCK)
                ON au.UserId = ulh.UserID
        INNER JOIN dbo.UserTenantMapping utm WITH (NOLOCK)
                ON utm.UserId = au.UserId
               AND utm.TenantId = @TenantId
               AND utm.IsDeleted = 0
        LEFT JOIN AspNetUserRoles ur WITH (NOLOCK)
                ON ur.UserId = au.Id
        LEFT JOIN AspNetRoles ar WITH (NOLOCK)
                ON ar.Id = ur.RoleId
        WHERE (@FromDate IS NULL OR ulh.LoginDateTime >= @FromDate)
          AND (@ToDate   IS NULL OR ulh.LoginDateTime <  DATEADD(DAY, 1, CAST(@ToDate AS DATETIME)))
          AND (@UserId   IS NULL OR ulh.UserID = @UserId)
          AND (@Source   IS NULL OR ISNULL(ulh.Source, 'APP') = @Source)
        ORDER BY
            CASE WHEN @SortBy = 'LoginDateTime' AND @SortOrder = 'asc'  THEN ulh.LoginDateTime END ASC,
            CASE WHEN @SortBy = 'LoginDateTime' AND @SortOrder = 'desc' THEN ulh.LoginDateTime END DESC,
            
            CASE WHEN @SortBy = 'FullName'      AND @SortOrder = 'asc'  THEN LTRIM(RTRIM(ISNULL(au.FirstName, '') + ' ' + ISNULL(au.LastName, ''))) END ASC,
            CASE WHEN @SortBy = 'FullName'      AND @SortOrder = 'desc' THEN LTRIM(RTRIM(ISNULL(au.FirstName, '') + ' ' + ISNULL(au.LastName, ''))) END DESC,
            
            CASE WHEN @SortBy = 'UserName'      AND @SortOrder = 'asc'  THEN ISNULL(au.UserName, '')  END ASC,
            CASE WHEN @SortBy = 'UserName'      AND @SortOrder = 'desc' THEN ISNULL(au.UserName, '')  END DESC,
            
            CASE WHEN @SortBy = 'RoleName'      AND @SortOrder = 'asc'  THEN ISNULL(REPLACE(ar.Name, '_' + CAST(@TenantId AS VARCHAR(20)), ''), '') END ASC,
            CASE WHEN @SortBy = 'RoleName'      AND @SortOrder = 'desc' THEN ISNULL(REPLACE(ar.Name, '_' + CAST(@TenantId AS VARCHAR(20)), ''), '') END DESC,
            
            CASE WHEN @SortBy = 'IPAddress'     AND @SortOrder = 'asc'  THEN ulh.IPAddress END ASC,
            CASE WHEN @SortBy = 'IPAddress'     AND @SortOrder = 'desc' THEN ulh.IPAddress END DESC,
            
            CASE WHEN @SortBy = 'UserAgent'     AND @SortOrder = 'asc'  THEN ulh.UserAgent END ASC,
            CASE WHEN @SortBy = 'UserAgent'     AND @SortOrder = 'desc' THEN ulh.UserAgent END DESC,
            
            CASE WHEN @SortBy = 'Source'        AND @SortOrder = 'asc'  THEN ISNULL(ulh.Source, 'APP') END ASC,
            CASE WHEN @SortBy = 'Source'        AND @SortOrder = 'desc' THEN ISNULL(ulh.Source, 'APP') END DESC,
            ulh.LoginDateTime DESC
            
        OFFSET (@PageIndex - 1) * @PageSize ROWS FETCH NEXT @PageSize ROWS ONLY;
        
    END TRY
    BEGIN CATCH
    		DECLARE @ObjectName VARCHAR(500)
    			,@ErrorMsg VARCHAR(MAX);
    
    		SET @ObjectName = OBJECT_NAME(@@PROCID);
    		SET @ErrorMsg = ERROR_MESSAGE();
    
    		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
    			,@ErrorMsg = @ErrorMsg;
    END CATCH
END;

GO

