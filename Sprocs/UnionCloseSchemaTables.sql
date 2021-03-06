/*
	This requires the DataType "TablesToUnion"
	Where to Get? https://raw.githubusercontent.com/xmikedanielsx/HelpfulTSQLCode/master/DataTypes/TablesToUnion.sql

*/
CREATE OR ALTER PROCEDURE [dbo].[UnionCloseSchemaTables] @tables TablesToUnion READONLY, @newTable VARCHAR(100) = NULL
AS
  BEGIN
	DECLARE @fields TABLE (field VARCHAR(200))
	DECLARE @fieldsAndTable TABLE (field VARCHAR(200), tbl VARCHAR(200))
	DECLARE @tname VARCHAR(200)
	DECLARE @fileName VARCHAR(5000)

	/*
		FIRST WE LOOP THROUGH ALL TABLES PASSED TO US. We gather all those fields  
		into a master table with unique columsn and also a table with coumns and tables that were passed
	*/
	SELECT @tname = MIN(tbl) FROM @tables 
	WHILE @tname IS NOT NULL 
	  BEGIN
		INSERT INTO @fields
		SELECT a.name FROM (
			SELECT c.Name FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id WHERE t.Name = @tname
		) a  LEFT JOIN (
			SELECT field AS NAME FROM @fields
		) b ON a.Name = b.name
		WHERE b.Name IS NULL
		INSERT INTO @fieldsAndTable 
		SELECT c.Name, @tname FROM sys.columns c JOIN sys.tables t ON c.object_id = t.object_id WHERE t.Name = @tname

		SELECT @tname = MIN(tbl) FROM @tables WHERE tbl > @tname
	  END

	  /*
		Now we got all fields that are possible into one table and all fields for each table we will 
		dynamically build our union to pull NULLS for fields that don't exist for a certain table
	*/
	DECLARE @query NVARCHAR(MAX) = ''
	DECLARE @maxTable VARCHAR(200)
	DECLARE @maxField VARCHAR(200)
	SELECT @maxTable = MAX(tbl) FROM @tables
	SELECT @maxField = MAX(field) FROM @fields
	IF (ISNULL(@newTable, '') <> '') BEGIN  SELECT @query = @query + 'SELECT *  INTO [' + @newTable + '] FROM (' END

	  SELECT @tname = MIN(tbl) FROM @tables 
		WHILE @tname IS NOT NULL 
		  BEGIN
			select @fileName = srcFile FROM @tables where tbl = @tname
			DECLARE @f VARCHAR(200)
			SELECT @query = @query + 'select  '
			SELECT @f = MIN(field) FROM @fields
			WHILE @f IS NOT NULL 
			  BEGIN
				IF EXISTS (SELECT 1 FROM @fieldsAndTable WHERE field = @f AND tbl = @tname)
					BEGIN SELECT @query = @query + ' [' + @f +'], ' END
				ELSE 
					BEGIN SELECT @query = @query + ' NULL as [' + @f + '], ' END
		
				SELECT @query = @query +' '
				SELECT @f = MIN(field) FROM @fields WHERE field > @f
			  END
			  
			  IF ( @tname = @maxTable)
			    BEGIN
					SELECT @query = @query + ' ''' + @tname + ''' as OriginalTable, ''' + @fileName + '''  as OriginalFileName FROM ['+  @tname + ']'
				END
			ELSE
			  BEGIN
				SELECT @query = @query + ' ''' + @tname + ''' as OriginalTable, ''' + @fileName + ''' as OriginalFileName  FROM [' + @tname +  '] UNION ALL ' 
			  END
			  
		  SELECT @tname = MIN(tbl) FROM @tables WHERE tbl > @tname
		  END
		IF (ISNULL(@newTable, '') <> '') BEGIN   SELECT @query = @query + ' ) a ' END
	EXEC sys.sp_executesql @query
  END
