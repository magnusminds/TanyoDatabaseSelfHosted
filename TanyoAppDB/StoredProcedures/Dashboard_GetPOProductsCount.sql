-- =============================================
-- Author:  MagnusMinds
-- Create date: 12-Nov-2025
-- Description: Get count of PO Products
-- =============================================
/*
    EXEC [dbo].[Dashboard_GetPOProductsCount]
        @TenantId = 2
*/ 
CREATE   PROCEDURE [dbo].[Dashboard_GetPOProductsCount]
    @TenantId INT
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    SELECT COUNT(1) AS StatusCount
    FROM POProducts WITH (NOLOCK)
    WHERE TenantId = @TenantId
    AND IsDeleted = 0
    AND Status IN (1,2,5) --Pending, Approved, Material Ready

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

