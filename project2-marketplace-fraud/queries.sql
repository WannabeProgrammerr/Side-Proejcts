-- ============================================================================
-- MARKETPLACE FRAUD DETECTION SYSTEM
-- Advanced SQL Queries for Risk Scoring & Pattern Detection
-- ============================================================================

-- ============================================================================
-- QUERY 1: Real-Time Fraud Risk Scoring
-- ============================================================================
-- Calculate dynamic fraud risk based on transaction patterns
-- Used to flag transactions before settling

WITH seller_metrics AS (
    SELECT 
        seller_id,
        COUNT(DISTINCT transaction_id) as total_transactions,
        COUNT(DISTINCT CASE WHEN is_fraud = 1 THEN transaction_id END) as fraud_count,
        AVG(seller_rating) as avg_rating,
        AVG(amount) as avg_transaction_value,
        DATEDIFF(DAY, MAX(account_created_date), CAST(GETDATE() AS DATE)) as account_age_days,
        PERCENTILE_CONT(0.95) OVER (PARTITION BY seller_id ORDER BY amount) as p95_amount
    FROM marketplace_transactions
    GROUP BY seller_id, account_created_date
),
buyer_metrics AS (
    SELECT 
        buyer_id,
        COUNT(DISTINCT transaction_id) as total_transactions,
        AVG(buyer_rating) as avg_rating,
        DATEDIFF(DAY, MAX(account_created_date), CAST(GETDATE() AS DATE)) as account_age_days
    FROM marketplace_transactions
    GROUP BY buyer_id, account_created_date
),
transaction_risk AS (
    SELECT 
        t.transaction_id,
        t.seller_id,
        t.buyer_id,
        t.amount,
        t.payment_method,
        t.ip_country,
        s.total_transactions,
        s.fraud_count,
        s.avg_rating as seller_rating,
        s.account_age_days as seller_age_days,
        b.total_transactions as buyer_transactions,
        b.avg_rating as buyer_rating,
        b.account_age_days as buyer_age_days,
        
        -- Risk Score Components
        CASE 
            WHEN s.account_age_days < 30 THEN 0.25
            WHEN s.account_age_days < 90 THEN 0.15
            WHEN s.account_age_days < 180 THEN 0.10
            ELSE 0.05
        END as seller_age_risk,
        
        CASE 
            WHEN payment_method = 'wire_transfer' THEN 0.20
            WHEN payment_method = 'paypal' THEN 0.10
            ELSE 0.05
        END as payment_method_risk,
        
        CASE 
            WHEN t.amount > s.p95_amount THEN 0.15
            WHEN t.amount > PERCENTILE_CONT(0.75) OVER (PARTITION BY seller_id) THEN 0.08
            ELSE 0.02
        END as amount_anomaly_risk,
        
        CASE 
            WHEN s.avg_rating < 2.0 THEN 0.15
            WHEN s.avg_rating < 3.0 THEN 0.08
            ELSE 0.03
        END as seller_rating_risk,
        
        CASE 
            WHEN ip_country IN ('NG', 'CN', 'RU', 'IN') THEN 0.10
            ELSE 0.02
        END as geographic_risk,
        
        CASE 
            WHEN b.account_age_days < 30 THEN 0.10
            WHEN b.account_age_days < 90 THEN 0.05
            ELSE 0.02
        END as buyer_age_risk
        
    FROM marketplace_transactions t
    LEFT JOIN seller_metrics s ON t.seller_id = s.seller_id
    LEFT JOIN buyer_metrics b ON t.buyer_id = b.buyer_id
)
SELECT 
    transaction_id,
    seller_id,
    buyer_id,
    amount,
    payment_method,
    ip_country,
    seller_rating,
    seller_age_days,
    buyer_rating,
    
    -- Final Risk Score (0-1.0)
    (seller_age_risk + payment_method_risk + amount_anomaly_risk + 
     seller_rating_risk + geographic_risk + buyer_age_risk) as overall_fraud_risk_score,
    
    -- Risk Level Classification
    CASE 
        WHEN (seller_age_risk + payment_method_risk + amount_anomaly_risk + 
              seller_rating_risk + geographic_risk + buyer_age_risk) > 0.70 THEN 'HIGH'
        WHEN (seller_age_risk + payment_method_risk + amount_anomaly_risk + 
              seller_rating_risk + geographic_risk + buyer_age_risk) > 0.40 THEN 'MEDIUM'
        ELSE 'LOW'
    END as risk_level,
    
    -- Recommendations
    CASE 
        WHEN seller_age_days < 30 THEN 'FLAG: New seller'
        WHEN payment_method = 'wire_transfer' THEN 'FLAG: Wire transfer'
        WHEN amount_anomaly_risk > 0.10 THEN 'FLAG: Unusual amount'
        WHEN seller_rating < 2.0 THEN 'FLAG: Poor seller rating'
        ELSE 'OK'
    END as recommendation
    
FROM transaction_risk
ORDER BY overall_fraud_risk_score DESC;


-- ============================================================================
-- QUERY 2: Seller Fraud Pattern Detection
-- ============================================================================
-- Identify suspicious seller behavior patterns

WITH seller_behavior AS (
    SELECT 
        seller_id,
        COUNT(DISTINCT transaction_id) as total_transactions,
        SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraudulent_transactions,
        SUM(amount) as total_volume,
        AVG(amount) as avg_amount,
        STDEV(amount) as stddev_amount,
        AVG(seller_rating) as avg_rating,
        MIN(seller_rating) as min_rating,
        MAX(amount) as max_amount,
        AVG(shipping_days) as avg_shipping_days,
        DATEDIFF(DAY, MAX(account_created_date), CAST(GETDATE() AS DATE)) as account_age_days,
        COUNT(DISTINCT ip_country) as unique_countries,
        COUNT(DISTINCT payment_method) as payment_methods_used,
        DATE_TRUNC('month', MAX(transaction_date)) as last_transaction_month
    FROM marketplace_transactions
    GROUP BY seller_id, account_created_date
)
SELECT 
    seller_id,
    total_transactions,
    fraudulent_transactions,
    ROUND(fraudulent_transactions * 100.0 / total_transactions, 2) as fraud_rate_pct,
    total_volume,
    ROUND(avg_amount, 2) as avg_amount,
    ROUND(avg_rating, 2) as avg_rating,
    account_age_days,
    unique_countries,
    payment_methods_used,
    
    -- Red Flags
    CASE 
        WHEN fraudulent_transactions > 0 THEN 'HAS FRAUD HISTORY'
        ELSE 'CLEAN'
    END as fraud_history,
    
    CASE 
        WHEN avg_rating < 2.0 AND total_transactions >= 10 THEN 'LOW RATING + ACTIVITY'
        WHEN avg_rating < 2.0 THEN 'LOW RATING'
        ELSE 'OK'
    END as rating_flag,
    
    CASE 
        WHEN unique_countries > 3 THEN 'MULTI-COUNTRY'
        ELSE 'NORMAL'
    END as geographic_flag,
    
    -- Velocity Anomalies
    CASE 
        WHEN total_transactions > 100 AND account_age_days < 180 THEN 'HIGH VELOCITY'
        ELSE 'NORMAL'
    END as velocity_flag

FROM seller_behavior
WHERE total_transactions >= 2
ORDER BY fraud_rate_pct DESC, total_volume DESC;


-- ============================================================================
-- QUERY 3: Geographic Fraud Hotspots
-- ============================================================================
-- Identify countries with higher fraud rates

SELECT 
    ip_country,
    COUNT(DISTINCT transaction_id) as total_transactions,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraud_count,
    ROUND(SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) * 100.0 / 
           COUNT(DISTINCT transaction_id), 2) as fraud_rate_pct,
    SUM(amount) as total_volume,
    ROUND(AVG(amount), 2) as avg_transaction_value,
    ROUND(AVG(CASE WHEN is_fraud = 1 THEN amount END), 2) as avg_fraud_amount,
    COUNT(DISTINCT seller_id) as unique_sellers,
    COUNT(DISTINCT buyer_id) as unique_buyers,
    COUNT(DISTINCT payment_method) as payment_methods,
    ROUND(AVG(seller_rating), 2) as avg_seller_rating
FROM marketplace_transactions
GROUP BY ip_country
ORDER BY fraud_rate_pct DESC;


-- ============================================================================
-- QUERY 4: High-Value Transaction Risk Analysis
-- ============================================================================
-- Focus on transactions above 75th percentile (where money is)

WITH amount_quantiles AS (
    SELECT 
        PERCENTILE_CONT(0.75) OVER () as p75_amount,
        PERCENTILE_CONT(0.90) OVER () as p90_amount,
        PERCENTILE_CONT(0.95) OVER () as p95_amount
    FROM marketplace_transactions
)
SELECT 
    t.transaction_id,
    t.seller_id,
    t.amount,
    CASE 
        WHEN t.amount > aq.p95_amount THEN '🔴 Top 5%'
        WHEN t.amount > aq.p90_amount THEN '🟠 Top 10%'
        WHEN t.amount > aq.p75_amount THEN '🟡 Top 25%'
    END as transaction_tier,
    t.payment_method,
    t.ip_country,
    t.is_fraud,
    DATEDIFF(DAY, t.account_created_date, t.transaction_date) as seller_age_at_transaction,
    t.seller_rating,
    t.buyer_rating,
    t.shipping_days,
    CASE 
        WHEN t.is_fraud = 1 THEN 'FRAUD'
        WHEN t.payment_method = 'wire_transfer' AND DATEDIFF(DAY, t.account_created_date, t.transaction_date) < 30 THEN 'HIGH RISK'
        WHEN t.amount > aq.p95_amount AND t.seller_rating < 3.0 THEN 'HIGH RISK'
        ELSE 'MONITOR'
    END as action
FROM marketplace_transactions t
CROSS JOIN amount_quantiles aq
WHERE t.amount >= aq.p75_amount
ORDER BY t.amount DESC;


-- ============================================================================
-- QUERY 5: New Seller Fraud Prediction
-- ============================================================================
-- Target high-risk new sellers (< 90 days old)

SELECT 
    seller_id,
    MIN(account_created_date) as account_creation_date,
    DATEDIFF(DAY, MIN(account_created_date), CAST(GETDATE() AS DATE)) as days_active,
    COUNT(DISTINCT transaction_id) as transactions_to_date,
    SUM(amount) as total_volume,
    SUM(CASE WHEN is_fraud = 1 THEN amount ELSE 0 END) as fraudulent_volume,
    SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) as fraud_count,
    ROUND(AVG(seller_rating), 2) as seller_rating,
    ROUND(AVG(CASE WHEN is_fraud = 1 THEN 1.0 WHEN is_fraud = 0 THEN 0.0 END) * 100, 1) as fraud_rate_pct,
    
    -- Early Warning Signs
    CASE 
        WHEN DATEDIFF(DAY, MIN(account_created_date), CAST(GETDATE() AS DATE)) < 14 THEN 'WATCH CLOSELY'
        WHEN SUM(CASE WHEN is_fraud = 1 THEN 1 ELSE 0 END) > 0 THEN 'SUSPEND'
        WHEN COUNT(DISTINCT transaction_id) > 20 AND DATEDIFF(DAY, MIN(account_created_date), CAST(GETDATE() AS DATE)) < 30 THEN 'VERIFY'
        WHEN ROUND(AVG(seller_rating), 2) < 2.5 THEN 'REVIEW'
        ELSE 'STANDARD'
    END as risk_level
FROM marketplace_transactions
WHERE DATEDIFF(DAY, account_created_date, CAST(GETDATE() AS DATE)) < 90
GROUP BY seller_id
HAVING COUNT(DISTINCT transaction_id) >= 1
ORDER BY fraud_count DESC, days_active ASC;


-- ============================================================================
-- QUERY 6: Exploit Pattern Detection
-- ============================================================================
-- Detect possible exploit chains (same buyer, multiple sellers, quick succession)

WITH buyer_transactions AS (
    SELECT 
        buyer_id,
        COUNT(DISTINCT seller_id) as unique_sellers,
        COUNT(DISTINCT transaction_id) as transaction_count,
        SUM(amount) as total_spent,
        MAX(amount) as max_single_transaction,
        DATEDIFF(DAY, MIN(transaction_date), MAX(transaction_date)) as transaction_span_days,
        COUNT(DISTINCT is_fraud) FILTER (WHERE is_fraud = 1) as fraud_count,
        DATEDIFF(DAY, MIN(account_created_date), MAX(transaction_date)) as buyer_age_at_last_txn
    FROM marketplace_transactions
    GROUP BY buyer_id
    HAVING COUNT(DISTINCT transaction_id) >= 3
)
SELECT 
    buyer_id,
    unique_sellers,
    transaction_count,
    total_spent,
    max_single_transaction,
    transaction_span_days,
    fraud_count,
    
    CASE 
        WHEN fraud_count > 0 THEN 'FRAUD DETECTED'
        WHEN unique_sellers >= 10 AND transaction_span_days < 30 THEN 'EXPLOIT PATTERN'
        WHEN transaction_count >= 15 AND unique_sellers >= 8 THEN 'RAPID MULTI-SELLER'
        ELSE 'NORMAL'
    END as pattern_type,
    
    ROUND(fraud_count * 100.0 / transaction_count, 1) as fraud_rate_pct
FROM buyer_transactions
WHERE fraud_count > 0 OR (unique_sellers >= 8 AND transaction_span_days < 30)
ORDER BY fraud_count DESC, transaction_count DESC;


-- ============================================================================
-- QUERY 7: Daily Fraud Monitoring Dashboard
-- ============================================================================
-- Real-time KPIs for fraud team

SELECT 
    CAST(GETDATE() AS DATE) as report_date,
    
    -- Volume Metrics
    (SELECT COUNT(*) FROM marketplace_transactions WHERE CAST(transaction_date AS DATE) = CAST(GETDATE() AS DATE)) as transactions_today,
    (SELECT COUNT(*) FROM marketplace_transactions WHERE CAST(transaction_date AS DATE) = CAST(GETDATE() AS DATE) AND is_fraud = 1) as fraud_today,
    
    -- Rate Metrics
    ROUND((SELECT COUNT(*) FROM marketplace_transactions WHERE CAST(transaction_date AS DATE) = CAST(GETDATE() AS DATE) AND is_fraud = 1) * 100.0 / 
          (SELECT COUNT(*) FROM marketplace_transactions WHERE CAST(transaction_date AS DATE) = CAST(GETDATE() AS DATE)), 2) as fraud_rate_pct_today,
    
    -- Value at Risk
    (SELECT SUM(amount) FROM marketplace_transactions WHERE CAST(transaction_date AS DATE) = CAST(GETDATE() AS DATE) AND is_fraud = 1) as fraud_value_today,
    
    -- Trend
    ROUND((SELECT COUNT(*) FROM marketplace_transactions WHERE is_fraud = 1) * 100.0 / 
          (SELECT COUNT(*) FROM marketplace_transactions), 2) as overall_fraud_rate_pct,
    
    -- Risk Count
    (SELECT COUNT(*) FROM marketplace_transactions WHERE fraud_risk_score > 0.7) as high_risk_transactions,
    (SELECT COUNT(*) FROM marketplace_transactions WHERE fraud_risk_score > 0.4 AND fraud_risk_score <= 0.7) as medium_risk_transactions
