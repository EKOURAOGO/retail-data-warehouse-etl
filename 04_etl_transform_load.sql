-- ============================================================
-- ETL Step 2 — TRANSFORM & LOAD
-- Populates dim_date, the SCD1 dimensions, the SCD2 customer
-- dimension, and the fact table — all from the staging layer.
-- ============================================================

USE retail_dw;

-- ------------------------------------------------------------
-- 2.1 — dim_date: generate one row per calendar day of 2024
-- ------------------------------------------------------------
INSERT INTO dim_date (date_key, full_date, day_of_week, day_of_month,
                       month_number, month_name, quarter, year, is_weekend)
SELECT
    CAST(DATE_FORMAT(d, '%Y%m%d') AS UNSIGNED) AS date_key,
    d AS full_date,
    DAYNAME(d) AS day_of_week,
    DAY(d) AS day_of_month,
    MONTH(d) AS month_number,
    MONTHNAME(d) AS month_name,
    QUARTER(d) AS quarter,
    YEAR(d) AS year,
    IF(DAYOFWEEK(d) IN (1,7), 1, 0) AS is_weekend
FROM (
    SELECT DATE_ADD('2024-01-01', INTERVAL seq DAY) AS d
    FROM (
        SELECT (a.N + b.N * 10 + c.N * 100) AS seq
        FROM
            (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
             UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) a,
            (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3 UNION SELECT 4
             UNION SELECT 5 UNION SELECT 6 UNION SELECT 7 UNION SELECT 8 UNION SELECT 9) b,
            (SELECT 0 N UNION SELECT 1 UNION SELECT 2 UNION SELECT 3) c
    ) seq_gen
    WHERE seq <= 365
) date_series
WHERE d <= '2024-12-31';

-- ------------------------------------------------------------
-- 2.2 — dim_store (SCD Type 1: simple overwrite, no history needed)
-- ------------------------------------------------------------
INSERT INTO dim_store (store_id, store_name, city, region, opening_date)
SELECT store_id, store_name, city, region, opening_date
FROM stg_stores;

-- ------------------------------------------------------------
-- 2.3 — dim_employee
-- ------------------------------------------------------------
INSERT INTO dim_employee (employee_id, full_name, role, store_key, hire_date)
SELECT se.employee_id, se.full_name, se.role, ds.store_key, se.hire_date
FROM stg_employees se
JOIN dim_store ds ON se.store_id = ds.store_id;

-- ------------------------------------------------------------
-- 2.4 — dim_product
-- ------------------------------------------------------------
INSERT INTO dim_product (product_id, product_name, category_name, unit_cost, unit_price)
SELECT sp.product_id, sp.product_name, sc.category_name, sp.unit_cost, sp.unit_price
FROM stg_products sp
JOIN stg_categories sc ON sp.category_id = sc.category_id;

-- ------------------------------------------------------------
-- 2.5 — dim_customer (SCD Type 2)
-- Since this is the initial load, every customer gets exactly
-- one "current" version, valid from their signup_date onward.
-- (The accompanying ETL run #2 script demonstrates how a city
--  change would be processed as a genuine SCD2 update.)
-- ------------------------------------------------------------
INSERT INTO dim_customer (customer_id, full_name, city, loyalty_member,
                           signup_date, valid_from, valid_to, is_current)
SELECT customer_id, full_name, city, loyalty_member,
       signup_date, signup_date AS valid_from, NULL AS valid_to, 1 AS is_current
FROM stg_customers;

-- ------------------------------------------------------------
-- 2.6 — fact_sales
-- Joins staging order items back to their order header, then
-- resolves every dimension key. Cost and margin are computed
-- at load time using the product's unit_cost.
-- ------------------------------------------------------------
INSERT INTO fact_sales (
    date_key, customer_key, product_key, store_key, employee_key,
    order_id, order_item_id, quantity, unit_price_paid, discount_pct,
    line_revenue, line_cost, line_margin, is_returned
)
SELECT
    CAST(DATE_FORMAT(so.order_date, '%Y%m%d') AS UNSIGNED) AS date_key,
    dc.customer_key,
    dp.product_key,
    dst.store_key,
    de.employee_key,
    soi.order_id,
    soi.order_item_id,
    soi.quantity,
    soi.unit_price_paid,
    soi.discount_pct,
    ROUND(soi.quantity * soi.unit_price_paid, 2) AS line_revenue,
    ROUND(soi.quantity * dp.unit_cost, 2) AS line_cost,
    ROUND(soi.quantity * soi.unit_price_paid - soi.quantity * dp.unit_cost, 2) AS line_margin,
    IF(spr.return_id IS NOT NULL, 1, 0) AS is_returned
FROM stg_sales_order_items soi
JOIN stg_sales_orders so ON soi.order_id = so.order_id
JOIN dim_customer dc ON so.customer_id = dc.customer_id AND dc.is_current = 1
JOIN dim_product dp ON soi.product_id = dp.product_id
JOIN dim_store dst ON so.store_id = dst.store_id
JOIN dim_employee de ON so.employee_id = de.employee_id
LEFT JOIN stg_product_returns spr ON soi.order_item_id = spr.order_item_id;
