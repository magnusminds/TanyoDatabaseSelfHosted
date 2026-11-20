
-- =============================================
-- Author:  MagnusMinds
-- Create date: 22-Jul-2025
-- Description: Get count of Orders which are in TotalComplain status
-- =============================================
/*
--Admin
EXEC Dashboard_GetInquiryCount
 @TenantId = 2,
 @CurrentUserId = 4328,
 @RoleId = '555D131D-3306-40AC-9A7B-6CBDA78A1C2F'

--SalesRepresentative
EXEC Dashboard_GetInquiryCount
 @TenantId = 2,
 @CurrentUserId = 4386,
 @RoleId = '17BE52F0-731D-4215-9CA3-021C068A9F6F'
*/ 
CREATE   PROCEDURE [dbo].[Dashboard_GetInquiryCount]
    @TenantId INT,
    @CurrentUserId INT,
    @RoleId NVARCHAR(100)
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    DECLARE @IsAdmin BIT = 0,
            @HasSuperAccess BIT = 0;

    IF EXISTS (
        SELECT 1 FROM AspNetRoles WHERE Id = @RoleId AND [Name] = 'Administrator_' + CAST(@TenantId AS VARCHAR(5))
    )
        SET @IsAdmin = 1;

    IF EXISTS (
        SELECT 1 FROM AspNetRoleClaims
        WHERE RoleId = @RoleId AND [ClaimValue] = 'Permissions.App.Lead.SuperAccess'
    )
        SET @HasSuperAccess = 1;

    -- Temporary table to hold user location mapping
    CREATE TABLE #UserLocations (AutoID INT IDENTITY PRIMARY KEY, LocationID INT);

    INSERT INTO #UserLocations(LocationID)
    SELECT LocationID
    FROM LocationUserMapping (NOLOCK)
    WHERE UserId = @CurrentUserId

    -- Final count query
    SELECT COUNT(1) AS StatusCount
    FROM Leads l (NOLOCK)
    INNER JOIN #UserLocations ul ON l.LocationID = ul.LocationID
    WHERE l.Status != 5 -- Closed
      AND l.Status != 6 -- Deleted
	  AND l.TenantId = @TenantId
      AND (
            @IsAdmin = 1 OR
            @HasSuperAccess = 1 OR
            l.SalesmanId = @CurrentUserId
          );

    DROP TABLE #UserLocations;

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

