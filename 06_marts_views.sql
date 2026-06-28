-- ============================================================
-- Layer 3 — ANALYTICAL MARTS
-- Business-ready views built exclusively from the star schema
-- (dim_* / fact_sales) — never from staging or source tables.
-- This is the layer a BI tool (Power BI, Tableau, Streamlit)
-- would connect to directly.
-- ============================================================

USE retail_dw;

-- ------------------------------------------------------------
-- mart_monthly_revenue
-- Monthly revenue, margin, and order count, by store
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW mart_monthly_revenue AS
SELECT
    dd.year,
    dd.month_number,
    dd.month_name,
    ds.store_name,
    ds.region,
    COUNT(DISTINCT f.order_id) AS num_orders,
    SUM(f.line_revenue) AS total_revenue,
    SUM(f.line_margin) AS total_margin,
    ROUND(SUM(f.line_margin) * 100.0 / SUM(f.line_revenue), 1) AS margin_pct
FROM fact_sales f
JOIN dim_date dd ON f.date_key = dd.date_key
JOIN dim_store ds ON f.store_key = ds.store_key
WHERE f.is_returned = 0
GROUP BY dd.year, dd.month_number, dd.month_name, ds.store_name, ds.region;

-- ------------------------------------------------------------
-- mart_customer_cohorts
-- Cohort analysis: customers grouped by signup month, tracking
-- their cumulative revenue contribution over time.
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW mart_customer_cohorts AS
SELECT
    DATE_FORMAT(dc.signup_date, '%Y-%m') AS cohort_month,
    dd.year AS order_year,
    dd.month_number AS order_month,
    COUNT(DISTINCT dc.customer_id) AS active_customers,
    SUM(f.line_revenue) AS cohort_revenue
FROM fact_sales f
JOIN dim_customer dc ON f.customer_key = dc.customer_key
JOIN dim_date dd ON f.date_key = dd.date_key
WHERE f.is_returned = 0
GROUP BY cohort_month, dd.year, dd.month_number
ORDER BY cohort_month, order_year, order_month;

-- ------------------------------------------------------------
-- mart_product_performance
-- Revenue, margin, and return rate per product / category
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW mart_product_performance AS
SELECT
    dp.category_name,
    dp.product_name,
    SUM(f.quantity) AS units_sold,
    SUM(f.line_revenue) AS total_revenue,
    SUM(f.line_margin) AS total_margin,
    ROUND(SUM(f.line_margin) * 100.0 / SUM(f.line_revenue), 1) AS margin_pct,
    SUM(f.is_returned) AS units_returned,
    ROUND(SUM(f.is_returned) * 100.0 / COUNT(*), 2) AS return_rate_pct
FROM fact_sales f
JOIN dim_product dp ON f.product_key = dp.product_key
GROUP BY dp.category_name, dp.product_name;

-- ------------------------------------------------------------
-- mart_employee_performance
-- Sales ranking per employee, with store context
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW mart_employee_performance AS
SELECT
    de.full_name AS employee_name,
    de.role,
    ds.store_name,
    COUNT(DISTINCT f.order_id) AS orders_handled,
    SUM(f.line_revenue) AS total_sales,
    RANK() OVER (ORDER BY SUM(f.line_revenue) DESC) AS sales_rank
FROM fact_sales f
JOIN dim_employee de ON f.employee_key = de.employee_key
JOIN dim_store ds ON de.store_key = ds.store_key
WHERE f.is_returned = 0
GROUP BY de.full_name, de.role, ds.store_name;

-- ------------------------------------------------------------
-- mart_customer_geography
-- Active customer count and revenue by current city
-- (uses only is_current = 1 rows: where customers live TODAY,
--  not where they lived when each historical order was placed)
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW mart_customer_geography AS
SELECT
    dc.city,
    COUNT(DISTINCT dc.customer_id) AS num_customers,
    SUM(f.line_revenue) AS total_revenue
FROM dim_customer dc
LEFT JOIN fact_sales f ON dc.customer_key = f.customer_key AND f.is_returned = 0
WHERE dc.is_current = 1
GROUP BY dc.city
ORDER BY total_revenue DESC;
