-- =============================================  
--Author		: MagnusMinds
--Create date	: 08-09-2023
--Description	: Report - OrderNotificationLogs Report
-- =============================================
/*
	EXEC [dbo].[ReportOrderInquiry]
		@FromDate = '2024-01-01'
		,@ToDate = '2024-08-16' 
		,@OrderNo = '8281'
		,@CustomerName = ''
		,@TenantId = 1
		,@PageIndex = 1
		,@PageSize = 500
		,@SortBy = 'CreatedDate' 
		,@SortOrder = 'DESC'
*/

CREATE   PROCEDURE [dbo].[ReportOrderInquiry] (
	@FromDate DATETIME
	,@ToDate DATETIME
	,@OrderNo VARCHAR(100) = NULL
	,@CustomerName VARCHAR(100) = NULL
	,@TenantId INT = 0
	,@PageIndex INT = 1
	,@PageSize INT = 100
	,@SortBy VARCHAR(50) = 'CreatedDate'
	,@SortOrder VARCHAR(50) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		SELECT TRIM(CONCAT(c.FirstName, ' ', ISNULL(c.LastName, ''))) AS CustomerName
			,o.OrderNo AS OrderNo
			,o.OrderId AS OrderId
			,OAV.IPAddress AS IPAddress
			,OAV.BrowserName AS BrowserName
			,CAST(OAV.CreatedDate AS DATETIME) AS CreatedDatewithTime
			,COUNT(1) OVER (PARTITION BY 1) AS TotalCount
		FROM OrderAnonymousViews OAV 
		INNER JOIN Orders O ON OAV.OrderId = O.OrderId
                    AND o.Status = 0
		INNER JOIN Customers C ON O.CustomerID = C.CustomerID
		WHERE o.TenantId = @TenantId
			AND CAST(OAV.CreatedDate AS DATE) BETWEEN CAST(@FromDate AS DATE)
				AND CAST(@ToDate AS DATE)
			AND (
				ISNULL(@OrderNo, '') = ''
				OR o.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				ISNULL(@CustomerName, '') = ''
				OR TRIM(CONCAT(c.FirstName, ' ', ISNULL(c.LastName, ''))) LIKE '%' + @CustomerName + '%'
				)
		ORDER BY CASE 
				WHEN @SortBy = 'CreatedDate'
					AND @SortOrder = 'ASC'
					THEN OAV.CreatedDate
				END ASC
			,CASE 
				WHEN @SortBy = 'CreatedDate'
					AND @SortOrder = 'DESC'
					THEN OAV.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'ASC'
					THEN O.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'OrderNo'
					AND @SortOrder = 'DESC'
					THEN O.OrderNo
                END DESC
            ,CASE 
				WHEN @SortBy = 'BrowserName'
					AND @SortOrder = 'ASC'
					THEN O.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'BrowserName'
					AND @SortOrder = 'DESC'
					THEN O.OrderNo
	            END ASC
			,CASE 
				WHEN @SortBy = 'IPAddress'
					AND @SortOrder = 'ASC'
					THEN O.OrderNo
				END ASC
			,CASE 
				WHEN @SortBy = 'IPAddress'
					AND @SortOrder = 'DESC'
					THEN O.OrderNo
            END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName' AND @SortOrder = 'ASC'
					THEN TRIM(CONCAT(c.FirstName, ' ', ISNULL(c.LastName, ''))) 
			END ASC
			,CASE 
				WHEN @SortBy = 'CustomerName' AND @SortOrder = 'DESC'
					THEN TRIM(CONCAT(c.FirstName, ' ', ISNULL(c.LastName, ''))) 
			END DESC

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

