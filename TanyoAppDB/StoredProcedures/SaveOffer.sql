/*
	EXEC dbo.SaveOffer
      @UserId = 4471
    , @TenantId = 2
    , @OfferId = 194
    , @OfferTypeId = 2
    , @OfferTitle = 'JhanviTest1'
    , @OfferCode = 'JhanviTes'
    , @OfferDescription = 'New Test'
    , @OfferPercentage = 10
    , @StartDate = '2026-08-01'
    , @EndDate = '2026-08-31'
    , @IsPublished = 1;
*/
CREATE PROCEDURE [dbo].[SaveOffer] (
	@UserId INT
	,@TenantId INT
	,@OfferId INT = NULL
	,@OfferTypeId INT = NULL
	,@OfferTitle VARCHAR(50) = NULL
	,@OfferCode VARCHAR(50) = NULL
	,@OfferDescription VARCHAR(1000) = NULL
	,@OfferPercentage INT = NULL
	,@StartDate DATE = NULL
	,@EndDate DATE = NULL
	,@IsPublished BIT = NULL
	)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DECLARE @dt DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@dtUTC DATE = GETUTCDATE()
		,@OfferSubjectTypeId INT
		,@OldOfferTypeId INT
		,@OldOfferTitle VARCHAR(50)
		,@OldOfferCode VARCHAR(50)
		,@OldOfferDescription VARCHAR(1000)
		,@OldOfferPercentage INT
		,@OldStartDate DATE
		,@OldEndDate DATE
		,@OldIsPublished BIT
		,@MaxCount INT
		,@Counter INT
		,@CurrentLog VARCHAR(1000)
		,@Status BIT = 0
		,@Message VARCHAR(200)
		,@ErrorMsg VARCHAR(MAX);

	-- Fetch Offer SubjectTypeId for the Tenant
	SELECT @OfferSubjectTypeId = SubjectTypeId
	FROM SubjectTypes
	WHERE TenantId = @TenantId
		AND SubjectTypeName = 'Offer';

	BEGIN TRY
		BEGIN TRANSACTION SAVEOFFER;

		IF @OfferId IS NOT NULL
			AND @OfferId > 0
		BEGIN
			-- 1. Get existing data before updating
			SELECT @OldOfferTypeId = OfferTypeId
				,@OldOfferTitle = OfferTitle
				,@OldOfferCode = OfferCode
				,@OldOfferDescription = OfferDescription
				,@OldOfferPercentage = OfferPercentage
				,@OldStartDate = StartDate
				,@OldEndDate = EndDate
				,@OldIsPublished = IsPublished
			FROM Offers
			WHERE OfferId = @OfferId
				AND TenantId = @TenantId;

			-- 2. Update existing offer
			UPDATE Offers
			SET OfferTypeId = @OfferTypeId
				,OfferTitle = @OfferTitle
				,OfferCode = @OfferCode
				,OfferDescription = @OfferDescription
				,OfferPercentage = @OfferPercentage
				,StartDate = @StartDate
				,EndDate = @EndDate
				,IsPublished = @IsPublished
				,UpdatedBy = @UserId
				,UpdatedDate = @dt
				,UpdatedUTCDate = @dtUTC
			WHERE OfferId = @OfferId
				AND TenantId = @TenantId;

			-- 3. Capture changes
			DECLARE @ChangedLogs TABLE (
				Id INT IDENTITY(1, 1)
				,Description NVARCHAR(MAX)
				);

			INSERT INTO @ChangedLogs (Description)
			SELECT 'Offer ' + ISNULL(@OfferTitle, '') + ' - ' + FieldName + ' changed from ''' + ISNULL(OldVal, '') + ''' to ''' + ISNULL(NewVal, '') + '''.'
			FROM (
				VALUES (
					'Type'
					,CAST(@OldOfferTypeId AS VARCHAR(50))
					,CAST(@OfferTypeId AS VARCHAR(50))
					)
					,(
					'Title'
					,@OldOfferTitle
					,@OfferTitle
					)
					,(
					'Code'
					,@OldOfferCode
					,@OfferCode
					)
					,(
					'Description'
					,@OldOfferDescription
					,@OfferDescription
					)
					,(
					'Percentage'
					,CAST(@OldOfferPercentage AS VARCHAR(50))
					,CAST(@OfferPercentage AS VARCHAR(50))
					)
					,(
					'Start Date'
					,CAST(@OldStartDate AS VARCHAR(50))
					,CAST(@StartDate AS VARCHAR(50))
					)
					,(
					'End Date'
					,CAST(@OldEndDate AS VARCHAR(50))
					,CAST(@EndDate AS VARCHAR(50))
					)
					,(
					'Published Status'
					,CASE 
						WHEN @OldIsPublished = 1
							THEN 'True'
						ELSE 'False'
						END
					,CASE 
						WHEN @IsPublished = 1
							THEN 'True'
						ELSE 'False'
						END
					)
				) AS Changes(FieldName, OldVal, NewVal)
			WHERE ISNULL(OldVal, '') <> ISNULL(NewVal, '');

			SET @Counter = 1;
			SET @MaxCount = (
					SELECT COUNT(*)
					FROM @ChangedLogs
					);

			-- 4. Save log per changed field
			WHILE @Counter <= @MaxCount
			BEGIN
				SELECT @CurrentLog = Description
				FROM @ChangedLogs
				WHERE Id = @Counter;

				EXEC dbo.SaveActivityLog @SubjectTypeId = @OfferSubjectTypeId
					,@SubjectId = @OfferId
					,@Description = @CurrentLog
					,@Action = 'UPDATE'
					,@CreatedBy = @UserId
					,@CreatedDate = @dt
					,@CreatedUTCDate = @dtUTC;

				SET @Counter = @Counter + 1;
			END

			SET @Message = 'Offer details updated successfully.';

			--IF @IsPublished = 0
			--BEGIN
			--    EXEC [dbo].[ApplyOffer_V2]
			--          @TenantId = @TenantId
			--        , @OfferId = @OfferId
			--        , @UserId = @UserId
			--        , @IsPublished = @IsPublished;
			--END
			IF @OldIsPublished <> @IsPublished
			BEGIN
				EXEC [dbo].[ApplyOffer_V2] @TenantId = @TenantId
					,@OfferId = @OfferId
					,@UserId = @UserId
					,@IsPublished = @IsPublished;
			END
		END
		ELSE
		BEGIN
			-- Insert new offer
			INSERT INTO Offers (
				TenantId
				,OfferTypeId
				,OfferTitle
				,OfferCode
				,OfferDescription
				,OfferPercentage
				,StartDate
				,EndDate
				,IsPublished
				,CreatedBy
				,CreatedDate
				,CreatedUTCDate
				)
			VALUES (
				@TenantId
				,@OfferTypeId
				,@OfferTitle
				,@OfferCode
				,@OfferDescription
				,@OfferPercentage
				,@StartDate
				,@EndDate
				,@IsPublished
				,@UserId
				,@dt
				,@dtUTC
				);

			SET @OfferId = SCOPE_IDENTITY();

			DECLARE @CreateDescription NVARCHAR(MAX) = 'Offer ' + ISNULL(@OfferTitle, '') + ' (Code: ' + ISNULL(@OfferCode, '') + ') has been created.';

			EXEC dbo.SaveActivityLog @SubjectTypeId = @OfferSubjectTypeId
				,@SubjectId = @OfferId
				,@Description = @CreateDescription
				,@Action = 'CREATE'
				,@CreatedBy = @UserId
				,@CreatedDate = @dt
				,@CreatedUTCDate = @dtUTC;

			SET @Message = 'Offer created successfully.';
		END

		COMMIT TRANSACTION SAVEOFFER;

		SET @Status = 1;

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,@OfferId AS [OfferId]
			,NULL AS [Error];
	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500);

		IF @@TRANCOUNT > 0
			ROLLBACK TRAN SAVEOFFER;

		SET @ErrorMsg = ERROR_MESSAGE();
		SET @Status = 0;
		SET @Message = CASE 
				WHEN @OfferId IS NOT NULL
					AND @OfferId > 0
					THEN 'The update of offer was unsuccessful.'
				ELSE 'The creation of new offer was unsuccessful.'
				END;
		SET @ObjectName = OBJECT_NAME(@@PROCID);

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;

		SELECT @Status AS [Status]
			,@Message AS [Message]
			,NULL AS [OfferId]
			,@ErrorMsg AS [Error];

		RETURN;
	END CATCH
END;

GO

