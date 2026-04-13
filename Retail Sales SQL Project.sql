-- ============================================================
-- RETAIL SALES ANALYSIS -- SQL PROJECT
-- ============================================================
-- SECTION 1: DATABASE SETUP (same as original)
-- ============================================================
CREATE TABLE retail_sales (
    transactions_id  INT PRIMARY KEY,
    sale_date        DATE,
    sale_time        TIME,
    customer_id      INT,
    gender           VARCHAR(10),
    age              INT,
    category         VARCHAR(35),
    quantity         INT,
    price_per_unit   FLOAT,
    cogs             FLOAT,
    total_sale       FLOAT
);


SELECT * FROM retail_sales;

-- ============================================================
-- SECTION 2: DATA CLEANING 
-- ============================================================

-- 2a. Check for duplicates
SELECT transactions_id, COUNT(*) AS cnt
FROM retail_sales
GROUP BY transactions_id
HAVING COUNT(*) > 1;

-- 2b. Check for nulls
SELECT * FROM retail_sales
WHERE sale_date IS NULL OR sale_time IS NULL OR customer_id IS NULL
   OR gender IS NULL OR age IS NULL OR category IS NULL
   OR quantity IS NULL OR price_per_unit IS NULL OR cogs IS NULL;

-- 2c. Check for business-logic anomalies
SELECT * FROM retail_sales
WHERE total_sale < 0
   OR quantity <= 0
   OR price_per_unit <= 0
   OR age < 0 OR age > 120;

-- 2d. Check for data consistency: total_sale should ≈ quantity * price_per_unit
SELECT transactions_id,
       total_sale,
       ROUND((quantity * price_per_unit)::NUMERIC, 2) AS calculated_sale,
       ROUND(ABS(total_sale - (quantity * price_per_unit))::NUMERIC, 2) AS discrepancy
FROM retail_sales
WHERE ABS(total_sale - (quantity * price_per_unit)) > 1
ORDER BY discrepancy DESC;

-- 2e. Delete null rows
DELETE FROM retail_sales
WHERE sale_date IS NULL OR sale_time IS NULL OR customer_id IS NULL
   OR gender IS NULL OR age IS NULL OR category IS NULL
   OR quantity IS NULL OR price_per_unit IS NULL OR cogs IS NULL;

-- ============================================================
-- SECTION 3: FEATURE ENGINEERING
-- Add derived columns for richer analysis
-- ============================================================
ALTER TABLE retail_sales
    ADD COLUMN profit          FLOAT GENERATED ALWAYS AS (total_sale - cogs) STORED,
    ADD COLUMN profit_margin   FLOAT GENERATED ALWAYS AS (
                                   CASE WHEN total_sale = 0 THEN 0
                                        ELSE ROUND(((total_sale - cogs) / total_sale * 100)::NUMERIC, 2)
                                   END) STORED,
    ADD COLUMN age_group       VARCHAR(20),
    ADD COLUMN day_of_week     VARCHAR(15);

UPDATE retail_sales
SET age_group = CASE
    WHEN age < 25 THEN 'Gen Z (< 25)'
    WHEN age BETWEEN 25 AND 40 THEN 'Millennial (25-40)'
    WHEN age BETWEEN 41 AND 56 THEN 'Gen X (41-56)'
    ELSE 'Boomer (57+)'
END;

UPDATE retail_sales
SET day_of_week = TO_CHAR(sale_date, 'Day');

-- ============================================================
-- SECTION 4: EXPLORATORY DATA ANALYSIS
-- ============================================================

-- 4a. Dataset overview
SELECT
    COUNT(*)                                          AS total_transactions,
    COUNT(DISTINCT customer_id)                       AS unique_customers,
    COUNT(DISTINCT category)                          AS categories,
    MIN(sale_date)                                    AS first_sale,
    MAX(sale_date)                                    AS last_sale,
    ROUND(AVG(total_sale)::NUMERIC, 2)                AS avg_transaction_value,
    ROUND(SUM(total_sale)::NUMERIC, 2)                AS total_revenue,
    ROUND(SUM(profit)::NUMERIC, 2)                    AS total_profit,
    ROUND(AVG(profit_margin)::NUMERIC, 2)             AS avg_profit_margin_pct
FROM retail_sales;

-- 4b. Sales distribution (percentiles)
SELECT
    PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY total_sale) AS p25,
    PERCENTILE_CONT(0.50) WITHIN GROUP (ORDER BY total_sale) AS median,
    PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY total_sale) AS p75,
    PERCENTILE_CONT(0.90) WITHIN GROUP (ORDER BY total_sale) AS p90,
    PERCENTILE_CONT(0.95) WITHIN GROUP (ORDER BY total_sale) AS p95
FROM retail_sales;

-- ============================================================
-- SECTION 5: ADVANCED BUSINESS ANALYSIS
-- ============================================================

-- -------------------------------------------------------
-- Q1: Sales on a specific date with full context
-- -------------------------------------------------------
SELECT
    s.*,
    ROUND((s.total_sale / SUM(s.total_sale) OVER () * 100)::NUMERIC, 2) AS pct_of_day_total
FROM retail_sales s
WHERE sale_date = '2022-11-05'
ORDER BY total_sale DESC;

-- -------------------------------------------------------
-- Q2: Category + quantity filter with monthly rank
-- -------------------------------------------------------
SELECT
    TO_CHAR(sale_date, 'YYYY-MM')          AS month,
    category,
    SUM(quantity)                           AS total_units,
    SUM(total_sale)                         AS total_revenue,
    RANK() OVER (
        PARTITION BY TO_CHAR(sale_date, 'YYYY-MM')
        ORDER BY SUM(quantity) DESC
    )                                       AS quantity_rank
FROM retail_sales
WHERE category = 'Clothing'
  AND TO_CHAR(sale_date, 'YYYY-MM') = '2022-11'
  AND quantity >= 4
GROUP BY 1, 2;

-- -------------------------------------------------------
-- Q3: Category performance with profit metrics
-- -------------------------------------------------------
SELECT
    category,
    COUNT(*)                                             AS total_orders,
    SUM(quantity)                                        AS total_units_sold,
    ROUND(SUM(total_sale)::NUMERIC, 2)                   AS total_revenue,
    ROUND(SUM(cogs)::NUMERIC, 2)                         AS total_cogs,
    ROUND(SUM(profit)::NUMERIC, 2)                       AS total_profit,
    ROUND(AVG(profit_margin)::NUMERIC, 2)                AS avg_profit_margin_pct,
    ROUND((SUM(total_sale) / SUM(SUM(total_sale)) OVER () * 100)::NUMERIC, 2) AS revenue_share_pct
FROM retail_sales
GROUP BY category
ORDER BY total_revenue DESC;

-- -------------------------------------------------------
-- Q4: Customer demographics deep dive by category
-- -------------------------------------------------------
SELECT
    category,
    age_group,
    gender,
    COUNT(*)                             AS transactions,
    ROUND(AVG(age)::NUMERIC, 1)          AS avg_age,
    ROUND(AVG(total_sale)::NUMERIC, 2)   AS avg_spend,
    ROUND(SUM(total_sale)::NUMERIC, 2)   AS total_spend
FROM retail_sales
GROUP BY category, age_group, gender
ORDER BY category, total_spend DESC;

-- -------------------------------------------------------
-- Q5: High-value transactions with customer context
-- -------------------------------------------------------
SELECT
    transactions_id,
    customer_id,
    sale_date,
    category,
    total_sale,
    profit,
    profit_margin,
    NTILE(4) OVER (ORDER BY total_sale) AS sales_quartile
FROM retail_sales
WHERE total_sale > 1000
ORDER BY total_sale DESC;

-- -------------------------------------------------------
-- Q6: Gender × category cross-tab with % share
-- -------------------------------------------------------
SELECT
    category,
    gender,
    COUNT(*)                                                         AS total_transactions,
    ROUND(SUM(total_sale)::NUMERIC, 2)                               AS total_revenue,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY category),
    2)                                                               AS pct_within_category
FROM retail_sales
GROUP BY category, gender
ORDER BY category, total_revenue DESC;

-- -------------------------------------------------------
-- Q7: Best month per year + MoM growth rate
-- -------------------------------------------------------
WITH monthly_sales AS (
    SELECT
        EXTRACT(YEAR  FROM sale_date)  AS yr,
        EXTRACT(MONTH FROM sale_date)  AS mo,
        TO_CHAR(sale_date, 'Mon YYYY') AS month_label,
        SUM(total_sale)                AS monthly_revenue,
        COUNT(*)                       AS orders
    FROM retail_sales
    GROUP BY 1, 2, 3
),
monthly_with_growth AS (
    SELECT *,
        LAG(monthly_revenue) OVER (ORDER BY yr, mo) AS prev_month_revenue,
        ROUND(
            (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY yr, mo))
            / NULLIF(LAG(monthly_revenue) OVER (ORDER BY yr, mo), 0) * 100
        , 2) AS mom_growth_pct,
        RANK() OVER (PARTITION BY yr ORDER BY monthly_revenue DESC) AS rnk
    FROM monthly_sales
)
SELECT yr, month_label, monthly_revenue, orders, mom_growth_pct, rnk
FROM monthly_with_growth
ORDER BY yr, mo;

-- -------------------------------------------------------
-- Q8: Top 5 customers with full loyalty profile
-- -------------------------------------------------------
WITH customer_stats AS (
    SELECT
        customer_id,
        gender,
        COUNT(*)                                        AS total_orders,
        ROUND(SUM(total_sale)::NUMERIC, 2)              AS lifetime_value,
        ROUND(AVG(total_sale)::NUMERIC, 2)              AS avg_order_value,
        MIN(sale_date)                                  AS first_purchase,
        MAX(sale_date)                                  AS last_purchase,
        MAX(sale_date) - MIN(sale_date)                 AS customer_lifespan_days,
        COUNT(DISTINCT category)                        AS categories_bought
    FROM retail_sales
    GROUP BY customer_id, gender
)
SELECT *,
    RANK() OVER (ORDER BY lifetime_value DESC) AS ltv_rank
FROM customer_stats
ORDER BY lifetime_value DESC
LIMIT 5;

-- -------------------------------------------------------
-- Q9: Customer retention + repeat buyer analysis
-- -------------------------------------------------------
WITH purchase_counts AS (
    SELECT
        customer_id,
        COUNT(*)                      AS total_purchases,
        COUNT(DISTINCT category)      AS categories_purchased
    FROM retail_sales
    GROUP BY customer_id
)
SELECT
    CASE
        WHEN total_purchases = 1  THEN '1 - One-time buyer'
        WHEN total_purchases BETWEEN 2 AND 3 THEN '2-3 - Occasional buyer'
        WHEN total_purchases BETWEEN 4 AND 6 THEN '4-6 - Regular buyer'
        ELSE '7+ - Loyal buyer'
    END                                              AS buyer_segment,
    COUNT(*)                                         AS customer_count,
    ROUND(AVG(categories_purchased)::NUMERIC, 2)     AS avg_categories_explored,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER ()
    , 2)                                             AS pct_of_customers
FROM purchase_counts
GROUP BY 1
ORDER BY 1;

-- -------------------------------------------------------
-- Q10: Shift analysis with revenue per order
-- -------------------------------------------------------
WITH shift_data AS (
    SELECT *,
        CASE
            WHEN EXTRACT(HOUR FROM sale_time) < 12 THEN 'Morning'
            WHEN EXTRACT(HOUR FROM sale_time) BETWEEN 12 AND 17 THEN 'Afternoon'
            ELSE 'Evening'
        END AS shift
    FROM retail_sales
)
SELECT
    shift,
    COUNT(*)                                         AS total_orders,
    ROUND(SUM(total_sale)::NUMERIC, 2)               AS total_revenue,
    ROUND(AVG(total_sale)::NUMERIC, 2)               AS avg_order_value,
    ROUND(SUM(profit)::NUMERIC, 2)                   AS total_profit,
    ROUND(AVG(profit_margin)::NUMERIC, 2)            AS avg_profit_margin_pct
FROM shift_data
GROUP BY shift
ORDER BY total_revenue DESC;

-- ============================================================
-- SECTION 6: ADVANCED ANALYTICS
-- ============================================================

-- -------------------------------------------------------
-- A1: RFM (Recency, Frequency, Monetary) Customer Segmentation
-- A classic model used in retail, e-commerce, and CRM
-- -------------------------------------------------------
WITH rfm_base AS (
    SELECT
        customer_id,
        MAX(sale_date)                       AS last_purchase_date,
        (SELECT MAX(sale_date) FROM retail_sales) - MAX(sale_date) AS recency_days,
        COUNT(*)                             AS frequency,
        SUM(total_sale)                      AS monetary
    FROM retail_sales
    GROUP BY customer_id
),
rfm_scores AS (
    SELECT *,
        NTILE(5) OVER (ORDER BY recency_days  ASC)  AS r_score,  -- lower recency = better
        NTILE(5) OVER (ORDER BY frequency     DESC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary      DESC) AS m_score
    FROM rfm_base
),
rfm_segments AS (
    SELECT *,
        (r_score + f_score + m_score)        AS rfm_total,
        CASE
            WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'Champions'
            WHEN r_score >= 3 AND f_score >= 3                  THEN 'Loyal Customers'
            WHEN r_score >= 4 AND f_score <= 2                  THEN 'New Customers'
            WHEN r_score >= 3 AND f_score <= 2                  THEN 'Promising'
            WHEN r_score <= 2 AND f_score >= 3                  THEN 'At Risk'
            WHEN r_score = 1 AND f_score >= 4                   THEN 'Cannot Lose Them'
            ELSE 'Lost Customers'
        END AS customer_segment
    FROM rfm_scores
)
SELECT
    customer_segment,
    COUNT(*)                                        AS customer_count,
    ROUND(AVG(recency_days)::NUMERIC, 1)            AS avg_recency_days,
    ROUND(AVG(frequency)::NUMERIC, 1)               AS avg_frequency,
    ROUND(AVG(monetary)::NUMERIC, 2)                AS avg_monetary,
    ROUND(SUM(monetary)::NUMERIC, 2)                AS total_revenue_contribution
FROM rfm_segments
GROUP BY customer_segment
ORDER BY total_revenue_contribution DESC;

-- -------------------------------------------------------
-- A2: Cohort Analysis — first-purchase month retention
-- -------------------------------------------------------
WITH first_purchase AS (
    SELECT
        customer_id,
        MIN(DATE_TRUNC('month', sale_date)) AS cohort_month
    FROM retail_sales
    GROUP BY customer_id
),
cohort_data AS (
    SELECT
        f.customer_id,
        f.cohort_month,
        DATE_TRUNC('month', r.sale_date)      AS purchase_month,
        EXTRACT(EPOCH FROM (
            DATE_TRUNC('month', r.sale_date) - f.cohort_month
        )) / (30 * 24 * 3600)                 AS month_number
    FROM first_purchase f
    JOIN retail_sales r USING (customer_id)
)
SELECT
    TO_CHAR(cohort_month, 'YYYY-MM')             AS cohort,
    month_number::INT                            AS months_since_first_purchase,
    COUNT(DISTINCT customer_id)                  AS active_customers
FROM cohort_data
GROUP BY 1, 2
ORDER BY 1, 2;

-- -------------------------------------------------------
-- A3: Product affinity / basket analysis
-- Which categories are bought together by the same customer?
-- -------------------------------------------------------
SELECT
    a.category  AS category_a,
    b.category  AS category_b,
    COUNT(DISTINCT a.customer_id) AS customers_bought_both
FROM retail_sales a
JOIN retail_sales b
    ON a.customer_id = b.customer_id
   AND a.category < b.category          -- avoid duplicates and self-joins
GROUP BY 1, 2
HAVING COUNT(DISTINCT a.customer_id) > 5
ORDER BY customers_bought_both DESC;

-- -------------------------------------------------------
-- A4: Day-of-week revenue heatmap
-- -------------------------------------------------------
SELECT
    TRIM(day_of_week)                            AS day_of_week,
    TO_CHAR(EXTRACT(DOW FROM sale_date),'9')     AS day_num,
    COUNT(*)                                     AS total_orders,
    ROUND(SUM(total_sale)::NUMERIC, 2)           AS total_revenue,
    ROUND(AVG(total_sale)::NUMERIC, 2)           AS avg_order_value
FROM retail_sales
GROUP BY 1, 2
ORDER BY day_num;

-- -------------------------------------------------------
-- A5: Running total revenue (cumulative) by month
-- -------------------------------------------------------
WITH monthly AS (
    SELECT
        DATE_TRUNC('month', sale_date)       AS month,
        SUM(total_sale)                      AS monthly_revenue
    FROM retail_sales
    GROUP BY 1
)
SELECT
    TO_CHAR(month, 'YYYY-MM')               AS month,
    ROUND(monthly_revenue::NUMERIC, 2)      AS monthly_revenue,
    ROUND(SUM(monthly_revenue) OVER (
        ORDER BY month ROWS UNBOUNDED PRECEDING
    )::NUMERIC, 2)                          AS cumulative_revenue
FROM monthly
ORDER BY month;

-- -------------------------------------------------------
-- A6: Z-score anomaly detection on daily revenue
-- Flags days where revenue is unusually high or low
-- -------------------------------------------------------
WITH daily_sales AS (
    SELECT
        sale_date,
        SUM(total_sale) AS daily_revenue
    FROM retail_sales
    GROUP BY sale_date
),
stats AS (
    SELECT
        AVG(daily_revenue)    AS mean_rev,
        STDDEV(daily_revenue) AS stddev_rev
    FROM daily_sales
)
SELECT
    d.sale_date,
    ROUND(d.daily_revenue::NUMERIC, 2) AS daily_revenue,
    ROUND(((d.daily_revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0))::NUMERIC, 2) AS z_score,
    CASE
        WHEN ABS((d.daily_revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0)) > 2 THEN 'ANOMALY'
        ELSE 'Normal'
    END AS flag
FROM daily_sales d, stats s
ORDER BY ABS((d.daily_revenue - s.mean_rev) / NULLIF(s.stddev_rev, 0)) DESC;

-- -------------------------------------------------------
-- A7: Price sensitivity analysis
-- Revenue vs. quantity by price tier
-- -------------------------------------------------------
SELECT
    CASE
        WHEN price_per_unit < 50  THEN 'Budget (< £50)'
        WHEN price_per_unit < 150 THEN 'Mid-range (£50-£150)'
        WHEN price_per_unit < 300 THEN 'Premium (£150-£300)'
        ELSE 'Luxury (£300+)'
    END                                     AS price_tier,
    category,
    COUNT(*)                                AS transactions,
    SUM(quantity)                           AS units_sold,
    ROUND(AVG(quantity)::NUMERIC, 2)        AS avg_qty_per_order,
    ROUND(SUM(total_sale)::NUMERIC, 2)      AS total_revenue,
    ROUND(AVG(profit_margin)::NUMERIC, 2)   AS avg_margin_pct
FROM retail_sales
GROUP BY 1, 2
ORDER BY 1, total_revenue DESC;

-- ============================================================
-- SECTION 7: VIEWS & REPORTING LAYER (NEW)
-- Production-ready views for dashboards (e.g., Power BI)
-- ============================================================

-- 7a. Executive summary view
CREATE OR REPLACE VIEW vw_executive_summary AS
SELECT
    TO_CHAR(sale_date, 'YYYY-MM')              AS month,
    category,
    COUNT(*)                                   AS orders,
    SUM(quantity)                              AS units_sold,
    ROUND(SUM(total_sale)::NUMERIC, 2)         AS revenue,
    ROUND(SUM(profit)::NUMERIC, 2)             AS profit,
    ROUND(AVG(profit_margin)::NUMERIC, 2)      AS avg_margin_pct,
    COUNT(DISTINCT customer_id)                AS unique_customers
FROM retail_sales
GROUP BY 1, 2;

-- 7b. Customer 360 view
CREATE OR REPLACE VIEW vw_customer_360 AS
SELECT
    customer_id,
    gender,
    age_group,
    COUNT(*)                                   AS total_orders,
    ROUND(SUM(total_sale)::NUMERIC, 2)         AS lifetime_value,
    ROUND(AVG(total_sale)::NUMERIC, 2)         AS avg_order_value,
    MAX(sale_date)                             AS last_purchase_date,
    MIN(sale_date)                             AS first_purchase_date,
    COUNT(DISTINCT category)                   AS categories_purchased,
    (SELECT MAX(sale_date) FROM retail_sales) - MAX(sale_date) AS days_since_last_purchase
FROM retail_sales
GROUP BY customer_id, gender, age_group;

-- ============================================================
-- END OF PROJECT
-- ============================================================