/*
exec GetTrainingModules
*/
CREATE   PROCEDURE dbo.GetTrainingModules
WITH ENCRYPTION
AS
BEGIN
    SET NOCOUNT ON;


	BEGIN TRY
    SELECT
        TM.TrainingModuleId,
        TM.TrainingModuleName,
        TM.ModuleDisplayOrder,
        (
            SELECT
                TMV.TrainingModuleVideoId,
                TMV.TrainingModuleVideoName,
                TMV.TrainingModuleVIdeoUrl,
                TMV.VideoDisplayOrder
            FROM TrainingModuleVideo TMV WITH (NOLOCK)
            WHERE TMV.TrainingModuleId = TM.TrainingModuleId
                  AND TMV.IsDeleted = 0
            ORDER BY TMV.VideoDisplayOrder
            FOR JSON PATH
        ) AS ModuleVideoList
    FROM TrainingModule TM WITH (NOLOCK)
    WHERE TM.IsDeleted = 0
    ORDER BY TM.ModuleDisplayOrder

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

