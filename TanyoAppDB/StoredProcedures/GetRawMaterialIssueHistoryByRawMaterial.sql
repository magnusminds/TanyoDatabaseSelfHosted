/*
EXEC GetRawMaterialIssueHistoryByRawMaterial
@ManufacturingWorkOrderDetailId  = 63
,@RawMaterialId	= 705
,@PageIndex = 1
,@PageSize = 20
,@SortBy = 'RawMaterialName'
,@SortOrder = 'DESC'	
*/
CREATE   PROCEDURE GetRawMaterialIssueHistoryByRawMaterial (
@ManufacturingWorkOrderDetailId BIGINT 
,@RawMaterialId	BIGINT
,@PageIndex INT = 1
,@PageSize INT = 20
,@SortBy VARCHAR(50) = 'RawMaterialName'
,@SortOrder VARCHAR(4) = 'DESC'	
)
WITH ENCRYPTION
AS
BEGIN

	SET NOCOUNT ON;	


	BEGIN TRY
	SELECT RM.Title AS RawMaterialName
	,MWODL.ProvidedQty AS IssuedQty
	,AUMP.FirstName + ' ' + AUMP.LastName AS MaterialProviderName
	,AUMR.FirstName + ' ' + AUMR.LastName AS MaterialReceiverName
	,FORMAT(MWODL.CreatedDate, 'dd/MM/yyyy hh:mm tt') AS CreatedDate
	,COUNT(*) OVER() AS TotalCount
	FROM ManufacturingWorkOrderDetailsLog MWODL WITH (NOLOCK)
	INNER JOIN AspNetUsers AUMP WITH (NOLOCK) ON AUMP.UserId = MWODL.MaterialProviderId
	INNER JOIN AspNetUsers AUMR WITH (NOLOCK) ON AUMR.UserId = MWODL.MaterialReceiveId
	INNER JOIN RawMaterials RM WITH (NOLOCK) ON RM.RawMaterialId = MWODL.RawMaterialId
	WHERE MWODL.ManufacturingWorkOrderDetailId = @ManufacturingWorkOrderDetailId
		AND MWODL.RawMaterialId = @RawMaterialId
    ORDER BY

        CASE WHEN @SortBy = 'MaterialProviderName' AND @SortOrder = 'ASC' THEN AUMP.FirstName + ' ' + AUMP.LastName END ASC,
        CASE WHEN @SortBy = 'MaterialProviderName' AND @SortOrder = 'DESC' THEN AUMP.FirstName + ' ' + AUMP.LastName END DESC,

        CASE WHEN @SortBy = 'RawMaterialName' AND @SortOrder = 'ASC' THEN RM.Title END ASC,
        CASE WHEN @SortBy = 'RawMaterialName' AND @SortOrder = 'DESC' THEN RM.Title END DESC,

        CASE WHEN @SortBy = 'MaterialReceiverName' AND @SortOrder = 'ASC' THEN AUMR.FirstName + ' ' + AUMR.LastName END ASC,
        CASE WHEN @SortBy = 'MaterialReceiverName' AND @SortOrder = 'DESC' THEN AUMR.FirstName + ' ' + AUMR.LastName END DESC,

		CASE WHEN @SortBy = 'ProvidedQty' AND @SortOrder = 'ASC' THEN MWODL.ProvidedQty END ASC,
        CASE WHEN @SortBy = 'ProvidedQty' AND @SortOrder = 'DESC' THEN MWODL.ProvidedQty END DESC,
		
		CASE WHEN @SortBy = 'CreatedDate' AND @SortOrder = 'ASC' THEN MWODL.CreatedDate END ASC,
        CASE WHEN @SortBy = 'CreatedDate' AND @SortOrder = 'DESC' THEN MWODL.CreatedDate END DESC
        
	OFFSET (@PageIndex - 1) * @PageSize ROWS
    FETCH NEXT @PageSize ROWS ONLY;

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

