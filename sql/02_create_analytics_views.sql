--1. Executive KPI view
CREATE OR ALTER VIEW analytics.vw_executive_kpis AS
SELECT
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin,
    CAST(SUM(fs.sales) / NULLIF(COUNT(DISTINCT fs.order_id), 0) AS DECIMAL(18,4)) AS avg_order_value
FROM fact.sales fs;
GO



--2. Monthly Sales and Profit Trend
CREATE OR ALTER VIEW analytics.vw_monthly_sales_profit AS
SELECT
    d.[year],
    d.[month],
    d.month_name,
    DATEFROMPARTS(d.[year], d.[month], 1) AS month_start_date,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
JOIN dim.date d
    ON fs.order_date_key = d.date_key
GROUP BY
    d.[year],
    d.[month],
    d.month_name;
GO



--3. Category and sub-category profitability
CREATE OR ALTER VIEW analytics.vw_category_profitability AS
SELECT
    p.category,
    p.sub_category,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
JOIN dim.product p
    ON fs.product_key = p.product_key
GROUP BY
    p.category,
    p.sub_category;
GO



--4. Product profitability
CREATE OR ALTER VIEW analytics.vw_product_profitability AS
SELECT
    p.product_key,
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
JOIN dim.product p
    ON fs.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category;
GO



--5. Region and geography performance
CREATE OR ALTER VIEW analytics.vw_region_performance AS
SELECT
    g.country,
    g.region,
    g.[state],
    g.city,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
JOIN dim.geography g
    ON fs.geography_key = g.geography_key
GROUP BY
    g.country,
    g.region,
    g.[state],
    g.city;
GO



--6. Customer profitability
CREATE OR ALTER VIEW analytics.vw_customer_profitability AS
SELECT
    c.customer_key,
    c.customer_id,
    c.customer_name,
    c.segment,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin,
    CAST(SUM(fs.sales) / NULLIF(COUNT(DISTINCT fs.order_id), 0) AS DECIMAL(18,4)) AS avg_order_value
FROM fact.sales fs
JOIN dim.customer c
    ON fs.customer_key = c.customer_key
GROUP BY
    c.customer_key,
    c.customer_id,
    c.customer_name,
    c.segment;
GO



--7. Segment profitability
CREATE OR ALTER VIEW analytics.vw_segment_profitability AS
SELECT
    c.segment,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_id) AS total_customers,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin,
    CAST(SUM(fs.sales) / NULLIF(COUNT(DISTINCT fs.order_id), 0) AS DECIMAL(18,4)) AS avg_order_value
FROM fact.sales fs
JOIN dim.customer c
    ON fs.customer_key = c.customer_key
GROUP BY
    c.segment;
GO



--8. Discount impact view. Useful for profitability dashboard
CREATE OR ALTER VIEW analytics.vw_discount_impact AS
SELECT
    CASE
        WHEN fs.discount = 0 THEN 'No Discount'
        WHEN fs.discount > 0 AND fs.discount <= 0.10 THEN '0-10%'
        WHEN fs.discount > 0.10 AND fs.discount <= 0.20 THEN '10-20%'
        WHEN fs.discount > 0.20 AND fs.discount <= 0.30 THEN '20-30%'
        WHEN fs.discount > 0.30 AND fs.discount <= 0.50 THEN '30-50%'
        ELSE '50%+'
    END AS discount_band,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
GROUP BY
    CASE
        WHEN fs.discount = 0 THEN 'No Discount'
        WHEN fs.discount > 0 AND fs.discount <= 0.10 THEN '0-10%'
        WHEN fs.discount > 0.10 AND fs.discount <= 0.20 THEN '10-20%'
        WHEN fs.discount > 0.20 AND fs.discount <= 0.30 THEN '20-30%'
        WHEN fs.discount > 0.30 AND fs.discount <= 0.50 THEN '30-50%'
        ELSE '50%+'
    END;
GO



--9. Shipping performance view
CREATE OR ALTER VIEW analytics.vw_shipping_performance AS
SELECT
    sm.ship_mode,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    COUNT(*) AS total_order_lines,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(DATEDIFF(DAY, od.[date], sd.[date])) AS avg_shipping_days,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
JOIN dim.ship_mode sm
    ON fs.ship_mode_key = sm.ship_mode_key
LEFT JOIN dim.date od
    ON fs.order_date_key = od.date_key
LEFT JOIN dim.date sd
    ON fs.ship_date_key = sd.date_key
GROUP BY
    sm.ship_mode;
GO



--10. Product Pareto view
--Identifies which products contribute most to sales
CREATE OR ALTER VIEW analytics.vw_product_pareto AS
WITH product_sales AS (
    SELECT
        p.product_key,
        p.product_id,
        p.product_name,
        p.category,
        p.sub_category,
        SUM(fs.sales) AS total_sales,
        SUM(fs.profit) AS total_profit
    FROM fact.sales fs
    JOIN dim.product p
        ON fs.product_key = p.product_key
    GROUP BY
        p.product_key,
        p.product_id,
        p.product_name,
        p.category,
        p.sub_category
),
ranked AS (
    SELECT
        *,
        SUM(total_sales) OVER () AS grand_total_sales,
        SUM(total_sales) OVER (
            ORDER BY total_sales DESC
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cumulative_sales
    FROM product_sales
)
SELECT
    product_key,
    product_id,
    product_name,
    category,
    sub_category,
    total_sales,
    total_profit,
    CAST(total_profit / NULLIF(total_sales, 0) AS DECIMAL(18,4)) AS profit_margin,
    CAST(cumulative_sales / NULLIF(grand_total_sales, 0) AS DECIMAL(18,4)) AS cumulative_sales_pct,
    CASE
        WHEN cumulative_sales / NULLIF(grand_total_sales, 0) <= 0.80 THEN 'Top 80% Sales Contributors'
        ELSE 'Remaining Products'
    END AS pareto_group
FROM ranked;
GO



--11. Loss-making products view
CREATE OR ALTER VIEW analytics.vw_loss_making_products AS
SELECT
    p.product_key,
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category,
    COUNT(DISTINCT fs.order_id) AS total_orders,
    SUM(fs.sales) AS total_sales,
    SUM(fs.profit) AS total_profit,
    SUM(fs.quantity) AS total_quantity,
    AVG(fs.discount) AS avg_discount,
    CAST(SUM(fs.profit) / NULLIF(SUM(fs.sales), 0) AS DECIMAL(18,4)) AS profit_margin
FROM fact.sales fs
JOIN dim.product p
    ON fs.product_key = p.product_key
GROUP BY
    p.product_key,
    p.product_id,
    p.product_name,
    p.category,
    p.sub_category
HAVING SUM(fs.profit) < 0;
GO



--12. Base reporting view for Power BI
--Gives one wide table for Power BI exploration
CREATE OR ALTER VIEW analytics.vw_sales_detail AS
SELECT
    fs.sales_key,
    fs.order_id,

    od.[date] AS order_date,
    od.[year] AS order_year,
    od.[quarter] AS order_quarter,
    od.[month] AS order_month,
    od.month_name AS order_month_name,

    sd.[date] AS ship_date,
    DATEDIFF(DAY, od.[date], sd.[date]) AS shipping_days,

    c.customer_id,
    c.customer_name,
    c.segment,

    p.product_id,
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
    fs.profit,
    CAST(fs.profit / NULLIF(fs.sales, 0) AS DECIMAL(18,4)) AS profit_margin
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



--Validation
--1.
SELECT 'vw_executive_kpis' AS view_name, COUNT(*) AS row_count FROM analytics.vw_executive_kpis
UNION ALL
SELECT 'vw_monthly_sales_profit', COUNT(*) FROM analytics.vw_monthly_sales_profit
UNION ALL
SELECT 'vw_category_profitability', COUNT(*) FROM analytics.vw_category_profitability
UNION ALL
SELECT 'vw_product_profitability', COUNT(*) FROM analytics.vw_product_profitability
UNION ALL
SELECT 'vw_region_performance', COUNT(*) FROM analytics.vw_region_performance
UNION ALL
SELECT 'vw_customer_profitability', COUNT(*) FROM analytics.vw_customer_profitability
UNION ALL
SELECT 'vw_segment_profitability', COUNT(*) FROM analytics.vw_segment_profitability
UNION ALL
SELECT 'vw_discount_impact', COUNT(*) FROM analytics.vw_discount_impact
UNION ALL
SELECT 'vw_shipping_performance', COUNT(*) FROM analytics.vw_shipping_performance
UNION ALL
SELECT 'vw_product_pareto', COUNT(*) FROM analytics.vw_product_pareto
UNION ALL
SELECT 'vw_loss_making_products', COUNT(*) FROM analytics.vw_loss_making_products
UNION ALL
SELECT 'vw_sales_detail', COUNT(*) FROM analytics.vw_sales_detail;


--Validation
--2
SELECT * FROM analytics.vw_executive_kpis;



--Validation
--3
SELECT TOP 20 *
FROM analytics.vw_sales_detail
ORDER BY order_date;


select * from dim.date