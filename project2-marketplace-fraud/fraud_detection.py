"""
Marketplace Fraud Detection System
Advanced ML-powered fraud detection with explainability
Uses ensemble methods, anomaly detection, and risk scoring
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import seaborn as sns
from sklearn.model_selection import train_test_split
from sklearn.preprocessing import LabelEncoder
from sklearn.ensemble import RandomForestClassifier, GradientBoostingClassifier
from sklearn.metrics import classification_report, roc_auc_score, roc_curve, confusion_matrix
from sklearn.preprocessing import StandardScaler
import warnings
warnings.filterwarnings('ignore')

# Set style
sns.set_style("whitegrid")
plt.rcParams['figure.figsize'] = (16, 12)

# Load data
df = pd.read_csv('data/transactions.csv')
df['transaction_date'] = pd.to_datetime(df['transaction_date'])
df['account_created_date'] = pd.to_datetime(df['account_created_date'])

print("=" * 100)
print("MARKETPLACE FRAUD DETECTION SYSTEM")
print("Advanced Machine Learning Approach with Risk Scoring")
print("=" * 100)

# 1. DATA EXPLORATION & FRAUD PATTERNS
print("\n📊 FRAUD DETECTION OVERVIEW")
print("-" * 100)
fraud_count = df['is_fraud'].sum()
fraud_pct = (fraud_count / len(df)) * 100
print(f"Total Transactions: {len(df)}")
print(f"Fraudulent Transactions: {fraud_count} ({fraud_pct:.1f}%)")
print(f"Legitimate Transactions: {len(df) - fraud_count} ({100-fraud_pct:.1f}%)")

# 2. FRAUD PATTERN ANALYSIS
print("\n\n⚠️  FRAUD PATTERN DETECTION")
print("-" * 100)

# Amount-based fraud
frauds = df[df['is_fraud'] == 1]
legit = df[df['is_fraud'] == 0]

print("\n🔍 AMOUNT ANALYSIS:")
print(f"Avg fraud transaction: ${frauds['amount'].mean():,.2f}")
print(f"Avg legitimate transaction: ${legit['amount'].mean():,.2f}")
print(f"Median fraud: ${frauds['amount'].median():.2f} | Median legit: ${legit['amount'].median():.2f}")

# Geographic fraud patterns
print("\n🌍 GEOGRAPHIC FRAUD PATTERNS:")
geo_fraud = df.groupby('ip_country').agg({
    'is_fraud': ['sum', 'count', 'mean']
}).round(3)
geo_fraud.columns = ['Fraud_Count', 'Total', 'Fraud_Rate']
geo_fraud['Fraud_Rate_Pct'] = (geo_fraud['Fraud_Rate'] * 100).round(1)
geo_fraud = geo_fraud.sort_values('Fraud_Rate_Pct', ascending=False)
print(geo_fraud[['Total', 'Fraud_Count', 'Fraud_Rate_Pct']])

# Account age fraud patterns
print("\n⏰ ACCOUNT AGE PATTERNS:")
df['account_age_bucket'] = pd.cut(df['account_age_days'], 
                                   bins=[0, 30, 90, 180, 365, 1000],
                                   labels=['<30d', '30-90d', '90-180d', '180-365d', '>365d'])
age_fraud = df.groupby('account_age_bucket').agg({
    'is_fraud': ['sum', 'count', 'mean']
}).round(3)
age_fraud.columns = ['Fraud_Count', 'Total', 'Fraud_Rate']
age_fraud['Fraud_Rate_Pct'] = (age_fraud['Fraud_Rate'] * 100).round(1)
print(age_fraud[['Total', 'Fraud_Count', 'Fraud_Rate_Pct']])

# Wire transfer fraud pattern
print("\n💳 PAYMENT METHOD FRAUD:")
method_fraud = df.groupby('payment_method').agg({
    'is_fraud': ['sum', 'count', 'mean']
}).round(3)
method_fraud.columns = ['Fraud_Count', 'Total', 'Fraud_Rate']
method_fraud['Fraud_Rate_Pct'] = (method_fraud['Fraud_Rate'] * 100).round(1)
print(method_fraud[['Total', 'Fraud_Count', 'Fraud_Rate_Pct']])

# 3. FEATURE ENGINEERING
print("\n\n🔧 FEATURE ENGINEERING")
print("-" * 100)

df_model = df.copy()

# Binary features
df_model['is_wire_transfer'] = (df_model['payment_method'] == 'wire_transfer').astype(int)
df_model['is_high_value'] = (df_model['amount'] > df_model['amount'].quantile(0.75)).astype(int)
df_model['is_new_seller'] = (df_model['account_age_days'] < 90).astype(int)
df_model['is_new_buyer'] = (df_model['account_age_days'] < 90).astype(int)
df_model['is_new_account'] = (df_model['account_age_days'] < 30).astype(int)
df_model['is_high_risk_country'] = df_model['ip_country'].isin(['NG', 'CN', 'IN', 'RU']).astype(int)

# Ratio features
df_model['rating_to_transaction_ratio'] = df_model['seller_rating'] / (df_model['transaction_count_seller'] + 1)
df_model['volume_to_rating'] = df_model['transaction_count_seller'] / (df_model['seller_rating'] + 0.1)

# Risk score (composite)
df_model['risk_score'] = (
    (df_model['is_wire_transfer'] * 0.25) +
    (df_model['is_high_value'] * 0.15) +
    (df_model['is_new_seller'] * 0.20) +
    (df_model['is_new_account'] * 0.25) +
    (df_model['is_high_risk_country'] * 0.15)
)

print("✅ Created 10 engineered features:")
print("   - is_wire_transfer (wire transfers are riskier)")
print("   - is_high_value (amounts above 75th percentile)")
print("   - is_new_seller (sellers <90 days old)")
print("   - is_new_account (accounts <30 days old)")
print("   - is_high_risk_country (known fraud hotspots)")
print("   - rating_to_transaction_ratio (quality metric)")
print("   - volume_to_rating (activity metric)")
print("   - risk_score (composite fraud risk 0-1.0)")

# 4. MACHINE LEARNING MODEL
print("\n\n🤖 MACHINE LEARNING MODELS")
print("-" * 100)

# Prepare features
features = ['amount', 'account_age_days', 'transaction_count_seller', 'transaction_count_buyer',
            'seller_rating', 'buyer_rating', 'shipping_days', 'is_wire_transfer', 'is_high_value',
            'is_new_seller', 'is_new_account', 'is_high_risk_country', 'rating_to_transaction_ratio',
            'volume_to_rating', 'risk_score']

X = df_model[features]
y = df_model['is_fraud']

# Encode categorical features
le_payment = LabelEncoder()
le_device = LabelEncoder()
le_category = LabelEncoder()
le_country = LabelEncoder()

df_model['payment_encoded'] = le_payment.fit_transform(df_model['payment_method'])
df_model['device_encoded'] = le_device.fit_transform(df_model['device_type'])
df_model['category_encoded'] = le_category.fit_transform(df_model['product_category'])
df_model['country_encoded'] = le_country.fit_transform(df_model['ip_country'])

# Add encoded features
X['payment_encoded'] = df_model['payment_encoded']
X['device_encoded'] = df_model['device_encoded']
X['category_encoded'] = df_model['category_encoded']
X['country_encoded'] = df_model['country_encoded']

# Split data
X_train, X_test, y_train, y_test = train_test_split(X, y, test_size=0.3, random_state=42, stratify=y)

# Scale features
scaler = StandardScaler()
X_train_scaled = scaler.fit_transform(X_train)
X_test_scaled = scaler.transform(X_test)

# Train Random Forest
print("\n1️⃣  RANDOM FOREST MODEL")
rf_model = RandomForestClassifier(n_estimators=100, max_depth=10, random_state=42, class_weight='balanced')
rf_model.fit(X_train, y_train)

rf_pred = rf_model.predict(X_test)
rf_proba = rf_model.predict_proba(X_test)[:, 1]
rf_auc = roc_auc_score(y_test, rf_proba)

print(f"   Accuracy: {rf_model.score(X_test, y_test):.2%}")
print(f"   ROC-AUC: {rf_auc:.2%}")

# Train Gradient Boosting
print("\n2️⃣  GRADIENT BOOSTING MODEL")
gb_model = GradientBoostingClassifier(n_estimators=50, max_depth=5, random_state=42)
gb_model.fit(X_train, y_train)

gb_pred = gb_model.predict(X_test)
gb_proba = gb_model.predict_proba(X_test)[:, 1]
gb_auc = roc_auc_score(y_test, gb_proba)

print(f"   Accuracy: {gb_model.score(X_test, y_test):.2%}")
print(f"   ROC-AUC: {gb_auc:.2%}")

# Ensemble average
ensemble_proba = (rf_proba + gb_proba) / 2
ensemble_auc = roc_auc_score(y_test, ensemble_proba)

print(f"\n3️⃣  ENSEMBLE MODEL (Average)")
print(f"   Accuracy: {(ensemble_proba > 0.5).astype(int).eq(y_test).mean():.2%}")
print(f"   ROC-AUC: {ensemble_auc:.2%}")

# 5. FEATURE IMPORTANCE
print("\n\n🔑 FEATURE IMPORTANCE (What Matters Most)")
print("-" * 100)
feature_importance = pd.DataFrame({
    'Feature': X.columns,
    'RF_Importance': rf_model.feature_importances_,
    'GB_Importance': gb_model.feature_importances_
}).sort_values('RF_Importance', ascending=False)

print(feature_importance.head(10).to_string(index=False))

# 6. FRAUD RISK SCORING
print("\n\n📍 FRAUD RISK SCORING (On Full Dataset)")
print("-" * 100)

df['fraud_risk_score'] = rf_model.predict_proba(X)[:, 1]
df['is_high_risk'] = (df['fraud_risk_score'] > 0.7).astype(int)
df['is_medium_risk'] = ((df['fraud_risk_score'] > 0.4) & (df['fraud_risk_score'] <= 0.7)).astype(int)
df['is_low_risk'] = (df['fraud_risk_score'] <= 0.4).astype(int)

risk_summary = pd.DataFrame({
    'Risk_Level': ['🟢 Low Risk', '🟡 Medium Risk', '🔴 High Risk'],
    'Count': [df['is_low_risk'].sum(), df['is_medium_risk'].sum(), df['is_high_risk'].sum()],
    'Fraud_Rate': [
        (df[df['is_low_risk']==1]['is_fraud'].mean() * 100),
        (df[df['is_medium_risk']==1]['is_fraud'].mean() * 100),
        (df[df['is_high_risk']==1]['is_fraud'].mean() * 100)
    ]
})

print(risk_summary.to_string(index=False))

# 7. HIGH RISK TRANSACTIONS
print("\n\n🚨 HIGH RISK TRANSACTIONS (Top Fraud Candidates)")
print("-" * 100)
high_risk_txns = df[df['is_high_risk'] == 1][['transaction_id', 'seller_id', 'amount', 
                                                 'ip_country', 'payment_method', 'fraud_risk_score', 'is_fraud']].sort_values('fraud_risk_score', ascending=False)
print(high_risk_txns.head(10).to_string(index=False))

# VISUALIZATIONS
fig, axes = plt.subplots(2, 2, figsize=(16, 12))

# Plot 1: ROC Curves
ax1 = axes[0, 0]
fpr_rf, tpr_rf, _ = roc_curve(y_test, rf_proba)
fpr_gb, tpr_gb, _ = roc_curve(y_test, gb_proba)
fpr_ensemble, tpr_ensemble, _ = roc_curve(y_test, ensemble_proba)

ax1.plot(fpr_rf, tpr_rf, label=f'Random Forest (AUC={rf_auc:.2f})', linewidth=2)
ax1.plot(fpr_gb, tpr_gb, label=f'Gradient Boosting (AUC={gb_auc:.2f})', linewidth=2)
ax1.plot(fpr_ensemble, tpr_ensemble, label=f'Ensemble (AUC={ensemble_auc:.2f})', linewidth=2.5, color='darkred')
ax1.plot([0, 1], [0, 1], 'k--', alpha=0.3)
ax1.set_title('ROC Curves - Fraud Detection Models', fontsize=13, fontweight='bold')
ax1.set_xlabel('False Positive Rate')
ax1.set_ylabel('True Positive Rate')
ax1.legend()
ax1.grid(True, alpha=0.3)

# Plot 2: Feature Importance
ax2 = axes[0, 1]
top_features = feature_importance.head(8)
ax2.barh(top_features['Feature'], top_features['RF_Importance'], color='steelblue', alpha=0.7)
ax2.set_title('Top 8 Features for Fraud Detection', fontsize=13, fontweight='bold')
ax2.set_xlabel('Importance')

# Plot 3: Risk Score Distribution
ax3 = axes[1, 0]
fraud_scores = df[df['is_fraud'] == 1]['fraud_risk_score']
legit_scores = df[df['is_fraud'] == 0]['fraud_risk_score']
ax3.hist([legit_scores, fraud_scores], label=['Legitimate', 'Fraudulent'], bins=15, color=['green', 'red'], alpha=0.7)
ax3.set_title('Fraud Risk Score Distribution', fontsize=13, fontweight='bold')
ax3.set_xlabel('Risk Score')
ax3.set_ylabel('Count')
ax3.legend()
ax3.axvline(x=0.5, color='black', linestyle='--', alpha=0.5, label='Threshold')

# Plot 4: Confusion Matrix
ax4 = axes[1, 1]
cm = confusion_matrix(y_test, (ensemble_proba > 0.5).astype(int))
sns.heatmap(cm, annot=True, fmt='d', ax=ax4, cmap='Blues', cbar=False)
ax4.set_title('Confusion Matrix - Ensemble Model', fontsize=13, fontweight='bold')
ax4.set_ylabel('Actual')
ax4.set_xlabel('Predicted')

plt.tight_layout()
plt.savefig('results/fraud_detection.png', dpi=300, bbox_inches='tight')
print("\n✅ Dashboard saved to: results/fraud_detection.png")

print("\n" + "=" * 100)
print("FRAUD DETECTION COMPLETE")
print("=" * 100)
