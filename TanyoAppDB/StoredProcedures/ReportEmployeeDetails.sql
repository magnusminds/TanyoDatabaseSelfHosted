/*
EXEC [dbo].[ReportEmployeeDetails]
    @TenantId = 1,
    @PageIndex = 1,
    @PageSize = 500,
    @SortBy = 'Departmant',
    @SortOrder = 'ASC';
*/
CREATE   PROCEDURE [dbo].[ReportEmployeeDetails]
(
    @TenantId INT,
    @PageIndex INT = 1,
    @PageSize INT = 100,
    @SortBy VARCHAR(50) = 'EmployeeName',
    @SortOrder VARCHAR(4) = 'ASC'
)
WITH ENCRYPTION
AS
BEGIN  
    SET NOCOUNT ON;  


	BEGIN TRY
    ;WITH EmployeeCTE AS (
        SELECT   
            ed.ProfilePic AS Photo,  
            au.FirstName + ' ' + au.LastName AS EmployeeName,  
            au.UserId,  
            au.PhoneNumber AS PhoneNumber,  
            au.Email AS OfficeEmail,  
            d.Name AS Department,  
            des.Name AS Designation,  
            rt.FirstName + ' ' + rt.LastName AS ReportingTo,  
            ed.DateOfJoining,  

            -- Numeric MMI Experience (in years, 1 decimal)
            CAST(ROUND(
                ISNULL(DATEDIFF(MONTH, ed.DateOfJoining, GETDATE()), 0) / 12.0, 1
            ) AS DECIMAL(5,1)) AS MMIExperienceNumeric,

            -- Numeric Total Experience (in years, 1 decimal)
            CAST(ROUND(
                (
                    ISNULL(DATEDIFF(MONTH, ed.DateOfJoining, GETDATE()), 0) + 
                    ISNULL(ed.JoiningExperienceInMonths, 0)
                ) / 12.0, 1
            ) AS DECIMAL(5,1)) AS TotalExperienceNumeric,

            COUNT(1) OVER() AS TotalCount  
        FROM EmployeeDetails ed WITH (NOLOCK)  
        INNER JOIN AspNetUsers au WITH (NOLOCK) ON ed.UserID = au.UserId  
        LEFT JOIN Departments d WITH (NOLOCK) ON ed.DepartmentID = d.DepartmentID AND d.TenantId = @TenantId  
        LEFT JOIN Designations des WITH (NOLOCK) ON ed.DesignationID = des.DesignationID AND des.TenantId = @TenantId  
        LEFT JOIN AspNetUsers rt WITH (NOLOCK) ON ed.ReportingTo = rt.UserId  
        INNER JOIN UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = au.UserId AND utm.TenantId = @TenantId  
        WHERE utm.TenantId = @TenantId  
		AND ISNULL(au.IsDeleted, 0) = 0
    )

    SELECT 
        Photo,
        EmployeeName,
        UserId,
        PhoneNumber,
        OfficeEmail,
        Department,
        Designation,
        ReportingTo,
        DateOfJoining,
        FORMAT(MMIExperienceNumeric, 'N1') AS MMIExperience,
        FORMAT(TotalExperienceNumeric, 'N1') AS TotalExperience,
        TotalCount
    FROM EmployeeCTE

    ORDER BY   
        CASE WHEN @SortBy = 'EmployeeName' AND @SortOrder = 'ASC' THEN EmployeeName END ASC,  
        CASE WHEN @SortBy = 'EmployeeName' AND @SortOrder = 'DESC' THEN EmployeeName END DESC,  
        CASE WHEN @SortBy = 'PhoneNumber' AND @SortOrder = 'ASC' THEN PhoneNumber END ASC,  
        CASE WHEN @SortBy = 'PhoneNumber' AND @SortOrder = 'DESC' THEN PhoneNumber END DESC,  
        CASE WHEN @SortBy = 'OfficeEmail' AND @SortOrder = 'ASC' THEN OfficeEmail END ASC,  
        CASE WHEN @SortBy = 'OfficeEmail' AND @SortOrder = 'DESC' THEN OfficeEmail END DESC,  
        CASE WHEN @SortBy = 'Department' AND @SortOrder = 'ASC' THEN Department END ASC,  
        CASE WHEN @SortBy = 'Department' AND @SortOrder = 'DESC' THEN Department END DESC,  
        CASE WHEN @SortBy = 'Designation' AND @SortOrder = 'ASC' THEN Designation END ASC,  
        CASE WHEN @SortBy = 'Designation' AND @SortOrder = 'DESC' THEN Designation END DESC,  
        CASE WHEN @SortBy = 'ReportingTo' AND @SortOrder = 'ASC' THEN ReportingTo END ASC,  
        CASE WHEN @SortBy = 'ReportingTo' AND @SortOrder = 'DESC' THEN ReportingTo END DESC,  
        CASE WHEN @SortBy = 'DateOfJoining' AND @SortOrder = 'ASC' THEN DateOfJoining END ASC,  
        CASE WHEN @SortBy = 'DateOfJoining' AND @SortOrder = 'DESC' THEN DateOfJoining END DESC,
        CASE WHEN @SortBy = 'MMIExperience' AND @SortOrder = 'ASC' THEN MMIExperienceNumeric END ASC,
        CASE WHEN @SortBy = 'MMIExperience' AND @SortOrder = 'DESC' THEN MMIExperienceNumeric END DESC,
		CASE WHEN @SortBy = 'TotalExperience' AND @SortOrder = 'ASC' THEN TotalExperienceNumeric END ASC,
        CASE WHEN @SortBy = 'TotalExperience' AND @SortOrder = 'DESC' THEN TotalExperienceNumeric END DESC

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

