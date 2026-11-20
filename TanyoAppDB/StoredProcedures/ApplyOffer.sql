/*
exec ApplyOffer
	@OfferId = 134
	,@ProductIds = '52277,52278,52283,62297,62326'
	,@TenantId = 2
	,@UserId = 4279
	,@IsApplyFromOffer = 1
*/
CREATE   PROCEDURE [dbo].[ApplyOffer]
(
	@OfferId BIGINT
	,@ProductIds NVARCHAR(MAX)
	,@TenantId BIGINT
	,@UserId BIGINT
	,@IsApplyFromOffer BIT = 0
)
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;

	DROP TABLE IF EXISTS #IncomingProducts;
		
	DECLARE @DateNow DATETIMEOFFSET = SYSDATETIMEOFFSET()
		,@DateUtcNow DATETIME = GETUTCDATE()
		,@ReturnMessage VARCHAR(512)

	DECLARE @OfferCode NVARCHAR(100)
		,@OfferTitle NVARCHAR(200)
		,@OfferPercentage DECIMAL(5, 2);

	DECLARE @ProductSubjectTypeId BIGINT;

	DECLARE @AnnouncementId BIGINT;
	DECLARE @OfferDisplayTitle NVARCHAR(200);

	DECLARE @RoleSuffix NVARCHAR(50) = '_' + CAST(@TenantId AS NVARCHAR(20));
	DECLARE @SalesRepRole NVARCHAR(50) = 'salesrepresentative';
	DECLARE @AdminRole NVARCHAR(50) = 'administrator';

	IF NOT EXISTS (
			SELECT 1
			FROM dbo.Offers WITH (NOLOCK)
			WHERE OfferId = @OfferId
			AND IsPublished = 1
			AND IsDeleted = 0
			--AND CAST (@DateNow AS DATE) BETWEEN StartDate and EndDate
			)
	BEGIN
		SET @ReturnMessage = 'Invalid Offer';
        THROW 50001,@ReturnMessage , 1;
	END

	SELECT @OfferCode = OfferCode
		,@OfferTitle = OfferTitle
		,@OfferPercentage = OfferPercentage
	FROM dbo.Offers WITH (NOLOCK)
	WHERE OfferId = @OfferId;

	CREATE TABLE #IncomingProducts (ProductId BIGINT);

	INSERT INTO #IncomingProducts (ProductId)
	SELECT CAST(value AS BIGINT)
	FROM STRING_SPLIT(@ProductIds, ',')
	WHERE LTRIM(RTRIM(value)) <> '';

	BEGIN TRY

	BEGIN TRAN

	IF (@IsApplyFromOffer = 1)
	BEGIN
		-- Clear products mapped with current offer

		UPDATE p
		SET p.RetailOfferPrice = NULL
			,p.UpdatedBy = @UserId
			,p.UpdatedDate = @DateNow
			,p.UpdatedUTCDate = @DateUtcNow
		FROM dbo.Products p
		INNER JOIN dbo.OfferProductMapping opm
			ON opm.ProductId = p.ProductId
		WHERE opm.OfferId = @OfferId;

		DELETE
		FROM dbo.OfferProductMapping
		WHERE OfferId = @OfferId;

		DELETE OPM
		FROM dbo.OfferProductMapping OPM
		INNER JOIN #IncomingProducts ip
			ON ip.ProductId = OPM.ProductId;
	END
	ELSE
	BEGIN
		-- Clear products mapped with any existing offer

		UPDATE p
		SET p.RetailOfferPrice = NULL
			,p.UpdatedBy = @UserId
			,p.UpdatedDate = @DateNow
			,p.UpdatedUTCDate = @DateUtcNow
		FROM dbo.Products p
		INNER JOIN #IncomingProducts ip
			ON ip.ProductId = p.ProductId
		WHERE EXISTS
		(
			SELECT 1
			FROM dbo.OfferProductMapping opm
			WHERE opm.ProductId = p.ProductId
		);

		DELETE OPM
		FROM dbo.OfferProductMapping OPM
		INNER JOIN #IncomingProducts ip
			ON ip.ProductId = OPM.ProductId;
	END

	INSERT INTO dbo.OfferProductMapping (
		ProductId
		,OfferId
		,LastModifiedBy
		,LastModifiedDate
		,LastModifiedUTCDate
		)
	SELECT ip.ProductId
		,@OfferId
		,@UserId
		,@DateNow
		,@DateUtcNow
	FROM #IncomingProducts ip
	WHERE NOT EXISTS (
			SELECT 1
			FROM dbo.OfferProductMapping opm
			WHERE opm.ProductId = ip.ProductId
			);

	UPDATE p
	SET p.RetailOfferPrice = p.RetailerPrice - (p.RetailerPrice * @OfferPercentage / 100)
		,p.UpdatedBy = @UserId
		,p.UpdatedDate = @DateNow
		,p.UpdatedUTCDate = @DateUtcNow
	FROM dbo.Products p
	INNER JOIN #IncomingProducts ip ON ip.ProductId = p.ProductId;

	SELECT @ProductSubjectTypeId = SubjectTypeId
	FROM dbo.SubjectTypes
	WHERE SubjectTypeName = 'Products'
	AND TenantId = @TenantId;

	INSERT INTO dbo.ActivityLogs (
		SubjectTypeId
		,SubjectId
		,Description
		,Action
		,CreatedBy
		,CreatedDate
		,CreatedUTCDate
		)
	SELECT @ProductSubjectTypeId
		,ip.ProductId
		,'Offer Applied ' + @OfferCode + ' ' + CAST(@OfferPercentage AS NVARCHAR(20)) + '%.'
		,'Create'
		,@UserId
		,@DateNow
		,@DateUtcNow
	FROM #IncomingProducts ip;
	
	SET @OfferDisplayTitle =
		CASE
			WHEN ISNULL(LTRIM(RTRIM(@OfferTitle)), '') = ''
				THEN LTRIM(RTRIM(@OfferCode))
			ELSE LTRIM(RTRIM(@OfferTitle))
		END;
	
	INSERT INTO dbo.Announcements
	(
		Message,
		TenantId,
		CreatedBy,
		CreatedDate,
		CreatedUTCDate
	)
	VALUES
	(
		'Hey! A new offer ''' + @OfferDisplayTitle + ''' has been added on products. Please check it out.',
		@TenantId,
		@UserId,
		@DateNow,
		@DateUtcNow
	);
	
	SET @AnnouncementId = SCOPE_IDENTITY();
	
	INSERT INTO dbo.AnnouncementsUserMapping
	(
		AnnouncementId,
		NotificationType,
		IsRead,
		SentTo,
		SentBy,
		TenantId,
		CreatedBy,
		CreatedDate,
		CreatedUTCDate,
		ApplicationType
	)
	SELECT DISTINCT
		@AnnouncementId,
		'Offers',
		0,
		u.UserId,
		@UserId,
		@TenantId,
		@UserId,
		@DateNow,
		@DateUtcNow,
		2 
	FROM dbo.AspNetUsers u WITH (NOLOCK)
	INNER JOIN dbo.UserTenantMapping utm WITH (NOLOCK)
		ON utm.UserId = u.UserId
		AND utm.TenantId = @TenantId
	INNER JOIN dbo.AspNetUserRoles ur WITH (NOLOCK)
		ON ur.UserId = u.Id
	INNER JOIN dbo.AspNetRoles r WITH (NOLOCK)
		ON r.Id = ur.RoleId
	WHERE u.IsActive = 1
		AND u.IsDeleted = 0
		AND r.Name IS NOT NULL
		AND LOWER(REPLACE(r.Name, @RoleSuffix, ''))
			IN (@SalesRepRole, @AdminRole);

	COMMIT

	SELECT DISTINCT u.UserId
		,ISNULL(u.RegisteredFCMToken, '') AS RegisteredFCMToken
	FROM dbo.AspNetUsers u WITH (NOLOCK)
	INNER JOIN dbo.UserTenantMapping utm WITH (NOLOCK) ON utm.UserId = u.UserId
		AND utm.TenantId = @TenantId
	INNER JOIN dbo.AspNetUserRoles ur WITH (NOLOCK) ON ur.UserId = u.Id
	INNER JOIN dbo.AspNetRoles r WITH (NOLOCK) ON r.Id = ur.RoleId
	WHERE u.IsActive = 1
		AND u.IsDeleted = 0
		AND r.Name IS NOT NULL
		AND LOWER(REPLACE(r.Name, @RoleSuffix, '')) IN (
			@SalesRepRole
			,@AdminRole
			)
		AND ISNULL(u.RegisteredFCMToken,'') <> ''
	ORDER BY u.UserId ASC;

	DROP TABLE #IncomingProducts;

	EXEC [dbo].[PopulateProductOffers] @TenantId = @TenantId, @OfferId = @OfferId
END TRY

BEGIN CATCH
		IF @@TRANCOUNT > 0
			ROLLBACK;

		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH

END

GO

