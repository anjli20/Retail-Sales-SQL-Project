# Retail Sales Analysis — SQL Project

End-to-end retail sales analysis in PostgreSQL covering data cleaning, feature engineering, 
business analysis, advanced customer segmentation, and a Power BI-ready reporting layer.

## Dataset

| Column | Description |
|---|---|
| `transactions_id` | Unique transaction ID (PK) |
| `sale_date / sale_time` | When the transaction occurred |
| `customer_id` | Customer identifier |
| `gender / age` | Customer demographics |
| `category` | Clothing, Beauty, or Electronics |
| `quantity / price_per_unit` | Units sold and unit price |
| `cogs` | Cost of goods sold |
| `total_sale` | Total transaction value |

---

## Project Structure

### Section 1 — Database Setup
Creates the `retail_sales` table and loads the dataset.

### Section 2 — Data Cleaning
Checks for duplicates, nulls, business-logic anomalies (negative sales, impossible ages), and `total_sale` consistency. 
Result: dataset confirmed clean across all checks.

### Section 3 — Feature Engineering
Adds four derived columns: `profit`, `profit_margin` (both generated/stored), `age_group` (Gen Z / Millennial / Gen X / Boomer), and `day_of_week`.

### Section 4 — Exploratory Data Analysis
- **Overview** — total transactions, revenue, profit, avg transaction value, date range
- **Percentiles** — P25 / median / P75 / P90 / P95 of `total_sale`

### Section 5 — Business Analysis (10 Questions)

| # | Question |
|---|---|
| Q1 | All sales on a specific date with each transaction's % share of day revenue |
| Q2 | Clothing transactions with quantity ≥ 4 in November 2022, ranked by units sold |
| Q3 | Revenue, profit, margin, and revenue share % by product category |
| Q4 | Spend breakdown by category, age group, and gender |
| Q5 | All transactions above £1,000 with profit, margin, and sales quartile |
| Q6 | Transaction count and revenue by gender per category with % share |
| Q7 | Best-selling month per year with month-on-month revenue growth rate |
| Q8 | Top 5 customers by lifetime value with full loyalty profile |
| Q9 | Customer segmentation by purchase frequency — one-time to loyal buyers |
| Q10 | Orders, revenue, and profit by time-of-day shift (Morning / Afternoon / Evening) |

### Section 6 — Advanced Analytics (7 Techniques)

| # | Analysis |
|---|---|
| A1 | **RFM segmentation** — scores customers on Recency, Frequency, Monetary value and classifies them into Champions, Loyal, At Risk, Lost, and more |
| A2 | **Cohort analysis** — tracks customer retention month-by-month from first purchase date |
| A3 | **Basket / affinity analysis** — identifies which product categories are most frequently bought together |
| A4 | **Day-of-week heatmap** — revenue and order volume by weekday |
| A5 | **Cumulative revenue** — running total of monthly revenue across 2 years |
| A6 | **Z-score anomaly detection** — flags statistically unusual daily revenue days |
| A7 | **Price sensitivity** — revenue, units, and margin by price tier (Budget / Mid / Premium / Luxury) |

### Section 7 — Reporting Views
Two views built for direct Power BI connection:
- **`vw_executive_summary`** — monthly revenue, profit, and margin by category
- **`vw_customer_360`** — full customer profile including lifetime value and days since last purchase

## Key Findings

- All three categories contribute roughly equal revenue — no single dominant product area
- Most customers (60%+) are repeat/loyal buyers, averaging ~13 purchases over 2 years
- Evening is the highest-revenue shift across both years
- Anomaly detection flagged November spikes consistent with Black Friday shopping behaviour
- Basket analysis shows strong cross-category purchasing — clear cross-sell opportunity
