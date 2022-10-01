
--for SQL Server 2019 and higher version

CREATE PROCEDURE [dbo].[GetDbSchema]
AS

--first, we create temporary table to store our preliminary data
CREATE TABLE #tables
     (table_name   VARCHAR(100), 
      create_table VARCHAR(MAX)
     );
     CREATE TABLE #indexes
     (table_name   VARCHAR(100), 
      create_index VARCHAR(MAX)
     );
	 
-- we get "create" results for tables
     INSERT INTO #tables
               SELECT 'dbo.' + so.name, 
                   'CREATE TABLE [' + 'dbo].[' +so.name + ']' + '(' + CHAR(10) + o.list + ')' + 
				                                                                 CASE
                                                                                          WHEN tc.Constraint_Name IS NULL
                                                                                          THEN ''
                                                                                          WHEN  tc.Constraint_Type = 'PRIMARY KEY' 
																						  THEN
																						       + CHAR(10) + 'ALTER TABLE ' + so.Name + ' ADD CONSTRAINT ' + '[' + tc.Constraint_Name + ']' + ' PRIMARY KEY '  + CHAR(10)
																							   + '('  + CHAR(9) + LEFT(j.List, LEN(j.List) - 1) + CHAR(10) + ')' + CHAR(10) + c.list 
																						  WHEN  tc.Constraint_Type = 'UNIQUE'
																						  THEN
																						       + CHAR(10) + 'ALTER TABLE ' + so.Name + ' ADD CONSTRAINT ' + '[' + tc.Constraint_Name + ']' + ' UNIQUE CLUSTERED '  + CHAR(10)
																							   + '('  + CHAR(9) + LEFT(j.List, LEN(j.List) - 1) + CHAR(10) + ')' + CHAR(10) + c.list
                                                                                      END
            FROM sysobjects so
                 CROSS APPLY
            (
                SELECT CHAR(9) + '[' + column_name + '] ' + '[' + data_type + ']' + CASE data_type
				                                                                         WHEN 'ntext'
																						 THEN ''
                                                                                         WHEN 'sql_variant'
                                                                                         THEN ''
                                                                                         WHEN 'text'
                                                                                         THEN ''
                                                                                         WHEN 'decimal'
                                                                                         THEN '(' + CAST(numeric_precision AS VARCHAR) + ', ' + CAST(numeric_scale AS VARCHAR) + ')'
                                                                                         ELSE COALESCE('(' + CASE
                                                                                                                 WHEN character_maximum_length = -1
                                                                                                                 THEN 'MAX'
							
                                                                                                                 ELSE CAST(character_maximum_length AS VARCHAR)
                                                                                                             END + ')', '')
																						 
                                                                                     END + ' ' + CASE
                                                                                                     WHEN EXISTS
                (
                    SELECT id
                    FROM syscolumns
                    WHERE OBJECT_NAME(id) = so.name
                          AND name = column_name
                          AND COLUMNPROPERTY(id, name, 'IsIdentity') = 1
                )
                                                                                                     THEN 'IDENTITY(' + CAST(IDENT_SEED(so.name) AS VARCHAR) + ',' + CAST(IDENT_INCR(so.name) AS VARCHAR) + ')'
                                                                                                     ELSE ''
                                                                                                 END + '' + (CASE
                                                                                                                 WHEN IS_NULLABLE = 'No'
                                                                                                                 THEN ' NOT '
                                                                                                                 ELSE ''
                                                                                                             END) + 'NULL' + CASE
                                                                                                                                 WHEN information_schema.columns.COLUMN_DEFAULT IS NOT NULL
                                                                                                                                 THEN ' DEFAULT ' + information_schema.columns.COLUMN_DEFAULT
                                                                                                                                 ELSE ''
                                                                                                                             END + ',' + CHAR(10)
                FROM information_schema.columns
                WHERE table_name = so.name
                ORDER BY ordinal_position FOR XML PATH('')
            ) o(list)
                 LEFT JOIN information_schema.table_constraints tc ON tc.Table_name = so.Name
                                                                      AND tc.Constraint_Type in ('PRIMARY KEY','UNIQUE')
                 CROSS APPLY
            ( 


                SELECT + CHAR(10) + CHAR(9) +'[' + Column_Name  + '], '
                FROM information_schema.key_column_usage kcu
                WHERE kcu.Constraint_Name = tc.Constraint_Name
                ORDER BY ORDINAL_POSITION FOR XML PATH('')
		    ) j(list) 

			    CROSS APPLY
            ( 
				 SELECT 
				      + 'WITH (' +
                      CASE 
                           WHEN I.is_padded = 1 THEN ' PAD_INDEX = ON'
                           ELSE 'PAD_INDEX = OFF'
                      END + ',' +
               	   CASE 
                           WHEN ST.no_recompute = 0 THEN ' STATISTICS_NORECOMPUTE = OFF'
                           ELSE ' STATISTICS_NORECOMPUTE = ON'
                      END + ',' +
                      CASE 
                           WHEN I.ignore_dup_key = 1 THEN ' IGNORE_DUP_KEY = ON'
                           ELSE ' IGNORE_DUP_KEY = OFF'
                      END + ',' +
                      ' ONLINE = OFF' + ',' +
                      CASE 
                           WHEN I.allow_row_locks = 1 THEN ' ALLOW_ROW_LOCKS = ON'
                           ELSE ' ALLOW_ROW_LOCKS = OFF'
                      END + ',' +
                      CASE 
                           WHEN I.allow_page_locks = 1 THEN ' ALLOW_PAGE_LOCKS = ON'
                           ELSE ' ALLOW_PAGE_LOCKS = OFF'
                      END + ',' +
               	   case 
               	        when I.optimize_for_sequential_key = 1 THEN ' OPTIMIZE_FOR_SEQUENTIAL_KEY = ON'
               			else ' OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF'
               		END +
               	   ')' 
				   FROM   sys.indexes I
                      JOIN sys.tables T
                           ON  T.object_id = I.object_id
                      JOIN sys.sysindexes SI
                           ON  I.object_id = SI.id
                           AND I.index_id = SI.indid
                      JOIN (
                               SELECT *
                               FROM   (
                                          SELECT IC2.object_id,
                                                 IC2.index_id,
                                                 STUFF(
                                                     (
                                                         SELECT ',' + CHAR(9) + CHAR(10) + CHAR(9) + '[' + C.name + CASE 
                                                                                      WHEN MAX(CONVERT(INT, IC1.is_descending_key)) 
                                                                                           = 1 THEN 
                                                                                           ']' +' DESC'
                                                                                      ELSE 
                                                                                           ']' + ' ASC' 
                                                                                 END
                                                         FROM   sys.index_columns IC1
                                                                JOIN sys.columns C
                                                                     ON  C.object_id = IC1.object_id
                                                                     AND C.column_id = IC1.column_id
                                                                     AND IC1.is_included_column = 
                                                                         0
                                                         WHERE  IC1.object_id = IC2.object_id
                                                                AND IC1.index_id = IC2.index_id
                                                         GROUP BY
                                                                IC1.object_id,
                                                                C.name,
                                                                index_id
                                                         ORDER BY
                                                                MAX(IC1.key_ordinal) 
                                                                FOR XML PATH('')
                                                     ),
                                                     1,
                                                     2,
                                                     ''
                                                 ) KeyColumns
                                          FROM   sys.index_columns IC2 
                                          GROUP BY
                                                 IC2.object_id,
                                                 IC2.index_id
                                      ) tmp3
                           )tmp4
                           ON  I.object_id = tmp4.object_id
                           AND I.Index_id = tmp4.index_id
                      JOIN sys.stats ST
                           ON  ST.object_id = I.object_id
                           AND ST.stats_id = I.index_id
                      JOIN sys.data_spaces DS
                           ON  I.data_space_id = DS.data_space_id
                      JOIN sys.filegroups FG
                           ON  I.data_space_id = FG.data_space_id
               		  join information_schema.table_constraints tc
               		    on tc.TABLE_NAME = T.name	
            ) c(list)
			

-- we get "create" results for indexes

     INSERT INTO #indexes
         SELECT 
'dbo.' + T.name,
'CREATE ' +
       CASE 
            WHEN I.is_unique = 1 THEN 'UNIQUE '
            ELSE ''
       END +
       I.type_desc COLLATE DATABASE_DEFAULT + ' INDEX ' +
       '[' + I.name +']' + ' ON ' +
       '['+SCHEMA_NAME(T.schema_id) + ']'+'.'+'[' + T.name + ']' + CHAR(10) +
	   '( ' +  CHAR(9) +
        KeyColumns + CHAR(10) +
	   ')  ' + CHAR(10) +
       ISNULL('INCLUDE (['+ IncludedColumns +') ', '') + 
       ISNULL(' WHERE  ' + I.filter_definition, '') + 'WITH (' +
       CASE 
            WHEN I.is_padded = 1 THEN ' PAD_INDEX = ON'
            ELSE 'PAD_INDEX = OFF'
       END + ',' + 
	   CASE 
            WHEN ST.no_recompute = 0 THEN ' STATISTICS_NORECOMPUTE = OFF'
            ELSE ' STATISTICS_NORECOMPUTE = ON'
       END + ',' +
       ' SORT_IN_TEMPDB = OFF' + ',' +
       CASE 
            WHEN I.ignore_dup_key = 1 THEN ' IGNORE_DUP_KEY = ON'
            ELSE ' IGNORE_DUP_KEY = OFF'
       END + ',' +
       ' ONLINE = OFF' + ',' +
       CASE 
            WHEN I.allow_row_locks = 1 THEN ' ALLOW_ROW_LOCKS = ON'
            ELSE ' ALLOW_ROW_LOCKS = OFF'
       END + ',' +
       CASE 
            WHEN I.allow_page_locks = 1 THEN ' ALLOW_PAGE_LOCKS = ON'
            ELSE ' ALLOW_PAGE_LOCKS = OFF'
       END + ',' +
	   case -- remove this option if you are using version lowers than 2019
	        when I.optimize_for_sequential_key = 1 THEN ' OPTIMIZE_FOR_SEQUENTIAL_KEY = ON' 
			else ' OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF'
		END +
	   ') ON [' +
       DS.name + ']' + ';' [CreateIndexScript]
FROM   sys.indexes I
       JOIN sys.tables T
            ON  T.object_id = I.object_id
       JOIN sys.sysindexes SI
            ON  I.object_id = SI.id
            AND I.index_id = SI.indid
       JOIN (
                SELECT *
                FROM   (
                           SELECT IC2.object_id,
                                  IC2.index_id,
                                  STUFF(
                                      (
                                          SELECT ',' + CHAR(9) + CHAR(10) + CHAR(9) + '[' + C.name + CASE 
                                                                       WHEN MAX(CONVERT(INT, IC1.is_descending_key)) 
                                                                            = 1 THEN 
                                                                            ']' +' DESC'
                                                                       ELSE 
                                                                            ']' + ' ASC' 
                                                                  END
                                          FROM   sys.index_columns IC1
                                                 JOIN sys.columns C
                                                      ON  C.object_id = IC1.object_id
                                                      AND C.column_id = IC1.column_id
                                                      AND IC1.is_included_column = 
                                                          0
                                          WHERE  IC1.object_id = IC2.object_id
                                                 AND IC1.index_id = IC2.index_id
                                          GROUP BY
                                                 IC1.object_id,
                                                 C.name,
                                                 index_id
                                          ORDER BY
                                                 MAX(IC1.key_ordinal) 
                                                 FOR XML PATH('')
                                      ),
                                      1,
                                      2,
                                      ''
                                  ) KeyColumns
                           FROM   sys.index_columns IC2 
                           GROUP BY
                                  IC2.object_id,
                                  IC2.index_id
                       ) tmp3
            )tmp4
            ON  I.object_id = tmp4.object_id
            AND I.Index_id = tmp4.index_id
       JOIN sys.stats ST
            ON  ST.object_id = I.object_id
            AND ST.stats_id = I.index_id
       JOIN sys.data_spaces DS
            ON  I.data_space_id = DS.data_space_id
       JOIN sys.filegroups FG
            ON  I.data_space_id = FG.data_space_id
       LEFT JOIN (
                SELECT *
                FROM   (
                           SELECT IC2.object_id,
                                  IC2.index_id,
                                  STUFF(
                                      (
                                          SELECT ',' + '[' + C.name + ']'
                                          FROM   sys.index_columns IC1
                                                 JOIN sys.columns C
                                                      ON  C.object_id = IC1.object_id
                                                      AND C.column_id = IC1.column_id
                                                      AND IC1.is_included_column = 
                                                          1
                                          WHERE  IC1.object_id = IC2.object_id
                                                 AND IC1.index_id = IC2.index_id
                                          GROUP BY
                                                 IC1.object_id,
                                                 C.name,
                                                 index_id
                                                 FOR XML PATH('')
                                      ),
                                      1,
                                      2,
                                      ''
                                  ) IncludedColumns
                           FROM   sys.index_columns IC2 
                           GROUP BY
                                  IC2.object_id,
                                  IC2.index_id
                       ) tmp1
                WHERE  IncludedColumns IS NOT NULL
            ) tmp2
            ON  tmp2.object_id = I.object_id
            AND tmp2.index_id = I.index_id
WHERE  I.is_primary_key = 0
       AND I.is_unique_constraint = 0

     --we get data for filegroups

	 SELECT 'dbo.' + o.[name] table_name, o.[type] table_type, i.[name] index_name, i.[index_id], f.[name] file_name 
     into
	 #filegroups
     FROM sys.indexes i
     INNER JOIN sys.filegroups f
     ON i.data_space_id = f.data_space_id
     INNER JOIN sys.all_objects o
     ON i.[object_id] = o.[object_id] WHERE i.data_space_id = f.data_space_id
     AND o.type = 'U' -- User Created Tables
     order by f.name
     
	

	 --we get creation dates of objects in order to sort them by date


	 SELECT
        'dbo.'+[name] as [table_name]
       ,create_date
       ,modify_date
    into #create_dates
    FROM
        sys.tables

      --select * from #create_dates

	 
--here we join temp tables in order to get final creation scripts	 
	 
	 SELECT distinct(t.table_name), 
            REPLACE(t.create_table, 'NULL,'  + CHAR(10) + ')', 'NULL'  + CHAR(10) + ')') + ' ON ' + '[' + f.file_name + '];' as create_table, 
            REPLACE(i.create_index, ' ( ' + CHAR(10) +  CHAR(9) +'[ ', ' ( ' + CHAR(10) +  CHAR(9) +'[') as create_index,
			c.create_date
     FROM #tables t
	 LEfT JOIN #indexes i 
	      ON t.table_name = i.table_name,
	      #filegroups f,
		   #create_dates c
     WHERE
	         t.table_name = f.table_name
	   and t.table_name = c.table_name
	   and f.index_id <> 2
	 order by c.create_date
  
  

--drop all temp tables

	 DROP TABLE #filegroups;
	 DROP TABLE #tables;
     DROP TABLE #indexes;
	 DROP TABLE #create_dates;
GO


