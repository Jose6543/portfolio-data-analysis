-- ============================================
-- DATA CLEANING PIPELINE — Ventas de Inmuebles
-- Author  : Jose Vargas
-- Source  : Inmuebles2.xlsx (México 2016–2020)
-- Purpose : Clean raw data before loading to Power BI
-- ============================================


-- STEP 0: Load raw data into staging table
-- (This assumes you imported the Excel into SQL Server)
-- Table: inmuebles_raw
-- Columns: Referencia, FechaAlta, Tip, Oper, Location,
--          Sup_M2, Precio_venta, Fventa, Vendedor, Estatus


-- ============================================
-- STEP 1: REMOVE DUPLICATES
-- Keep only the first record per Referencia
-- ============================================
WITH duplicados AS (
  SELECT *,
    ROW_NUMBER() OVER (
      PARTITION BY Referencia
      ORDER BY FechaAlta DESC
    ) AS row_num
  FROM inmuebles_raw
)
DELETE FROM duplicados WHERE row_num > 1;


-- ============================================
-- STEP 2: REMOVE NULL / EMPTY ROWS
-- Drop rows without Referencia or Location
-- ============================================
DELETE FROM inmuebles_raw
WHERE Referencia IS NULL
   OR TRIM(Location) = ''
   OR Location IS NULL;


-- ============================================
-- STEP 3: STANDARDIZE TEXT FIELDS
-- Trim spaces, normalize case
-- ============================================
UPDATE inmuebles_raw
SET
  Tip      = UPPER(TRIM(Tip)),
  Oper     = UPPER(TRIM(Oper)),
  Vendedor = UPPER(TRIM(Vendedor)),
  Estatus  = UPPER(TRIM(Estatus));


-- ============================================
-- STEP 4: SPLIT LOCATION COLUMN
-- Location format: "América Norte|México|Ciudad"
-- Extract País and Ciudad into separate columns
-- ============================================
ALTER TABLE inmuebles_raw
  ADD Pais  VARCHAR(100),
      Ciudad VARCHAR(100);

UPDATE inmuebles_raw
SET
  Pais   = TRIM(PARSENAME(REPLACE(Location, '|', '.'), 2)),
  Ciudad = TRIM(PARSENAME(REPLACE(Location, '|', '.'), 1));


-- ============================================
-- STEP 5: CLEAN PRECIO_VENTA
-- Remove "$" and "," symbols, convert to numeric
-- ============================================
ALTER TABLE inmuebles_raw
  ADD Precio_num DECIMAL(18,2);

UPDATE inmuebles_raw
SET Precio_num = TRY_CAST(
  REPLACE(REPLACE(Precio_venta, '$', ''), ',', '')
  AS DECIMAL(18,2)
);

-- Flag invalid prices
UPDATE inmuebles_raw
SET Precio_num = NULL
WHERE Precio_num <= 0;


-- ============================================
-- STEP 6: STANDARDIZE DATES
-- Ensure FechaAlta and Fventa are proper DATEs
-- ============================================
UPDATE inmuebles_raw
SET
  FechaAlta = TRY_CONVERT(DATE, FechaAlta),
  Fventa    = TRY_CONVERT(DATE, Fventa);


-- ============================================
-- STEP 7: STANDARDIZE ESTATUS VALUES
-- V = Vendida, P = En Proceso
-- ============================================
UPDATE inmuebles_raw
SET Estatus = CASE
  WHEN Estatus = 'V' THEN 'Vendida'
  WHEN Estatus = 'P' THEN 'En Proceso'
  ELSE 'Desconocido'
END;


-- ============================================
-- STEP 8: CREATE CLEAN OUTPUT TABLE
-- Ready to import into Power BI
-- ============================================
SELECT
  Referencia,
  CAST(FechaAlta AS DATE)  AS fecha_alta,
  Tip                       AS tipo_inmueble,
  Oper                      AS operacion,
  Pais,
  Ciudad,
  Sup_M2,
  Precio_num                AS precio_venta,
  CAST(Fventa AS DATE)     AS fecha_venta,
  Vendedor,
  Estatus
INTO inmuebles_clean
FROM inmuebles_raw
WHERE Referencia IS NOT NULL
  AND Precio_num IS NOT NULL;
