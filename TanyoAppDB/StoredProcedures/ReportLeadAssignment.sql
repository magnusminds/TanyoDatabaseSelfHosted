CREATE PROCEDURE [dbo].[ReportLeadAssignment] (  
 @TenantId INT  
 ,@SalemanId BIGINT = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 100  
 ,@SortBy VARCHAR(50) = 'SalesmanName'  
 ,@SortOrder VARCHAR(50) = 'ASC'  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  SELECT au.UserId AS SalesmanId  
   ,au.FirstName + ' ' + au.LastName  + CASE WHEN au.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END  AS SalesmanName  
   ,COUNT(il.LeadId) AS TotalLeads  
   ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
  FROM [dbo].[LeadLogs] AS il WITH (NOLOCK)  
  INNER JOIN [dbo].[Leads] AS i WITH (NOLOCK) ON i.LeadId = il.LeadId  
   AND i.TenantId = @TenantId  
  INNER JOIN [dbo].[AspNetUsers] AS au WITH (NOLOCK) ON il.SalesmanId = au.UserId  
  WHERE il.CreatedDate = (  
    SELECT MAX(il2.CreatedDate)  
    FROM [dbo].[LeadLogs] AS il2 WITH (NOLOCK)  
    WHERE il2.LeadId = il.LeadId  
    )  
  AND (@SalemanId IS NULL OR au.UserId = @SalemanId)  
  GROUP BY au.UserId  
   ,au.FirstName + ' ' + au.LastName,
   au.IsDeleted
  ORDER BY   
   CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'ASC' THEN au.FirstName + ' ' + au.LastName END ASC  
   ,CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'DESC' THEN au.FirstName + ' ' + au.LastName END DESC  
   ,CASE WHEN @SortBy = 'TotalLeads' AND @SortOrder = 'ASC' THEN COUNT(il.LeadId) END ASC  
   ,CASE WHEN @SortBy = 'TotalLeads' AND @SortOrder = 'DESC' THEN COUNT(il.LeadId) END DESC   
  OFFSET(@PageIndex - 1) * @PageSize ROWS  
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

