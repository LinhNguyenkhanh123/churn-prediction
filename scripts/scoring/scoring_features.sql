-- Scoring features for snapshot 2026-09

CREATE OR REPLACE TABLE staging.stg_gmv_features_score_202609 AS

WITH active_merchants AS (
    SELECT
        shop_key,
        snapshot_month,
        DATE_TRUNC('month', snapshot_month)::DATE AS month_start
    FROM mart.fact_merchant_monthly
    WHERE snapshot_month = DATE '2026-09-01'
      AND eom_mrr > 0
      AND churn_mrr = 0
),

gmv_joined AS (
    SELECT
        a.shop_key,
        a.snapshot_month,
        a.month_start,
        g0.currency_code AS current_currency,
        g0.total_gmv AS current_gmv,
        g0.has_gmv_data AS current_has_data,
        g0.multi_currency_flag AS current_multi_currency,
        g1.currency_code AS prev_currency,
        g1.total_gmv AS prev_gmv,
        g1.has_gmv_data AS prev_has_data,
        g1.multi_currency_flag AS prev_multi_currency,
        g2.currency_code AS prev2_currency,
        g2.total_gmv AS prev2_gmv,
        g2.has_gmv_data AS prev2_has_data,
        g2.multi_currency_flag AS prev2_multi_currency,
        g3.currency_code AS prev3_currency,
        g3.total_gmv AS prev3_gmv,
        g3.has_gmv_data AS prev3_has_data,
        g3.multi_currency_flag AS prev3_multi_currency

    FROM active_merchants a

    LEFT JOIN staging.stg_gmv_merchant_monthly g0
        ON a.shop_key = g0.tenant_key
       AND a.month_start = g0.order_month

    LEFT JOIN staging.stg_gmv_merchant_monthly g1
        ON a.shop_key = g1.tenant_key
       AND (a.month_start - INTERVAL '1 month')::DATE = g1.order_month

    LEFT JOIN staging.stg_gmv_merchant_monthly g2
        ON a.shop_key = g2.tenant_key
       AND (a.month_start - INTERVAL '2 months')::DATE = g2.order_month

    LEFT JOIN staging.stg_gmv_merchant_monthly g3
        ON a.shop_key = g3.tenant_key
       AND (a.month_start - INTERVAL '3 months')::DATE = g3.order_month
)

SELECT
    shop_key,
    snapshot_month,

    -- Current month
    current_gmv AS gmv_30d,
    current_currency AS gmv_currency_code,

    COALESCE(current_has_data, 0) AS has_gmv_data,
    COALESCE(current_multi_currency, 0) AS multi_currency_flag,

    -- Current month + previous month
    CASE
        WHEN current_has_data = 1
         AND prev_has_data = 1
         AND current_multi_currency = 0
         AND prev_multi_currency = 0
         AND current_currency = prev_currency
        THEN current_gmv + prev_gmv
        ELSE NULL
    END AS gmv_60d,

    -- Current month compared with previous month
    CASE
        WHEN current_has_data = 1
         AND prev_has_data = 1
         AND current_multi_currency = 0
         AND prev_multi_currency = 0
         AND current_currency = prev_currency
         AND prev_gmv <> 0
        THEN (current_gmv - prev_gmv) / prev_gmv
        ELSE NULL
    END AS gmv_growth_30d,

    -- Current 2-month window compared with previous 2-month window
    CASE
        WHEN current_has_data = 1
         AND prev_has_data = 1
         AND prev2_has_data = 1
         AND prev3_has_data = 1

         AND current_multi_currency = 0
         AND prev_multi_currency = 0
         AND prev2_multi_currency = 0
         AND prev3_multi_currency = 0

         AND current_currency = prev_currency
         AND current_currency = prev2_currency
         AND current_currency = prev3_currency

         AND (prev2_gmv + prev3_gmv) <> 0

        THEN
            (
                (current_gmv + prev_gmv)
                - (prev2_gmv + prev3_gmv)
            ) / (prev2_gmv + prev3_gmv)

        ELSE NULL
    END AS gmv_growth_60d

FROM gmv_joined;

CREATE OR REPLACE TABLE staging.stg_search_features_score_202609 AS

WITH active_merchants AS (
    SELECT
        shop_key,
        snapshot_month
    FROM mart.fact_merchant_monthly
    WHERE snapshot_month = DATE '2026-09-01'
      AND eom_mrr > 0
      AND churn_mrr = 0
),

search_joined AS (
    SELECT
        a.shop_key,
        a.snapshot_month,

        -- Current month
        s0.total_searches AS searches_current,
        s0.total_product_click AS product_clicks_current,
        s0.total_search_click AS search_clicks_current,
        s0.total_add_carts AS add_carts_current,
        s0.total_orders AS orders_current,

        -- Previous month
        s1.total_searches AS searches_prev,
        s1.total_product_click AS product_clicks_prev,
        s1.total_search_click AS search_clicks_prev,
        s1.total_add_carts AS add_carts_prev,
        s1.total_orders AS orders_prev,

        -- Two months before
        s2.total_searches AS searches_prev2,
        s2.total_product_click AS product_clicks_prev2,
        s2.total_search_click AS search_clicks_prev2,
        s2.total_add_carts AS add_carts_prev2,
        s2.total_orders AS orders_prev2,

        -- Three months before
        s3.total_searches AS searches_prev3,
        s3.total_product_click AS product_clicks_prev3,
        s3.total_search_click AS search_clicks_prev3,
        s3.total_add_carts AS add_carts_prev3,
        s3.total_orders AS orders_prev3,

        CASE WHEN s0.tenant_key IS NOT NULL THEN 1 ELSE 0 END
            AS has_current_data,
        CASE WHEN s1.tenant_key IS NOT NULL THEN 1 ELSE 0 END
            AS has_prev_data,
        CASE WHEN s2.tenant_key IS NOT NULL THEN 1 ELSE 0 END
            AS has_prev2_data,
        CASE WHEN s3.tenant_key IS NOT NULL THEN 1 ELSE 0 END
            AS has_prev3_data

    FROM active_merchants a

    LEFT JOIN staging.stg_search_traffic_raw_monthly s0
        ON a.shop_key = s0.tenant_key
       AND a.snapshot_month = s0.order_month

    LEFT JOIN staging.stg_search_traffic_raw_monthly s1
        ON a.shop_key = s1.tenant_key
       AND (a.snapshot_month - INTERVAL '1 month')::DATE = s1.order_month

    LEFT JOIN staging.stg_search_traffic_raw_monthly s2
        ON a.shop_key = s2.tenant_key
       AND (a.snapshot_month - INTERVAL '2 months')::DATE = s2.order_month

    LEFT JOIN staging.stg_search_traffic_raw_monthly s3
        ON a.shop_key = s3.tenant_key
       AND (a.snapshot_month - INTERVAL '3 months')::DATE = s3.order_month
)

SELECT
    shop_key,
    snapshot_month,

    -- 60d volume features
    CASE WHEN has_current_data = 1 AND has_prev_data = 1
        THEN searches_current + searches_prev
    END AS searches_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
        THEN product_clicks_current + product_clicks_prev
    END AS product_clicks_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
        THEN search_clicks_current + search_clicks_prev
    END AS search_clicks_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
        THEN add_carts_current + add_carts_prev
    END AS add_carts_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
        THEN orders_current + orders_prev
    END AS orders_60d,

    -- 30d growth features
    CASE WHEN has_current_data = 1
          AND has_prev_data = 1
          AND searches_prev <> 0
        THEN (searches_current - searches_prev) * 1.0 / searches_prev
    END AS searches_growth_30d,

    CASE WHEN has_current_data = 1
          AND has_prev_data = 1
          AND product_clicks_prev <> 0
        THEN (product_clicks_current - product_clicks_prev) * 1.0
             / product_clicks_prev
    END AS product_clicks_growth_30d,

    CASE WHEN has_current_data = 1
          AND has_prev_data = 1
          AND search_clicks_prev <> 0
        THEN (search_clicks_current - search_clicks_prev) * 1.0
             / search_clicks_prev
    END AS search_clicks_growth_30d,

    CASE WHEN has_current_data = 1
          AND has_prev_data = 1
          AND add_carts_prev <> 0
        THEN (add_carts_current - add_carts_prev) * 1.0
             / add_carts_prev
    END AS add_carts_growth_30d,

    CASE WHEN has_current_data = 1
          AND has_prev_data = 1
          AND orders_prev <> 0
        THEN (orders_current - orders_prev) * 1.0
             / orders_prev
    END AS orders_growth_30d,

    -- 60d growth features
    CASE WHEN has_current_data = 1 AND has_prev_data = 1
          AND has_prev2_data = 1 AND has_prev3_data = 1
          AND (searches_prev2 + searches_prev3) <> 0
        THEN (
            (searches_current + searches_prev)
            - (searches_prev2 + searches_prev3)
        ) * 1.0 / (searches_prev2 + searches_prev3)
    END AS searches_growth_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
          AND has_prev2_data = 1 AND has_prev3_data = 1
          AND (product_clicks_prev2 + product_clicks_prev3) <> 0
        THEN (
            (product_clicks_current + product_clicks_prev)
            - (product_clicks_prev2 + product_clicks_prev3)
        ) * 1.0 / (product_clicks_prev2 + product_clicks_prev3)
    END AS product_clicks_growth_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
          AND has_prev2_data = 1 AND has_prev3_data = 1
          AND (search_clicks_prev2 + search_clicks_prev3) <> 0
        THEN (
            (search_clicks_current + search_clicks_prev)
            - (search_clicks_prev2 + search_clicks_prev3)
        ) * 1.0 / (search_clicks_prev2 + search_clicks_prev3)
    END AS search_clicks_growth_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
          AND has_prev2_data = 1 AND has_prev3_data = 1
          AND (add_carts_prev2 + add_carts_prev3) <> 0
        THEN (
            (add_carts_current + add_carts_prev)
            - (add_carts_prev2 + add_carts_prev3)
        ) * 1.0 / (add_carts_prev2 + add_carts_prev3)
    END AS add_carts_growth_60d,

    CASE WHEN has_current_data = 1 AND has_prev_data = 1
          AND has_prev2_data = 1 AND has_prev3_data = 1
          AND (orders_prev2 + orders_prev3) <> 0
        THEN (
            (orders_current + orders_prev)
            - (orders_prev2 + orders_prev3)
        ) * 1.0 / (orders_prev2 + orders_prev3)
    END AS orders_growth_60d,

    -- 30d conversion rates
    searches_current * 1.0
        / NULLIF(searches_current, 0) AS search_to_search_rate_30d,

    product_clicks_current * 1.0
        / NULLIF(searches_current, 0) AS search_to_product_click_rate_30d,

    search_clicks_current * 1.0
        / NULLIF(searches_current, 0) AS search_click_rate_30d,

    add_carts_current * 1.0
        / NULLIF(product_clicks_current, 0) AS product_click_to_cart_rate_30d,

    orders_current * 1.0
        / NULLIF(add_carts_current, 0) AS cart_to_order_rate_30d,

    -- 60d conversion rates
    (product_clicks_current + product_clicks_prev) * 1.0
        / NULLIF(searches_current + searches_prev, 0)
        AS search_to_product_click_rate_60d,

    (search_clicks_current + search_clicks_prev) * 1.0
        / NULLIF(searches_current + searches_prev, 0)
        AS search_click_rate_60d,

    (add_carts_current + add_carts_prev) * 1.0
        / NULLIF(product_clicks_current + product_clicks_prev, 0)
        AS product_click_to_cart_rate_60d,

    (orders_current + orders_prev) * 1.0
        / NULLIF(add_carts_current + add_carts_prev, 0)
        AS cart_to_order_rate_60d

FROM search_joined;