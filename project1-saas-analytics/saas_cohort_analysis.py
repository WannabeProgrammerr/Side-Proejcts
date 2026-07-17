"""
SaaS Cohort Analytics & Unit Economics Analysis
Real-world SaaS metrics: CAC, LTV, Payback Period, Cohort Retention
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from datetime import datetime, timedelta

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (16, 10)

# Load data
df = pd.read_csv('data/subscriptions.csv')
df['signup_date'] = pd.to_datetime(df['signup_date'])
df['churn_date'] = pd.to_datetime(df['churn_date'])
df['cohort_month'] = pd.to_datetime(df['cohort_month'])

print("=" * 80)
print("SAAS COHORT ANALYTICS & UNIT ECONOMICS ANALYSIS")
print("=" * 80)

# 1. COHORT RETENTION ANALYSIS
print("\n📊 COHORT RETENTION TABLE (% of customers retained by month)")
print("-" * 80)

# Create cohort analysis table
cohort_data = []
for cohort in df['cohort_month'].unique():
    cohort_df = df[df['cohort_month'] == cohort].copy()
    cohort_size = len(cohort_df)
    
    # Month 0 (signup month)
    m0_active = len(cohort_df)
    
    # Month 1+
    m1_active = len(cohort_df[(cohort_df['is_churned'] == 0) | 
                              (cohort_df['churn_date'] >= cohort_df['signup_date'] + timedelta(days=30))])
    m3_active = len(cohort_df[(cohort_df['is_churned'] == 0) | 
                              (cohort_df['churn_date'] >= cohort_df['signup_date'] + timedelta(days=90))])
    m6_active = len(cohort_df[(cohort_df['is_churned'] == 0) | 
                              (cohort_df['churn_date'] >= cohort_df['signup_date'] + timedelta(days=180))])
    
    cohort_data.append({
        'Cohort': cohort.strftime('%Y-%m'),
        'Size': cohort_size,
        'M0': '100%',
        'M1': f"{(m1_active/cohort_size*100):.0f}%",
        'M3': f"{(m3_active/cohort_size*100):.0f}%",
        'M6': f"{(m6_active/cohort_size*100):.0f}%"
    })

cohort_table = pd.DataFrame(cohort_data)
print(cohort_table.to_string(index=False))

# 2. CHURN ANALYSIS BY PLAN
print("\n\n⚠️  CHURN ANALYSIS BY PLAN TYPE")
print("-" * 80)
churn_by_plan = df.groupby('plan_type').agg({
    'is_churned': ['sum', 'count', 'mean'],
    'mrr': 'sum'
}).round(3)
churn_by_plan.columns = ['Churned_Count', 'Total_Users', 'Churn_Rate', 'MRR']
churn_by_plan['Churn_Rate_Pct'] = (churn_by_plan['Churn_Rate'] * 100).round(1)
print(churn_by_plan[['Total_Users', 'Churned_Count', 'Churn_Rate_Pct', 'MRR']])

# 3. UNIT ECONOMICS CALCULATION
print("\n\n💰 UNIT ECONOMICS (Key SaaS Metrics)")
print("-" * 80)

total_mrr = df['mrr'].sum()
churned_users = df[df['is_churned'] == 1]
active_users = df[df['is_churned'] == 0]

# CAC (Customer Acquisition Cost - simplified: assume $500 per acquisition)
assumed_marketing_spend = len(df) * 500
cac = assumed_marketing_spend / len(df)

# LTV (Lifetime Value)
avg_mrr_per_user = df['mrr'].mean()
avg_customer_lifetime_months = 24  # Assume 24 months average
ltv = avg_mrr_per_user * avg_customer_lifetime_months

# Payback Period
if avg_mrr_per_user > 0:
    payback_months = cac / avg_mrr_per_user
else:
    payback_months = 0

# Monthly churn rate
monthly_churn_rate = df['is_churned'].mean()

# Net Revenue Retention (simplified)
current_mrr = active_users['mrr'].sum()
revenue_loss_from_churn = churned_users['mrr'].sum()
nrr = ((current_mrr - revenue_loss_from_churn) / current_mrr * 100) if current_mrr > 0 else 0

print(f"Monthly Recurring Revenue (MRR): ${total_mrr:,.0f}")
print(f"Average MRR per Customer: ${avg_mrr_per_user:.2f}")
print(f"Customer Acquisition Cost (CAC): ${cac:.2f}")
print(f"Lifetime Value (LTV): ${ltv:.2f}")
print(f"LTV:CAC Ratio: {ltv/cac:.1f}x (Target: >3x)")
print(f"Payback Period: {payback_months:.1f} months")
print(f"Monthly Churn Rate: {monthly_churn_rate*100:.1f}%")
print(f"Current Active MRR: ${current_mrr:,.0f}")
print(f"MRR Lost to Churn: ${revenue_loss_from_churn:,.0f}")

# 4. GEOGRAPHIC ANALYSIS
print("\n\n🌍 GEOGRAPHIC PERFORMANCE")
print("-" * 80)
geo_analysis = df.groupby('country').agg({
    'user_id': 'count',
    'mrr': 'sum',
    'is_churned': 'mean'
}).round(3)
geo_analysis.columns = ['Users', 'MRR', 'Churn_Rate']
geo_analysis['Churn_Rate_Pct'] = (geo_analysis['Churn_Rate'] * 100).round(1)
geo_analysis = geo_analysis.sort_values('MRR', ascending=False)
print(geo_analysis[['Users', 'MRR', 'Churn_Rate_Pct']])

# 5. INDUSTRY ANALYSIS
print("\n\n🏢 INDUSTRY SEGMENT ANALYSIS")
print("-" * 80)
industry_analysis = df.groupby('industry').agg({
    'user_id': 'count',
    'mrr': ['sum', 'mean'],
    'is_churned': 'mean'
}).round(2)
industry_analysis.columns = ['Users', 'Total_MRR', 'Avg_MRR', 'Churn_Rate']
industry_analysis['Churn_Rate_Pct'] = (industry_analysis['Churn_Rate'] * 100).round(1)
industry_analysis = industry_analysis.sort_values('Total_MRR', ascending=False)
print(industry_analysis[['Users', 'Total_MRR', 'Avg_MRR', 'Churn_Rate_Pct']])

# VISUALIZATIONS
fig, axes = plt.subplots(2, 2, figsize=(16, 12))

# Plot 1: Churn Rate by Plan
ax1 = axes[0, 0]
churn_rates = df.groupby('plan_type')['is_churned'].mean() * 100
colors = ['green', 'orange', 'red']
churn_rates.plot(kind='bar', ax=ax1, color=colors, alpha=0.7, edgecolor='black')
ax1.set_title('Churn Rate by Plan Type', fontsize=13, fontweight='bold')
ax1.set_ylabel('Churn Rate (%)')
ax1.set_xlabel('Plan Type')
ax1.axhline(y=monthly_churn_rate*100, color='red', linestyle='--', label='Average', alpha=0.5)
ax1.legend()
ax1.tick_params(axis='x', rotation=45)

# Plot 2: MRR by Cohort
ax2 = axes[0, 1]
mrr_by_cohort = df.groupby('cohort_month')['mrr'].sum() / 1000
mrr_by_cohort.plot(kind='bar', ax=ax2, color='steelblue', alpha=0.7, edgecolor='black')
ax2.set_title('MRR by Signup Cohort', fontsize=13, fontweight='bold')
ax2.set_ylabel('MRR ($1000s)')
ax2.set_xlabel('Cohort Month')
ax2.tick_params(axis='x', rotation=45)

# Plot 3: LTV vs CAC
ax3 = axes[1, 0]
metrics = ['CAC', 'LTV']
values = [cac, ltv]
bars = ax3.bar(metrics, values, color=['red', 'green'], alpha=0.7, edgecolor='black', width=0.6)
ax3.set_title('Customer Economics: CAC vs LTV', fontsize=13, fontweight='bold')
ax3.set_ylabel('Amount ($)')
for bar, val in zip(bars, values):
    height = bar.get_height()
    ax3.text(bar.get_x() + bar.get_width()/2., height,
            f'${val:.0f}', ha='center', va='bottom', fontweight='bold', fontsize=11)
# Add target line
ax3.axhline(y=cac * 3, color='purple', linestyle='--', alpha=0.5, label='3x CAC Target')
ax3.legend()

# Plot 4: Churn by Geography
ax4 = axes[1, 1]
geo_churn = df.groupby('country')['is_churned'].mean() * 100
geo_churn.plot(kind='barh', ax=ax4, color='coral', alpha=0.7, edgecolor='black')
ax4.set_title('Churn Rate by Country', fontsize=13, fontweight='bold')
ax4.set_xlabel('Churn Rate (%)')
ax4.axvline(x=monthly_churn_rate*100, color='red', linestyle='--', alpha=0.5, label='Average')
ax4.legend()

plt.tight_layout()
plt.savefig('results/saas_analytics.png', dpi=300, bbox_inches='tight')
print("\n✅ Dashboard saved to: results/saas_analytics.png")

print("\n" + "=" * 80)
print("KEY INSIGHTS & RECOMMENDATIONS")
print("=" * 80)

# Find insights
starter_churn = df[df['plan_type']=='starter']['is_churned'].mean()
professional_churn = df[df['plan_type']=='professional']['is_churned'].mean()

if starter_churn > professional_churn:
    print(f"⚠️  Starter plan has {(starter_churn-professional_churn)*100:.0f}% higher churn")
    print("   → Recommendation: Improve starter plan value or upsell faster")

high_churn_country = geo_analysis['Churn_Rate_Pct'].idxmax()
print(f"\n⚠️  {high_churn_country} has highest churn at {geo_analysis.loc[high_churn_country, 'Churn_Rate_Pct']:.1f}%")
print(f"   → Recommendation: Investigate support quality or product-market fit in {high_churn_country}")

if ltv/cac < 3:
    print(f"\n⚠️  LTV:CAC ratio is {ltv/cac:.1f}x (below 3x target)")
    print("   → Recommendation: Increase customer lifetime or reduce CAC")

if payback_months > 12:
    print(f"\n⚠️  Payback period is {payback_months:.0f} months (too long)")
    print("   → Recommendation: Increase price or reduce acquisition costs")

print("\n" + "=" * 80)
