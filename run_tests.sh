#!/bin/bash
# ============================================================
# Retail Data Warehouse — Automated test suite
# Verifies cross-layer consistency (staging <-> star schema)
# and the correctness of the SCD2 mechanism — not just that
# queries run without error.
# ============================================================

set -uo pipefail

PASS=0
FAIL=0

run_query() {
    local db="$1"
    local sql="$2"
    mysql -u root -N -B "$db" -e "$sql" 2>&1
}

assert_eq() {
    local description="$1"
    local actual="$2"
    local expected="$3"
    if [ "$actual" == "$expected" ]; then
        echo "  PASS  $description"
        PASS=$((PASS+1))
    else
        echo "  FAIL  $description (expected '$expected', got '$actual')"
        FAIL=$((FAIL+1))
    fi
}

echo "============================================================"
echo "Running Retail Data Warehouse test suite"
echo "============================================================"

# ------------------------------------------------------------
echo ""
echo "-- Layer 1: Staging row counts match source --"

result=$(run_query "retail_dw" "SELECT COUNT(*) FROM stg_sales_orders;")
assert_eq "Staging has all 909 source orders" "$result" "909"

result=$(run_query "retail_dw" "SELECT COUNT(*) FROM stg_sales_order_items;")
assert_eq "Staging has all 2258 source order items" "$result" "2258"

result=$(run_query "retail_dw" "SELECT COUNT(*) FROM stg_customers;")
assert_eq "Staging has all 300 source customers" "$result" "300"

# ------------------------------------------------------------
echo ""
echo "-- Layer 2: Star schema integrity --"

result=$(run_query "retail_dw" "SELECT COUNT(*) FROM fact_sales;")
assert_eq "fact_sales has exactly one row per staged order item (2258)" "$result" "2258"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM fact_sales f
LEFT JOIN dim_date dd ON f.date_key = dd.date_key
WHERE dd.date_key IS NULL;
")
assert_eq "Zero fact_sales rows with an unresolved date_key" "$result" "0"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM fact_sales f
LEFT JOIN dim_customer dc ON f.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL;
")
assert_eq "Zero fact_sales rows with an unresolved customer_key" "$result" "0"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM fact_sales f
LEFT JOIN dim_product dp ON f.product_key = dp.product_key
WHERE dp.product_key IS NULL;
")
assert_eq "Zero fact_sales rows with an unresolved product_key" "$result" "0"

# ------------------------------------------------------------
echo ""
echo "-- Financial consistency: staging vs star schema --"

staging_total=$(run_query "retail_dw" "
SELECT ROUND(SUM(quantity * unit_price_paid), 2) FROM stg_sales_order_items;
")
fact_total=$(run_query "retail_dw" "
SELECT ROUND(SUM(line_revenue), 2) FROM fact_sales;
")
assert_eq "Total revenue matches exactly between staging and fact_sales" "$staging_total" "$fact_total"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM fact_sales WHERE line_margin != ROUND(line_revenue - line_cost, 2);
")
assert_eq "line_margin always equals line_revenue minus line_cost" "$result" "0"

# ------------------------------------------------------------
echo ""
echo "-- SCD2 mechanism correctness --"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM dim_customer WHERE customer_id = 1;
")
assert_eq "Customer 1 has exactly 2 versions after the SCD2 demo run" "$result" "2"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM dim_customer WHERE customer_id = 1 AND is_current = 1;
")
assert_eq "Customer 1 has exactly 1 current version" "$result" "1"

result=$(run_query "retail_dw" "
SELECT city FROM dim_customer WHERE customer_id = 1 AND is_current = 1;
")
assert_eq "Customer 1's current version shows the new city (Paris)" "$result" "Paris"

result=$(run_query "retail_dw" "
SELECT city FROM dim_customer WHERE customer_id = 1 AND is_current = 0;
")
assert_eq "Customer 1's historical version still shows the old city (Nantes)" "$result" "Nantes"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM dim_customer
WHERE customer_id = 1 AND is_current = 0 AND valid_to IS NULL;
")
assert_eq "Every non-current dim_customer version has a non-null valid_to" "$result" "0"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM dim_customer
GROUP BY customer_id
HAVING SUM(is_current) > 1;
")
assert_eq "No customer has more than one current version simultaneously" "$result" ""

# ------------------------------------------------------------
echo ""
echo "-- Layer 3: Analytical marts --"

mart_total=$(run_query "retail_dw" "
SELECT ROUND(SUM(total_revenue), 2) FROM mart_monthly_revenue;
")
fact_total_no_returns=$(run_query "retail_dw" "
SELECT ROUND(SUM(line_revenue), 2) FROM fact_sales WHERE is_returned = 0;
")
assert_eq "mart_monthly_revenue total matches fact_sales total (excluding returns)" "$mart_total" "$fact_total_no_returns"

result=$(run_query "retail_dw" "
SELECT COUNT(*) FROM mart_product_performance;
")
assert_eq "mart_product_performance has exactly 25 products" "$result" "25"

result=$(run_query "retail_dw" "
SELECT product_name FROM mart_product_performance ORDER BY total_revenue DESC LIMIT 1;
")
assert_eq "Top revenue product in the mart is Laptop Pro 15 (matches OLTP analysis)" "$result" "Laptop Pro 15"

# ------------------------------------------------------------
echo ""
echo "============================================================"
echo "RESULTS: $PASS passed, $FAIL failed"
echo "============================================================"

if [ "$FAIL" -gt 0 ]; then
    exit 1
fi
exit 0
