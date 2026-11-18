CREATE PROCEDURE zGetTenantBankDetails (@TenantID BIGINT)
WITH ENCRYPTION
AS
BEGIN
	SELECT BankName
		,AccountNo
		,IFSCCode
		,BranchName
		,QRCode
	FROM TenantBankDetails WITH (NOLOCK)
	WHERE TenantID = @TenantID
		AND IsDeleted = 0
END

GO

