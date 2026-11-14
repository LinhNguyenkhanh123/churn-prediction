
CREATE OR REPLACE TABLE mart.churn_scoring_set_2026_09 AS

WITH finance_features AS (
    SELECT
        shop_key,
        snapshot_month,
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

        has_search_data,
        total_searches AS searches_30d,
        total_product_click AS product_clicks_30d,
        total_search_click AS search_clicks_30d,
        total_add_carts AS add_carts_30d,
        total_orders AS orders_30d,

        NULL::INTEGER AS churn_next_30d

    FROM mart.fact_merchant_monthly
    WHERE snapshot_month = DATE '2026-09-01'
      AND eom_mrr > 0
      AND churn_mrr = 0
),

scoring_features AS (
    SELECT
        f.*,

        g.gmv_30d,
        g.gmv_60d,
        g.gmv_growth_30d,
        g.gmv_growth_60d,
        g.gmv_currency_code,
        g.has_gmv_data,
        g.multi_currency_flag,

        s.searches_60d,
        s.product_clicks_60d,
        s.search_clicks_60d,
        s.add_carts_60d,
        s.orders_60d,

        s.searches_growth_30d,
        s.product_clicks_growth_30d,
        s.search_clicks_growth_30d,
        s.add_carts_growth_30d,
        s.orders_growth_30d,

        s.searches_growth_60d,
        s.product_clicks_growth_60d,
        s.search_clicks_growth_60d,
        s.add_carts_growth_60d,
        s.orders_growth_60d,

        s.search_to_product_click_rate_30d,
        s.search_click_rate_30d,
        s.product_click_to_cart_rate_30d,
        s.cart_to_order_rate_30d,

        s.search_to_product_click_rate_60d,
        s.search_click_rate_60d,
        s.product_click_to_cart_rate_60d,
        s.cart_to_order_rate_60d

    FROM finance_features f

    LEFT JOIN staging.stg_gmv_features_score_202609 g
        ON f.shop_key = g.shop_key
       AND f.snapshot_month = g.snapshot_month

    LEFT JOIN staging.stg_search_features_score_202609 s
        ON f.shop_key = s.shop_key
       AND f.snapshot_month = s.snapshot_month
)

SELECT
    *,
    'score' AS split
FROM scoring_features;
