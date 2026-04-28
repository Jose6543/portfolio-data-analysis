-- ============================================
-- DATA CLEANING PIPELINE
-- Author : Jose Vargas
-- Purpose: Clean raw data before loading to Power BI
-- ============================================


-- 1. REMOVE DUPLICATES
-- Keep only the first occurrence based on id
WITH duplicates AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY id
      ORDER BY created_at DESC
    ) AS row_num
  FROM raw_data
)
DELETE FROM duplicates WHERE row_num > 1;


-- 2. REMOVE NULL / EMPTY ROWS
DELETE FROM raw_data
WHERE id IS NULL
   OR name IS NULL
   OR TRIM(name) = '';


-- 3. STANDARDIZE TEXT (trim spaces, uppercase)
UPDATE raw_data
SET
  name    = UPPER(TRIM(name)),
  city    = UPPER(TRIM(city)),
  country = UPPER(TRIM(country));


-- 4. STANDARDIZE DATE FORMAT
-- Convert from DD/MM/YYYY text to proper DATE
UPDATE raw_data
SET date_column = CONVERT(DATE, date_column, 103)
WHERE ISDATE(date_column) = 1;


-- 5. FIX NEGATIVE / INVALID NUMBERS
UPDATE raw_data
SET amount = ABS(amount)
WHERE amount < 0;


-- 6. CREATE CLEAN OUTPUT TABLE
SELECT
  id,
  name,
  city,
  country,
  CAST(date_column AS DATE)    AS clean_date,
  ROUND(amount, 2)             AS clean_amount
INTO clean_data
FROM raw_data
WHERE id IS NOT NULL
  AND name IS NOT NULL;
