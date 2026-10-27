
CREATE FUNCTION [Search] (@str VARCHAR(100))
RETURNS TABLE

RETURN

SELECT DISTINCT s.NAME AS SchemaName
	,o.NAME AS ObjectName
	,o.type_desc AS ObjectType
FROM sys.objects o
INNER JOIN syscomments c ON c.Id = o.object_id
INNER JOIN sys.schemas s ON s.schema_id = o.schema_id
WHERE is_ms_shipped = 0
	AND c.TEXT LIKE '%' + @str + '%'

GO

