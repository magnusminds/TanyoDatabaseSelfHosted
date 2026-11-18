-- =============================================
-- Author:		MagnusMinds IT Solution
-- Create date: 18-07-2022
-- Description:	To generate model property of tables
-- =============================================
/*
	EXEC dbo.GenerateModelProperty
		@TableName = 'Lookups'
		,@ClassName = 'public class'
*/
CREATE PROCEDURE [dbo].[zGenerateModelProperty]
(
	@TableName SYSNAME
	,@ClassName VARCHAR(150) = 'public class'
)
WITH ENCRYPTION
AS
BEGIN
DECLARE @Result VARCHAR(MAX)  
  
SET @Result = LOWER(@ClassName) + ' ' + + @TableName + '  
{'  
  
SELECT @Result = @Result + '  
	public ' + ColumnType + NullableSign + ' ' + ColumnName + ' { get; set; }'  
FROM  
(  
	SELECT   
		REPLACE(col.NAME, ' ', '_') ColumnName,  
		column_id ColumnId,  
		CASE typ.NAME   
			WHEN 'bigint' THEN 'long'  
			WHEN 'binary' THEN 'byte[]'  
			WHEN 'bit' THEN 'bool'  
			WHEN 'char' THEN 'string'  
			WHEN 'date' THEN 'DateTime'  
			WHEN 'datetime' THEN 'DateTime'  
			WHEN 'datetime2' then 'DateTime'  
			WHEN 'datetimeoffset' THEN 'DateTimeOffset'  
			WHEN 'decimal' THEN 'decimal'  
			WHEN 'float' THEN 'float'  
			WHEN 'image' THEN 'byte[]'  
			WHEN 'int' THEN 'int'  
			WHEN 'money' THEN 'decimal'  
			WHEN 'nchar' THEN 'char'  
			WHEN 'ntext' THEN 'string'  
			WHEN 'numeric' THEN 'decimal'  
			WHEN 'nvarchar' THEN 'string'  
			WHEN 'real' THEN 'double'  
			WHEN 'smalldatetime' THEN 'DateTime'  
			WHEN 'smallint' THEN 'short'  
			WHEN 'smallmoney' THEN 'decimal'  
			WHEN 'text' THEN 'string'  
			WHEN 'time' THEN 'TimeSpan'  
			WHEN 'timestamp' THEN 'DateTime'  
			WHEN 'tinyint' THEN 'byte'  
			WHEN 'uniqueidentifier' THEN 'Guid'  
			WHEN 'varbinary' THEN 'byte[]'  
			WHEN 'varchar' THEN 'string'  
			ELSE 'UNKNOWN_' + typ.name  
		END ColumnType,  
		CASE   
			WHEN col.is_nullable = 1 and 
				typ.name in ('bigint', 'bit', 'date', 'datetime', 'datetime2', 'datetimeoffset', 'decimal', 'float', 'int', 'money', 'numeric', 'real', 'smalldatetime', 'smallint', 'smallmoney', 'time', 'tinyint', 'uniqueidentifier', 'varchar', 'nvarchar')   
			THEN '?'   
			ELSE ''   
		END NullableSign  
	FROM sys.columns col 
	INNER JOIN sys.types typ ON col.system_type_id = typ.system_type_id 
		AND col.user_type_id = typ.user_type_id  
	where OBJECT_ID = OBJECT_ID(@TableName)  
) t  
ORDER BY ColumnId  
SET @Result = @Result  + '  
}'  
  
PRINT @Result  

END

GO

