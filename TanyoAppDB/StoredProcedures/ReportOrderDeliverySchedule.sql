CREATE PROCEDURE [dbo].[ReportOrderDeliverySchedule] (  
 @TenantId INT  
 ,@FromDate DATE  
 ,@ToDate DATE  
 ,@OrderNo VARCHAR(50) = NULL  
 ,@SalesmanName BIGINT = NULL  
 ,@CustomerName VARCHAR(50) = NULL  
 ,@PhoneNumber VARCHAR(50) = NULL  
 ,@ReminderType VARCHAR(50) = NULL  
 ,@PageIndex INT = 1  
 ,@PageSize INT = 100  
 ,@SortBy VARCHAR(50) = 'TentativeDeliveryDate'  
 ,@SortOrder VARCHAR(50) = 'DESC'  
 )  
WITH ENCRYPTION
AS
BEGIN  
 SET NOCOUNT ON;  
  
 BEGIN TRY  
  DECLARE @CurrentDate DATE = GETDATE()  
  
  SELECT OrderId  
   ,OrderNo  
   ,CustomerName  
   ,PhoneNumber  
   ,CreatedByName  
   ,TentativeDeliveryDate  
   ,ReminderType  
   ,SalesmanId  
   ,COUNT(1) OVER (PARTITION BY 1) AS TotalCount  
  FROM (  
   SELECT o.OrderId  
    ,o.OrderNo  
    ,CONCAT(a.FirstName,' ',a.LastName + CASE WHEN a.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END) AS CreatedByName  
    ,CONCAT(cust.FirstName,' ',cust.LastName) AS CustomerName  
    ,cust.PhoneNumber  
    ,o.TentativeDeliveryDate  
    ,a.UserId AS SalesmanId  
    ,'Upcoming' AS ReminderType  
    ,o.TenantId  
   FROM [dbo].[Orders] AS o WITH (NOLOCK)  
   INNER JOIN [dbo].[Customers] AS cust WITH (NOLOCK) ON o.CustomerID = cust.CustomerId  
   INNER JOIN [dbo].[AspNetUsers] AS a WITH (NOLOCK) ON o.CreatedBy = a.UserId  
   WHERE o.TenantId = @TenantId  
   AND o.TentativeDeliveryDate >= @CurrentDate  
   AND (o.Status = 2 OR o.Status= 3) --Approved, Inprogress  
   AND o.DeliveryDate IS NULL  
     
   UNION ALL  
     
   SELECT o.OrderId  
    ,o.OrderNo  
    ,CONCAT(a.FirstName,' ',a.LastName + CASE WHEN a.IsDeleted = 1 THEN ' (Inactive)' ELSE '' END) AS CreatedByName  
    ,CONCAT(cust.FirstName,' ',cust.LastName) AS CustomerName  
    ,cust.PhoneNumber  
    ,o.TentativeDeliveryDate  
    ,a.UserId AS SalesmanId  
    ,'Overdue' AS ReminderType  
    ,o.TenantId  
   FROM [dbo].[Orders] AS o WITH (NOLOCK)  
   INNER JOIN [dbo].[Customers] AS cust WITH (NOLOCK) ON o.CustomerID = cust.CustomerId  
   INNER JOIN [dbo].[AspNetUsers] AS a WITH (NOLOCK) ON o.CreatedBy = a.UserId  
   WHERE cust.TenantId = @TenantId  
   AND o.TentativeDeliveryDate <= DATEADD(DAY, - 1, @CurrentDate)  
   AND (o.Status = 2 OR o.Status= 3) --Approved, Inprogress  
   AND o.DeliveryDate IS NULL  
   ) AS DeliveryData  
   WHERE (TentativeDeliveryDate BETWEEN @FromDate AND @ToDate)  
   AND (  
    ISNULL(@OrderNo, '') = ''  
    OR OrderNo LIKE '%' + @OrderNo + '%'  
    )  
   AND (  
    ISNULL(@SalesmanName, '') = '-1'  
    OR SalesmanId =  @SalesmanName  
    )  
   AND (  
    ISNULL(@CustomerName, '') = ''  
    OR CustomerName LIKE '%' + @CustomerName + '%'  
    )  
   AND (  
    ISNULL(@PhoneNumber, '') = ''  
    OR PhoneNumber LIKE '%' + @PhoneNumber + '%'  
    )  
   AND (  
    ISNULL(@ReminderType, '') = '-1'  
    OR ReminderType = @ReminderType  
    )  
   ORDER BY CASE WHEN @SortBy = 'TentativeDeliveryDate' AND @SortOrder = 'ASC' THEN TentativeDeliveryDate END ASC  
   ,CASE WHEN @SortBy = 'TentativeDeliveryDate' AND @SortOrder = 'DESC' THEN TentativeDeliveryDate END DESC  
   ,CASE WHEN @SortBy = 'OrderId' AND @SortOrder = 'ASC' THEN OrderId END ASC  
   ,CASE WHEN @SortBy = 'OrderId' AND @SortOrder = 'DESC' THEN OrderId END DESC  
   ,CASE WHEN @SortBy = 'OrderNumber' AND @SortOrder = 'ASC' THEN OrderNo END ASC  
   ,CASE WHEN @SortBy = 'OrderNumber' AND @SortOrder = 'DESC' THEN OrderNo END DESC  
   ,CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC' THEN CustomerName END ASC  
   ,CASE WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC' THEN CustomerName END DESC  
   ,CASE WHEN @SortBy = 'PhoneNumber' AND @SortOrder = 'ASC' THEN PhoneNumber END ASC  
   ,CASE WHEN @SortBy = 'PhoneNumber' AND @SortOrder = 'DESC' THEN PhoneNumber END DESC  
   ,CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'ASC' THEN CreatedByName END ASC  
   ,CASE WHEN @SortBy = 'SalesmanName' AND @SortOrder = 'DESC' THEN CreatedByName END DESC  
   ,CASE WHEN @SortBy = 'ReminderType' AND @SortOrder = 'ASC' THEN ReminderType END ASC  
   ,CASE WHEN @SortBy = 'ReminderType' AND @SortOrder = 'DESC' THEN ReminderType END DESC   
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

