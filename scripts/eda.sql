--1. Profile the distribution of key metrics in the mart.fact_merchant_monthly table
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

--2. Zero-value analysis for key metrics
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

--3. MRR movement analysis
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

--4. MRR movement analysis with churn label
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