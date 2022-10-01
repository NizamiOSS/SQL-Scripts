

CREATE PROCEDURE [dbo].[GetDbCreation]
as

-- first we create table to store preliminary results

create table #db_create
(
file_id int IDENTITY(1,1) NOT NULL,
create_db nvarchar(1000)
)

--populate it with results of "select"

insert into #db_create (create_db)
select 

     'CREATE DATABASE' + ' ['+ DB_NAME(DB_ID()) + ']'
	 + ' ON PRIMARY'
	 from sys.database_files AS df
	 where df.file_id = 1
union all
select 
     case when fg.name is not null then 'FILEGROUP' + ' ['+ fg.name + ']' else 'LOG ON' end
	 + '( NAME = ' 
	 + 'N'
	 + '"' + df.name + '"' + ',' 
	 + ' FILENAME = ' 
	 + 'N' + 
	 + '"' + df.physical_name + '"'
	 + ',' 
	 + ' SIZE = ' 
	 + cast(df.size*8/1024 as varchar(10) )+'MB'
	 + ',' 
	 + ' MAXSIZE = '
	 + case when df.max_size = -1 then 'UNLIMITED' else cast(cast(df.max_size as bigint)*8/1024 as varchar(10) )+'MB' end
	 + ','  
	 + ' FILEGROWTH = ' 
	 + cast(df.growth*8/1024 as varchar(10) )+'MB'
	 + case when fg.name is not null then  ' ),' else  ' )' end
	 FROM sys.database_files AS df
LEFT JOIN sys.filegroups AS fg
ON df.data_space_id = fg.data_space_id


-- from here below we perform manipulations with temp tables in order to get clear, readable creation script of our current database

declare @nocomma1 nvarchar(1000)
declare @nocomma2 nvarchar(1000)



select top 1 @nocomma1 = create_db from #db_create
order by file_id


select  @nocomma2 = create_db from #db_create
where create_db like 'LOG%'


select * into #db_create2
from #db_create
where 1=2

insert into #db_create2 (create_db)
select REPLACE(REPLACE(create_db, '),',') '),'"','''') from #db_create
where create_db = @nocomma1
union all
select REPLACE(REPLACE(create_db, '"',''''), 'FILEGROUP [PRIMARY]', '')  from #db_create
where create_db not in (@nocomma1,@nocomma2)
union all
select REPLACE(REPLACE(create_db, '),',') '),'"','''') from #db_create
where create_db = @nocomma2


declare @filegroup nvarchar(1000)

select top 1 @filegroup = create_db from #db_create2
where create_db < (select max(create_db) from #db_create2)
order by file_id desc



update #db_create2
set create_db = REPLACE(@filegroup,' ),', ' )' )
where create_db = @filegroup




select create_db from #db_create2


-- in the end we drop the temp tables

drop table #db_create
drop table #db_create2
GO


