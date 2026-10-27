/*
EXEC [dbo].[ReportCustomerFeedback]
     @TenantId = 1206,
     @OrderNo = NULL,
     @SalesmanId = NULL,
     @CustomerName = NULL,
     @PhoneNo = NULL,
     @RatingFromDate = NULL,
     @RatingToDate = NULL,
     @RatingStatus = NULL,
     @SortBy = 'RatingDate',
     @SortOrder = 'DESC',
     @PageIndex = 1,
     @PageSize = 100;
*/
CREATE PROCEDURE [dbo].[ReportCustomerFeedback] 
     @TenantId BIGINT 
    ,@OrderNo NVARCHAR(100) = NULL
	,@SalesmanId BIGINT = NULL
	,@CustomerName NVARCHAR(100) = NULL
	,@PhoneNo NVARCHAR(16) = NULL
	,@RatingFromDate DATETIME = NULL
	,@RatingToDate DATETIME = NULL
	,@RatingStatus DECIMAL(18, 2) = NULL
	,@SortBy VARCHAR(50) = 'RatingDate'
	,@SortOrder VARCHAR(4) = 'ASC'
	,@PageIndex INT = 1
	,@PageSize INT = 100

WITH ENCRYPTION
AS
BEGIN
	BEGIN TRY
		SET NOCOUNT ON;

		SELECT O.OrderId
			,O.OrderNo AS Ordernumber
			,ISNULL(O.SalesmanId, 0) AS SalesmanId
			,LTRIM(RTRIM(CONCAT (
						U.FirstName
						,' '
						,U.LastName
						,CASE 
							WHEN U.IsDeleted = 1
								THEN ' (Inactive)'
							ELSE ''
							END
						))) AS SalesmanName
			,LTRIM(RTRIM(CONCAT (
						C.FirstName
						,' '
						,C.LastName
						))) AS CustomerName
			,C.PhoneNumber
			,CAST(ROUND(AVG(CAST(FO.FeedbackValue AS DECIMAL(18, 2))), 2) AS DECIMAL(18, 2)) AS Rating
			,MIN(FO.CreatedDate) AS RatingDate
			,ISNULL(MAX(FC.Comment), '') AS comments
			,ISNULL((
				SELECT FO_Sub.OrderId
					,FQ_Sub.QuestionTitle AS QuestionName
					,FO_Sub.FeedbackValue AS QuestionRating
				FROM FeedbackOrders FO_Sub WITH (NOLOCK)
				INNER JOIN FeedbackQuestions FQ_Sub WITH (NOLOCK) ON FQ_Sub.FeedbackQuestionId = FO_Sub.FeedbackQuestionId
				WHERE FO_Sub.OrderId = O.OrderId
				FOR JSON PATH
				), '[]') AS RatingQuestions
			,ISNULL((
				SELECT FUO.FollowUpOrdersId
					,FUO.OrderId
					,CONVERT(VARCHAR(19), FUO.FollowUpDate, 120) AS FollowUpDate
					,FUO.FollowUpComment
				FROM FollowUpOrders FUO WITH (NOLOCK)
				WHERE FUO.OrderId = O.OrderId
				FOR JSON PATH
				), '[]') AS RatingDatashowData
			,COUNT(1) OVER () AS TotalCount
		FROM Orders O WITH (NOLOCK)
		INNER JOIN FeedbackOrders FO WITH (NOLOCK) ON FO.OrderId = O.OrderId
		LEFT JOIN Customers C WITH (NOLOCK) ON C.CustomerId = O.CustomerID
		LEFT JOIN AspNetUsers U WITH (NOLOCK) ON U.UserId = O.SalesmanId
		LEFT JOIN FeedbackComments FC WITH (NOLOCK) ON FC.OrderId = O.OrderId
		WHERE O.TenantId = @TenantId
		    AND (
				@OrderNo IS NULL
				OR @OrderNo = ''
				OR O.OrderNo LIKE '%' + @OrderNo + '%'
				)
			AND (
				@SalesmanId IS NULL
				OR @SalesmanId = 0
				OR O.SalesmanId = @SalesmanId
				)
			AND (
				@CustomerName IS NULL
				OR @CustomerName = ''
				OR CONCAT (
					C.FirstName
					,' '
					,C.LastName
					) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@PhoneNo IS NULL
				OR @PhoneNo = ''
				OR C.PhoneNumber LIKE '%' + @PhoneNo + '%'
				)
		GROUP BY O.OrderId
			,O.OrderNo
			,O.SalesmanId
			,U.FirstName
			,U.LastName
			,U.IsDeleted
			,C.FirstName
			,C.LastName
			,C.PhoneNumber
		HAVING (
				@RatingFromDate IS NULL
				OR CAST(MIN(FO.CreatedDate) AS DATE) >= CAST(@RatingFromDate AS DATE)
				)
			AND (
				@RatingToDate IS NULL
				OR CAST(MIN(FO.CreatedDate) AS DATE) <= CAST(@RatingToDate AS DATE)
				)
			AND (
				@RatingStatus IS NULL
				OR @RatingStatus = 0
				OR (
					CAST(ROUND(AVG(CAST(FO.FeedbackValue AS DECIMAL(18, 2))), 2) AS DECIMAL(18, 2)) >= @RatingStatus
					AND CAST(ROUND(AVG(CAST(FO.FeedbackValue AS DECIMAL(18, 2))), 2) AS DECIMAL(18, 2)) <= @RatingStatus + 0.99
					)
				)
		ORDER BY CASE 
				WHEN @SortOrder = 'ASC'
					AND @SortBy = 'OrderNo'
					THEN O.OrderNo
				END ASC
			,CASE 
				WHEN @SortOrder = 'DESC'
					AND @SortBy = 'OrderNo'
					THEN O.OrderNo
				END DESC
			,CASE 
				WHEN @SortOrder = 'ASC'
					AND @SortBy = 'SalesmanName'
					THEN LTRIM(RTRIM(CONCAT (
									U.FirstName
									,' '
									,U.LastName
									,CASE 
										WHEN U.IsDeleted = 1
											THEN ' (Inactive)'
										ELSE ''
										END
									)))
				END ASC
			,CASE 
				WHEN @SortOrder = 'DESC'
					AND @SortBy = 'SalesmanName'
					THEN LTRIM(RTRIM(CONCAT (
									U.FirstName
									,' '
									,U.LastName
									,CASE 
										WHEN U.IsDeleted = 1
											THEN ' (Inactive)'
										ELSE ''
										END
									)))
				END DESC
			,CASE 
				WHEN @SortOrder = 'ASC'
					AND @SortBy = 'CustomerName'
					THEN LTRIM(RTRIM(CONCAT (
									C.FirstName
									,' '
									,C.LastName
									)))
				END ASC
			,CASE 
				WHEN @SortOrder = 'DESC'
					AND @SortBy = 'CustomerName'
					THEN LTRIM(RTRIM(CONCAT (
									C.FirstName
									,' '
									,C.LastName
									)))
				END DESC
			,CASE 
				WHEN @SortOrder = 'ASC'
					AND @SortBy = 'PhoneNumber'
					THEN C.PhoneNumber
				END ASC
			,CASE 
				WHEN @SortOrder = 'DESC'
					AND @SortBy = 'PhoneNumber'
					THEN C.PhoneNumber
				END DESC
			,CASE 
				WHEN @SortOrder = 'ASC'
					AND @SortBy = 'Rating'
					THEN AVG(CAST(FO.FeedbackValue AS DECIMAL(18, 2)))
				END ASC
			,CASE 
				WHEN @SortOrder = 'DESC'
					AND @SortBy = 'Rating'
					THEN AVG(CAST(FO.FeedbackValue AS DECIMAL(18, 2)))
				END DESC
			,CASE 
				WHEN @SortOrder = 'ASC'
					AND @SortBy = 'RatingDate'
					THEN MIN(FO.CreatedDate)
				END ASC
			,CASE 
				WHEN @SortOrder = 'DESC'
					AND @SortBy = 'RatingDate'
					THEN MIN(FO.CreatedDate)
				END DESC
			,CASE 
				WHEN @SortBy NOT IN (
						'OrderNo'
						,'SalesmanName'
						,'CustomerName'
						,'PhoneNumber'
						,'Rating'
						,'RatingDate'
						)
					THEN MIN(FO.CreatedDate)
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

