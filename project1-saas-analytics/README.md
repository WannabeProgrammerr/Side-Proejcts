# Project 1: SaaS Cohort Analytics & Unit Economics

## Why This Project Stands Out

This is **real SaaS company analysis**. If you get hired at a startup, this is what they'll ask you to do on day 1. It's NOT generic—it's what actually matters for business.

## What You're Analyzing

A subscription SaaS product with:
- 40 customers across different plans (Starter, Professional, Enterprise)
- Monthly Recurring Revenue (MRR) tracking
- Churn analysis across geographies and industries
- Real business metrics that CEOs care about

## Key Metrics You're Calculating

### 1. **Cohort Retention** (The Most Important Metric)
Shows what percentage of customers from each signup month stay active.

**Why it matters**: 
- Proves product-market fit
- Shows if onboarding works
- Investors obsess over this

**Example insight**: "Jan 2023 cohort has 75% retention at 3 months"

### 2. **Net Revenue Retention (NRR)**
The holy grail of SaaS metrics. >100% means customers are spending more over time.

**Formula**: (Active MRR - Churned MRR) / Active MRR × 100

**Why it matters**:
- Shows if product gets stickier
- VCs value this more than revenue growth
- Indicates expansion revenue

### 3. **Unit Economics**
- **CAC**: Customer Acquisition Cost (how much to get one customer)
- **LTV**: Lifetime Value (total revenue from one customer)
- **LTV:CAC Ratio**: Should be >3x
- **Payback Period**: How long to recover acquisition cost

**Example**: "LTV of $2,376 vs CAC of $500 = 4.75x ratio ✅ Healthy"

### 4. **Churn Cohort Analysis**
Identifies WHEN customers churn:
- Early churn (Week 1-4) = Onboarding problem
- Late churn (Month 4+) = Product issue or market saturation

**Why it matters**: Tells you WHERE to fix the product

### 5. **Geographic Expansion**
Which countries are growing? Which are declining?

### 6. **Industry Segmentation**
Which industry verticals are most profitable?

## Files in This Project

### `saas_cohort_analysis.py`
Main analysis script that calculates:
- Cohort retention table (Month 0, 1, 3, 6)
- Churn rates by plan type
- Unit economics (CAC, LTV, payback)
- Geographic analysis
- Industry segmentation
- Professional 4-panel visualization dashboard

**Output**: `results/saas_analytics.png` - Dashboard showing all metrics

### `queries.sql`
7 advanced SQL queries demonstrating:

1. **Cohort Retention** - Shows retention table using window functions
2. **NRR Calculation** - Advanced aggregation showing revenue health
3. **LTV by Segment** - Multi-dimensional analysis
4. **Churn Timing** - Case statements + window functions
5. **Geographic Trends** - LAG function for MoM growth
6. **Expansion Opportunities** - Identifies upsell candidates
7. **Health Dashboard** - Quick KPI snapshot

**Difficulty**: Intermediate-Advanced SQL (CTEs, window functions, LAG)

### `data/subscriptions.csv`
40 customer records with:
- Signup dates and cohort assignment
- Plan types (Starter/Professional/Enterprise)
- Monthly Recurring Revenue (MRR)
- Churn status and churn dates
- Geographic and industry data

## How to Run

```bash
# Install dependencies
pip install pandas numpy matplotlib seaborn

# Run analysis
python saas_cohort_analysis.py

# Output: Dashboard in results/saas_analytics.png
```

## What Your Dashboard Shows

### Panel 1: Churn Rate by Plan
Shows that Starter plan has higher churn than Enterprise (expected). Identifies opportunity.

### Panel 2: MRR by Signup Cohort
Shows if later cohorts are bigger/smaller. Indicates if product is getting better or worse.

### Panel 3: CAC vs LTV
Visual comparison of acquisition cost vs lifetime value. Target line shows 3x healthy ratio.

### Panel 4: Churn Rate by Country
Identifies geographic weaknesses. Maybe US customers stick around longer?

## Interview Talking Points

**"I analyzed SaaS subscription data using cohort analysis—a technique every startup uses to measure product-market fit."**

**"I calculated key metrics: cohort retention shows 75% of our Jan users stayed 3 months. Our LTV:CAC ratio is 4.75x, well above the 3x minimum for healthy growth."**

**"The data revealed early churn patterns—40% of Starter plan customers churn within 30 days. This suggests an onboarding problem worth fixing."**

**"Geographic analysis showed the US has 60% churn vs UK with 30%. This indicates either better product-market fit in UK or localization issues in US."**

## Why This Project Is Powerful

1. **Real Business Problem**: Actual SaaS companies do this analysis
2. **Advanced Metrics**: Cohort analysis, NRR, CAC/LTV—not basic stuff
3. **Actionable Insights**: You're not just analyzing, you're recommending fixes
4. **Technical Skills**: SQL window functions, Python cohort analysis
5. **Business Acumen**: Shows you understand SaaS fundamentals

## Expected Skills Demonstrated

- ✅ Cohort analysis (intermediate)
- ✅ Window functions in SQL (LAG, ROW_NUMBER)
- ✅ Python data manipulation (groupby, apply)
- ✅ Financial metrics calculation
- ✅ Business metrics understanding (CAC, LTV, NRR)
- ✅ Professional visualization
- ✅ Data-driven recommendations

## Key Insights From This Dataset

1. **Churn patterns**: Starter plan churns at 50%, Professional at 40%, Enterprise at 20%
   - **Insight**: Enterprise customers are stickier (expected)
   - **Opportunity**: Improve Starter experience to reduce churn

2. **Early vs late churn**: 40% of churned customers leave within 30 days
   - **Insight**: Onboarding is a critical problem
   - **Opportunity**: Improve first-run experience

3. **Geographic differences**: US has higher churn than UK/Canada
   - **Insight**: Possible product-market fit issues in US
   - **Opportunity**: Investigate market differences

4. **Unit economics**: LTV:CAC ratio is 4.75x
   - **Insight**: Business model is healthy
   - **Benchmark**: Healthy SaaS is >3x

## Follow-Up Questions (Prepare for Interview)

1. "If churn is highest in the first 30 days, what would you prioritize?"
   → Answer: "Improve onboarding—better tutorial, faster time-to-value"

2. "What does NRR >100% mean?"
   → Answer: "Customers spending more over time—either expansion revenue or price increases outpacing churn"

3. "How would you reduce CAC?"
   → Answer: "Improve conversion rate, reduce marketing spend per customer, or focus on retention (cheaper than acquisition)"

4. "Why is Enterprise plan retention better?"
   → Answer: "Larger customers invest more time, need better support, switching costs are higher"

## Real-World Application

This exact analysis is run daily by:
- **Slack** (tracking user adoption cohorts)
- **Salesforce** (monitoring customer expansion)
- **Intercom** (analyzing churn by feature usage)
- **Stripe** (understanding payment processor customers)

When you do this project, you're using the exact same framework as billion-dollar companies.

## Skills This Demonstrates

**To Hiring Manager**: 
"This candidate understands SaaS metrics, knows how to analyze cohort behavior, can calculate unit economics, and can turn data into business recommendations. They could start work on day 1."

---

**Difficulty Level**: ⭐⭐⭐ Intermediate (SQL + Python)  
**Time to Complete**: 30-45 minutes  
**Wow Factor**: ⭐⭐⭐⭐⭐ (This impresses!)
