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
        ) AS next_bom_mrr

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
        ) AS next_churn_mrr

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

        WHEN next_churn_mrr < 0 THEN 1

        WHEN next_churn_mrr = 0 THEN 0

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
