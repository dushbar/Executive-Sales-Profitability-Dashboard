/* ============================================================
   Executive Sales / Profitability Dashboard
   Database + Schema + Table Creation Script
   ============================================================ */

-- Create database
IF DB_ID('ExecutiveSalesProfitability') IS NULL
BEGIN
    CREATE DATABASE ExecutiveSalesProfitability;
END;
GO

USE ExecutiveSalesProfitability;
GO

-- Create schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dim')
    EXEC('CREATE SCHEMA dim');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'fact')
    EXEC('CREATE SCHEMA fact');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO



--Drop tables if exist
--DROP TABLE IF EXISTS fact.sales;
--DROP TABLE IF EXISTS dim.ship_mode;
--DROP TABLE IF EXISTS dim.geography;
--DROP TABLE IF EXISTS dim.product;
--DROP TABLE IF EXISTS dim.customer;
--DROP TABLE IF EXISTS dim.date;
--GO

--Add primary key on date table
IF (OBJECT_ID('dim.PK_dim_date', 'PK') IS NOT NULL)
BEGIN
    ALTER TABLE dim.date DROP CONSTRAINT PK_dim_date
END

ALTER TABLE dim.date ADD CONSTRAINT PK_dim_date PRIMARY KEY (date_key);

--Add primary key on customer table
IF (OBJECT_ID('dim.PK_dim_customer', 'PK') IS NOT NULL)
BEGIN
    ALTER TABLE dim.customer DROP CONSTRAINT PK_dim_customer
END

ALTER TABLE dim.customer ADD CONSTRAINT PK_dim_customer PRIMARY KEY (customer_key);


--Add primary key on product table
IF (OBJECT_ID('dim.PK_dim_product', 'PK') IS NOT NULL)
BEGIN
    ALTER TABLE dim.product DROP CONSTRAINT PK_dim_product
END

ALTER TABLE dim.product ADD CONSTRAINT PK_dim_product PRIMARY KEY (product_key)


--Add primary key on geography table
IF (OBJECT_ID('dim.PK_dim_geography','PK') IS NOT NULL)
BEGIN
    ALTER TABLE dim.geography DROP CONSTRAINT PK_dim_geography
END

ALTER TABLE dim.geography ADD CONSTRAINT PK_dim_geography PRIMARY KEY (geography_key)



--Add primary key on ship_mode table
IF (OBJECT_ID('dim.PK_dim_ship_mode','PK') IS NOT NULL)
BEGIN
    ALTER TABLE dim.ship_mode DROP CONSTRAINT PK_dim_ship_mode
END

ALTER TABLE dim.ship_mode ADD CONSTRAINT PK_dim_ship_mode PRIMARY KEY (ship_mode_key)



--Add Primary key on fact.sales table
IF (OBJECT_ID('dim.PK_fact_sales','PK') IS NOT NULL)
BEGIN
    ALTER TABLE fact.sales DROP CONSTRAINT PK_fact_sales
END

ALTER TABLE fact.sales ADD CONSTRAINT PK_fact_sales PRIMARY KEY (sales_key)



--Add foreign key on fact.sales table for order_date referencing
--dim.date table
ALTER TABLE fact.sales ADD CONSTRAINT FK_fact_sales_order_date 
FOREIGN KEY(order_date_key) REFERENCES dim.date(date_key);

--Add foreign key on fact.sales table for ship_date column referencing
--dim.date table
ALTER TABLE fact.sales ADD CONSTRAINT FK_fact_sales_ship_date 
        FOREIGN KEY(ship_date_key) REFERENCES dim.date(date_key);


ALTER TABLE fact.sales ADD CONSTRAINT FK_fact_sales_customer
        FOREIGN KEY (customer_key) REFERENCES dim.customer(customer_key);

ALTER TABLE fact.sales ADD CONSTRAINT FK_fact_sales_product
        FOREIGN KEY (product_key) REFERENCES dim.product(product_key);

ALTER TABLE fact.sales ADD CONSTRAINT FK_fact_sales_geography
        FOREIGN KEY (geography_key) REFERENCES dim.geography(geography_key);

ALTER TABLE fact.sales ADD CONSTRAINT FK_fact_sales_ship_mode
        FOREIGN KEY (ship_mode_key) REFERENCES dim.ship_mode(ship_mode_key);



--CREATE Indexes
CREATE INDEX IX_fact_sales_order_date_key
ON fact.sales(order_date_key);
GO

CREATE INDEX IX_fact_sales_customer_key
ON fact.sales(customer_key);
GO

CREATE INDEX IX_fact_sales_product_key
ON fact.sales(product_key);
GO

CREATE INDEX IX_fact_sales_geography_key
ON fact.sales(geography_key);
GO

CREATE INDEX IX_fact_sales_ship_mode_key
ON fact.sales(ship_mode_key);
GO

CREATE INDEX IX_fact_sales_order_id
ON fact.sales(order_id);
GO


--VALIDATION Check for the imported tables

-- Row counts
SELECT 'dim.date' AS table_name, COUNT(*) AS row_count FROM dim.date
UNION ALL
SELECT 'dim.customer', COUNT(*) FROM dim.customer
UNION ALL
SELECT 'dim.product', COUNT(*) FROM dim.product
UNION ALL
SELECT 'dim.geography', COUNT(*) FROM dim.geography
UNION ALL
SELECT 'dim.ship_mode', COUNT(*) FROM dim.ship_mode
UNION ALL
SELECT 'fact.sales', COUNT(*) FROM fact.sales;
GO


--Check for missing foreign keys
SELECT
    SUM(CASE WHEN order_date_key IS NULL THEN 1 ELSE 0 END) AS missing_order_date_key,
    SUM(CASE WHEN ship_date_key IS NULL THEN 1 ELSE 0 END) AS missing_ship_date_key,
    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END) AS missing_customer_key,
    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END) AS missing_product_key,
    SUM(CASE WHEN geography_key IS NULL THEN 1 ELSE 0 END) AS missing_geography_key,
    SUM(CASE WHEN ship_mode_key IS NULL THEN 1 ELSE 0 END) AS missing_ship_mode_key
FROM fact.sales;
GO

--Check sales/profit totals
SELECT
    COUNT(*) AS fact_rows,
    SUM(sales) AS total_sales,
    SUM(profit) AS total_profit,
    SUM(quantity) AS total_quantity,
    AVG(discount) AS avg_discount
FROM fact.sales;
GO


--Check fact-to-dimension joins
SELECT TOP 20
    fs.sales_key,
    fs.order_id,
    od.[date] AS order_date,
    sd.[date] AS ship_date,
    c.customer_name,
    c.segment,
    p.product_name,
    p.category,
    p.sub_category,
    g.country,
    g.region,
    g.[state],
    g.city,
    sm.ship_mode,
    fs.sales,
    fs.quantity,
    fs.discount,
    fs.profit
FROM fact.sales fs
LEFT JOIN dim.date od
    ON fs.order_date_key = od.date_key
LEFT JOIN dim.date sd
    ON fs.ship_date_key = sd.date_key
LEFT JOIN dim.customer c
    ON fs.customer_key = c.customer_key
LEFT JOIN dim.product p
    ON fs.product_key = p.product_key
LEFT JOIN dim.geography g
    ON fs.geography_key = g.geography_key
LEFT JOIN dim.ship_mode sm
    ON fs.ship_mode_key = sm.ship_mode_key;
GO



--Check for orphan fact rows
SELECT COUNT(*) AS orphan_customer_rows
FROM fact.sales fs
LEFT JOIN dim.customer c
    ON fs.customer_key = c.customer_key
WHERE fs.customer_key IS NOT NULL
  AND c.customer_key IS NULL;
GO

SELECT COUNT(*) AS orphan_product_rows
FROM fact.sales fs
LEFT JOIN dim.product p
    ON fs.product_key = p.product_key
WHERE fs.product_key IS NOT NULL
  AND p.product_key IS NULL;
GO

SELECT COUNT(*) AS orphan_geography_rows
FROM fact.sales fs
LEFT JOIN dim.geography g
    ON fs.geography_key = g.geography_key
WHERE fs.geography_key IS NOT NULL
  AND g.geography_key IS NULL;
GO


