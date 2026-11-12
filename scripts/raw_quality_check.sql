--1. List all tables and their columns in the 'raw' schema, along with data types and ordinal positions.
SELECT
    table_name,
    column_name,
    data_type,
    ordinal_position
FROM information_schema.columns
WHERE table_schema = 'raw'
ORDER BY table_name, ordinal_position;

--2. Null and blank values
SELECT
    'dim_plan_name' AS table_name,
    'tenant_id' AS column_name,
    COUNT(*) FILTER (WHERE tenant_id IS NULL) AS null_count,
    COUNT(*) FILTER (
        WHERE tenant_id IS NOT NULL AND TRIM(tenant_id) = ''
    ) AS blank_count
FROM raw.dim_plan_name

UNION ALL

SELECT 'dim_plan_name', 'price_version',
    COUNT(*) FILTER (WHERE price_version IS NULL),
    COUNT(*) FILTER (WHERE price_version IS NOT NULL AND TRIM(price_version) = '')
FROM raw.dim_plan_name

UNION ALL

SELECT 'dim_plan_name', 'uninstallation_reason',
    COUNT(*) FILTER (WHERE uninstallation_reason IS NULL),
    COUNT(*) FILTER (WHERE uninstallation_reason IS NOT NULL AND TRIM(uninstallation_reason) = '')
FROM raw.dim_plan_name

UNION ALL

SELECT 'dim_plan_name', 'boost_plan_name',
    COUNT(*) FILTER (WHERE boost_plan_name IS NULL),
    COUNT(*) FILTER (WHERE boost_plan_name IS NOT NULL AND TRIM(boost_plan_name) = '')
FROM raw.dim_plan_name

UNION ALL

SELECT 'dim_plan_name', 'boost_price_plan',
    COUNT(*) FILTER (WHERE boost_price_plan IS NULL),
    COUNT(*) FILTER (WHERE boost_price_plan IS NOT NULL AND TRIM(boost_price_plan) = '')
FROM raw.dim_plan_name

UNION ALL

SELECT 'finance_cube_data', 'date_t_eom',
    COUNT(*) FILTER (WHERE date_t_eom IS NULL),
    COUNT(*) FILTER (WHERE date_t_eom IS NOT NULL AND TRIM(date_t_eom) = '')
FROM raw.finance_cube_data

UNION ALL

SELECT 'finance_cube_data', 'shop_domain',
    COUNT(*) FILTER (WHERE shop_domain IS NULL),
    COUNT(*) FILTER (WHERE shop_domain IS NOT NULL AND TRIM(shop_domain) = '')
FROM raw.finance_cube_data

UNION ALL

SELECT 'finance_cube_data', 'tenure_in_months',
    COUNT(*) FILTER (WHERE tenure_in_months IS NULL),
    COUNT(*) FILTER (WHERE tenure_in_months IS NOT NULL AND TRIM(tenure_in_months) = '')
FROM raw.finance_cube_data

UNION ALL

SELECT 'finance_cube_data', 'churn_mrr',
    COUNT(*) FILTER (WHERE churn_mrr IS NULL),
    COUNT(*) FILTER (WHERE churn_mrr IS NOT NULL AND TRIM(churn_mrr) = '')
FROM raw.finance_cube_data

UNION ALL

SELECT 'finance_cube_data', 'bom_mrr',
    COUNT(*) FILTER (WHERE bom_mrr IS NULL),
    COUNT(*) FILTER (WHERE bom_mrr IS NOT NULL AND TRIM(bom_mrr) = '')
FROM raw.finance_cube_data

UNION ALL

SELECT 'finance_cube_data', 'eom_mrr',
    COUNT(*) FILTER (WHERE eom_mrr IS NULL),
    COUNT(*) FILTER (WHERE eom_mrr IS NOT NULL AND TRIM(eom_mrr) = '')
FROM raw.finance_cube_data

UNION ALL

SELECT 'gmv_base_month', 'tenant_id',
    COUNT(*) FILTER (WHERE tenant_id IS NULL),
    COUNT(*) FILTER (WHERE tenant_id IS NOT NULL AND TRIM(tenant_id) = '')
FROM raw.gmv_base_month

UNION ALL

SELECT 'gmv_base_month', 'order_month',
    COUNT(*) FILTER (WHERE order_month IS NULL),
    COUNT(*) FILTER (WHERE order_month IS NOT NULL AND TRIM(order_month) = '')
FROM raw.gmv_base_month

UNION ALL

SELECT 'gmv_base_month', 'shop_currency_code',
    COUNT(*) FILTER (WHERE shop_currency_code IS NULL),
    COUNT(*) FILTER (WHERE shop_currency_code IS NOT NULL AND TRIM(shop_currency_code) = '')
FROM raw.gmv_base_month

UNION ALL

SELECT 'gmv_base_month', 'total_gmv',
    COUNT(*) FILTER (WHERE total_gmv IS NULL),
    COUNT(*) FILTER (WHERE total_gmv IS NOT NULL AND TRIM(total_gmv) = '')
FROM raw.gmv_base_month

UNION ALL

SELECT 'search_traffic_raw_monthly', 'tenant_id',
    COUNT(*) FILTER (WHERE tenant_id IS NULL),
    COUNT(*) FILTER (WHERE tenant_id IS NOT NULL AND TRIM(tenant_id) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'order_month',
    COUNT(*) FILTER (WHERE order_month IS NULL),
    COUNT(*) FILTER (WHERE order_month IS NOT NULL AND TRIM(order_month) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'total_searches',
    COUNT(*) FILTER (WHERE total_searches IS NULL),
    COUNT(*) FILTER (WHERE total_searches IS NOT NULL AND TRIM(total_searches) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'total_product_click',
    COUNT(*) FILTER (WHERE total_product_click IS NULL),
    COUNT(*) FILTER (WHERE total_product_click IS NOT NULL AND TRIM(total_product_click) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'total_search_click',
    COUNT(*) FILTER (WHERE total_search_click IS NULL),
    COUNT(*) FILTER (WHERE total_search_click IS NOT NULL AND TRIM(total_search_click) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'total_add_carts',
    COUNT(*) FILTER (WHERE total_add_carts IS NULL),
    COUNT(*) FILTER (WHERE total_add_carts IS NOT NULL AND TRIM(total_add_carts) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'total_orders',
    COUNT(*) FILTER (WHERE total_orders IS NULL),
    COUNT(*) FILTER (WHERE total_orders IS NOT NULL AND TRIM(total_orders) = '')
FROM raw.search_traffic_raw_monthly

UNION ALL

SELECT 'search_traffic_raw_monthly', 'total_sales',
    COUNT(*) FILTER (WHERE total_sales IS NULL),
    COUNT(*) FILTER (WHERE total_sales IS NOT NULL AND TRIM(total_sales) = '')
FROM raw.search_traffic_raw_monthly

ORDER BY table_name, column_name;

--Further investigation of null values
    boost_plan_name,
    boost_price_plan,
    price_version,
    COUNT(*) AS null_reason_count
FROM raw.dim_plan_name
WHERE uninstallation_reason IS NULL
GROUP BY
    boost_plan_name,
    boost_price_plan,
    price_version
ORDER BY null_reason_count DESC;

SELECT
    COUNT(*) FILTER (WHERE price_version IS NULL) AS actual_null,
    COUNT(*) FILTER (WHERE LOWER(TRIM(price_version)) = 'null') AS string_null,
    COUNT(*) FILTER (WHERE TRIM(price_version) = '') AS blank
FROM raw.dim_plan_name;

--3. Duplicate check
-- dim_plan
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT tenant_id) AS unique_tenants,
    COUNT(*) - COUNT(DISTINCT tenant_id) AS repeated_tenant_rows
FROM raw.dim_plan_name;

-- finance_cube_data
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT shop_domain) AS unique_shops,
    COUNT(*) - COUNT(DISTINCT shop_domain) AS repeated_shop_rows
FROM raw.finance_cube_data;

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (shop_domain, date_t_eom)) AS unique_combinations,
    COUNT(*) - COUNT(DISTINCT (shop_domain, date_t_eom)) AS duplicate_combinations
FROM raw.finance_cube_data;

-- GMV monthly key
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (tenant_id, order_month)) AS unique_combinations,
    COUNT(*) - COUNT(DISTINCT (tenant_id, order_month)) AS duplicate_combinations
FROM raw.gmv_base_month;

-- Search traffic monthly key
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (tenant_id, order_month)) AS unique_combinations,
    COUNT(*) - COUNT(DISTINCT (tenant_id, order_month)) AS duplicate_combinations
FROM raw.search_traffic_raw_monthly;

-- Investigate duplicates in GMV monthly
SELECT
    tenant_id,
    order_month,
    COUNT(*) AS record_count
FROM raw.gmv_base_month
GROUP BY tenant_id, order_month
HAVING COUNT(*) > 1
ORDER BY record_count DESC
LIMIT 20;

SELECT
    tenant_id,
    order_month,
    shop_currency_code,
    COUNT(*) AS record_count,
    COUNT(DISTINCT total_gmv) AS distinct_gmv_values
FROM raw.gmv_base_month
WHERE tenant_id = 'store-y25d93h2.myshopify.com'
  AND order_month = '2026-03'
GROUP BY
    tenant_id,
    order_month,
    shop_currency_code
ORDER BY record_count DESC;

-- Further investigate duplicates in GMV monthly to decide the key for the table
SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT (
        tenant_id,
        order_month,
        shop_currency_code
    )) AS unique_combinations,
    COUNT(*) - COUNT(DISTINCT (
        tenant_id,
        order_month,
        shop_currency_code
    )) AS duplicate_combinations
FROM raw.gmv_base_month;

--4. Categorical columns check for dim_plan_name
-- Categogical columns combination check
SELECT
    boost_plan_name,
    boost_price_plan,
    COUNT(*) AS record_count
FROM raw.dim_plan_name
GROUP BY
    boost_plan_name,
    boost_price_plan
ORDER BY record_count DESC;

SELECT
    tenant_id,
    boost_plan_name,
    boost_price_plan,
    price_version,
    uninstallation_reason
FROM raw.dim_plan_name
WHERE LOWER(TRIM(price_version)) = 'null'
  AND boost_plan_name <> 'other'
ORDER BY boost_plan_name;

-- Uninstallation reason investigation
SELECT
    uninstallation_reason,
    COUNT(*) AS record_count
FROM raw.dim_plan_name
GROUP BY uninstallation_reason
ORDER BY record_count DESC;

-- Further investigation of uninstallation_reason
SELECT
    COUNT(*) FILTER (
        WHERE uninstallation_reason IS NULL
    ) AS actual_null,

    COUNT(*) FILTER (
        WHERE LOWER(TRIM(uninstallation_reason)) = 'null'
    ) AS literal_null,

    COUNT(*) FILTER (
        WHERE TRIM(uninstallation_reason) = ''
    ) AS blank_values
FROM raw.dim_plan_name;

-- Summarize uninstallation_reason
SELECT
    COUNT(*) AS total_rows,

    COUNT(DISTINCT uninstallation_reason)
        FILTER (
            WHERE uninstallation_reason IS NOT NULL
              AND LOWER(TRIM(uninstallation_reason)) <> 'null'
              AND TRIM(uninstallation_reason) <> ''
        ) AS distinct_reason_values,

    COUNT(*) FILTER (
        WHERE uninstallation_reason IS NOT NULL
          AND LOWER(TRIM(uninstallation_reason)) <> 'null'
          AND TRIM(uninstallation_reason) <> ''
    ) AS non_missing_reasons,

    COUNT(*) FILTER (
        WHERE uninstallation_reason LIKE '%,%'
    ) AS multiple_reason_rows

FROM raw.dim_plan_name;

--5. Finance cube data checks
-- Summarize finance_cube_data by date_t_eom
SELECT
    date_t_eom,
    COUNT(*) AS total_rows,
    COUNT(DISTINCT shop_domain) AS unique_shops
FROM raw.finance_cube_data
GROUP BY date_t_eom
ORDER BY date_t_eom;

-- Data type validation for finance_cube_data
SELECT
    'date_t_eom' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE TRY_CAST(date_t_eom AS DATE) IS NULL
    ) AS invalid_rows,
    NULL AS min_value,
    NULL AS max_value
FROM raw.finance_cube_data

UNION ALL

SELECT
    'tenure_in_months',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE TRY_CAST(tenure_in_months AS INTEGER) IS NULL
    ),
    MIN(TRY_CAST(tenure_in_months AS INTEGER))::VARCHAR,
    MAX(TRY_CAST(tenure_in_months AS INTEGER))::VARCHAR
FROM raw.finance_cube_data

UNION ALL

SELECT
    'churn_mrr',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE TRY_CAST(churn_mrr AS DOUBLE) IS NULL
    ),
    MIN(TRY_CAST(churn_mrr AS DOUBLE))::VARCHAR,
    MAX(TRY_CAST(churn_mrr AS DOUBLE))::VARCHAR
FROM raw.finance_cube_data

UNION ALL

SELECT
    'bom_mrr',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE TRY_CAST(bom_mrr AS DOUBLE) IS NULL
    ),
    MIN(TRY_CAST(bom_mrr AS DOUBLE))::VARCHAR,
    MAX(TRY_CAST(bom_mrr AS DOUBLE))::VARCHAR
FROM raw.finance_cube_data

UNION ALL

SELECT
    'eom_mrr',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE TRY_CAST(eom_mrr AS DOUBLE) IS NULL
    ),
    MIN(TRY_CAST(eom_mrr AS DOUBLE))::VARCHAR,
    MAX(TRY_CAST(eom_mrr AS DOUBLE))::VARCHAR
FROM raw.finance_cube_data;

-- Check for rows with tenure_in_months < 0 and their MRR values
SELECT
    tenure_in_months,
    COUNT(*) AS total_rows,

    COUNT(*) FILTER (
        WHERE TRY_CAST(bom_mrr AS DOUBLE) = 0
          AND TRY_CAST(eom_mrr AS DOUBLE) = 0
          AND TRY_CAST(churn_mrr AS DOUBLE) = 0
    ) AS all_mrr_zero,

    COUNT(*) FILTER (
        WHERE TRY_CAST(bom_mrr AS DOUBLE) <> 0
           OR TRY_CAST(eom_mrr AS DOUBLE) <> 0
           OR TRY_CAST(churn_mrr AS DOUBLE) <> 0
    ) AS has_nonzero_mrr

FROM raw.finance_cube_data
WHERE TRY_CAST(tenure_in_months AS INTEGER) < 0
GROUP BY tenure_in_months
ORDER BY TRY_CAST(tenure_in_months AS INTEGER);

-- Investigate rows with churn_mrr < 0 and their MRR values
SELECT
    COUNT(*) AS churn_rows,

    COUNT(*) FILTER (
        WHERE TRY_CAST(eom_mrr AS DOUBLE) = 0
    ) AS eom_zero,

    COUNT(*) FILTER (
        WHERE TRY_CAST(eom_mrr AS DOUBLE) > 0
    ) AS eom_still_positive,

    COUNT(*) FILTER (
        WHERE TRY_CAST(bom_mrr AS DOUBLE) > 0
          AND TRY_CAST(eom_mrr AS DOUBLE) = 0
    ) AS positive_to_zero

FROM raw.finance_cube_data
WHERE TRY_CAST(churn_mrr AS DOUBLE) < 0;

-- Check for MRR consistency between consecutive months for each shop_domain
WITH monthly_comparison AS (
    SELECT
        a.shop_domain,
        a.date_t_eom AS current_snapshot,
        b.date_t_eom AS next_snapshot,
        TRY_CAST(a.eom_mrr AS DOUBLE) AS current_eom_mrr,
        TRY_CAST(b.bom_mrr AS DOUBLE) AS next_bom_mrr
    FROM raw.finance_cube_data a
    INNER JOIN raw.finance_cube_data b
        ON LOWER(TRIM(a.shop_domain)) = LOWER(TRIM(b.shop_domain))
        AND TRY_CAST(b.date_t_eom AS DATE)
            = TRY_CAST(a.date_t_eom AS DATE) + INTERVAL '1 month'
)
SELECT
    COUNT(*) AS matched_shop_months,

    COUNT(*) FILTER (
        WHERE current_eom_mrr = next_bom_mrr
    ) AS matching_mrr,

    COUNT(*) FILTER (
        WHERE current_eom_mrr <> next_bom_mrr
    ) AS mismatching_mrr,

    COUNT(*) FILTER (
        WHERE current_eom_mrr IS NULL
           OR next_bom_mrr IS NULL
    ) AS null_mrr
FROM monthly_comparison;

-- Further investigate mismatching MRR rows
SELECT
    CASE
        WHEN TRY_CAST(eom_mrr AS DOUBLE)
             - TRY_CAST(bom_mrr AS DOUBLE) > 0
            THEN 'MRR increased'

        WHEN TRY_CAST(eom_mrr AS DOUBLE)
             - TRY_CAST(bom_mrr AS DOUBLE) < 0
            THEN 'MRR decreased'

        ELSE 'MRR unchanged'
    END AS mrr_movement,

    CASE
        WHEN TRY_CAST(churn_mrr AS DOUBLE) < 0
            THEN 'Has churn_mrr'
        ELSE 'No churn_mrr'
    END AS churn_status,

    COUNT(*) AS row_count

FROM raw.finance_cube_data
WHERE TRY_CAST(churn_mrr AS DOUBLE) <>
      TRY_CAST(eom_mrr AS DOUBLE)
      - TRY_CAST(bom_mrr AS DOUBLE)

GROUP BY 1, 2
ORDER BY 1, 2;

--6. GMV base month checks
-- Data type validation for gmv_base_month
SELECT
    'order_month' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE TRY_CAST(order_month || '-01' AS DATE) IS NULL
    ) AS invalid_rows,
    MIN(order_month) AS min_value,
    MAX(order_month) AS max_value
FROM raw.gmv_base_month

UNION ALL

SELECT
    'total_gmv',
    COUNT(*),
    COUNT(*) FILTER (
        WHERE TRY_CAST(total_gmv AS DOUBLE) IS NULL
    ),
    MIN(TRY_CAST(total_gmv AS DOUBLE))::VARCHAR,
    MAX(TRY_CAST(total_gmv AS DOUBLE))::VARCHAR
FROM raw.gmv_base_month;

-- GMV < 0, GMV = 0, GMV > 0 counts
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE TRY_CAST(total_gmv AS DOUBLE) = 0
    ) AS zero_gmv,
    COUNT(*) FILTER (
        WHERE TRY_CAST(total_gmv AS DOUBLE) < 0
    ) AS negative_gmv,
    COUNT(*) FILTER (
        WHERE TRY_CAST(total_gmv AS DOUBLE) > 0
    ) AS positive_gmv
FROM raw.gmv_base_month;

-- Investigate extreme GMV values and their corresponding tenants
WITH extreme_merchants AS (
    SELECT DISTINCT tenant_id
    FROM raw.gmv_base_month
    WHERE TRY_CAST(total_gmv AS DOUBLE) >= 1000000000
)
SELECT
    g.tenant_id,
    g.order_month,
    g.shop_currency_code,
    TRY_CAST(g.total_gmv AS DOUBLE) AS total_gmv
FROM raw.gmv_base_month g
INNER JOIN extreme_merchants e
    ON g.tenant_id = e.tenant_id
ORDER BY g.tenant_id, g.order_month, g.shop_currency_code;

-- GMV distribution statistics by shop_currency_code
WITH gmv AS (
    SELECT
        shop_currency_code,
        TRY_CAST(total_gmv AS DOUBLE) AS gmv
    FROM raw.gmv_base_month
)
SELECT
    shop_currency_code,
    COUNT(*) AS row_count,
    MIN(gmv) AS min_gmv,
    MEDIAN(gmv) AS median_gmv,
    QUANTILE_CONT(gmv, 0.95) AS p95,
    QUANTILE_CONT(gmv, 0.99) AS p99,
    MAX(gmv) AS max_gmv
FROM gmv
GROUP BY shop_currency_code
HAVING COUNT(*) >= 30
ORDER BY row_count DESC;

-- Further investigate extreme GMV values by shop_currency_code
WITH gmv AS (
    SELECT
        shop_currency_code,
        TRY_CAST(total_gmv AS DOUBLE) AS gmv
    FROM raw.gmv_base_month
),
currency_stats AS (
    SELECT
        shop_currency_code,
        COUNT(*) AS row_count,
        QUANTILE_CONT(gmv, 0.99) AS p99,
        MAX(gmv) AS max_gmv
    FROM gmv
    GROUP BY shop_currency_code
    HAVING COUNT(*) >= 30
)
SELECT
    s.shop_currency_code,
    s.row_count,
    ROUND(s.p99, 2) AS p99,
    ROUND(s.max_gmv, 2) AS max_gmv,
    ROUND(s.max_gmv / NULLIF(s.p99, 0), 2) AS max_to_p99_ratio,
    COUNT(*) FILTER (
        WHERE g.gmv > 10 * s.p99
    ) AS rows_over_10x_p99
FROM currency_stats s
JOIN gmv g
    ON s.shop_currency_code = g.shop_currency_code
GROUP BY
    s.shop_currency_code,
    s.row_count,
    s.p99,
    s.max_gmv
ORDER BY max_to_p99_ratio DESC;

--7. Search traffic raw monthly checks
-- Null and blank values check for search_traffic_raw_monthly
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE tenant_id IS NULL OR TRIM(tenant_id) = ''
    ) AS missing_tenant_id,
    COUNT(*) FILTER (
        WHERE order_month IS NULL OR TRIM(order_month) = ''
    ) AS missing_order_month,
    COUNT(*) FILTER (
        WHERE total_searches IS NULL OR TRIM(total_searches) = ''
    ) AS missing_total_searches,
    COUNT(*) FILTER (
        WHERE total_product_click IS NULL OR TRIM(total_product_click) = ''
    ) AS missing_product_click,
    COUNT(*) FILTER (
        WHERE total_search_click IS NULL OR TRIM(total_search_click) = ''
    ) AS missing_search_click,
    COUNT(*) FILTER (
        WHERE total_add_carts IS NULL OR TRIM(total_add_carts) = ''
    ) AS missing_add_carts,
    COUNT(*) FILTER (
        WHERE total_orders IS NULL OR TRIM(total_orders) = ''
    ) AS missing_orders,
    COUNT(*) FILTER (
        WHERE total_sales IS NULL OR TRIM(total_sales) = ''
    ) AS missing_sales
FROM raw.search_traffic_raw_monthly;

-- Data type validation and distribution statistics for search_traffic_raw_monthly
WITH parsed AS (
    SELECT
        TRY_CAST(order_month || '-01' AS DATE) AS order_month_date,
        TRY_CAST(total_searches AS DOUBLE) AS total_searches,
        TRY_CAST(total_product_click AS DOUBLE) AS total_product_click,
        TRY_CAST(total_search_click AS DOUBLE) AS total_search_click,
        TRY_CAST(total_add_carts AS DOUBLE) AS total_add_carts,
        TRY_CAST(total_orders AS DOUBLE) AS total_orders,
        TRY_CAST(total_sales AS DOUBLE) AS total_sales
    FROM raw.search_traffic_raw_monthly
),
metrics AS (
    SELECT 'total_searches' AS metric, total_searches AS value FROM parsed
    UNION ALL
    SELECT 'total_product_click', total_product_click FROM parsed
    UNION ALL
    SELECT 'total_search_click', total_search_click FROM parsed
    UNION ALL
    SELECT 'total_add_carts', total_add_carts FROM parsed
    UNION ALL
    SELECT 'total_orders', total_orders FROM parsed
    UNION ALL
    SELECT 'total_sales', total_sales FROM parsed
)
SELECT
    metric,
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (WHERE value IS NULL) AS invalid_numeric,
    COUNT(*) FILTER (WHERE value < 0) AS negative_rows,
    COUNT(*) FILTER (WHERE value = 0) AS zero_rows,
    COUNT(*) FILTER (WHERE value <> FLOOR(value)) AS non_integer_rows,
    MIN(value) AS min_value,
    MAX(value) AS max_value
FROM metrics
GROUP BY metric
ORDER BY metric;

-- order_month distribution
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE TRY_CAST(order_month || '-01' AS DATE) IS NULL
    ) AS invalid_months,
    MIN(TRY_CAST(order_month || '-01' AS DATE)) AS min_month,
    MAX(TRY_CAST(order_month || '-01' AS DATE)) AS max_month
FROM raw.search_traffic_raw_monthly;

-- Check for logical inconsistencies in search_traffic_raw_monthly
WITH parsed AS (
    SELECT
        TRY_CAST(total_searches AS BIGINT) AS searches,
        TRY_CAST(total_product_click AS BIGINT) AS product_clicks,
        TRY_CAST(total_search_click AS BIGINT) AS search_clicks,
        TRY_CAST(total_add_carts AS BIGINT) AS add_carts,
        TRY_CAST(total_orders AS BIGINT) AS orders
    FROM raw.search_traffic_raw_monthly
)
SELECT
    COUNT(*) AS total_rows,
    COUNT(*) FILTER (
        WHERE search_clicks > searches
    ) AS search_clicks_gt_searches,
    COUNT(*) FILTER (
        WHERE product_clicks > searches
    ) AS product_clicks_gt_searches,
    COUNT(*) FILTER (
        WHERE add_carts > product_clicks
    ) AS add_carts_gt_product_clicks,
    COUNT(*) FILTER (
        WHERE orders > add_carts
    ) AS orders_gt_add_carts
FROM parsed;

-- Further investigate rows with logical inconsistencies
SELECT
    tenant_id,
    order_month,
    TRY_CAST(total_searches AS BIGINT) AS searches,
    TRY_CAST(total_search_click AS BIGINT) AS search_clicks,
    TRY_CAST(total_product_click AS BIGINT) AS product_clicks,
    TRY_CAST(total_add_carts AS BIGINT) AS add_carts,
    TRY_CAST(total_orders AS BIGINT) AS orders
FROM raw.search_traffic_raw_monthly
WHERE
    TRY_CAST(total_search_click AS BIGINT)
        > TRY_CAST(total_searches AS BIGINT)
    OR TRY_CAST(total_product_click AS BIGINT)
        > TRY_CAST(total_searches AS BIGINT)
    OR TRY_CAST(total_orders AS BIGINT)
        > TRY_CAST(total_add_carts AS BIGINT)
ORDER BY tenant_id, order_month;

-- Investigate extreme total_sales in search_traffic_raw_monthly
SELECT
    tenant_id,
    order_month,
    TRY_CAST(total_searches AS BIGINT) AS total_searches,
    TRY_CAST(total_product_click AS BIGINT) AS total_product_click,
    TRY_CAST(total_search_click AS BIGINT) AS total_search_click,
    TRY_CAST(total_add_carts AS BIGINT) AS total_add_carts,
    TRY_CAST(total_orders AS BIGINT) AS total_orders,
    TRY_CAST(total_sales AS DOUBLE) AS total_sales
FROM raw.search_traffic_raw_monthly
ORDER BY TRY_CAST(total_sales AS DOUBLE) DESC
LIMIT 20;

WITH extreme_merchants AS (
    SELECT DISTINCT tenant_id
    FROM raw.search_traffic_raw_monthly
    WHERE TRY_CAST(total_sales AS DOUBLE) >= 1000000000
)
SELECT
    s.tenant_id,
    s.order_month,
    TRY_CAST(s.total_orders AS BIGINT) AS total_orders,
    TRY_CAST(s.total_sales AS DOUBLE) AS total_sales
FROM raw.search_traffic_raw_monthly s
JOIN extreme_merchants e
    ON s.tenant_id = e.tenant_id
ORDER BY s.tenant_id, s.order_month;

--8. Cross-table checks
-- Check for matching shop keys across finance_cube_data, gmv_base_month, search_traffic_raw_monthly
WITH finance_keys AS (
    SELECT DISTINCT LOWER(TRIM(shop_domain)) AS shop_key
    FROM raw.finance_cube_data
),
gmv_keys AS (
    SELECT DISTINCT LOWER(TRIM(tenant_id)) AS shop_key
    FROM raw.gmv_base_month
),
search_keys AS (
    SELECT DISTINCT LOWER(TRIM(tenant_id)) AS shop_key
    FROM raw.search_traffic_raw_monthly
),
key_matches AS (
    SELECT
        'Finance - GMV' AS comparison,
        COUNT(*) AS matched_shops
    FROM finance_keys f
    INNER JOIN gmv_keys g USING (shop_key)

    UNION ALL

    SELECT
        'Finance - Search' AS comparison,
        COUNT(*) AS matched_shops
    FROM finance_keys f
    INNER JOIN search_keys s USING (shop_key)

    UNION ALL

    SELECT
        'GMV - Search' AS comparison,
        COUNT(*) AS matched_shops
    FROM gmv_keys g
    INNER JOIN search_keys s USING (shop_key)
),
finance_id_types AS (
    SELECT
        CASE
            WHEN shop_key LIKE 'store-%myshopify.com'
                THEN 'Shopify domain'
            WHEN STARTS_WITH(shop_key, 'cus_')
                THEN 'cus_ ID'
            WHEN UPPER(shop_key) = 'REDACTED'
                THEN 'REDACTED'
            ELSE 'Other format'
        END AS id_type,
        COUNT(*) AS shop_count
    FROM finance_keys
    GROUP BY 1
)
SELECT
    'MATCH: ' || comparison AS check_type,
    matched_shops AS result
FROM key_matches

UNION ALL

SELECT
    'FINANCE ID: ' || id_type AS check_type,
    shop_count AS result
FROM finance_id_types

ORDER BY check_type;

-- June active shops analysis
WITH june_active AS (
    SELECT DISTINCT
        LOWER(TRIM(shop_domain)) AS shop_key
    FROM raw.finance_cube_data
    WHERE TRY_CAST(date_t_eom AS DATE) = DATE '2026-06-30'
      AND TRY_CAST(eom_mrr AS DOUBLE) > 0
),
june_gmv AS (
    SELECT DISTINCT
        LOWER(TRIM(tenant_id)) AS shop_key
    FROM raw.gmv_base_month
    WHERE order_month = '2026-06'
),
june_search AS (
    SELECT DISTINCT
        LOWER(TRIM(tenant_id)) AS shop_key
    FROM raw.search_traffic_raw_monthly
    WHERE order_month = '2026-06'
)
SELECT
    COUNT(*) AS active_shops,
    COUNT(g.shop_key) AS shops_with_gmv,
    COUNT(s.shop_key) AS shops_with_search,
    COUNT(
        CASE WHEN g.shop_key IS NOT NULL
              AND s.shop_key IS NOT NULL
             THEN 1 END
    ) AS shops_with_both
FROM june_active a
LEFT JOIN june_gmv g USING (shop_key)
LEFT JOIN june_search s USING (shop_key);

-- Monthly active shops (eom_mrr > 0) comparison across tables
WITH finance_monthly AS (
    SELECT
        DATE_TRUNC('month', TRY_CAST(date_t_eom AS DATE)) AS month,
        COUNT(DISTINCT LOWER(TRIM(shop_domain))) AS finance_shops
    FROM raw.finance_cube_data
    GROUP BY 1
),
gmv_monthly AS (
    SELECT
        TRY_CAST(order_month || '-01' AS DATE) AS month,
        COUNT(DISTINCT LOWER(TRIM(tenant_id))) AS gmv_shops
    FROM raw.gmv_base_month
    GROUP BY 1
),
search_monthly AS (
    SELECT
        TRY_CAST(order_month || '-01' AS DATE) AS month,
        COUNT(DISTINCT LOWER(TRIM(tenant_id))) AS search_shops
    FROM raw.search_traffic_raw_monthly
    GROUP BY 1
)
SELECT
    f.month,
    f.finance_shops,
    g.gmv_shops,
    s.search_shops
FROM finance_monthly f
LEFT JOIN gmv_monthly g USING (month)
LEFT JOIN search_monthly s USING (month)
ORDER BY f.month;

-- Monthly active shops (shop with Finance snapshot) comparison
WITH finance_monthly AS (
    SELECT DISTINCT
        DATE_TRUNC('month', TRY_CAST(date_t_eom AS DATE)) AS month,
        LOWER(TRIM(shop_domain)) AS shop_key
    FROM raw.finance_cube_data
),
gmv_monthly AS (
    SELECT DISTINCT
        TRY_CAST(order_month || '-01' AS DATE) AS month,
        LOWER(TRIM(tenant_id)) AS shop_key
    FROM raw.gmv_base_month
),
search_monthly AS (
    SELECT DISTINCT
        TRY_CAST(order_month || '-01' AS DATE) AS month,
        LOWER(TRIM(tenant_id)) AS shop_key
    FROM raw.search_traffic_raw_monthly
)
SELECT
    f.month,
    COUNT(*) AS finance_shops,
    COUNT(g.shop_key) AS matched_gmv_shops,
    COUNT(s.shop_key) AS matched_search_shops,
    ROUND(
        100.0 * COUNT(g.shop_key) / COUNT(*), 2
    ) AS gmv_coverage_pct,
    ROUND(
        100.0 * COUNT(s.shop_key) / COUNT(*), 2
    ) AS search_coverage_pct
FROM finance_monthly f
LEFT JOIN gmv_monthly g
    ON f.month = g.month
   AND f.shop_key = g.shop_key
LEFT JOIN search_monthly s
    ON f.month = s.month
   AND f.shop_key = s.shop_key
GROUP BY f.month
ORDER BY f.month;