-- ============================================================
-- Layer 2 — STAR SCHEMA (dimensions + fact table)
-- This is the analytical core of the warehouse: business-ready
-- dimensions with surrogate keys, and a fact table at the
-- grain of "one row per order line item".
-- ============================================================

USE retail_dw;

-- ------------------------------------------------------------
-- dim_date — standard date dimension, pre-populated for 2024
-- ------------------------------------------------------------
CREATE TABLE dim_date (
    date_key        INT PRIMARY KEY,         -- YYYYMMDD
    full_date        DATE NOT NULL,
    day_of_week      VARCHAR(10) NOT NULL,
    day_of_month     INT NOT NULL,
    month_number     INT NOT NULL,
    month_name       VARCHAR(10) NOT NULL,
    quarter          INT NOT NULL,
    year             INT NOT NULL,
    is_weekend       TINYINT(1) NOT NULL
);

-- ------------------------------------------------------------
-- dim_store — one row per store (no history needed: stores
-- don't change name/region in this dataset, so SCD1 is enough)
-- ------------------------------------------------------------
CREATE TABLE dim_store (
    store_key        INT PRIMARY KEY AUTO_INCREMENT,
    store_id          INT NOT NULL,           -- natural key from source
    store_name        VARCHAR(100) NOT NULL,
    city              VARCHAR(80) NOT NULL,
    region            VARCHAR(50) NOT NULL,
    opening_date      DATE NOT NULL
);

-- ------------------------------------------------------------
-- dim_employee
-- ------------------------------------------------------------
CREATE TABLE dim_employee (
    employee_key      INT PRIMARY KEY AUTO_INCREMENT,
    employee_id        INT NOT NULL,
    full_name           VARCHAR(100) NOT NULL,
    role                VARCHAR(50) NOT NULL,
    store_key           INT NOT NULL,
    hire_date           DATE NOT NULL,
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key)
);

-- ------------------------------------------------------------
-- dim_product
-- ------------------------------------------------------------
CREATE TABLE dim_product (
    product_key       INT PRIMARY KEY AUTO_INCREMENT,
    product_id          INT NOT NULL,
    product_name        VARCHAR(120) NOT NULL,
    category_name        VARCHAR(80) NOT NULL,
    unit_cost            DECIMAL(10,2) NOT NULL,
    unit_price            DECIMAL(10,2) NOT NULL
);

-- ------------------------------------------------------------
-- dim_customer — SLOWLY CHANGING DIMENSION, TYPE 2
-- Tracks the full history of a customer's city over time.
-- Each row is a "version" of the customer, valid between
-- valid_from and valid_to. is_current flags the active version.
-- ------------------------------------------------------------
CREATE TABLE dim_customer (
    customer_key      INT PRIMARY KEY AUTO_INCREMENT,
    customer_id         INT NOT NULL,          -- natural key from source
    full_name            VARCHAR(100) NOT NULL,
    city                 VARCHAR(80) NOT NULL,
    loyalty_member       TINYINT(1) NOT NULL,
    signup_date          DATE NOT NULL,
    valid_from           DATE NOT NULL,
    valid_to             DATE,                 -- NULL = current version
    is_current           TINYINT(1) NOT NULL DEFAULT 1
);

CREATE INDEX idx_dim_customer_natural_key ON dim_customer(customer_id, is_current);

-- ------------------------------------------------------------
-- fact_sales — grain: one row per order line item
-- ------------------------------------------------------------
CREATE TABLE fact_sales (
    fact_id            BIGINT PRIMARY KEY AUTO_INCREMENT,
    date_key             INT NOT NULL,
    customer_key         INT NOT NULL,
    product_key          INT NOT NULL,
    store_key             INT NOT NULL,
    employee_key          INT NOT NULL,
    order_id               INT NOT NULL,
    order_item_id           INT NOT NULL,
    quantity                INT NOT NULL,
    unit_price_paid          DECIMAL(10,2) NOT NULL,
    discount_pct              DECIMAL(5,2) NOT NULL,
    line_revenue               DECIMAL(12,2) NOT NULL,   -- quantity * unit_price_paid
    line_cost                   DECIMAL(12,2) NOT NULL,  -- quantity * unit_cost (from product dim at load time)
    line_margin                  DECIMAL(12,2) NOT NULL, -- line_revenue - line_cost
    is_returned                   TINYINT(1) NOT NULL DEFAULT 0,
    FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
    FOREIGN KEY (customer_key) REFERENCES dim_customer(customer_key),
    FOREIGN KEY (product_key) REFERENCES dim_product(product_key),
    FOREIGN KEY (store_key) REFERENCES dim_store(store_key),
    FOREIGN KEY (employee_key) REFERENCES dim_employee(employee_key)
);

CREATE INDEX idx_fact_sales_date ON fact_sales(date_key);
CREATE INDEX idx_fact_sales_customer ON fact_sales(customer_key);
CREATE INDEX idx_fact_sales_product ON fact_sales(product_key);
CREATE INDEX idx_fact_sales_store ON fact_sales(store_key);
