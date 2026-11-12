CREATE TABLE mart.fact_merchant_monthly AS

WITH finance_base AS (
    SELECT
        shop_key,
        DATE_TRUNC('month', snapshot_date)::DATE AS snapshot_month,
        snapshot_date,
        tenure_months,
        churn_mrr,
        bom_mrr,
        eom_mrr,
        invalid_snapshot_date_flag,
        invalid_tenure_flag,
        invalid_mrr_flag,
        negative_tenure_flag,
        churn_label,
        next_snapshot_date

    FROM staging.stg_finance_monthly_labeled
    WHERE eom_mrr > 0
),

gmv_monthly AS (
    SELECT
        tenant_key,
        order_month AS snapshot_month,
        COUNT(DISTINCT currency_code) AS gmv_currency_count,
        SUM(zero_gmv_flag) AS gmv_zero_currency_count
    FROM staging.stg_gmv_base_month
    GROUP BY
        tenant_key,
        order_month
),

search_monthly AS (
    SELECT
        tenant_key,
        order_month AS snapshot_month,
        total_searches,
        total_product_click,
        total_search_click,
        total_add_carts,
        total_orders,
        total_sales,
        search_click_exceeds_searches_flag,
        product_click_exceeds_searches_flag,
        add_carts_exceeds_product_click_flag,
        orders_exceeds_add_carts_flag

    FROM staging.stg_search_traffic_raw_monthly
)

SELECT
    -- Identifiers
    f.shop_key,
    f.snapshot_month,
    f.snapshot_date,
    -- Finance features
    f.tenure_months,
    f.bom_mrr,
    f.eom_mrr,
    f.churn_mrr,

    -- GMV availability metadata
    CASE
        WHEN g.tenant_key IS NOT NULL THEN 1
        ELSE 0
    END AS has_gmv_data,
    COALESCE(g.gmv_currency_count, 0) AS gmv_currency_count,
    COALESCE(g.gmv_zero_currency_count, 0) AS gmv_zero_currency_count,

    -- Search availability metadata
    CASE
        WHEN s.tenant_key IS NOT NULL THEN 1
        ELSE 0
    END AS has_search_data,
    -- Search features
    s.total_searches,
    s.total_product_click,
    s.total_search_click,
    s.total_add_carts,
    s.total_orders,
    s.total_sales,
    -- Search data quality flags
    s.search_click_exceeds_searches_flag,
    s.product_click_exceeds_searches_flag,
    s.add_carts_exceeds_product_click_flag,
    s.orders_exceeds_add_carts_flag,

    -- September Search anomaly indicator
    CASE
        WHEN f.snapshot_month = DATE '2026-09-01' THEN 1
        ELSE 0
    END AS search_anomaly_flag,
    -- Plan attributes
    p.price_version,
    p.price_version_status,
    p.boost_plan_name,
    p.boost_price_plan,

    CASE
        WHEN p.tenant_id_key IS NOT NULL THEN 1
        ELSE 0
    END AS has_plan_data,
    -- Finance DQ flags
    f.invalid_snapshot_date_flag,
    f.invalid_tenure_flag,
    f.invalid_mrr_flag,
    f.negative_tenure_flag,
    -- Prediction target
    f.churn_label,
    f.next_snapshot_date

FROM finance_base f

LEFT JOIN gmv_monthly g
    ON f.shop_key = g.tenant_key
   AND f.snapshot_month = g.snapshot_month

LEFT JOIN search_monthly s
    ON f.shop_key = s.tenant_key
   AND f.snapshot_month = s.snapshot_month

LEFT JOIN staging.stg_dim_plan_name p
    ON f.shop_key = p.tenant_id_key;

-- Check the coverage of the mart.fact_merchant_monthly table
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT shop_key) AS distinct_merchants,
    COUNT(DISTINCT shop_key || '|' ||
        CAST(snapshot_month AS VARCHAR)) AS distinct_merchant_months,

    SUM(has_gmv_data) AS records_with_gmv,
    SUM(has_search_data) AS records_with_search,
    SUM(has_plan_data) AS records_with_plan,

    SUM(CASE WHEN churn_label IS NULL THEN 1 ELSE 0 END)
        AS unlabeled_records

FROM mart.fact_merchant_monthly;

-- Check for duplicate records in the mart.fact_merchant_monthly table
SELECT
    shop_key,
    snapshot_month,
    COUNT(*) AS record_count
FROM mart.fact_merchant_monthly
GROUP BY shop_key, snapshot_month
HAVING COUNT(*) > 1;

-- Check the distribution of merchants across months in the mart.fact_merchant_monthly table
SELECT
    snapshot_month,
    COUNT(*) AS active_merchant_months,
    SUM(CASE WHEN churn_label = 1 THEN 1 ELSE 0 END)
        AS churn_count,
    SUM(CASE WHEN churn_label = 0 THEN 1 ELSE 0 END)
        AS non_churn_count,
    SUM(CASE WHEN churn_label IS NULL THEN 1 ELSE 0 END)
        AS unlabeled_count,
    SUM(has_gmv_data) AS merchants_with_gmv,
    SUM(has_search_data) AS merchants_with_search,
    SUM(has_plan_data) AS merchants_with_plan,
    SUM(search_anomaly_flag) AS search_anomaly_records

FROM mart.fact_merchant_monthly
GROUP BY snapshot_month
ORDER BY snapshot_month;