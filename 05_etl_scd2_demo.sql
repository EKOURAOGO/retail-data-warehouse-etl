-- ============================================================
-- ETL Step 3 — INCREMENTAL LOAD DEMO (SCD Type 2 in action)
-- Simulates a real-world event: a customer moves to a new city.
-- This script shows the actual SCD2 mechanics:
--   1. Close the current version (set valid_to + is_current = 0)
--   2. Insert a new version (new city, valid_from = change date)
-- Both versions remain queryable afterward — this is what lets
-- a warehouse answer "where did this customer live when they
-- placed order #X", not just "where do they live today".
-- ============================================================

USE retail_dw;

-- Simulate: customer_id = 1 moves from their original city to Paris
-- on 2024-07-01. We don't know the city in advance here, so we
-- look it up first for the example to be self-contained.

SET @target_customer_id = 1;
SET @change_date = '2024-07-01';
SET @new_city = 'Paris';

-- Step 1 — close the currently active version
UPDATE dim_customer
SET valid_to = DATE_SUB(@change_date, INTERVAL 1 DAY),
    is_current = 0
WHERE customer_id = @target_customer_id
  AND is_current = 1;

-- Step 2 — insert the new version
INSERT INTO dim_customer (customer_id, full_name, city, loyalty_member,
                           signup_date, valid_from, valid_to, is_current)
SELECT customer_id, full_name, @new_city, loyalty_member,
       signup_date, @change_date, NULL, 1
FROM dim_customer
WHERE customer_id = @target_customer_id
  AND is_current = 0
ORDER BY valid_from DESC
LIMIT 1;

-- ------------------------------------------------------------
-- Verification query: full version history for that customer
-- ------------------------------------------------------------
SELECT customer_key, customer_id, full_name, city, valid_from, valid_to, is_current
FROM dim_customer
WHERE customer_id = @target_customer_id
ORDER BY valid_from;
