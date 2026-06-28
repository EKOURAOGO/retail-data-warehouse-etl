-- ============================================================
-- Retail Sales Analytics — Schema
-- MySQL 8.0+ / MariaDB 10.5+
-- ============================================================

DROP DATABASE IF EXISTS retail_analytics;
CREATE DATABASE retail_analytics CHARACTER SET utf8mb4;
USE retail_analytics;

-- ------------------------------------------------------------
-- stores
-- ------------------------------------------------------------
CREATE TABLE stores (
    store_id        INT PRIMARY KEY AUTO_INCREMENT,
    store_name      VARCHAR(100) NOT NULL,
    city            VARCHAR(80) NOT NULL,
    region          VARCHAR(50) NOT NULL,
    opening_date    DATE NOT NULL
);

-- ------------------------------------------------------------
-- employees (sales staff, linked to a store)
-- ------------------------------------------------------------
CREATE TABLE employees (
    employee_id     INT PRIMARY KEY AUTO_INCREMENT,
    full_name       VARCHAR(100) NOT NULL,
    store_id        INT NOT NULL,
    hire_date       DATE NOT NULL,
    role            VARCHAR(50) NOT NULL,
    FOREIGN KEY (store_id) REFERENCES stores(store_id)
);

-- ------------------------------------------------------------
-- categories
-- ------------------------------------------------------------
CREATE TABLE categories (
    category_id     INT PRIMARY KEY AUTO_INCREMENT,
    category_name   VARCHAR(80) NOT NULL
);

-- ------------------------------------------------------------
-- products
-- ------------------------------------------------------------
CREATE TABLE products (
    product_id      INT PRIMARY KEY AUTO_INCREMENT,
    product_name    VARCHAR(120) NOT NULL,
    category_id     INT NOT NULL,
    unit_cost       DECIMAL(10,2) NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    FOREIGN KEY (category_id) REFERENCES categories(category_id)
);

-- ------------------------------------------------------------
-- customers
-- ------------------------------------------------------------
CREATE TABLE customers (
    customer_id     INT PRIMARY KEY AUTO_INCREMENT,
    full_name       VARCHAR(100) NOT NULL,
    city            VARCHAR(80),
    signup_date     DATE NOT NULL,
    loyalty_member  TINYINT(1) NOT NULL DEFAULT 0
);

-- ------------------------------------------------------------
-- sales_orders (order header)
-- ------------------------------------------------------------
CREATE TABLE sales_orders (
    order_id        INT PRIMARY KEY AUTO_INCREMENT,
    customer_id     INT,
    store_id        INT NOT NULL,
    employee_id     INT NOT NULL,
    order_date      DATE NOT NULL,
    payment_method  VARCHAR(30) NOT NULL,
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id),
    FOREIGN KEY (store_id) REFERENCES stores(store_id),
    FOREIGN KEY (employee_id) REFERENCES employees(employee_id)
);

-- ------------------------------------------------------------
-- sales_order_items (order lines — one row per product sold)
-- ------------------------------------------------------------
CREATE TABLE sales_order_items (
    order_item_id   INT PRIMARY KEY AUTO_INCREMENT,
    order_id        INT NOT NULL,
    product_id      INT NOT NULL,
    quantity        INT NOT NULL,
    unit_price_paid DECIMAL(10,2) NOT NULL,
    discount_pct    DECIMAL(5,2) NOT NULL DEFAULT 0,
    FOREIGN KEY (order_id) REFERENCES sales_orders(order_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

-- ------------------------------------------------------------
-- product_returns
-- ------------------------------------------------------------
CREATE TABLE product_returns (
    return_id       INT PRIMARY KEY AUTO_INCREMENT,
    order_item_id   INT NOT NULL,
    return_date     DATE NOT NULL,
    reason          VARCHAR(100),
    FOREIGN KEY (order_item_id) REFERENCES sales_order_items(order_item_id)
);

-- ------------------------------------------------------------
-- Indexes for analytical query performance
-- ------------------------------------------------------------
CREATE INDEX idx_orders_date ON sales_orders(order_date);
CREATE INDEX idx_orders_customer ON sales_orders(customer_id);
CREATE INDEX idx_orders_store ON sales_orders(store_id);
CREATE INDEX idx_items_order ON sales_order_items(order_id);
CREATE INDEX idx_items_product ON sales_order_items(product_id);
