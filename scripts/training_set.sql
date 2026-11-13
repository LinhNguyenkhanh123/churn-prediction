--1. Create training set table
CREATE TABLE mart.churn_training_set AS

WITH finance_features AS (
    SELECT
        shop_key,
        snapshot_month,

        -- Finance features
        tenure_months,
        bom_mrr,
        eom_mrr,
        eom_mrr - bom_mrr AS mrr_change,

        CASE
            WHEN bom_mrr > 0
            THEN (eom_mrr - bom_mrr) / bom_mrr
            ELSE NULL
        END AS mrr_growth_rate,

        CASE
            WHEN bom_mrr = 0 AND eom_mrr > 0 THEN 'new_mrr'
            WHEN eom_mrr > bom_mrr THEN 'increased'
            WHEN eom_mrr = bom_mrr THEN 'unchanged'
            WHEN eom_mrr < bom_mrr THEN 'decreased'
            ELSE NULL
        END AS mrr_movement_type,

        -- Search volume 30d
        has_search_data,
        total_searches AS searches_30d,
        total_product_click AS product_clicks_30d,
        total_search_click AS search_clicks_30d,
        total_add_carts AS add_carts_30d,
        total_orders AS orders_30d,

        -- Target
        churn_label AS churn_next_30d

    FROM mart.fact_merchant_monthly
    WHERE snapshot_month BETWEEN DATE '2026-06-01'
                             AND DATE '2026-08-01'
      AND eom_mrr > 0
      AND churn_mrr = 0
      AND churn_label IS NOT NULL
),

training_features AS (
    SELECT
        f.*,

        -- GMV features
        g.gmv_30d,
        g.gmv_60d,
        g.gmv_growth_30d,
        g.gmv_growth_60d,
        g.gmv_currency_code,
        g.has_gmv_data,
        g.multi_currency_flag,

        -- Search volume 60d
        s.searches_60d,
        s.product_clicks_60d,
        s.search_clicks_60d,
        s.add_carts_60d,
        s.orders_60d,

        -- Search growth 30d
        s.searches_growth_30d,
        s.product_clicks_growth_30d,
        s.search_clicks_growth_30d,
        s.add_carts_growth_30d,
        s.orders_growth_30d,

        -- Search growth 60d
        s.searches_growth_60d,
        s.product_clicks_growth_60d,
        s.search_clicks_growth_60d,
        s.add_carts_growth_60d,
        s.orders_growth_60d,

        -- Search conversion 30d
        s.search_to_product_click_rate_30d,
        s.search_click_rate_30d,
        s.product_click_to_cart_rate_30d,
        s.cart_to_order_rate_30d,

        -- Search conversion 60d
        s.search_to_product_click_rate_60d,
        s.search_click_rate_60d,
        s.product_click_to_cart_rate_60d,
        s.cart_to_order_rate_60d

    FROM finance_features f

    LEFT JOIN staging.stg_gmv_features g
        ON f.shop_key = g.shop_key
       AND f.snapshot_month = g.snapshot_month

    LEFT JOIN staging.stg_search_features s
        ON f.shop_key = s.shop_key
       AND f.snapshot_month = s.snapshot_month
)

SELECT
    *,
    CASE
        WHEN snapshot_month IN (
            DATE '2026-06-01',
            DATE '2026-07-01'
        ) THEN 'train'
        WHEN snapshot_month = DATE '2026-08-01'
        THEN 'test'
    END AS split

FROM training_features;

--2. Check the training set for duplicates and invalid keys
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT shop_key) AS distinct_merchants,
    COUNT(DISTINCT (shop_key, snapshot_month)) AS distinct_grain,
    COUNT(*) - COUNT(DISTINCT (shop_key, snapshot_month)) AS duplicate_rows,
    COUNT(*) FILTER (
        WHERE shop_key IS NULL OR snapshot_month IS NULL
    ) AS invalid_key_rows
FROM mart.churn_training_set;

--3. Check the distribution of churn labels across the training set
SELECT
    split,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT shop_key) AS distinct_merchants,
    COUNT(*) FILTER (
        WHERE churn_next_30d = 1
    ) AS churn_count,
    COUNT(*) FILTER (
        WHERE churn_next_30d = 0
    ) AS non_churn_count,
    ROUND(
        100.0 * COUNT(*) FILTER (
            WHERE churn_next_30d = 1
        ) / COUNT(*),
        2
    ) AS churn_rate_pct
FROM mart.churn_training_set
GROUP BY split
ORDER BY split;

--3. Check the distribution of GMV features
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE gmv_30d IS NULL) AS gmv_30d_null,
    ROUND(100.0 * COUNT(*) FILTER (WHERE gmv_30d IS NULL) / COUNT(*), 2) AS gmv_30d_null_pct,
    COUNT(*) FILTER (WHERE gmv_60d IS NULL) AS gmv_60d_null,
    ROUND(100.0 * COUNT(*) FILTER (WHERE gmv_60d IS NULL) / COUNT(*), 2) AS gmv_60d_null_pct,
    COUNT(*) FILTER (WHERE gmv_growth_30d IS NULL) AS gmv_growth_30d_null,
    ROUND(100.0 * COUNT(*) FILTER (WHERE gmv_growth_30d IS NULL) / COUNT(*), 2) AS gmv_growth_30d_null_pct,
    COUNT(*) FILTER (WHERE gmv_growth_60d IS NULL) AS gmv_growth_60d_null,
    ROUND(100.0 * COUNT(*) FILTER (WHERE gmv_growth_60d IS NULL) / COUNT(*), 2) AS gmv_growth_60d_null_pct,
    COUNT(*) FILTER (WHERE gmv_currency_code IS NULL) AS gmv_currency_null,
    COUNT(*) FILTER (WHERE has_gmv_data = 0) AS no_gmv_data,
    COUNT(*) FILTER (WHERE multi_currency_flag = 1) AS multi_currency

FROM mart.churn_training_set;

--4. Check the distribution of search features
SELECT
    COUNT(*) AS total_rows,
    -- Search volume 30d
    COUNT(*) FILTER (WHERE searches_30d IS NULL) AS searches_30d_null,
    COUNT(*) FILTER (WHERE product_clicks_30d IS NULL) AS product_clicks_30d_null,
    COUNT(*) FILTER (WHERE search_clicks_30d IS NULL) AS search_clicks_30d_null,
    COUNT(*) FILTER (WHERE add_carts_30d IS NULL) AS add_carts_30d_null,
    COUNT(*) FILTER (WHERE orders_30d IS NULL) AS orders_30d_null,
    -- Search volume 60d
    COUNT(*) FILTER (WHERE searches_60d IS NULL) AS searches_60d_null,
    COUNT(*) FILTER (WHERE product_clicks_60d IS NULL) AS product_clicks_60d_null,
    COUNT(*) FILTER (WHERE search_clicks_60d IS NULL) AS search_clicks_60d_null,
    COUNT(*) FILTER (WHERE add_carts_60d IS NULL) AS add_carts_60d_null,
    COUNT(*) FILTER (WHERE orders_60d IS NULL) AS orders_60d_null,
    -- Search growth 30d
    COUNT(*) FILTER (WHERE searches_growth_30d IS NULL) AS searches_growth_30d_null,
    COUNT(*) FILTER (WHERE product_clicks_growth_30d IS NULL) AS product_clicks_growth_30d_null,
    COUNT(*) FILTER (WHERE search_clicks_growth_30d IS NULL) AS search_clicks_growth_30d_null,
    COUNT(*) FILTER (WHERE add_carts_growth_30d IS NULL) AS add_carts_growth_30d_null,
    COUNT(*) FILTER (WHERE orders_growth_30d IS NULL) AS orders_growth_30d_null,
    -- Search growth 60d
    COUNT(*) FILTER (WHERE searches_growth_60d IS NULL) AS searches_growth_60d_null,
    COUNT(*) FILTER (WHERE product_clicks_growth_60d IS NULL) AS product_clicks_growth_60d_null,
    COUNT(*) FILTER (WHERE search_clicks_growth_60d IS NULL) AS search_clicks_growth_60d_null,
    COUNT(*) FILTER (WHERE add_carts_growth_60d IS NULL) AS add_carts_growth_60d_null,
    COUNT(*) FILTER (WHERE orders_growth_60d IS NULL) AS orders_growth_60d_null,
    -- Search conversion 30d
    COUNT(*) FILTER (WHERE search_to_product_click_rate_30d IS NULL) AS search_to_product_click_rate_30d_null,
    COUNT(*) FILTER (WHERE search_click_rate_30d IS NULL) AS search_click_rate_30d_null,
    COUNT(*) FILTER (WHERE product_click_to_cart_rate_30d IS NULL) AS product_click_to_cart_rate_30d_null,
    COUNT(*) FILTER (WHERE cart_to_order_rate_30d IS NULL) AS cart_to_order_rate_30d_null,
    -- Search conversion 60d
    COUNT(*) FILTER (WHERE search_to_product_click_rate_60d IS NULL) AS search_to_product_click_rate_60d_null,
    COUNT(*) FILTER (WHERE search_click_rate_60d IS NULL) AS search_click_rate_60d_null,
    COUNT(*) FILTER (WHERE product_click_to_cart_rate_60d IS NULL) AS product_click_to_cart_rate_60d_null,
    COUNT(*) FILTER (WHERE cart_to_order_rate_60d IS NULL) AS cart_to_order_rate_60d_null

FROM mart.churn_training_set;