CREATE   PROCEDURE [dbo].[HFJob_GetReadyToDeliverData]
WITH ENCRYPTION
AS
BEGIN
	SET NOCOUNT ON;


	BEGIN TRY
	IF OBJECT_ID('tempdb..#ProductSubjectType') IS NOT NULL
		DROP TABLE #ProductSubjectType

	IF OBJECT_ID('tempdb..#PolishSubjectType') IS NOT NULL
		DROP TABLE #PolishSubjectType

	IF OBJECT_ID('tempdb..#FabricSubjectType') IS NOT NULL
		DROP TABLE #FabricSubjectType

	DECLARE @Yesterday DATE = DATEADD(DAY, - 1, CAST(GETDATE() AS DATE));
	DECLARE @ProductSubjectTypeId INT
		,@PolishSubjectTypeId INT
		,@FabricSubjectTypeId INT
		,@ReadyToDelivered INT = 2
		,@Delivered INT = 3;

	SELECT SubjectTypeId AS ProductSubjecttypeId
		,TenantId
	INTO #ProductSubjectType
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Products';

	SELECT SubjectTypeId AS PolishSubjectTypeId
		,TenantId
	INTO #PolishSubjectType
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Polish';

	SELECT SubjectTypeId AS FabricSubjectTypeId
		,TenantId
	INTO #FabricSubjectType
	FROM SubjectTypes WITH (NOLOCK)
	WHERE SubjectTypeName = 'Fabrics';;

	WITH OrderDetails
	AS (
		SELECT OSI.OrderId
			,O.OrderNo
			,OSI.DeliveryNo
			,ISNULL(CAT.CategoryName, '') AS CategoryName
			,CASE 
				WHEN OSI.SubjectTypeId IN (
						SELECT ProductSubjecttypeId
						FROM #ProductSubjectType
						WHERE TenantId = O.TenantId
						)
					THEN P.ProductTitle
				WHEN OSI.SubjectTypeId IN (
						SELECT PolishSubjectTypeId
						FROM #PolishSubjectType
						WHERE TenantId = O.TenantId
						)
					THEN POL.Title
				WHEN OSI.SubjectTypeId IN (
						SELECT FabricSubjectTypeId
						FROM #FabricSubjectType
						WHERE TenantId = O.TenantId
						)
					THEN FAB.Title
				ELSE ''
				END AS ProductTitle
			,OSI.OrderSetItemId
			,OSI.ItemStatus
			,O.TentativeDeliveryDate
			,O.ApprovedDate
			,O.CreatedDate AS OrderDate
			,U.FirstName + ' ' + U.LastName AS CreatedByName
			,CONCAT(TRIM(C.FirstName), ' ', ISNULL(TRIM(C.LastName),'')) AS CustomerName
			,O.CreatedBy
			,O.OrderType
			,OSI.ReadyToDeliveredDate
			,OSI.DeliveryDate
			,TSD.FromEmail
			,TSD.[Password]
			,TSD.SMTPPort
			,TSD.SMTPServer
			,TSD.Username
			,TSD.EnableSSL
			,TSD.TargetName
			,T.EmailId AS NotificationEmail
			,T.TenantId
			,T.TenantName
			,T.EnableWhatsappNotification
			,T.PhoneNumber
		FROM OrderSetItems OSI WITH (NOLOCK)
		INNER JOIN Orders O WITH (NOLOCK) ON OSI.OrderId = O.OrderId
		INNER JOIN Customers C WITH (NOLOCK) ON O.CustomerID = C.CustomerId
			AND C.IsDeleted = 0
		INNER JOIN AspNetUsers U WITH (NOLOCK) ON O.CreatedBy = U.UserId
		INNER JOIN Tenants T WITH (NOLOCK) ON O.TenantId = T.TenantId
			AND T.IsDeleted = 0
		INNER JOIN TenantSMTPDetails TSD WITH (NOLOCK) ON O.TenantId = TSD.TenantID
		LEFT JOIN Products P WITH (NOLOCK) ON P.ProductId = OSI.SubjectId
			AND OSI.SubjectTypeId IN (
				SELECT ProductSubjecttypeId
				FROM #ProductSubjectType PST
				WHERE PST.TenantId = O.TenantId
				)
			AND P.TenantId = O.TenantId
		LEFT JOIN Polish POL WITH (NOLOCK) ON POL.PolishId = OSI.SubjectId
			AND OSI.SubjectTypeId IN (
				SELECT PolishSubjectTypeId
				FROM #PolishSubjectType PLST
				WHERE PLST.TenantId = O.TenantId
				)
			AND POL.TenantId = O.TenantId
		LEFT JOIN Fabrics FAB WITH (NOLOCK) ON FAB.FabricId = OSI.SubjectId
			AND OSI.SubjectTypeId IN (
				SELECT FabricSubjectTypeId
				FROM #FabricSubjectType FST
				WHERE FST.TenantId = O.TenantId
				)
			AND FAB.TenantId = O.TenantId
		LEFT JOIN Categories CAT WITH (NOLOCK) ON P.CategoryId = CAT.CategoryId
			AND CAT.TenantId = O.TenantId
		WHERE OSI.ParentOrderSetItemId IS NULL
			AND O.STATUS <> 9
			AND OSI.IsDeleted = 0
			AND T.TenantId != 116 -- Exclude Tenant for notification
		)
	SELECT *
		,CASE 
			WHEN ItemStatus = @ReadyToDelivered
				AND CAST(ReadyToDeliveredDate AS DATE) = @Yesterday
				THEN 'ReadyToDelivered'
			WHEN ItemStatus = @Delivered
				AND CAST(DeliveryDate AS DATE) = @Yesterday
				THEN 'Delivered'
			END AS StatusType
	FROM OrderDetails
	WHERE (
			ItemStatus = @ReadyToDelivered
			AND CAST(ReadyToDeliveredDate AS DATE) = @Yesterday
			)
		OR (
			ItemStatus = @Delivered
			AND CAST(DeliveryDate AS DATE) = @Yesterday
			)
	ORDER BY TentativeDeliveryDate DESC;

	END TRY

	BEGIN CATCH
		DECLARE @ObjectName VARCHAR(500)
			,@ErrorMsg VARCHAR(MAX);

		SET @ObjectName = OBJECT_NAME(@@PROCID);
		SET @ErrorMsg = ERROR_MESSAGE();

		EXEC dbo.SaveDBErrorLog @ObjectName = @ObjectName
			,@ErrorMsg = @ErrorMsg;
	END CATCH
END;

GO

