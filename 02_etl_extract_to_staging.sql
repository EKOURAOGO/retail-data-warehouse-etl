-- ============================================================
-- ETL Step 1 — EXTRACT
-- Loads data from the source OLTP database (retail_analytics)
-- into the staging layer (retail_dw).
-- In a real pipeline this would be a Python/Spark job hitting
-- a live OLTP connection; here it is simulated with cross-
-- database INSERT ... SELECT, which is the direct MySQL
-- equivalent of "copy this table as-is".
-- ============================================================

USE retail_dw;

INSERT INTO stg_stores (store_id, store_name, city, region, opening_date)
SELECT store_id, store_name, city, region, opening_date
FROM retail_analytics.stores;

INSERT INTO stg_employees (employee_id, full_name, store_id, hire_date, role)
SELECT employee_id, full_name, store_id, hire_date, role
FROM retail_analytics.employees;

INSERT INTO stg_categories (category_id, category_name)
SELECT category_id, category_name
FROM retail_analytics.categories;

INSERT INTO stg_products (product_id, product_name, category_id, unit_cost, unit_price)
SELECT product_id, product_name, category_id, unit_cost, unit_price
FROM retail_analytics.products;

INSERT INTO stg_customers (customer_id, full_name, city, signup_date, loyalty_member)
SELECT customer_id, full_name, city, signup_date, loyalty_member
FROM retail_analytics.customers;

INSERT INTO stg_sales_orders (order_id, customer_id, store_id, employee_id, order_date, payment_method)
SELECT order_id, customer_id, store_id, employee_id, order_date, payment_method
FROM retail_analytics.sales_orders;

INSERT INTO stg_sales_order_items (order_item_id, order_id, product_id, quantity, unit_price_paid, discount_pct)
SELECT order_item_id, order_id, product_id, quantity, unit_price_paid, discount_pct
FROM retail_analytics.sales_order_items;

INSERT INTO stg_product_returns (return_id, order_item_id, return_date, reason)
SELECT return_id, order_item_id, return_date, reason
FROM retail_analytics.product_returns;
