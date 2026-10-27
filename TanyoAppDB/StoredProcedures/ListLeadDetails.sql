/*      
 EXEC [dbo].[ListLeadDetails]      
   @TenantId = 1      
  ,@CustomerName  = NULL      
  ,@PhoneNumber = NULL      
  ,@SalesmanId  = NULL      
  ,@LeadSourceId  = NULL     
  ,@Status  = NULL      
  ,@Tags  = NULL      
  ,@LocationID = NULL    
  ,@PageIndex  = 1      
  ,@PageSize  = 25      
  ,@SortBy = 'LastCreatedOn'      
  ,@SortOrder  = 'DESC'      
   ,@InquiryFor = NULL    
   ,@BuyingRangeValueId = NULL  
   ,@CreatedFromDate = NULL
   ,@CreatedToDate = NULL
   ,@PipelineType = NULL
 */
CREATE PROC [dbo].[ListLeadDetails] (
	@TenantId BIGINT
	,@CustomerName VARCHAR(50) = NULL
	,@PhoneNumber VARCHAR(16) = NULL
	,@SalesmanId BIGINT = NULL
	,@LeadSourceId BIGINT = NULL
	,@Status INT = NULL
	,@Tags BIGINT = NULL
	,@LocationID VARCHAR(500) = NULL
	,@PageIndex INT = 1
	,@PageSize INT = 25
	,@SortBy VARCHAR(50) = 'LastCreatedOn'
	,@SortOrder VARCHAR(10) = 'DESC'
	,@InquiryFor VARCHAR(100) = NULL
	,@BuyingRangeValueId BIGINT = NULL
	,@CreatedFromDate DATE = NULL
	,@CreatedToDate DATE = NULL
	,@PipelineType INT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT l.LeadId
			,
			--ISNULL(l.FirstName, '') + ' ' + ISNULL(l.LastName, '') AS CustomerName,    
			LTRIM(RTRIM(ISNULL(NULLIF(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''), ' '), ISNULL(l.FirstName, '') + ' ' + ISNULL(l.LastName, '')))) AS CustomerName
			,ISNULL(l.LeadSourceId, 0) AS LeadSourceId
			,CASE 
				WHEN @LeadSourceId = - 1
					THEN 'Other'
				WHEN l.LeadSourceId IS NULL
					THEN 'Other'
				WHEN lv.LookupValueId IS NULL
					THEN 'Other'
				ELSE ISNULL(lv.LookupValueName, '')
				END AS LeadSourceName
			,ISNULL(l.Priority, 0) AS Priority
			,ISNULL(ll.LabelName, '') AS LabelName
			,ISNULL(ll.ColorCode, '') AS ColorCode
			,
			--l.PhoneNumber,    
			ISNULL(c.PhoneNumber, l.PhoneNumber) AS PhoneNumber
			,l.Notes AS InquiryAbout
			,fl.FollowUpComment AS FollowupComment
			,l.Status AS Status
			,FORMAT(l.CreatedDate, 'dd/MM/yyyy hh:mm tt') AS LastCreatedOn
			,ISNULL(au.FirstName + ' ' + au.LastName + CASE 
					WHEN au.IsDeleted = 1
						THEN ' (Inactive)'
					ELSE ''
					END, '') AS Salesman
			,ISNULL(la.LocationName, '') AS LocationName
			,ISNULL(br.LookupValueName, '') AS BuyingRange
			,REPLACE(l.InquiryFor, ',', ',<BR>') AS InquiryFor
			,ISNULL(FORMAT(l.UpdatedDate, 'dd/MM/yyyy hh:mm tt'), '') AS LastModifiedOn
			,l.AlternateMobileNumber
			,l.InquiryAreaRequirement
			,l.AlternateSalesmanId
			,l.ClientMeetingStageId
			,l.ArchitectMeetingStageId
			,l.LeadType
			,CASE 
				WHEN ISNULL(l.LeadType, 0) = 0
					AND au.FieldStoreOperationType = 1
					THEN 'Field Pipeline'
				WHEN ISNULL(l.LeadType, 0) = 0
					AND au.FieldStoreOperationType IN (
						2
						,3
						)
					THEN 'Sales Pipeline'
				WHEN ISNULL(l.LeadType, 0) = 1
					AND au.FieldStoreOperationType IN (
						2
						,3
						)
					THEN 'Architects Visit - Store'
				WHEN ISNULL(l.LeadType, 0) = 1
					AND au.FieldStoreOperationType = 1
					THEN 'Architects Visit - Field'
				ELSE ''
				END AS PipelineName
			,COUNT(1) OVER () AS TotalCount
		FROM dbo.Leads l WITH (NOLOCK)
		LEFT JOIN dbo.Customers AS c WITH (NOLOCK) ON l.CustomerId = c.CustomerId
		LEFT JOIN dbo.AspNetUsers au WITH (NOLOCK) ON au.UserId = l.SalesmanId
		LEFT JOIN dbo.Labels ll WITH (NOLOCK) ON ll.LabelId = l.Priority
			AND ll.TenantId = l.TenantId
		LEFT JOIN dbo.Locations la WITH (NOLOCK) ON la.LocationID = l.LocationID
			AND la.TenantID = l.TenantId
			AND la.IsDeleted = 0
		LEFT JOIN dbo.LookupValues lv WITH (NOLOCK) ON lv.LookupValueId = l.LeadSourceId
			AND lv.IsDeleted = 0
		LEFT JOIN dbo.LookupValues br WITH (NOLOCK) ON br.LookupValueId = l.BuyingRangeValueId
			AND br.IsDeleted = 0
		LEFT JOIN (
			SELECT LeadId
				,FollowUpComment
				,ROW_NUMBER() OVER (
					PARTITION BY LeadId ORDER BY CreatedDate DESC
					) AS rn
			FROM dbo.FollowUpLeads WITH (NOLOCK)
			) AS fl ON fl.LeadId = l.LeadId
			AND fl.rn = 1
		WHERE l.TenantId = @TenantId
			AND l.Status <> 6 -- Deleted      
			--AND (@CustomerName IS NULL OR (ISNULL(l.FirstName, '') + ' ' + ISNULL(l.LastName, '')) LIKE '%' + @CustomerName + '%')    
			--AND (@PhoneNumber IS NULL OR l.PhoneNumber LIKE '%' + @PhoneNumber + '%')    
			AND (
				@CustomerName IS NULL
				OR LTRIM(RTRIM(ISNULL(NULLIF(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''), ' '), ISNULL(l.FirstName, '') + ' ' + ISNULL(l.LastName, '')))) LIKE '%' + @CustomerName + '%'
				)
			AND (
				@PhoneNumber IS NULL
				OR ISNULL(c.PhoneNumber, l.PhoneNumber) LIKE '%' + @PhoneNumber + '%'
				)
			AND (
				@LeadSourceId IS NULL
				OR @LeadSourceId = 0
				OR l.LeadSourceId = @LeadSourceId
				)
			AND (
				@SalesmanId IS NULL
				OR l.SalesmanId = @SalesmanId
				)
			AND (
				@Status IS NULL
				OR l.Status = @Status
				)
			AND (
				@Tags IS NULL
				OR ll.LabelId = @Tags
				)
			AND (
				@InquiryFor IS NULL
				OR l.InquiryFor LIKE '%' + @InquiryFor + '%'
				)
			AND (
				@LocationID IS NULL
				OR l.LocationID IN (
					SELECT value
					FROM STRING_SPLIT(@LocationID, ',')
					)
				)
			AND (
				@BuyingRangeValueId IS NULL
				OR l.BuyingRangeValueId = @BuyingRangeValueId
				)
			AND (
				@CreatedFromDate IS NULL
				OR l.CreatedDate >= @CreatedFromDate
				)
			AND (
				@CreatedToDate IS NULL
				OR l.CreatedDate < DATEADD(DAY, 1, @CreatedToDate)
				)
			AND (
				@PipelineType IS NULL
				OR (
					@PipelineType = 1
					AND ISNULL(l.LeadType, 0) = 0
					AND au.FieldStoreOperationType = 1
					)
				OR (
					@PipelineType = 2
					AND ISNULL(l.LeadType, 0) = 0
					AND au.FieldStoreOperationType IN (
						2
						,3
						)
					)
				OR (
					@PipelineType = 3
					AND ISNULL(l.LeadType, 0) = 1
					AND au.FieldStoreOperationType IN (
						2
						,3
						)
					)
				OR (
					@PipelineType = 4
					AND ISNULL(l.LeadType, 0) = 1
					AND au.FieldStoreOperationType = 1
					)
				)
		ORDER BY CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'ASC'
					THEN LTRIM(RTRIM(ISNULL(NULLIF(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''), ' '), ISNULL(l.FirstName, '') + ' ' + ISNULL(l.LastName, ''))))
				END
			,CASE 
				WHEN @SortBy = 'CustomerName'
					AND @SortOrder = 'DESC'
					THEN LTRIM(RTRIM(ISNULL(NULLIF(ISNULL(c.FirstName, '') + ' ' + ISNULL(c.LastName, ''), ' '), ISNULL(l.FirstName, '') + ' ' + ISNULL(l.LastName, ''))))
				END DESC
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'ASC'
					THEN ISNULL(c.PhoneNumber, l.PhoneNumber)
				END
			,CASE 
				WHEN @SortBy = 'PhoneNumber'
					AND @SortOrder = 'DESC'
					THEN ISNULL(c.PhoneNumber, l.PhoneNumber)
				END DESC
			,CASE 
				WHEN @SortBy = 'LastCreatedOn'
					AND @SortOrder = 'ASC'
					THEN l.CreatedDate
				END
			,CASE 
				WHEN @SortBy = 'LastCreatedOn'
					AND @SortOrder = 'DESC'
					THEN l.CreatedDate
				END DESC
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'ASC'
					THEN (au.FirstName + ' ' + au.LastName)
				END
			,CASE 
				WHEN @SortBy = 'Salesman'
					AND @SortOrder = 'DESC'
					THEN (au.FirstName + ' ' + au.LastName)
				END DESC
			,CASE 
				WHEN @SortBy = 'LeadSourceName'
					AND @SortOrder = 'ASC'
					THEN ISNULL(lv.LookupValueName, '')
				END
			,CASE 
				WHEN @SortBy = 'LeadSourceName'
					AND @SortOrder = 'DESC'
					THEN ISNULL(lv.LookupValueName, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'Notes'
					AND @SortOrder = 'ASC'
					THEN ISNULL(l.Notes, '')
				END
			,CASE 
				WHEN @SortBy = 'Notes'
					AND @SortOrder = 'DESC'
					THEN ISNULL(l.Notes, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'followupComment'
					AND @SortOrder = 'ASC'
					THEN ISNULL(fl.FollowUpComment, '')
				END
			,CASE 
				WHEN @SortBy = 'followupComment'
					AND @SortOrder = 'DESC'
					THEN ISNULL(fl.FollowUpComment, '')
				END DESC
			,CASE 
				WHEN @SortBy = 'LocationName'
					AND @SortOrder = 'ASC'
					THEN la.LocationName
				END
			,CASE 
				WHEN @SortBy = 'LocationName'
					AND @SortOrder = 'DESC'
					THEN la.LocationName
				END DESC
			,CASE 
				WHEN @SortBy = 'LastModifiedOn'
					AND @SortOrder = 'ASC'
					THEN ISNULL(l.UpdatedDate, l.CreatedDate)
				END
			,CASE 
				WHEN @SortBy = 'LastModifiedOn'
					AND @SortOrder = 'DESC'
					THEN ISNULL(l.UpdatedDate, l.CreatedDate)
				END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

		FETCH NEXT @PageSize ROWS ONLY;
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
			,@ObjectName VARCHAR(500);

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ObjectName = OBJECT_NAME(@@PROCID);

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMessage
	END CATCH
END

GO

