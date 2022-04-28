USE [master];
/****** Script for SelectTopNRows command from SSMS  ******/
SELECT TOP (1000) [ID_VAR]
      ,[SEQ_VAR]
      ,[EMPTY_STR_VAR]
      ,[NULL_VAR]
      ,[NA_STR_VAR]
      ,[NUM_VAR]
      ,[DATE_VAR1]
      ,[DATE_VAR2]
  FROM [master].[dbo].[CURRENT_TABLE]

---- 1) COALESCE() to recode the NULL value to the character string MISSING
SELECT 
    ID_VAR, 
    NULL_VAR,
	EMPTY_STR_VAR,
    COALESCE(NULL_VAR, 'MISSING')  AS RECODE_NULL_VAR, 
	COALESCE(EMPTY_STR_VAR, 'MISSING') AS RECODE_EMPTY_VAR 
FROM  
  CURRENT_TABLE    
ORDER BY ID_VAR;


--- However, COALESCE() NOT WORK for Empty or NA string, instead, use CASE WHEN
SELECT 
  ID_VAR, 
  EMPTY_STR_VAR, 
  -- EMPTY_STR_VAR: empty string/blank space
  -- NA_STR_VAR: a character value 'NA'
  COALESCE(EMPTY_STR_VAR, 'MISSING') AS COALESCE_EMPTY_STR_VAR, 

  CASE WHEN EMPTY_STR_VAR = '' THEN 'EMPTY_MISSING' END AS CASEWHEN_EMPTY_STR_VAR,   
  NA_STR_VAR, 
  COALESCE(NA_STR_VAR, 'NA_MISSING') AS COALESCE_NA_STR_VAR, 

  CASE WHEN NA_STR_VAR = 'NA' THEN 'NA_MISSING' END AS CASEWHEN_NA_STR_VAR
FROM 
  CURRENT_TABLE 
ORDER BY ID_VAR;


--- 2) Running total/frequency
-- to solve this, divide the task into two steps: 
-- step1: we need to calculate the cumulative sum prior to the current row; -- SQL command ROW UNBOUNDED PRECEDING 
-- step2: we need to calculate the total sum
SELECT *
  FROM [master].[dbo].[CURRENT_TABLE]

SELECT 
	T.*,
	SUM(NUM_VAR) OVER (ORDER BY NUM_VAR ROWS UNBOUNDED PRECEDING) AS CUM_SUM, 
	CASE WHEN ID_VAR IS NOT NULL THEN '1' END AS JOIN_ID
FROM CURRENT_TABLE    T
WHERE ID_VAR = '19228';

-- put the two parts together:
SELECT 
  DAT.NUM_VAR, 
  SUM(NUM_VAR) OVER (PARTITION BY JOIN_ID) AS TOTAL_SUM, 
  ROUND(CUM_SUM / SUM(NUM_VAR) OVER (PARTITION BY JOIN_ID), 4) AS CUM_FREQ
FROM 
(
  SELECT 
	 T.*, 
	 SUM(NUM_VAR) OVER (ORDER BY NUM_VAR ROWS UNBOUNDED PRECEDING) AS CUM_SUM, 
	 CASE WHEN ID_VAR IS NOT NULL THEN '1' END AS JOIN_ID
  FROM CURRENT_TABLE    T
) DAT 	
--WHERE  ID_VAR = '19228' 
ORDER BY CUM_FREQ;

--- 3) Find the record having a number calculated by analytic functions (e.g., MAX) without self-joining 
SELECT *
  FROM [master].[dbo].[CURRENT_TABLE]

SELECT 
	Dat1.*, 
	Dat2.MAX_NUM_VAR
FROM CURRENT_TABLE  Dat1
INNER JOIN 
(
	SELECT 
		ID_VAR, 
		MAX(NUM_VAR) AS MAX_NUM_VAR
	FROM CURRENT_TABLE 
	GROUP BY ID_VAR
) Dat2 ON Dat1.ID_VAR = Dat2.ID_VAR and Dat1.NUM_VAR = Dat2.MAX_NUM_VAR
ORDER BY ID_VAR;

-- now, let's look at a more concise way, 
SELECT *
FROM 
(
  SELECT 
    DAT.*, 
    CASE WHEN (NUM_VAR = MAX(NUM_VAR) OVER (PARTITION BY ID_VAR)) THEN 'Y' ELSE 'N' END AS MAX_NUM_IND
  FROM 
    CURRENT_TABLE     DAT
) DAT2
WHERE MAX_NUM_IND = 'Y'
ORDER BY ID_VAR;

-- 4) Conditional where clause:
--— if SEQ_VAR in (1, 2, 3) & diff(DATE_VAR2, DATE_VAR1)? 0
--— elif SEQ_VAR in (4, 5, 6) & diff(DATE_VAR2, DATE_VAR1) ?1
--— else diff(DATE_VAR2, DATE_VAR1) ?2
SELECT *
  FROM [master].[dbo].[CURRENT_TABLE];

SELECT 
  DAT.*,
  DATEDIFF(day, DATE_VAR1, DATE_VAR2) AS LAG_IN_DATES
FROM 
  CURRENT_TABLE      DAT 
WHERE
  DATEDIFF(day, DATE_VAR1, DATE_VAR2) >= CASE WHEN SEQ_VAR IN (1, 2, 3) THEN 0 WHEN SEQ_VAR IN (4, 5, 6) THEN 1 ELSE 2 END
ORDER BY ID_VAR, SEQ_VAR;

-- Datatable name: LongData
SELECT *
FROM [Master].[Dbo].[LongData]
ORDER BY Id_var, Date_var;

-- 5) Lag() and Lead() to work with consecutive rows
-- Lag(): looking at the previous row;
-- Lead(): looking at the new row; 
-- * Task: difference in money spent comparing two consecutive logins for each customer;
SELECT 
	Dat.*, 
	Dat.num_var - Dat.Prev_Num AS Num_Diff
FROM 
(
	SELECT 
		mytab.*, 
		LAG(num_var, 1, 0) OVER (PARTITION BY id_var ORDER BY date_var) AS Prev_Num        
	FROM 
		[Master].[Dbo].[LongData]  Mytab
) Dat
ORDER BY id_var, date_var;



-- 6) ROW_NUMBER() to handle the infamous "TOP N" problems
-- * Task: select the top 3 records with the most money spent for each ID
SELECT 
  dat.*
FROM 
(
  SELECT 
	ROW_NUMBER() OVER (PARTITION BY id_var ORDER BY num_var DESC) AS RowNum_Var, 
    tab.*
  FROM [Master].[Dbo].[LongData]	tab	
)	dat
WHERE RowNum_var <= 3
ORDER BY id_var, RowNum_var


-- 7) WITH statement to keep it DRY: Don't Repeat Yourself
-- WITH Common Table Expression(CTE in short) = temporary named result table
WITH rownumtab AS
(
	SELECT 
	ROW_NUMBER() OVER (PARTITION BY id_var ORDER BY num_var DESC) AS RowNum_Var, 
    tab.*
	FROM [Master].[Dbo].[LongData]	tab	
)
SELECT *
FROM 
	rownumtab
WHERE RowNum_var <= 3
ORDER BY id_var, RowNum_Var


-- 8) Concatenating to re-format your data structure
-- *Task: create an aggregated report for our internal stakeholders, showing the dates each customer logged in. 
-- many-to-many aggregation
SELECT
  id_var,
  gen_var,  
  STRING_AGG(date_var, ',') WITHIN GROUP (ORDER BY date_var) AS concat_dates  
FROM
  [Master].[Dbo].[LongData]
GROUP BY id_var, gen_var
ORDER BY id_var


-- 9) Regular expression in SQL 
-- *Task: select all possible Female records, including the ones with typos;
SELECT *
FROM LongData
WHERE Gen_var LIKE '%[e][a-z]%[e]'


-- 10) Integrate SQL with Python
-- The prerequisite of integrating SQL queries into Python is to establish the database connections via ODBC or JDBC. 


