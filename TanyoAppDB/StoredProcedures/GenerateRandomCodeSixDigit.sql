CREATE   PROCEDURE dbo.GenerateRandomCodeSixDigit
WITH ENCRYPTION
AS
BEGIN

	BEGIN TRY
    DECLARE @Code CHAR(6)
    SET @Code = CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) +
                CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) +
                CHAR(48 + ABS(CHECKSUM(NEWID())) % 10) +
                CHAR(65 + ABS(CHECKSUM(NEWID())) % 26) +
                CHAR(48 + ABS(CHECKSUM(NEWID())) % 10) +
                CHAR(65 + ABS(CHECKSUM(NEWID())) % 26)
    SELECT @Code AS GeneratedCode

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

