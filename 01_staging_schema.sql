-- ============================================================
-- Layer 1 — STAGING
-- Raw copies of source (OLTP) tables, with lineage columns.
-- No business transformation happens here: staging tables
-- are a faithful, append-friendly mirror of the source system.
-- ============================================================

DROP DATABASE IF EXISTS retail_dw;
CREATE DATABASE retail_dw CHARACTER SET utf8mb4;
USE retail_dw;

-- ------------------------------------------------------------
-- stg_stores
-- ------------------------------------------------------------
CREATE TABLE stg_stores (
    store_id        INT,
    store_name      VARCHAR(100),
    city            VARCHAR(80),
    region          VARCHAR(50),
    opening_date    DATE,
    _source_table   VARCHAR(50) DEFAULT 'stores',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_employees
-- ------------------------------------------------------------
CREATE TABLE stg_employees (
    employee_id     INT,
    full_name       VARCHAR(100),
    store_id        INT,
    hire_date       DATE,
    role            VARCHAR(50),
    _source_table   VARCHAR(50) DEFAULT 'employees',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_categories
-- ------------------------------------------------------------
CREATE TABLE stg_categories (
    category_id     INT,
    category_name   VARCHAR(80),
    _source_table   VARCHAR(50) DEFAULT 'categories',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_products
-- ------------------------------------------------------------
CREATE TABLE stg_products (
    product_id      INT,
    product_name    VARCHAR(120),
    category_id     INT,
    unit_cost       DECIMAL(10,2),
    unit_price      DECIMAL(10,2),
    _source_table   VARCHAR(50) DEFAULT 'products',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_customers
-- (signup_date and city kept as-is — they will feed an SCD2
--  dimension downstream when city changes are simulated)
-- ------------------------------------------------------------
CREATE TABLE stg_customers (
    customer_id     INT,
    full_name       VARCHAR(100),
    city            VARCHAR(80),
    signup_date     DATE,
    loyalty_member  TINYINT(1),
    _source_table   VARCHAR(50) DEFAULT 'customers',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_sales_orders
-- ------------------------------------------------------------
CREATE TABLE stg_sales_orders (
    order_id        INT,
    customer_id     INT,
    store_id        INT,
    employee_id     INT,
    order_date      DATE,
    payment_method  VARCHAR(30),
    _source_table   VARCHAR(50) DEFAULT 'sales_orders',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_sales_order_items
-- ------------------------------------------------------------
CREATE TABLE stg_sales_order_items (
    order_item_id   INT,
    order_id        INT,
    product_id      INT,
    quantity        INT,
    unit_price_paid DECIMAL(10,2),
    discount_pct    DECIMAL(5,2),
    _source_table   VARCHAR(50) DEFAULT 'sales_order_items',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ------------------------------------------------------------
-- stg_product_returns
-- ------------------------------------------------------------
CREATE TABLE stg_product_returns (
    return_id       INT,
    order_item_id   INT,
    return_date     DATE,
    reason          VARCHAR(100),
    _source_table   VARCHAR(50) DEFAULT 'product_returns',
    _loaded_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
