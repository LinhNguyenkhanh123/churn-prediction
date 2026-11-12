

# Data Quality Assessment

## 1. Dataset Overview

| Table | Rows | Columns | Grain |
|---|---:|---:|---|
| `dim_plan_name` | 111,013 | 5 | One row per tenant |
| `finance_cube_data` | 118,043 | 6 | One shop per monthly snapshot |
| `gmv_base_month` | 80,339 | 4 | One shop per month per currency |
| `search_traffic_raw_monthly` | 48,927 | 8 | One shop per month |
| **Total** | **358,322** | **23** | |

All source columns were loaded as `VARCHAR` to preserve original values. No cleaning or modification was performed in RAW.

## 2. Data Quality Results

| Table | Key findings | Status |
|---|---|---|
| `dim_plan_name` | No duplicate tenants. Contains literal `'null'` values in `price_version` and `uninstallation_reason`; 36 actual SQL NULLs in `uninstallation_reason`. 495 distinct non-missing reason strings across multiple languages. | Review required |
| `finance_cube_data` | No duplicate shop-month records. All tested dates and numeric fields are parseable. 240 negative-tenure records, all with zero MRR. MRR continuity across consecutive snapshots is consistent. | Mostly valid |
| `gmv_base_month` | No duplicate shop-month-currency records. 93 currency codes. 656 zero-GMV rows, no negative values. Several extreme GMV outliers. | Review required |
| `search_traffic_raw_monthly` | No duplicate shop-month records. All tested values are parseable and non-negative. Some funnel metric relationships need clarification. One prominent extreme sales value. | Mostly valid |

## 3. Cross-table Consistency

Shop identifiers were normalized using `LOWER(TRIM(...))`.

| Table pair | Matched shops | Reference |
|---|---:|---:|
| Finance – GMV | 9,013 | 9,013 |
| Finance – Search | 7,628 | 7,628 |
| GMV – Search | 8,196 | 8,196 |

June 2026 active-shop coverage:

| Metric | Shops |
|---|---:|
| Active shops (`eom_mrr > 0`) | 8,670 |
| With GMV data | 7,490 |
| With Search data | 6,401 |
| With both | 5,862 |

### Monthly coverage within Finance

| Month | GMV coverage | Search coverage |
|---|---:|---:|
| June 2026 | 26.77% | 22.45% |
| July 2026 | 26.14% | 22.04% |
| August 2026 | 25.60% | 21.39% |
| September 2026 | 24.88% | 17.94% |

Coverage declines over time, particularly for Search in September. Missing monthly activity records should not automatically be treated as data errors.

## 4. Key Issues and STAGING Considerations

| Issue | Proposed handling |
|---|---|
| Literal `'null'` values | Preserve separately from SQL NULL until semantics are confirmed. |
| Multilingual uninstallation reasons | Standardize into documented categories while retaining original text. |
| Negative tenure | Add a data-quality flag; do not silently replace values. |
| Non-standard Finance IDs (`cus_`, `REDACTED`) | Retain without inventing identifier mappings. |
| Multiple GMV currencies | Keep currency in the data grain; never sum across currencies without conversion. |
| Extreme GMV and Search sales | Preserve source values and flag potential outliers; no automatic deletion or capping. |
| Search funnel inconsistencies | Do not enforce unverified metric relationships. |
| Missing monthly GMV/Search records | Distinguish absent activity records from NULL values in existing records. |

## 5. Decisions for Downstream Modeling

- Use Finance as the anchor table for merchant-month snapshots.
- Define an active merchant as `eom_mrr > 0`, following the main project specification.
- Define churn using `churn_mrr < 0` in the next monthly snapshot.
- Do not label merchants without a following snapshot as non-churn.
- Use September 2026 for scoring only.
- Normalize shop identifiers before joining.
- Ensure features use only information available at or before the prediction snapshot to prevent data leakage.

## 6. Conclusion

No duplicate-key issues were found at the confirmed table grains, and cross-table matching results agree with the project guide.

The main concerns involve business semantics, currency consistency, outliers, identifier formats and monthly data coverage.