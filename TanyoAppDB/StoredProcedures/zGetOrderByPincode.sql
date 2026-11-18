
/*
 =============================================    
Author  : MagnusMinds -- Create date : 20-08-2024
 =============================================

EXEC [dbo].[GetOrderByPincode]
		@Pincode = null,
		@TenantId = 1
*/
CREATE PROC [dbo].[zGetOrderByPincode] (
	@Pincode VARCHAR(MAX) = NULL
	,@TenantId INT
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	BEGIN TRY
		SELECT DISTINCT TOP 10 CAST(count(1) AS varchar) as 'maximumvalue'
			,os.ZipCode as 'pincode'  
			,COALESCE(ap.District,'') as 'city'
			,ap.STATE
			,ap.Name
		FROM OrderAddresses os
		INNER JOIN AreaByPincode ap ON os.ZipCode = ap.ZipCode
		INNER JOIN Orders o ON os.OrderId = o.OrderId
			AND o.STATUS != 9
			AND o.TenantId = @TenantId
			AND os.AddressType = 'Shipping'
		WHERE (
				@Pincode IS NULL
				OR ap.ZipCode IN (
					SELECT CAST(value AS INT)
					FROM string_split(@Pincode, ',')
					)
				)
		GROUP BY os.ZipCode
			,ap.District
			,ap.STATE
			,ap.Name
		ORDER BY 1 DESC
	END TRY

	BEGIN CATCH
		DECLARE @ErrorMessage NVARCHAR(4000)
		DECLARE @ErrorSeverity INT
		DECLARE @ErrorState INT

		SELECT @ErrorMessage = ERROR_MESSAGE()
			,@ErrorSeverity = ERROR_SEVERITY()
			,@ErrorState = ERROR_STATE()

		RAISERROR (
				@ErrorMessage
				,@ErrorSeverity
				,@ErrorState
				)
	END CATCH
END

GO

