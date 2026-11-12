--1. Finance feature analysis for mart.fact_merchant_monthly table
--1.1. Profile the distribution of key metrics
SELECT
    snapshot_month,
    COUNT(*) AS total_records,
    -- Tenure
    MIN(tenure_months) AS tenure_min,
    MAX(tenure_months) AS tenure_max,
    ROUND(AVG(tenure_months), 2) AS tenure_mean,
    ROUND(MEDIAN(tenure_months), 2) AS tenure_median,
    ROUND(QUANTILE_CONT(tenure_months, 0.25), 2) AS tenure_p25,
    ROUND(QUANTILE_CONT(tenure_months, 0.75), 2) AS tenure_p75,
    ROUND(QUANTILE_CONT(tenure_months, 0.95), 2) AS tenure_p95,
    ROUND(SKEWNESS(tenure_months), 3) AS tenure_skewness,
    -- Beginning-of-Month MRR
    MIN(bom_mrr) AS bom_mrr_min,
    MAX(bom_mrr) AS bom_mrr_max,
    ROUND(AVG(bom_mrr), 2) AS bom_mrr_mean,
    ROUND(MEDIAN(bom_mrr), 2) AS bom_mrr_median,
    ROUND(QUANTILE_CONT(bom_mrr, 0.25), 2) AS bom_mrr_p25,
    ROUND(QUANTILE_CONT(bom_mrr, 0.75), 2) AS bom_mrr_p75,
    ROUND(QUANTILE_CONT(bom_mrr, 0.95), 2) AS bom_mrr_p95,
    ROUND(SKEWNESS(bom_mrr), 3) AS bom_mrr_skewness,
    -- End-of-Month MRR
    MIN(eom_mrr) AS eom_mrr_min,
    MAX(eom_mrr) AS eom_mrr_max,
    ROUND(AVG(eom_mrr), 2) AS eom_mrr_mean,
    ROUND(MEDIAN(eom_mrr), 2) AS eom_mrr_median,
    ROUND(QUANTILE_CONT(eom_mrr, 0.25), 2) AS eom_mrr_p25,
    ROUND(QUANTILE_CONT(eom_mrr, 0.75), 2) AS eom_mrr_p75,
    ROUND(QUANTILE_CONT(eom_mrr, 0.95), 2) AS eom_mrr_p95,
    ROUND(SKEWNESS(eom_mrr), 3) AS eom_mrr_skewness

FROM mart.fact_merchant_monthly
GROUP BY snapshot_month
ORDER BY snapshot_month;

--1.2. Zero-value analysis for key metrics
SELECT
    snapshot_month,
    COUNT(*) AS total_records,
    COUNT(*) FILTER (WHERE tenure_months = 0) AS zero_tenure,
    COUNT(*) FILTER (WHERE bom_mrr = 0) AS zero_bom_mrr,
    COUNT(*) FILTER (WHERE eom_mrr = 0) AS zero_eom_mrr,
    COUNT(*) FILTER (
        WHERE bom_mrr = 0 AND eom_mrr > 0
    ) AS zero_bom_positive_eom,
    COUNT(*) FILTER (
        WHERE bom_mrr > 0 AND eom_mrr > 0
    ) AS positive_bom_positive_eom

FROM mart.fact_merchant_monthly
GROUP BY snapshot_month
ORDER BY snapshot_month;

--1.3. MRR movement analysis
WITH mrr_movement AS (
    SELECT
        snapshot_month,
        bom_mrr,
        eom_mrr,
        eom_mrr - bom_mrr AS mrr_change,

        CASE
            WHEN bom_mrr > 0
            THEN (eom_mrr - bom_mrr) / bom_mrr
            ELSE NULL
        END AS mrr_growth_rate

    FROM mart.fact_merchant_monthly
)

SELECT
    snapshot_month,
    COUNT(*) AS total_records,

    COUNT(*) FILTER (WHERE mrr_change > 0) AS mrr_increased,
    COUNT(*) FILTER (WHERE mrr_change = 0) AS mrr_unchanged,
    COUNT(*) FILTER (WHERE mrr_change < 0) AS mrr_decreased,

    ROUND(AVG(mrr_change), 2) AS avg_mrr_change,
    MEDIAN(mrr_change) AS median_mrr_change,

    ROUND(AVG(mrr_growth_rate), 4) AS avg_mrr_growth_rate,
    ROUND(MEDIAN(mrr_growth_rate), 4) AS median_mrr_growth_rate,

    COUNT(*) FILTER (
        WHERE mrr_growth_rate IS NULL
    ) AS undefined_growth_rate

FROM mrr_movement
GROUP BY snapshot_month
ORDER BY snapshot_month;

--1.4. MRR movement analysis with churn label
WITH mrr_movement AS (
    SELECT
        snapshot_month,
        churn_label,
        bom_mrr,
        eom_mrr,

        CASE
            WHEN bom_mrr = 0 AND eom_mrr > 0
                THEN 'new_mrr'
            WHEN eom_mrr > bom_mrr
                THEN 'increased'
            WHEN eom_mrr = bom_mrr
                THEN 'unchanged'
            WHEN eom_mrr < bom_mrr
                THEN 'decreased'
        END AS mrr_movement_type

    FROM mart.fact_merchant_monthly
    WHERE churn_label IS NOT NULL
)

SELECT
    snapshot_month,
    mrr_movement_type,

    COUNT(*) AS total_merchants,

    COUNT(*) FILTER (
        WHERE churn_label = 1
    ) AS churned_merchants,

    COUNT(*) FILTER (
        WHERE churn_label = 0
    ) AS non_churned_merchants,

    ROUND(
        100.0 * COUNT(*) FILTER (WHERE churn_label = 1)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct

FROM mrr_movement
GROUP BY
    snapshot_month,
    mrr_movement_type
ORDER BY
    snapshot_month,
    mrr_movement_type;

--2. GMV feature analysis for mart.fact_merchant_monthly table
--2.1. Profile the distribution of GMV currency count and zero GMV currency count
SELECT
    snapshot_month,
    gmv_currency_count,
    CASE
        WHEN gmv_zero_currency_count = 0 THEN 'no_zero_gmv'
        ELSE 'has_zero_gmv'
    END AS zero_gmv_status,
    COUNT(*) AS total_merchants,
    COUNT(*) FILTER (
        WHERE churn_label = 1
    ) AS churned_merchants,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE churn_label = 1)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct

FROM mart.fact_merchant_monthly
WHERE churn_label IS NOT NULL
GROUP BY
    snapshot_month,
    gmv_currency_count,
    zero_gmv_status
ORDER BY
    snapshot_month,
    gmv_currency_count,
    zero_gmv_status;

--3. Search feature analysis for mart.fact_merchant_monthly table
--3.1. Distribution of search data availability and churn label
SELECT
    snapshot_month,
    has_search_data,
    COUNT(*) AS total_merchants,
    COUNT(*) FILTER (
        WHERE churn_label = 1
    ) AS churned_merchants,
    COUNT(*) FILTER (
        WHERE churn_label = 0
    ) AS non_churned_merchants,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE churn_label = 1)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct

FROM mart.fact_merchant_monthly
WHERE churn_label IS NOT NULL
GROUP BY
    snapshot_month,
    has_search_data
ORDER BY
    snapshot_month,
    has_search_data;

--3.2. Profile the distribution of Search activity metrics
SELECT
    snapshot_month,
    COUNT(*) AS total_records,

    -- Search volume
    MEDIAN(total_searches) AS searches_median,
    QUANTILE_CONT(total_searches, 0.75) AS searches_p75,
    QUANTILE_CONT(total_searches, 0.95) AS searches_p95,
    MAX(total_searches) AS searches_max,
    ROUND(SKEWNESS(total_searches), 3) AS searches_skewness,

    -- Product clicks
    MEDIAN(total_product_click) AS product_click_median,
    QUANTILE_CONT(total_product_click, 0.95) AS product_click_p95,
    MAX(total_product_click) AS product_click_max,
    ROUND(SKEWNESS(total_product_click), 3) AS product_click_skewness,

    -- Search clicks
    MEDIAN(total_search_click) AS search_click_median,
    QUANTILE_CONT(total_search_click, 0.95) AS search_click_p95,
    MAX(total_search_click) AS search_click_max,
    ROUND(SKEWNESS(total_search_click), 3) AS search_click_skewness,

    -- Add to carts
    MEDIAN(total_add_carts) AS add_carts_median,
    QUANTILE_CONT(total_add_carts, 0.95) AS add_carts_p95,
    MAX(total_add_carts) AS add_carts_max,
    ROUND(SKEWNESS(total_add_carts), 3) AS add_carts_skewness,

    -- Orders
    MEDIAN(total_orders) AS orders_median,
    QUANTILE_CONT(total_orders, 0.95) AS orders_p95,
    MAX(total_orders) AS orders_max,
    ROUND(SKEWNESS(total_orders), 3) AS orders_skewness,

    -- Sales
    MEDIAN(total_sales) AS sales_median,
    QUANTILE_CONT(total_sales, 0.95) AS sales_p95,
    MAX(total_sales) AS sales_max,
    ROUND(SKEWNESS(total_sales), 3) AS sales_skewness

FROM mart.fact_merchant_monthly
WHERE snapshot_month < DATE '2026-09-01'
  AND churn_label IS NOT NULL
  AND has_search_data = 1
GROUP BY snapshot_month
ORDER BY snapshot_month;

--3.3. Consistency check: total_sales with total_orders
SELECT
    snapshot_month,
    shop_key,
    total_orders,
    total_sales,
    ROUND(
        total_sales / NULLIF(total_orders, 0),
        2
    ) AS sales_per_order,
    total_searches,
    total_product_click,
    total_search_click,
    total_add_carts

FROM mart.fact_merchant_monthly

WHERE shop_key IN (
    'store-sv2267fc.myshopify.com',
    'store-508ao957.myshopify.com',
    'store-6de38tqn.myshopify.com',
    'store-s2kd8hxa.myshopify.com',
    'store-40hate87.myshopify.com'
)

ORDER BY shop_key, snapshot_month;

--4. GMV analysis
-- 4.1. GMV currency count and zero GMV currency count analysis
WITH currency_frequency AS (
    SELECT
        tenant_key,
        currency_code,
        COUNT(DISTINCT snapshot_month) AS active_months
    FROM mart.fact_merchant_monthly_gmv_currency
    WHERE snapshot_month BETWEEN DATE '2026-03-01'
                             AND DATE '2026-09-01'
    GROUP BY tenant_key, currency_code
),

ranked_currency AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY tenant_key
            ORDER BY active_months DESC, currency_code
        ) AS rn
    FROM currency_frequency
),

reference_currency AS (
    SELECT
        tenant_key,
        currency_code
    FROM ranked_currency
    WHERE rn = 1
      AND active_months = 7
),

monthly_gmv AS (
    SELECT
        r.tenant_key,
        r.currency_code,
        g.snapshot_month,
        g.total_gmv,
        g.zero_gmv_flag
    FROM reference_currency r
    LEFT JOIN mart.fact_merchant_monthly_gmv_currency g
        ON r.tenant_key = g.tenant_key
       AND r.currency_code = g.currency_code
       AND g.snapshot_month BETWEEN DATE '2026-03-01'
                                AND DATE '2026-09-01'
)

SELECT
    COUNT(*) AS merchant_months,
    COUNT(*) FILTER (
        WHERE total_gmv IS NOT NULL
    ) AS months_with_record,
    COUNT(*) FILTER (
        WHERE total_gmv = 0
    ) AS months_with_zero_gmv,
    COUNT(*) FILTER (
        WHERE total_gmv > 0
    ) AS months_with_positive_gmv,
    COUNT(*) FILTER (
        WHERE total_gmv IS NULL
    ) AS months_without_record
FROM monthly_gmv;

--4.2. Currency change analysis
WITH merchant_month AS (
    SELECT
        tenant_key,
        snapshot_month,
        COUNT(DISTINCT currency_code) AS currency_count,
        STRING_AGG(
            DISTINCT currency_code,
            ', ' ORDER BY currency_code
        ) AS currencies
    FROM mart.fact_merchant_monthly_gmv_currency
    WHERE snapshot_month BETWEEN DATE '2026-03-01'
                             AND DATE '2026-09-01'
    GROUP BY tenant_key, snapshot_month
),

merchant_currency_change AS (
    SELECT
        tenant_key,
        COUNT(*) AS observed_months,
        COUNT(DISTINCT currencies) AS distinct_currency_combinations,
        COUNT(DISTINCT currency_count) AS distinct_currency_counts
    FROM merchant_month
    GROUP BY tenant_key
)

SELECT
    observed_months,
    distinct_currency_combinations,
    COUNT(*) AS merchant_count
FROM merchant_currency_change
GROUP BY
    observed_months,
    distinct_currency_combinations
ORDER BY
    observed_months,
    distinct_currency_combinations;

--4.3. GMV and currency analysis for active merchants between June 2026 and September 2026
WITH active_merchants AS (
    SELECT
        shop_key,
        snapshot_month
    FROM mart.fact_merchant_monthly
    WHERE snapshot_month BETWEEN DATE '2026-06-01'
                              AND DATE '2026-09-01'
      AND eom_mrr > 0
),

merchant_currency AS (
    SELECT
        tenant_key,
        snapshot_month,
        COUNT(DISTINCT currency_code) AS currency_count,
        STRING_AGG(
            DISTINCT currency_code,
            ', ' ORDER BY currency_code
        ) AS currencies
    FROM mart.fact_merchant_monthly_gmv_currency
    WHERE snapshot_month BETWEEN DATE '2026-06-01'
                              AND DATE '2026-09-01'
    GROUP BY tenant_key, snapshot_month
)

SELECT
    a.snapshot_month,
    COUNT(*) AS active_merchants,
    COUNT(*) FILTER (
        WHERE m.currency_count IS NULL
    ) AS no_gmv,
    COUNT(*) FILTER (
        WHERE m.currency_count = 1
    ) AS single_currency,
    COUNT(*) FILTER (
        WHERE m.currency_count > 1
    ) AS multi_currency
FROM active_merchants a
LEFT JOIN merchant_currency m
    ON a.shop_key = m.tenant_key
   AND a.snapshot_month = m.snapshot_month
GROUP BY a.snapshot_month
ORDER BY a.snapshot_month;

--4.4. GMV currency consistency analysis for active merchants between June 2026 and September 2026
WITH monthly_gmv AS (
    SELECT
        tenant_key,
        snapshot_month,
        COUNT(DISTINCT currency_code) AS currency_count,
        MIN(currency_code) AS single_currency,
        SUM(total_gmv) AS single_currency_gmv
    FROM mart.fact_merchant_monthly_gmv_currency
    WHERE snapshot_month BETWEEN DATE '2026-06-01'
                             AND DATE '2026-09-01'
    GROUP BY
        tenant_key,
        snapshot_month
),

active_merchants AS (
    SELECT
        shop_key,
        snapshot_month
    FROM mart.fact_merchant_monthly
    WHERE snapshot_month BETWEEN DATE '2026-06-01'
                              AND DATE '2026-09-01'
      AND eom_mrr > 0
),

active_gmv AS (
    SELECT
        a.shop_key,
        a.snapshot_month,
        g.currency_count,
        g.single_currency,
        g.single_currency_gmv
    FROM active_merchants a
    JOIN monthly_gmv g
        ON a.shop_key = g.tenant_key
       AND a.snapshot_month = g.snapshot_month
),

gmv_pairs AS (
    SELECT
        curr.snapshot_month,
        curr.shop_key,
        prev.currency_count AS previous_currency_count,
        curr.currency_count AS current_currency_count,
        prev.single_currency AS previous_currency,
        curr.single_currency AS current_currency
    FROM active_gmv curr
    JOIN active_gmv prev
        ON curr.shop_key = prev.shop_key
       AND curr.snapshot_month =
           prev.snapshot_month + INTERVAL '1 month'
)

SELECT
    snapshot_month,
    COUNT(*) AS merchants_with_gmv_both_months,
    COUNT(*) FILTER (
        WHERE previous_currency_count = 1
          AND current_currency_count = 1
          AND previous_currency = current_currency
    ) AS eligible_single_currency,
    COUNT(*) FILTER (
        WHERE previous_currency_count > 1
           OR current_currency_count > 1
    ) AS contains_multi_currency
FROM gmv_pairs
GROUP BY snapshot_month
ORDER BY snapshot_month;

-- 5. GMV and Search feature analysis
SELECT
    snapshot_month,
    has_gmv_data,
    has_search_data,
    COUNT(*) AS total_merchants,
    COUNT(*) FILTER (
        WHERE churn_label = 1
    ) AS churned_merchants,
    ROUND(
        100.0 * COUNT(*) FILTER (WHERE churn_label = 1)
        / NULLIF(COUNT(*), 0),
        2
    ) AS churn_rate_pct

FROM mart.fact_merchant_monthly
WHERE churn_label IS NOT NULL
GROUP BY
    snapshot_month,
    has_gmv_data,
    has_search_data
ORDER BY
    snapshot_month,
    has_gmv_data,
    has_search_data;