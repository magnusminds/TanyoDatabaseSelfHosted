-- =============================================  
--Author		: MagnusMinds
--Create date	: 08-09-2023
--Description	:  
-- =============================================
CREATE   PROCEDURE zUpdateOrderApprovedDate 
	@OrderNo VARCHAR(500)
WITH ENCRYPTION
AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;

    -- Insert statements for procedure here
	DECLARE @OrderId INT
	DECLARE @OldApprovedDate DateTimeoffset
	DECLARE @CurrentApprovedDate DateTimeoffset
	
	SELECT 
		@OrderId = OrderId,
		@CurrentApprovedDate = ApprovedDate
	FROM Orders
	Where OrderNo = @OrderNo
	
	SELECT 
		@OldApprovedDate = CONVERT(datetimeoffset, atr.OldValue,103)
	FROM AuditLogs_Temp_resolve_ApprovedDateIssue atr
	Where TableKey = @OrderId
	
	IF @OldApprovedDate IS NOT NULL AND @OrderId IS NOT NULL
		Update Orders
		SET ApprovedDate = @OldApprovedDate
		Where OrderId = @OrderId

		--SELECT 
		--	@OldApprovedDate = CONVERT(datetimeoffset, atr.OldValue,103) as OldApprovedDate,
		--	*
		--FROM Orders ord
		--INNER JOIN AuditLogs_Temp_resolve_ApprovedDateIssue atr ON ord.OrderId = atr.TableKey
		--Where OrderId = @OrderId
	
	
	

	--PRINT 'Current ApprovedDate'
	--SELECT @CurrentApprovedDate as CurrentApprovedDate
	--PRINT 'Updated OldApprovedDate'
	--SELECT @OldApprovedDate as UpdatedOldApprovedDate
END

GO

