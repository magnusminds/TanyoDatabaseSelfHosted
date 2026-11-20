CREATE   PROCEDURE [dbo].[GetAllPOPaymentDetails] (
	@POProductId BIGINT
	,@PageIndex INT = 1
	,@PageSize INT = 10
	,@SortBy NVARCHAR(50) = 'PaymentDate'
	,@SortOrder NVARCHAR(4) = 'DESC'
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	SELECT PPP.POProductPaymentId
		,PPP.POProductId
		,PPP.VendorId
		,PPP.TenantId
		,PPP.PaymentType
		,PPP.PaymentStatus
		,PPP.BankName
		,PPP.AccountHolderName
		,PPP.ChequeNo
		,PPP.ReceivedAmount
		,PPP.PaymentReceivedBy
		,CONCAT(AUP.FirstName,' ',AUP.LastName) AS PaymentReceivedByUserName
		,PPP.ReceivedDate
		,PPP.PaymentApprovedBy
		,CONCAT(AUR.FirstName,' ',AUR.LastName) AS PaymentApprovedByUserName
		,PPP.ApprovedDate
		,PPP.Comments
		,PPP.TransactionId
		,PPP.IsDeleted
		,PPP.CreatedBy
		,CONCAT(AUC.FirstName,' ',AUC.LastName) AS CreatedByUserName
		,PPP.CreatedDate
		,PPP.CreatedUTCDate
		,PPP.UpdatedBy
		,CONCAT(AUU.FirstName,' ',AUU.LastName) AS UpdatedByUserName
		,PPP.UpdatedDate
		,PPP.UpdatedUTCDate
		,COUNT(1) OVER () AS TotalCount
	FROM POProductPayment PPP WITH (NOLOCK) 
	INNER JOIN AspNetUsers AUC WITH (NOLOCK) ON PPP.CreatedBy = AUC.UserId
	LEFT JOIN AspNetUsers AUU WITH (NOLOCK) ON PPP.UpdatedBy = AUU.UserId	
	LEFT JOIN AspNetUsers AUP WITH (NOLOCK) ON PPP.PaymentApprovedBy = AUP.UserId
	LEFT JOIN AspNetUsers AUR WITH (NOLOCK) ON PPP.PaymentReceivedBy = AUR.UserId
	WHERE POProductId = @POProductId
		AND PPP.IsDeleted = 0
	ORDER BY CASE 
			WHEN @SortBy = 'PaymentDate'
				AND @SortOrder = 'ASC'
				THEN CreatedDate
			END ASC
		,CASE 
			WHEN @SortBy = 'PaymentDate'
				AND @SortOrder = 'DESC'
				THEN CreatedDate
			END DESC OFFSET(@PageIndex - 1) * @PageSize ROWS

	FETCH NEXT @PageSize ROWS ONLY

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

