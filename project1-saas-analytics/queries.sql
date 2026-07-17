-- ============================================================================
-- SaaS COHORT ANALYTICS & UNIT ECONOMICS
-- Intermediate SQL + Python Project
-- ============================================================================

-- ============================================================================
-- QUERY 1: Cohort Retention Analysis
-- ============================================================================
-- Shows month-over-month retention for each signup cohort
-- Real SaaS companies use this to measure product stickiness

WITH monthly_cohorts AS (
    SELECT 
        DATE_TRUNC('month', signup_date) as cohort_month,
        user_id,
        signup_date,
        plan_type,
        mrr,
        is_churned,
        churn_date
    FROM subscriptions
),
cohort_months AS (
    SELECT 
        mc.cohort_month,
        mc.user_id,
        mc.plan_type,
        mc.mrr,
        DATEDIFF(MONTH, mc.cohort_month, CAST(GETDATE() AS DATE)) as months_since_signup,
        CASE WHEN mc.is_churned = 0 THEN 1
             WHEN DATEDIFF(MONTH, mc.cohort_month, mc.churn_date) >= 1 THEN 1
             ELSE 0 END as retained_m1,
        CASE WHEN mc.is_churned = 0 THEN 1
             WHEN DATEDIFF(MONTH, mc.cohort_month, mc.churn_date) >= 3 THEN 1
             ELSE 0 END as retained_m3,
        CASE WHEN mc.is_churned = 0 THEN 1
             WHEN DATEDIFF(MONTH, mc.cohort_month, mc.churn_date) >= 6 THEN 1
             ELSE 0 END as retained_m6
    FROM monthly_cohorts mc
)
SELECT 
    cohort_month,
    COUNT(DISTINCT user_id) as cohort_size,
    SUM(retained_m1) as m1_retained,
    ROUND(SUM(retained_m1) * 100.0 / COUNT(DISTINCT user_id), 1) as m1_retention_pct,
    SUM(retained_m3) as m3_retained,
    ROUND(SUM(retained_m3) * 100.0 / COUNT(DISTINCT user_id), 1) as m3_retention_pct,
    SUM(retained_m6) as m6_retained,
    ROUND(SUM(retained_m6) * 100.0 / COUNT(DISTINCT user_id), 1) as m6_retention_pct,
    SUM(mrr) as cohort_mrr
FROM cohort_months
GROUP BY cohort_month
ORDER BY cohort_month DESC;


-- ============================================================================
-- QUERY 2: Net Revenue Retention (NRR) - Most Important SaaS Metric
-- ============================================================================
-- NRR > 100% means expansion (upsells/expansion revenue outpaces churn)
-- This is what VCs care about most

WITH current_state AS (
    SELECT 
        'Current' as period,
        SUM(CASE WHEN is_churned = 0 THEN mrr ELSE 0 END) as active_mrr,
        SUM(CASE WHEN is_churned = 1 THEN mrr ELSE 0 END) as churned_mrr,
        COUNT(DISTINCT user_id) as active_users,
        COUNT(DISTINCT CASE WHEN is_churned = 1 THEN user_id END) as churned_users
    FROM subscriptions
)
SELECT 
    period,
    active_mrr,
    churned_mrr,
    active_users,
    churned_users,
    ROUND((active_mrr - churned_mrr) / active_mrr * 100, 1) as nrr_percentage,
    CASE 
        WHEN (active_mrr - churned_mrr) / active_mrr * 100 >= 100 THEN 'Expansion'
        WHEN (active_mrr - churned_mrr) / active_mrr * 100 >= 90 THEN 'Stable'
        ELSE 'Declining'
    END as health_status
FROM current_state;


-- ============================================================================
-- QUERY 3: Customer Lifetime Value (LTV) by Segment
-- ============================================================================
-- Calculate LTV for different segments to identify most valuable cohorts

WITH customer_ltv AS (
    SELECT 
        plan_type,
        country,
        industry,
        user_id,
        mrr,
        is_churned,
        DATEDIFF(DAY, signup_date, COALESCE(churn_date, CAST(GETDATE() AS DATE))) as customer_lifetime_days,
        SUM(mrr) OVER (PARTITION BY user_id) as total_revenue,
        AVG(mrr) OVER (PARTITION BY plan_type) as avg_mrr_by_plan,
        COUNT(DISTINCT user_id) OVER (PARTITION BY plan_type) as plan_user_count
    FROM subscriptions
)
SELECT 
    plan_type,
    country,
    industry,
    COUNT(DISTINCT user_id) as customer_count,
    ROUND(AVG(customer_lifetime_days), 0) as avg_lifetime_days,
    ROUND(AVG(mrr), 2) as avg_mrr,
    ROUND(AVG(mrr) * (AVG(customer_lifetime_days) / 30), 2) as estimated_ltv,
    ROUND(SUM(total_revenue), 2) as total_revenue_generated,
    ROUND(SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END) * 100.0 / COUNT(DISTINCT user_id), 1) as churn_rate_pct
FROM customer_ltv
GROUP BY plan_type, country, industry
ORDER BY estimated_ltv DESC;


-- ============================================================================
-- QUERY 4: Churn Cohort Analysis (Early vs Late Churn)
-- ============================================================================
-- Identify if churn happens early (bad onboarding) or late (product issue)

WITH churn_timing AS (
    SELECT 
        user_id,
        signup_date,
        churn_date,
        DATEDIFF(DAY, signup_date, churn_date) as days_to_churn,
        CASE 
            WHEN DATEDIFF(DAY, signup_date, churn_date) <= 30 THEN 'Week 1-4'
            WHEN DATEDIFF(DAY, signup_date, churn_date) <= 90 THEN 'Month 2-3'
            WHEN DATEDIFF(DAY, signup_date, churn_date) <= 180 THEN 'Month 4-6'
            ELSE 'Month 7+'
        END as churn_timeframe,
        plan_type,
        mrr,
        DATE_TRUNC('month', signup_date) as signup_cohort
    FROM subscriptions
    WHERE is_churned = 1
)
SELECT 
    churn_timeframe,
    signup_cohort,
    COUNT(DISTINCT user_id) as churned_customers,
    ROUND(AVG(days_to_churn), 0) as avg_days_to_churn,
    ROUND(AVG(mrr), 2) as avg_mrr_lost,
    SUM(mrr) as total_mrr_lost,
    COUNT(CASE WHEN plan_type = 'starter' THEN user_id END) as starter_churn_count,
    COUNT(CASE WHEN plan_type = 'professional' THEN user_id END) as pro_churn_count,
    COUNT(CASE WHEN plan_type = 'enterprise' THEN user_id END) as enterprise_churn_count
FROM churn_timing
GROUP BY churn_timeframe, signup_cohort
ORDER BY signup_cohort DESC, 
         CASE WHEN churn_timeframe = 'Week 1-4' THEN 1
              WHEN churn_timeframe = 'Month 2-3' THEN 2
              WHEN churn_timeframe = 'Month 4-6' THEN 3
              ELSE 4 END;


-- ============================================================================
-- QUERY 5: Geographic Expansion Analysis
-- ============================================================================
-- Analyze which geographic markets are growing/shrinking

WITH geographic_trends AS (
    SELECT 
        country,
        DATE_TRUNC('month', signup_date) as month,
        COUNT(DISTINCT user_id) as new_users,
        SUM(mrr) as new_mrr,
        SUM(CASE WHEN is_churned = 1 THEN 1 ELSE 0 END) as churned_this_month,
        LAG(SUM(mrr)) OVER (PARTITION BY country ORDER BY DATE_TRUNC('month', signup_date)) as prev_month_mrr
    FROM subscriptions
    GROUP BY country, DATE_TRUNC('month', signup_date)
)
SELECT 
    country,
    month,
    new_users,
    new_mrr,
    churned_this_month,
    prev_month_mrr,
    ROUND((new_mrr - COALESCE(prev_month_mrr, 0)) / COALESCE(prev_month_mrr, new_mrr) * 100, 1) as mom_growth_pct,
    ROW_NUMBER() OVER (PARTITION BY country ORDER BY month DESC) as recency_rank
FROM geographic_trends
WHERE prev_month_mrr IS NOT NULL
ORDER BY month DESC, country;


-- ============================================================================
-- QUERY 6: Expansion Revenue Opportunities
-- ============================================================================
-- Identify customers who might be upsell/expansion candidates

WITH customer_usage AS (
    SELECT 
        user_id,
        plan_type,
        mrr,
        is_churned,
        country,
        industry,
        ROW_NUMBER() OVER (PARTITION BY plan_type ORDER BY mrr DESC) as plan_rank,
        COUNT(DISTINCT user_id) OVER (PARTITION BY plan_type) as users_in_plan,
        AVG(mrr) OVER (PARTITION BY plan_type) as avg_mrr_in_plan,
        MAX(mrr) OVER (PARTITION BY plan_type) as max_mrr_in_plan,
        PERCENTILE_CONT(0.75) OVER (PARTITION BY plan_type ORDER BY mrr) as p75_mrr_in_plan
    FROM subscriptions
)
SELECT 
    plan_type,
    industry,
    COUNT(DISTINCT user_id) as customer_count,
    ROUND(AVG(mrr), 2) as current_mrr,
    ROUND(AVG(CASE WHEN plan_type = 'starter' THEN 99 - mrr
                   WHEN plan_type = 'professional' THEN 499 - mrr
                   ELSE 0 END), 2) as potential_expansion_per_customer,
    SUM(CASE WHEN mrr >= p75_mrr_in_plan THEN mrr ELSE 0 END) as top_25_pct_revenue,
    SUM(CASE WHEN is_churned = 0 AND mrr >= p75_mrr_in_plan THEN 1 ELSE 0 END) as top_customers_at_risk
FROM customer_usage
WHERE is_churned = 0
GROUP BY plan_type, industry
ORDER BY potential_expansion_per_customer DESC;


-- ============================================================================
-- QUERY 7: Quick Health Check Dashboard
-- ============================================================================
-- KPIs every SaaS CEO checks daily

SELECT 
    -- Growth Metrics
    (SELECT COUNT(DISTINCT user_id) FROM subscriptions WHERE is_churned = 0) as total_active_customers,
    (SELECT SUM(mrr) FROM subscriptions WHERE is_churned = 0) as current_mrr,
    (SELECT COUNT(DISTINCT user_id) FROM subscriptions 
     WHERE DATE_TRUNC('month', signup_date) = DATE_TRUNC('month', CAST(GETDATE() AS DATE))) as new_customers_this_month,
    
    -- Churn Metrics
    (SELECT ROUND(COUNT(CASE WHEN is_churned = 1 THEN 1 END) * 100.0 / COUNT(*), 1)
     FROM subscriptions) as total_churn_rate_pct,
    
    -- Revenue Metrics
    (SELECT ROUND(AVG(mrr), 2) FROM subscriptions WHERE is_churned = 0) as avg_mrr_per_active_customer,
    (SELECT ROUND(SUM(mrr), 0) FROM subscriptions) as total_historical_mrr,
    
    -- Efficiency Metrics
    (SELECT COUNT(DISTINCT CASE WHEN is_churned = 1 AND 
                   DATEDIFF(DAY, signup_date, churn_date) <= 30 THEN user_id END)
     FROM subscriptions) as early_churn_count,
    
    -- Segment Health
    (SELECT ROUND(COUNT(CASE WHEN is_churned = 1 THEN 1 END) * 100.0 / COUNT(*), 1)
     FROM subscriptions WHERE plan_type = 'starter') as starter_churn_pct
