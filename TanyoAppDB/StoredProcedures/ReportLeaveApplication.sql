
/*  
 EXEC [dbo].[ReportLeaveApplication]  
  @TenantId = 1  
  ,@StartDate = '2023-01-01'  
  ,@EndDate = '2024-12-31'  
  ,@UserID = NULL  
  ,@LeaveCategoryID = NULL  
  ,@PageIndex = 1  
  ,@PageSize = 100  
  ,@SortBy = 'LeaveDate'  
  ,@SortOrder = 'ASC'  
*/
CREATE PROCEDURE [dbo].[ReportLeaveApplication] (
	@TenantId INT
	,@UserID INT = NULL
	,@LeaveCategoryID INT = NULL
	,@StartDate DATE
	,@EndDate DATE
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'LeaveDate'
	,@SortOrder VARCHAR(50) = 'ASC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT la.UserID
		,au.FirstName + ' ' + au.LastName AS UserName
		,au.PhoneNumber AS PhoneNumber
		,lc.LeaveCategoryID
		,lc.Name AS LeaveCategory
		,lad.LeaveDate
		,lad.LeaveType AS [LeaveTypeInt]
		,CAST(lad.LeaveType AS VARCHAR) AS [LeaveType]
		,aua.FirstName + ' ' + aua.LastName [ApprovedBy]
		,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
	FROM [dbo].[LeaveApplications] AS la WITH (NOLOCK)
	INNER JOIN [dbo].[LeaveApplicationDetails] lad WITH (NOLOCK) ON lad.LeaveApplicationID = la.LeaveApplicationID
		AND lad.LeaveDate BETWEEN @StartDate
			AND @EndDate
	INNER JOIN [dbo].[LeaveCategory] AS lc WITH (NOLOCK) ON la.LeaveCategoryID = lc.LeaveCategoryID
		AND lc.TenantId = @TenantId
	INNER JOIN [dbo].[AspNetUsers] AS au WITH (NOLOCK) ON au.UserId = la.UserID
	INNER JOIN [dbo].[AspNetUsers] AS aua WITH (NOLOCK) ON aua.UserId = la.ApprovedBy
	INNER JOIN [dbo].[UserTenantMapping] utm WITH (NOLOCK) ON utm.UserId = au.UserId
		AND utm.TenantId = @TenantId
	WHERE utm.TenantId = @TenantId
		AND la.STATUS = 2
		AND lad.LeaveDate >= @StartDate
		AND lad.LeaveDate <= @EndDate
		AND (
			@UserID IS NULL
			OR la.UserID = @UserID
			)
		AND (
			@LeaveCategoryID IS NULL
			OR la.LeaveCategoryID = @LeaveCategoryID
			)
	ORDER BY CASE 
			WHEN @SortBy = 'LeaveDate'
				AND @SortOrder = 'ASC'
				THEN lad.LeaveDate
			END ASC
		,CASE 
			WHEN @SortBy = 'LeaveDate'
				AND @SortOrder = 'DESC'
				THEN lad.LeaveDate
			END DESC
		,CASE 
			WHEN @SortBy = 'EmployeeName'
				AND @SortOrder = 'ASC'
				THEN au.UserName
			END ASC
		,CASE 
			WHEN @SortBy = 'EmployeeName'
				AND @SortOrder = 'DESC'
				THEN au.UserName
			END DESC
		,CASE 
			WHEN @SortBy = 'PhoneNumber'
				AND @SortOrder = 'ASC'
				THEN au.PhoneNumber
			END ASC
		,CASE 
			WHEN @SortBy = 'PhoneNumber'
				AND @SortOrder = 'DESC'
				THEN au.PhoneNumber
			END DESC
		,CASE 
			WHEN @SortBy = 'LeaveCategory'
				AND @SortOrder = 'ASC'
				THEN lc.Name
			END ASC
		,CASE 
			WHEN @SortBy = 'LeaveCategory'
				AND @SortOrder = 'DESC'
				THEN lc.Name
			END DESC
		,CASE 
			WHEN @SortBy = 'LeaveType'
				AND @SortOrder = 'ASC'
				THEN lad.LeaveType
			END ASC
		,CASE 
			WHEN @SortBy = 'LeaveType'
				AND @SortOrder = 'DESC'
				THEN lad.LeaveType
			END DESC
		,CASE 
			WHEN @SortBy = 'ApprovedBy'
				AND @SortOrder = 'ASC'
				THEN aua.FirstName + ' ' + aua.LastName
			END ASC
		,CASE 
			WHEN @SortBy = 'ApprovedBy'
				AND @SortOrder = 'DESC'
				THEN aua.FirstName + ' ' + aua.LastName
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

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

