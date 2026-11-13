--1. CREATE TABLE staging.stg_dim_plan_name
CREATE TABLE staging.stg_dim_plan_name AS

SELECT
    -- Merchant identifier
    tenant_id AS tenant_id_raw,
    LOWER(TRIM(tenant_id)) AS tenant_id_key,
    -- Price version
    price_version AS price_version_raw,

    CASE
        WHEN price_version IS NULL THEN NULL
        WHEN TRIM(price_version) = '' THEN NULL
        WHEN LOWER(TRIM(price_version)) = 'null' THEN NULL
        ELSE TRIM(price_version)
    END AS price_version,

    CASE
        WHEN price_version IS NULL THEN 'sql_null'
        WHEN TRIM(price_version) = '' THEN 'blank'
        WHEN LOWER(TRIM(price_version)) = 'null' THEN 'literal_null'
        ELSE 'populated'
    END AS price_version_status,
    -- Uninstallation reason
    uninstallation_reason AS uninstallation_reason_raw,

    CASE
        WHEN uninstallation_reason IS NULL THEN NULL
        WHEN TRIM(uninstallation_reason) = '' THEN NULL
        WHEN LOWER(TRIM(uninstallation_reason)) = 'null' THEN NULL
        ELSE TRIM(uninstallation_reason)
    END AS uninstallation_reason,

    CASE
        WHEN uninstallation_reason IS NULL THEN 'sql_null'
        WHEN TRIM(uninstallation_reason) = '' THEN 'blank'
        WHEN LOWER(TRIM(uninstallation_reason)) = 'null' THEN 'literal_null'
        ELSE 'populated'
    END AS uninstallation_reason_status,

    -- Plan attributes
    TRIM(boost_plan_name) AS boost_plan_name,
    TRIM(boost_price_plan) AS boost_price_plan

FROM raw.dim_plan_name;

-- Quality check for staging.stg_dim_plan_name
SELECT
    price_version_status,
    COUNT(*) AS row_count
FROM staging.stg_dim_plan_name
GROUP BY 1
ORDER BY 1;

SELECT
    uninstallation_reason_status,
    COUNT(*) AS row_count
FROM staging.stg_dim_plan_name
GROUP BY 1
ORDER BY 1;

-- Quality check for boost_plan_name and boost_price_plan
SELECT
    boost_plan_name,
    boost_price_plan,
    price_version,
    COUNT(*) AS merchant_count
FROM staging.stg_dim_plan_name
GROUP BY 1, 2, 3
ORDER BY merchant_count DESC;

--2. CREATE TABLE staging.stg_finance_cube_data
CREATE TABLE staging.stg_finance_cube_data AS

SELECT
    -- Original source values: preserve for traceability
    date_t_eom AS date_t_eom_raw,
    shop_domain AS shop_domain_raw,
    tenure_in_months AS tenure_in_months_raw,
    churn_mrr AS churn_mrr_raw,
    bom_mrr AS bom_mrr_raw,
    eom_mrr AS eom_mrr_raw,
    -- Standardized snapshot date
    TRY_CAST(TRIM(date_t_eom) AS DATE) AS snapshot_date,
    -- Standardized merchant identifier
    LOWER(TRIM(shop_domain)) AS shop_key,
    -- Standardized numeric fields
    TRY_CAST(TRIM(tenure_in_months) AS INTEGER) AS tenure_months,
    TRY_CAST(TRIM(churn_mrr) AS DECIMAL(18,6)) AS churn_mrr,
    TRY_CAST(TRIM(bom_mrr) AS DECIMAL(18,6)) AS bom_mrr,
    TRY_CAST(TRIM(eom_mrr) AS DECIMAL(18,6)) AS eom_mrr,

    -- Data quality flags
    CASE
        WHEN TRY_CAST(TRIM(date_t_eom) AS DATE) IS NULL THEN 1
        ELSE 0
    END AS invalid_snapshot_date_flag,

    CASE
        WHEN TRY_CAST(TRIM(tenure_in_months) AS INTEGER) IS NULL THEN 1
        ELSE 0
    END AS invalid_tenure_flag,

    CASE
        WHEN TRY_CAST(TRIM(churn_mrr) AS DECIMAL(18,6)) IS NULL
          OR TRY_CAST(TRIM(bom_mrr) AS DECIMAL(18,6)) IS NULL
          OR TRY_CAST(TRIM(eom_mrr) AS DECIMAL(18,6)) IS NULL
        THEN 1
        ELSE 0
    END AS invalid_mrr_flag,

    CASE
        WHEN TRY_CAST(TRIM(tenure_in_months) AS INTEGER) < 0 THEN 1
        ELSE 0
    END AS negative_tenure_flag

FROM raw.finance_cube_data;

-- Quality check for staging.stg_finance_cube_data
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT shop_key || '|' || CAST(snapshot_date AS VARCHAR))
        AS distinct_shop_months,
    COUNT(*) - COUNT(DISTINCT shop_key || '|' || CAST(snapshot_date AS VARCHAR))
        AS duplicate_rows,
    COUNT(*) FILTER (WHERE shop_key IS NULL OR shop_key = '')
        AS invalid_shop_keys
FROM staging.stg_finance_cube_data;

-- Quality check for data quality flags
SELECT
    SUM(invalid_snapshot_date_flag) AS invalid_dates,
    SUM(invalid_tenure_flag) AS invalid_tenure,
    SUM(invalid_mrr_flag) AS invalid_mrr,
    SUM(negative_tenure_flag) AS negative_tenure
FROM staging.stg_finance_cube_data;

-- Quality check for consecutive snapshots and MRR matching
WITH finance_next AS (
    SELECT
        shop_key,
        snapshot_date,
        eom_mrr,
        LEAD(snapshot_date) OVER (
            PARTITION BY shop_key
            ORDER BY snapshot_date
        ) AS next_snapshot_date,
        LEAD(bom_mrr) OVER (
            PARTITION BY shop_key
            ORDER BY snapshot_date
        ) AS next_bom_mrr,
        LEAD(eom_mrr) OVER (
            PARTITION BY shop_key
            ORDER BY snapshot_date
        ) AS next_eom_mrr

    FROM staging.stg_finance_cube_data
)

SELECT
    COUNT(*) FILTER (
        WHERE next_snapshot_date IS NOT NULL
    ) AS matched_snapshot_pairs,

    COUNT(*) FILTER (
        WHERE next_snapshot_date IS NOT NULL
          AND eom_mrr = next_bom_mrr
    ) AS matching_mrr_pairs,

    COUNT(*) FILTER (
        WHERE next_snapshot_date IS NOT NULL
          AND eom_mrr <> next_bom_mrr
    ) AS mismatching_mrr_pairs,

    COUNT(*) FILTER (
        WHERE next_snapshot_date IS NOT NULL
          AND DATE_TRUNC('month', next_snapshot_date)
              <> DATE_TRUNC('month', snapshot_date)
                 + INTERVAL '1 month'
    ) AS non_consecutive_month_pairs

FROM finance_next;

-- Quality check for churn patterns
SELECT
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE eom_mrr > 0
    ) AS active_rows,

    COUNT(*) FILTER (
        WHERE churn_mrr < 0
    ) AS churn_mrr_negative_rows,

    COUNT(*) FILTER (
        WHERE churn_mrr < 0
          AND bom_mrr > 0
          AND eom_mrr = 0
    ) AS valid_churn_pattern,

    COUNT(*) FILTER (
        WHERE churn_mrr < 0
          AND NOT (bom_mrr > 0 AND eom_mrr = 0)
    ) AS unusual_churn_pattern

FROM staging.stg_finance_cube_data;

--3. CREATE TABLE finance_monthly_labeled

CREATE TABLE staging.stg_finance_monthly_labeled AS

WITH finance_next AS (
    SELECT
        *,
        LEAD(snapshot_date) OVER (
            PARTITION BY shop_key
            ORDER BY snapshot_date
        ) AS next_snapshot_date,
        LEAD(churn_mrr) OVER (
            PARTITION BY shop_key
            ORDER BY snapshot_date
        ) AS next_churn_mrr,
        LEAD(eom_mrr) OVER (
            PARTITION BY shop_key
            ORDER BY snapshot_date
        ) AS next_eom_mrr

    FROM staging.stg_finance_cube_data
)

SELECT
    *,
    CASE
        WHEN eom_mrr <= 0 THEN NULL
        WHEN next_snapshot_date IS NULL THEN NULL

        WHEN DATE_TRUNC('month', next_snapshot_date)
            <> DATE_TRUNC('month', snapshot_date)
                + INTERVAL '1 month' THEN NULL

        WHEN next_eom_mrr = 0 THEN 1
        WHEN next_eom_mrr > 0 THEN 0

        ELSE NULL
    END AS churn_label

FROM finance_next

WHERE eom_mrr > 0;

-- Quality check for staging.stg_finance_monthly_labeled
SELECT
    DATE_TRUNC('month', snapshot_date) AS snapshot_month,

    COUNT(*) AS active_merchants,

    COUNT(*) FILTER (
        WHERE churn_label = 1
    ) AS churned_merchants,

    COUNT(*) FILTER (
        WHERE churn_label = 0
    ) AS non_churned_merchants,

    COUNT(*) FILTER (
        WHERE churn_label IS NULL
    ) AS unknown_merchants

FROM staging.stg_finance_monthly_labeled
GROUP BY 1
ORDER BY 1;

--4. Create staging table for GMV base month data
CREATE TABLE staging.stg_gmv_base_month AS

SELECT
    -- Original values
    tenant_id AS tenant_id_raw,
    order_month AS order_month_raw,
    shop_currency_code AS shop_currency_code_raw,
    total_gmv AS total_gmv_raw,

    -- Standardized values
    LOWER(TRIM(tenant_id)) AS tenant_key,

    TRY_CAST(
        TRIM(order_month) || '-01' AS DATE
    ) AS order_month,

    UPPER(TRIM(shop_currency_code)) AS currency_code,

    TRY_CAST(
        TRIM(total_gmv) AS DECIMAL(38,19)
    ) AS total_gmv,

    -- Data quality flags
    CASE
        WHEN tenant_id IS NULL OR TRIM(tenant_id) = ''
        THEN 1 ELSE 0
    END AS invalid_tenant_flag,

    CASE
        WHEN TRY_CAST(TRIM(order_month) || '-01' AS DATE) IS NULL
        THEN 1 ELSE 0
    END AS invalid_order_month_flag,

    CASE
        WHEN shop_currency_code IS NULL
          OR TRIM(shop_currency_code) = ''
        THEN 1 ELSE 0
    END AS invalid_currency_flag,

    CASE
        WHEN TRY_CAST(
            TRIM(total_gmv) AS DECIMAL(38,19)
        ) IS NULL
        THEN 1 ELSE 0
    END AS invalid_gmv_flag,

    CASE
        WHEN TRY_CAST(
            TRIM(total_gmv) AS DECIMAL(38,19)
        ) = 0
        THEN 1 ELSE 0
    END AS zero_gmv_flag

FROM raw.gmv_base_month;

-- Quality check for staging.stg_gmv_base_month
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT tenant_key) AS distinct_tenants,
    COUNT(DISTINCT order_month) AS distinct_months,
    COUNT(DISTINCT currency_code) AS distinct_currencies,
    COUNT(*) FILTER (
        WHERE invalid_tenant_flag = 1
    ) AS invalid_tenants,
    COUNT(*) FILTER (
        WHERE invalid_order_month_flag = 1
    ) AS invalid_dates,
    COUNT(*) FILTER (
        WHERE invalid_currency_flag = 1
    ) AS invalid_currencies,
    COUNT(*) FILTER (
        WHERE invalid_gmv_flag = 1
    ) AS invalid_gmv,
    COUNT(*) FILTER (
        WHERE zero_gmv_flag = 1
    ) AS zero_gmv

FROM staging.stg_gmv_base_month;

--5. Create staging table for search traffic raw monthly data
CREATE TABLE staging.stg_search_traffic_raw_monthly AS

WITH standardized AS (
    SELECT
        -- Original values
        tenant_id AS tenant_id_raw,
        order_month AS order_month_raw,
        total_searches AS total_searches_raw,
        total_product_click AS total_product_click_raw,
        total_search_click AS total_search_click_raw,
        total_add_carts AS total_add_carts_raw,
        total_orders AS total_orders_raw,
        total_sales AS total_sales_raw,
        -- Standardized values
        LOWER(TRIM(tenant_id)) AS tenant_key,
        TRY_CAST(
            TRIM(order_month) || '-01' AS DATE
        ) AS order_month,
        TRY_CAST(TRIM(total_searches) AS BIGINT)
            AS total_searches,
        TRY_CAST(TRIM(total_product_click) AS BIGINT)
            AS total_product_click,
        TRY_CAST(TRIM(total_search_click) AS BIGINT)
            AS total_search_click,
        TRY_CAST(TRIM(total_add_carts) AS BIGINT)
            AS total_add_carts,
        TRY_CAST(TRIM(total_orders) AS BIGINT)
            AS total_orders,
        TRY_CAST(TRIM(total_sales) AS DECIMAL(38,19))
            AS total_sales

    FROM raw.search_traffic_raw_monthly
)

SELECT
    *,
    -- Data quality flags
    CASE WHEN tenant_key IS NULL OR tenant_key = ''
         THEN 1 ELSE 0 END AS invalid_tenant_flag,

    CASE WHEN order_month IS NULL
         THEN 1 ELSE 0 END AS invalid_order_month_flag,

    CASE
        WHEN total_searches IS NULL
          OR total_product_click IS NULL
          OR total_search_click IS NULL
          OR total_add_carts IS NULL
          OR total_orders IS NULL
          OR total_sales IS NULL
        THEN 1 ELSE 0
    END AS invalid_numeric_flag,

    -- Negative value flags
    CASE
        WHEN total_searches < 0
          OR total_product_click < 0
          OR total_search_click < 0
          OR total_add_carts < 0
          OR total_orders < 0
          OR total_sales < 0
        THEN 1 ELSE 0
    END AS negative_metric_flag,

    -- Logical consistency flags
    CASE WHEN total_search_click > total_searches
         THEN 1 ELSE 0 END AS search_click_exceeds_searches_flag,

    CASE WHEN total_product_click > total_searches
         THEN 1 ELSE 0 END AS product_click_exceeds_searches_flag,

    CASE WHEN total_add_carts > total_product_click
         THEN 1 ELSE 0 END AS add_carts_exceeds_product_click_flag,

    CASE WHEN total_orders > total_add_carts
         THEN 1 ELSE 0 END AS orders_exceeds_add_carts_flag

FROM standardized;

-- Quality check for staging.stg_search_traffic_raw_monthly
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT tenant_key) AS distinct_tenants,
    COUNT(DISTINCT order_month) AS distinct_months,
    COUNT(*) FILTER (
        WHERE invalid_tenant_flag = 1
    ) AS invalid_tenants,
    COUNT(*) FILTER (
        WHERE invalid_order_month_flag = 1
    ) AS invalid_dates,
    COUNT(*) FILTER (
        WHERE invalid_numeric_flag = 1
    ) AS invalid_numeric,
    COUNT(*) FILTER (
        WHERE negative_metric_flag = 1
    ) AS negative_metrics,
    COUNT(*) FILTER (
        WHERE search_click_exceeds_searches_flag = 1
    ) AS search_click_exceptions,
    COUNT(*) FILTER (
        WHERE product_click_exceeds_searches_flag = 1
    ) AS product_click_exceptions,
    COUNT(*) FILTER (
        WHERE add_carts_exceeds_product_click_flag = 1
    ) AS add_carts_exceptions,
    COUNT(*) FILTER (
        WHERE orders_exceeds_add_carts_flag = 1
    ) AS orders_exceptions

FROM staging.stg_search_traffic_raw_monthly;

-- Check for duplicate records in staging.stg_search_traffic_raw_monthly
SELECT
    tenant_key,
    order_month,
    COUNT(*) AS record_count

FROM staging.stg_search_traffic_raw_monthly

GROUP BY
    tenant_key,
    order_month
HAVING COUNT(*) > 1
ORDER BY record_count DESC;

--6. Cross-check across the 3 staging tables
-- Check for overlapping merchants across staging tables
WITH finance_shops AS (
    SELECT DISTINCT shop_key AS merchant_key
    FROM staging.stg_finance_cube_data
    WHERE shop_key IS NOT NULL
),
gmv_shops AS (
    SELECT DISTINCT tenant_key AS merchant_key
    FROM staging.stg_gmv_base_month
    WHERE tenant_key IS NOT NULL
),
search_shops AS (
    SELECT DISTINCT tenant_key AS merchant_key
    FROM staging.stg_search_traffic_raw_monthly
    WHERE tenant_key IS NOT NULL
)

SELECT
    (SELECT COUNT(*) FROM finance_shops) AS finance_merchants,
    (SELECT COUNT(*) FROM gmv_shops) AS gmv_merchants,
    (SELECT COUNT(*) FROM search_shops) AS search_merchants,
    (SELECT COUNT(*)
     FROM finance_shops f
     INNER JOIN gmv_shops g
        ON f.merchant_key = g.merchant_key
    ) AS finance_gmv_overlap,
    
    (SELECT COUNT(*)
     FROM finance_shops f
     INNER JOIN search_shops s
        ON f.merchant_key = s.merchant_key
    ) AS finance_search_overlap,

    (SELECT COUNT(*)
     FROM gmv_shops g
     INNER JOIN search_shops s
        ON g.merchant_key = s.merchant_key
    ) AS gmv_search_overlap,

    (SELECT COUNT(*)
     FROM finance_shops f
     INNER JOIN gmv_shops g
        ON f.merchant_key = g.merchant_key
     INNER JOIN search_shops s
        ON f.merchant_key = s.merchant_key
    ) AS all_three_overlap;

---Coverage analysis for merchants across staging tables
WITH finance_monthly AS (
    SELECT DISTINCT
        shop_key AS merchant_key,
        snapshot_date
    FROM staging.stg_finance_cube_data
),

gmv_monthly AS (
    SELECT DISTINCT
        tenant_key AS merchant_key,
        order_month
    FROM staging.stg_gmv_base_month
),

search_monthly AS (
    SELECT DISTINCT
        tenant_key AS merchant_key,
        order_month
    FROM staging.stg_search_traffic_raw_monthly
),

coverage AS (
    SELECT
        DATE_TRUNC('month', f.snapshot_date)::DATE AS snapshot_month,
        COUNT(DISTINCT f.merchant_key) AS finance_merchants,
        COUNT(DISTINCT CASE
            WHEN g.merchant_key IS NOT NULL
            THEN f.merchant_key
        END) AS merchants_with_gmv,
        COUNT(DISTINCT CASE
            WHEN s.merchant_key IS NOT NULL
            THEN f.merchant_key
        END) AS merchants_with_search,
        COUNT(DISTINCT CASE
            WHEN g.merchant_key IS NOT NULL
             AND s.merchant_key IS NOT NULL
            THEN f.merchant_key
        END) AS merchants_with_both
    FROM finance_monthly f
    LEFT JOIN gmv_monthly g
        ON f.merchant_key = g.merchant_key
       AND DATE_TRUNC('month', f.snapshot_date)::DATE = g.order_month
    LEFT JOIN search_monthly s
        ON f.merchant_key = s.merchant_key
       AND DATE_TRUNC('month', f.snapshot_date)::DATE = s.order_month
    GROUP BY 1
)

SELECT
    snapshot_month,
    finance_merchants,
    merchants_with_gmv,
    ROUND(
        100.0 * merchants_with_gmv / finance_merchants, 2
    ) AS gmv_coverage_pct,
    merchants_with_search,
    ROUND(
        100.0 * merchants_with_search / finance_merchants, 2
    ) AS search_coverage_pct,
    merchants_with_both,
    ROUND(
        100.0 * merchants_with_both / finance_merchants, 2
    ) AS both_coverage_pct
FROM coverage
ORDER BY snapshot_month;

-- Coverage analysis for active merchants across staging tables
WITH active_finance AS (
    SELECT DISTINCT
        shop_key AS merchant_key,
        DATE_TRUNC('month', snapshot_date)::DATE AS snapshot_month
    FROM staging.stg_finance_cube_data
    WHERE eom_mrr > 0
),

gmv_monthly AS (
    SELECT DISTINCT
        tenant_key AS merchant_key,
        order_month
    FROM staging.stg_gmv_base_month
),

search_monthly AS (
    SELECT DISTINCT
        tenant_key AS merchant_key,
        order_month
    FROM staging.stg_search_traffic_raw_monthly
)

SELECT
    f.snapshot_month,
    COUNT(*) AS active_merchants,

    COUNT(g.merchant_key) AS active_with_gmv,
    ROUND(
        100.0 * COUNT(g.merchant_key) / COUNT(*), 2
    ) AS gmv_coverage_pct,

    COUNT(s.merchant_key) AS active_with_search,
    ROUND(
        100.0 * COUNT(s.merchant_key) / COUNT(*), 2
    ) AS search_coverage_pct,

    COUNT(
        CASE WHEN g.merchant_key IS NOT NULL
               AND s.merchant_key IS NOT NULL
             THEN 1 END
    ) AS active_with_both,

    ROUND(
        100.0 * COUNT(
            CASE WHEN g.merchant_key IS NOT NULL
                   AND s.merchant_key IS NOT NULL
                 THEN 1 END
        ) / COUNT(*), 2
    ) AS both_coverage_pct

FROM active_finance f

LEFT JOIN gmv_monthly g
    ON f.merchant_key = g.merchant_key
   AND f.snapshot_month = g.order_month

LEFT JOIN search_monthly s
    ON f.merchant_key = s.merchant_key
   AND f.snapshot_month = s.order_month

GROUP BY f.snapshot_month
ORDER BY f.snapshot_month;

-- Status analysis for merchants in September 2026
WITH active_sep AS (
    SELECT DISTINCT
        shop_key AS merchant_key
    FROM staging.stg_finance_cube_data
    WHERE DATE_TRUNC('month', snapshot_date)::DATE
              = DATE '2026-09-01'
      AND eom_mrr > 0
),

search_aug AS (
    SELECT DISTINCT tenant_key AS merchant_key
    FROM staging.stg_search_traffic_raw_monthly
    WHERE order_month = DATE '2026-08-01'
),

search_sep AS (
    SELECT DISTINCT tenant_key AS merchant_key
    FROM staging.stg_search_traffic_raw_monthly
    WHERE order_month = DATE '2026-09-01'
),

gmv_sep AS (
    SELECT DISTINCT tenant_key AS merchant_key
    FROM staging.stg_gmv_base_month
    WHERE order_month = DATE '2026-09-01'
),

merchant_status AS (
    SELECT
        a.merchant_key,
        CASE
            WHEN sa.merchant_key IS NOT NULL THEN 1
            ELSE 0
        END AS has_search_aug,
        CASE
            WHEN ss.merchant_key IS NOT NULL THEN 1
            ELSE 0
        END AS has_search_sep,
        CASE
            WHEN g.merchant_key IS NOT NULL THEN 1
            ELSE 0
        END AS has_gmv_sep
    FROM active_sep a
    LEFT JOIN search_aug sa
        ON a.merchant_key = sa.merchant_key
    LEFT JOIN search_sep ss
        ON a.merchant_key = ss.merchant_key
    LEFT JOIN gmv_sep g
        ON a.merchant_key = g.merchant_key
)

SELECT
    has_search_aug,
    has_search_sep,
    has_gmv_sep,
    COUNT(*) AS merchant_count
FROM merchant_status
GROUP BY 1, 2, 3
ORDER BY 1 DESC, 2, 3;

-- Monthly search traffic analysis
SELECT
    order_month,
    COUNT(*) AS merchant_count,
    SUM(total_searches) AS total_searches,
    SUM(total_product_click) AS total_product_click,
    SUM(total_search_click) AS total_search_click,
    SUM(total_add_carts) AS total_add_carts,
    SUM(total_orders) AS total_orders,
    SUM(total_sales) AS total_sales
FROM staging.stg_search_traffic_raw_monthly
GROUP BY order_month
ORDER BY order_month;

--7. Churn label distribution
SELECT
    DATE_TRUNC('month', snapshot_date)::DATE AS snapshot_month,
    COUNT(*) AS total_records,
    COUNT(churn_label) AS labeled_records,
    SUM(CASE WHEN churn_label = 1 THEN 1 ELSE 0 END) AS churned,
    SUM(CASE WHEN churn_label = 0 THEN 1 ELSE 0 END) AS non_churned,
    SUM(CASE WHEN churn_label IS NULL THEN 1 ELSE 0 END) AS unlabeled
FROM staging.stg_finance_monthly_labeled
GROUP BY 1
ORDER BY 1;

--8. Create a consolidated view of monthly features for modeling
CREATE TABLE staging.stg_gmv_merchant_monthly AS
WITH currency_summary AS (
    SELECT
        tenant_key,
        order_month,
        COUNT(DISTINCT currency_code) AS currency_count,
        MIN(currency_code) AS single_currency_code,
        SUM(total_gmv) AS gmv_sum
    FROM staging.stg_gmv_base_month
    WHERE tenant_key IS NOT NULL
      AND order_month IS NOT NULL
      AND currency_code IS NOT NULL
      AND total_gmv IS NOT NULL
    GROUP BY
        tenant_key,
        order_month
)
SELECT
    tenant_key,
    order_month,

    CASE
        WHEN currency_count = 1 THEN single_currency_code
        ELSE NULL
    END AS currency_code,

    CASE
        WHEN currency_count = 1 THEN gmv_sum
        ELSE NULL
    END AS total_gmv,

    currency_count,

    CASE
        WHEN currency_count > 1 THEN 1
        ELSE 0
    END AS multi_currency_flag,

    1 AS has_gmv_data

FROM currency_summary;