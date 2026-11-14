### 1. Problem and Data

This project aims to help Shopify merchants identify customers who are at risk of churning within the next 30 days, enabling the Customer Success team to prioritize retention efforts. The model uses merchant-level monthly data, combining financial indicators such as MRR, GMV activity, search behavior, merchant tenure, and plan-related information. A total of 25,556 labeled merchant-month records from June to August 2026 were used for model development and evaluation: June and July data were used for training, while August was reserved for final testing. The selected model was subsequently applied to 8,227 eligible merchants in September 2026 to generate churn-risk scores for business prioritization.

### 2. Model Results

The final HistGradientBoosting Tuned model outperformed both the Dummy Classifier and Logistic Regression on the August 2026 test set.

| Model | ROC-AUC | PR-AUC |
|---|---:|---:|
| Dummy Classifier | 0.5000 | 0.0245 |
| Logistic Regression | 0.6977 | 0.0665 |
| HistGradientBoosting Tuned | **0.7371** | **0.0817** |

For business prioritization, the final model also achieved better results than Logistic Regression:

| Metric | Logistic Regression Top 5% | Final Model Top 5% | Logistic Regression Top 10% | Final Model Top 10% |
|---|---:|---:|---:|---:|
| Precision@K | 8.59% | **12.41%** | 7.16% | **8.35%** |
| Recall@K | 17.56% | **25.37%** | 29.27% | **34.15%** |
| Lift@K | 3.51x | **5.07x** | 2.93x | **3.41x** |

The final model demonstrates stronger ability to prioritize merchants with higher churn risk. At Top 5%, approximately 12 out of every 100 selected merchants actually churned, and the group had a churn concentration approximately 5.07 times higher than random selection. Expanding the selection to Top 10% increases churn coverage from 25.37% to 34.15%, although it requires the CS team to contact twice as many merchants.

Overall, the model provides a useful prioritization tool for the CS team rather than a definitive prediction of which individual merchant will churn.

### 3. Key Merchant Insights

The model interpretation results highlight several behavioral patterns associated with merchant churn risk.

- **Declining search activity:** Search growth over the previous 60 days is the most influential feature in both permutation importance and SHAP analysis. A decline in search activity may indicate reduced engagement with the application.
- **Declining GMV activity:** GMV growth over the previous 30 days is another important predictor. A decrease in GMV activity may signal weakening merchant business activity on the platform.
- **Merchant tenure:** Tenure contributes to churn-risk estimation, suggesting that merchants at different stages of their lifecycle may exhibit different risk patterns.
- **Data availability:** Missing behavioral indicators also influence model predictions. False positives are more frequently associated with missing search and GMV data, highlighting the importance of interpreting risk scores alongside data availability.

Error analysis further shows that some false negatives are established merchants with relatively high GMV and search activity. This suggests that not all churn cases are preceded by visible declines in platform usage.

These findings should be interpreted as associations learned by the model rather than evidence of causal relationships. They can nevertheless help the CS team identify potential warning signs and guide further investigation into merchant needs.

### 4. Recommendations and Limitations

#### 4.1. Recommended Retention Actions

Based on the segmentation of 5,783 at-risk merchants, retention strategies should be tailored to both churn risk and merchant value.

| Customer Segment | Merchants | Share of Expected MRR at Risk | Recommended Action |
|---|---:|---:|---|
| High Risk – High Value | 561 | 46.37% | Personalized outreach, account reviews and tailored retention plans |
| Low Risk – High Value | 967 | 29.14% | Proactive account health checks and relationship management |
| High Risk – Low Value | 885 | 12.07% | Automated campaigns, product education and targeted support |
| Low Risk – Low Value | 3,370 | 12.43% | Automated engagement and self-service resources |

The High Risk – High Value segment should receive the highest priority because it represents 46.37% of total Expected MRR at Risk while accounting for only 9.70% of at-risk merchants. The Low Risk – High Value segment should also receive proactive attention, as it contributes another 29.14% of Expected MRR at Risk. Automated engagement is more appropriate for lower-value segments to maintain cost efficiency.

#### 4.2. Prioritization Based on Top-K Results

The August test results suggest that the Top 5% strategy is suitable when CS resources are limited: contacting 419 merchants would have captured 52 actual churn cases. Expanding to the Top 10% would require contacting 838 merchants and capture 70 actual churn cases.

Therefore, the CS team can begin with the Top 5% highest-risk merchants and expand outreach based on available capacity. Churn-risk ranking and customer segmentation should be used together: the former identifies merchants with higher estimated churn probability, while the latter helps determine the appropriate level of intervention based on merchant value.

These figures represent historical test-set results and should not be interpreted as guaranteed retention outcomes.

#### 4.3. Model Limitations

- **Limited historical data:** The model was trained using June and July data and evaluated on August data. Its ability to generalize across longer periods or seasonal changes remains unverified.
- **Class imbalance:** Only 2.45% of merchants in the August test set actually churned, making it challenging to identify all potential churn cases.
- **Incomplete behavioral data:** Missing search and GMV information may affect prediction reliability and contribute to false positives or false negatives.
- **No intervention validation:** The model estimates churn risk but does not establish whether contacting merchants or offering retention support will prevent churn.

Finally, September 2026 is an unlabeled scoring period. Therefore, predictive performance and actual retention outcomes for September cannot yet be evaluated. These should be assessed once the corresponding churn labels become available.