-- =============================================
-- Author:		Parshwa Kapadia
-- Create date: 03-Feb-2025
-- Description:	Get tenant statistics monthly, rank them based on module usage.
-- =============================================
/*
	EXEC dbo.GetTenantUsageByMonth
		@Month = 'January'
		,@Year = 2025
*/
CREATE   PROC dbo.zGetTenantUsageByMonth
(
	@Month VARCHAR(50)
	,@Year INT
)
WITH ENCRYPTION
AS
BEGIN
	
	SET NOCOUNT ON;

	;WITH RankData AS (
		SELECT 
			r.TenantId,
			t.TenantName,
			r.ModuleName,
			r.TotalCount,
			r.Position,
			MAX(r.Position) OVER (PARTITION BY r.ModuleName) AS MaxPosition
		FROM TenantUsageStatistics r
		JOIN Tenants t ON r.TenantId = t.TenantId
		WHERE r.[Month] = @Month
		AND r.[Year] = @Year
	),
	cteMessages AS (
		SELECT 
			rd.TenantId,
			rd.TenantName,
			rd.ModuleName,
			rd.Position,
			rd.MaxPosition,
			CASE
				WHEN rd.Position = 1 THEN 'You are ranked 1st in ' + LOWER(rd.ModuleName) + '.'
				WHEN rd.Position = rd.MaxPosition THEN 'You are ranked ' + CAST(rd.Position AS VARCHAR) + ' in ' + LOWER(rd.ModuleName) + '.'
				ELSE 'You are ranked ' + CAST(rd.Position AS VARCHAR) + ' in ' + LOWER(rd.ModuleName) + '.'
			END AS SelfMessage
		FROM RankData rd
	),
	NeighborMessages AS (
		SELECT 
			rd.TenantId,
			rd.ModuleName,
			ISNULL(prev.TenantName + ' is ranked ' + CAST(prev.Position AS VARCHAR) + ' in ' + LOWER(rd.ModuleName) + '.', '') AS PrevMessage,
			ISNULL(next.TenantName + ' is ranked ' + CAST(next.Position AS VARCHAR) + ' in ' + LOWER(rd.ModuleName) + '.', '') AS NextMessage
		FROM RankData rd
		OUTER APPLY (
			SELECT TOP 1 TenantName, Position 
			FROM RankData 
			WHERE ModuleName = rd.ModuleName AND Position = rd.Position - 1
		) prev
		OUTER APPLY (
			SELECT TOP 1 TenantName, Position 
			FROM RankData 
			WHERE ModuleName = rd.ModuleName AND Position = rd.Position + 1
		) next
	),
	FinalMessages AS (
		SELECT 
			m.TenantId,
			m.TenantName,
			m.ModuleName,
			CASE
				WHEN m.Position = 1 THEN CONCAT(m.SelfMessage, CHAR(13) + CHAR(10), nm.NextMessage)
				WHEN m.Position = m.MaxPosition THEN CONCAT(nm.PrevMessage, CHAR(13) + CHAR(10), m.SelfMessage)
				ELSE CONCAT(nm.PrevMessage, CHAR(13) + CHAR(10), m.SelfMessage, CHAR(13) + CHAR(10), nm.NextMessage)
			END AS FullMessage
		FROM cteMessages m
		JOIN NeighborMessages nm ON m.TenantId = nm.TenantId AND m.ModuleName = nm.ModuleName
	)
	SELECT 
		TenantId,
		TenantName,
		ModuleName,
		FullMessage
	FROM FinalMessages
	ORDER BY TenantId, ModuleName;

END

GO

