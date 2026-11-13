# Churn Prediction – Phase 2 Summary

## 1. Target Definition

### Active merchant

The implemented definition is:

```sql
eom_mrr > 0
AND churn_mrr = 0
```

This differs from the coach's suggested `bom_mrr <> 0 AND churn_mrr = 0`. The implemented definition retains merchants with positive ending MRR even when beginning MRR is zero.

### Churn target

`churn_next_30d = 1` when the next consecutive monthly snapshot has `next_churn_mrr < 0`.

`churn_next_30d = 0` when the next consecutive monthly snapshot has `next_churn_mrr = 0`.

The label is NULL when there is no next consecutive snapshot or the next churn MRR does not meet either condition.

The target is therefore based on next-month churn MRR, not simply on whether ending MRR becomes 0.

### Final label distribution

| Snapshot | Active rows | Churn | Non-churn | NULL labels | Churn rate |
|---|---:|---:|---:|---:|---:|
| June 2026 | 8,669 | 247 | 8,422 | 0 | 2.85% |
| July 2026 | 8,512 | 215 | 8,297 | 0 | 2.53% |
| August 2026 | 8,375 | 205 | 8,170 | 0 | 2.45% |
| **Total** | **25,556** | **667** | **24,889** | **0** | **2.61%** |

September 2026 has 8,227 active merchants but no next-month snapshot available for labeling. These records were excluded from the supervised training set.

## 2. Feature Engineering

### 3.1 Finance features

| Feature | Definition |
|---|---|
| `tenure_months` | Merchant tenure |
| `bom_mrr` | Beginning-of-month MRR |
| `eom_mrr` | End-of-month MRR |
| `mrr_change` | `eom_mrr - bom_mrr` |
| `mrr_growth_rate` | `(eom_mrr - bom_mrr) / bom_mrr`, when BOM > 0 |
| `mrr_movement_type` | MRR movement category |

Movement categories:
- `new_mrr`: BOM = 0 and EOM > 0
- `increased`: EOM > BOM
- `unchanged`: EOM = BOM
- `decreased`: EOM < BOM

`mrr_growth_rate` remains NULL when BOM = 0 because the growth rate is undefined.

### 3.2 GMV features

| Feature | Definition |
|---|---|
| `gmv_30d` | Current month's GMV |
| `gmv_60d` | Current month plus previous month |
| `gmv_growth_30d` | Current month versus previous month |
| `gmv_growth_60d` | Current two-month window versus previous two-month window |
| `gmv_currency_code` | Currency associated with GMV |
| `has_gmv_data` | GMV data availability indicator |
| `multi_currency_flag` | Indicates multiple currencies in a merchant-month |

Currency handling:
- Single currency: retain GMV and currency code.
- Multiple currencies: set aggregate GMV to NULL and flag the record.
- No GMV record: retain NULL GMV and set `has_gmv_data = 0`.
- Growth is calculated only when the comparison periods have consistent currency and valid denominators.

GMV/MRR ratios were excluded because the MRR currency has not been identified.

### 3.3 Search Traffic features

**Volume 30d**
- `searches_30d`
- `product_clicks_30d`
- `search_clicks_30d`
- `add_carts_30d`
- `orders_30d`

**Volume 60d**
- `searches_60d`
- `product_clicks_60d`
- `search_clicks_60d`
- `add_carts_60d`
- `orders_60d`

**Growth 30d and 60d**
- Searches growth
- Product clicks growth
- Search clicks growth
- Add carts growth
- Orders growth

**Conversion 30d and 60d**
- `search_to_product_click_rate`
- `search_click_rate`
- `product_click_to_cart_rate`
- `cart_to_order_rate`

The redundant `search_to_search_rate_30d` was excluded because it is always 1 when data is available.

Search 60d volume requires data in both months. Growth features require valid comparison periods and denominators. Conversion features remain NULL when the relevant denominator is 0 or data is unavailable.

### 3.4 Excluded features

- `churn_mrr`, `next_churn_mrr`, `next_eom_mrr`: target construction or future-related information.
- `churn_label`: retained as the source target, renamed to `churn_next_30d`.
- `next_snapshot_date`: future-related metadata.
- `total_sales`: excluded from the model candidates because its currency is not established.
- `price_version`, `boost_plan_name`, `boost_price_plan`: excluded because historical validity timestamps are unavailable.
- `uninstallation_reason`: excluded due to potential target leakage.
- GMV/MRR ratio: excluded until MRR currency is known.

## 3. Training set

The final table was created by joining:
- Finance features from `mart.fact_merchant_monthly`
- GMV features from `staging.stg_gmv_features`
- Search features from `staging.stg_search_features`

### Feature candidates

- 6 Finance features
- 7 GMV features
- 28 Search features

## 4. Train/Test Split

| Snapshot | Split | Rows | Churn | Non-churn |
|---|---|---:|---:|---:|
| June 2026 | train | 8,669 | 247 | 8,422 |
| July 2026 | train | 8,512 | 215 | 8,297 |
| August 2026 | test | 8,375 | 205 | 8,170 |
| **Total** | | **25,556** | **667** | **24,889** |

The split is time-based:
- Train: June and July 2026
- Test: August 2026

## 5. Data Quality Validation

### 5.1 Grain validation

| Check | Result |
|---|---:|
| Total rows | 25,556 |
| Distinct merchants | 8,843 |
| Distinct merchant-month keys | 25,556 |
| Duplicate keys | 0 |
| Invalid keys | 0 |

### 5.2 NULL analysis

**Finance**

| Feature | NULL rows | NULL % |
|---|---:|---:|
| `tenure_months` | 0 | 0% |
| `bom_mrr` | 0 | 0% |
| `eom_mrr` | 0 | 0% |
| `mrr_change` | 0 | 0% |
| `mrr_growth_rate` | 308 | 1.21% |
| `mrr_movement_type` | 0 | 0% |
| `has_gmv_data` | 0 | 0% |
| `multi_currency_flag` | 0 | 0% |
| `has_search_data` | 0 | 0% |

The 308 NULL values in `mrr_growth_rate` are due to BOM = 0.

**GMV**

| Feature | NULL rows | NULL % |
|---|---:|---:|
| `gmv_30d` | 3,657 | 14.31% |
| `gmv_60d` | 4,227 | 16.54% |
| `gmv_growth_30d` | 4,341 | 16.99% |
| `gmv_growth_60d` | 4,942 | 19.34% |
| `gmv_currency_code` | 3,657 | 14.31% |

There are:
- 3,504 merchant-months without GMV records.
- 153 merchant-months with multiple currencies.

These account for the 3,657 NULL values in current-month GMV.

**Search**

| Group | Feature | NULL rows | NULL % |
|---|---|---:|---:|
| Volume 30d | Each of 5 features | 6,720 | 26.29% |
| Volume 60d | Each of 5 features | 7,164 | 28.03% |
| Growth 30d | Searches | 7,164 | 28.03% |
| | Product clicks | 10,442 | 40.86% |
| | Search clicks | 10,442 | 40.86% |
| | Add carts | 11,805 | 46.20% |
| | Orders | 14,754 | 57.72% |
| Growth 60d | Searches | 7,764 | 30.38% |
| | Product clicks | 10,527 | 41.20% |
| | Search clicks | 10,527 | 41.20% |
| | Add carts | 11,501 | 45.00% |
| | Orders | 13,921 | 54.47% |
| Conversion 30d | Search-to-product-click | 6,720 | 26.29% |
| | Search-click rate | 6,720 | 26.29% |
| | Product-click-to-cart | 10,286 | 40.25% |
| | Cart-to-order | 11,710 | 45.82% |
| Conversion 60d | Search-to-product-click | 7,164 | 28.03% |
| | Search-click rate | 7,164 | 28.03% |
| | Product-click-to-cart | 10,129 | 39.63% |
| | Cart-to-order | 11,184 | 43.76% |

Search NULLs arise from missing source records, insufficient historical months and zero denominators for conversion or growth calculations.

**Missing-value decision:** Retain NULLs in the SQL training set. Handle imputation and missing indicators in the modeling pipeline. Do not automatically replace missing activity with zero.

## 6. MRR Movement Analysis

| Movement type | Rows | Share | Churn | Churn rate |
|---|---:|---:|---:|---:|
| unchanged | 25,052 | 98.03% | 610 | 2.43% |
| new_mrr | 308 | 1.21% | 49 | 15.91% |
| increased | 138 | 0.54% | 4 | 2.90% |
| decreased | 58 | 0.23% | 4 | 6.90% |

The `new_mrr` and `decreased` groups show higher observed churn rates, but their sample sizes are small. These patterns should be investigated further in Phase 3 rather than treated as definitive conclusions.