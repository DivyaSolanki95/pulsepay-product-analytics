"""
PulsePay Phase 2 — Realistic Synthetic Product Dataset Generator
Generates reproducible CSVs for MySQL import.

Run:
    python generate_pulsepay_data.py
"""

from pathlib import Path
import random
import uuid
import numpy as np
import pandas as pd

SEED = 42
N_USERS = 50_000
random.seed(SEED)
rng = np.random.default_rng(SEED)

BASE_DIR = Path(__file__).resolve().parents[2]
OUT = BASE_DIR / "data" / "raw"
OUT.mkdir(parents=True, exist_ok=True)

START = pd.Timestamp("2026-01-01 00:00:00")
END = pd.Timestamp("2026-06-30 23:59:59")

channels = ["Organic", "Paid Search", "Paid Social", "Referral", "Influencer", "Partnership"]
channel_p = [0.28, 0.18, 0.20, 0.17, 0.08, 0.09]
campaign_map = {
    "Organic": ["Organic"],
    "Paid Search": ["Search_Brand", "Search_UPI", "Search_Rewards"],
    "Paid Social": ["Meta_Growth", "Instagram_Cashback", "ShortVideo_Acquisition"],
    "Referral": ["Refer_A_Friend"],
    "Influencer": ["Creator_Finance", "Creator_Student"],
    "Partnership": ["Bank_Partner", "Campus_Partner"]
}
devices = ["Android", "iOS", "Web"]
device_p = [0.74, 0.22, 0.04]
tiers = ["Tier 1", "Tier 2", "Tier 3"]
tier_p = [0.36, 0.39, 0.25]
age_groups = ["18-24", "25-34", "35-44", "45+"]
age_p = [0.38, 0.36, 0.17, 0.09]

def rand_ts(start, end, n):
    seconds = int((end - start).total_seconds())
    return start + pd.to_timedelta(rng.integers(0, seconds + 1, n), unit="s")

def version_for(ts, device):
    if device == "Web":
        return "web-2.1"
    if ts < pd.Timestamp("2026-03-01"):
        return "5.2"
    if ts < pd.Timestamp("2026-05-15"):
        return "5.3"
    return rng.choice(["5.3", "5.4"], p=[0.25, 0.75])

# ---------------- USERS ----------------
user_ids = np.arange(100001, 100001 + N_USERS)
signup_ts = rand_ts(START, END - pd.Timedelta(days=7), N_USERS)
channel = rng.choice(channels, N_USERS, p=channel_p)
device = rng.choice(devices, N_USERS, p=device_p)
city_tier = rng.choice(tiers, N_USERS, p=tier_p)
age_group = rng.choice(age_groups, N_USERS, p=age_p)

users = pd.DataFrame({
    "user_id": user_ids,
    "signup_timestamp": signup_ts,
    "acquisition_channel": channel,
    "campaign_name": [rng.choice(campaign_map[c]) for c in channel],
    "device_type": device,
    "city_tier": city_tier,
    "age_group": age_group,
})
users["signup_app_version"] = [version_for(t, d) for t, d in zip(users.signup_timestamp, users.device_type)]
users["is_premium"] = (rng.random(N_USERS) < 0.08).astype(int)

# Paid Social intentionally has lower-quality cohorts.
quality = rng.beta(3.0, 2.0, N_USERS)
quality -= np.where(users.acquisition_channel.eq("Paid Social"), 0.12, 0)
quality += np.where(users.acquisition_channel.eq("Referral"), 0.10, 0)
quality = np.clip(quality, 0.02, 0.98)
users["_quality"] = quality

users.drop(columns="_quality").to_csv(OUT/"users.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")

# ---------------- KYC + EVENTS ----------------
events = []
kyc_rows = []
activated_users = []
event_id = 1
kyc_id = 1

def add_event(uid, sid, name, ts, feature, version, dev, props="{}"):
    global event_id
    events.append([event_id, uid, sid, name, ts, feature, version, dev, props])
    event_id += 1

for row, q in zip(users.itertuples(index=False), quality):
    uid = row.user_id
    sid = uuid.uuid4().hex[:20]
    t = row.signup_timestamp
    v = row.signup_app_version
    d = row.device_type

    add_event(uid, sid, "account_created", t, "Onboarding", v, d)
    otp_ok = rng.random() < (0.91 + 0.05*q)
    if not otp_ok:
        continue

    otp_t = t + pd.Timedelta(minutes=int(rng.integers(1, 15)))
    add_event(uid, sid, "otp_verified", otp_t, "Onboarding", v, d)

    kyc_start = rng.random() < (0.78 + 0.15*q)
    if not kyc_start:
        continue

    ks = otp_t + pd.Timedelta(minutes=int(rng.integers(1, 60)))
    add_event(uid, sid, "kyc_started", ks, "KYC", v, d)

    # Deliberate incident: Android 5.4 after May 15 has worse KYC completion.
    incident = d == "Android" and v == "5.4" and ks >= pd.Timestamp("2026-05-15")
    completion_p = 0.58 + 0.30*q - (0.22 if incident else 0)
    completed = rng.random() < np.clip(completion_p, 0.15, 0.95)

    if completed:
        kc = ks + pd.Timedelta(minutes=int(rng.integers(5, 240)))
        kyc_rows.append([kyc_id, uid, ks, kc, "completed", "", "3-step" if rng.random() < 0.5 else "5-step"])
        add_event(uid, sid, "kyc_completed", kc, "KYC", v, d)
        bank_linked = rng.random() < (0.78 + 0.16*q)
        if bank_linked:
            bl = kc + pd.Timedelta(minutes=int(rng.integers(2, 1440)))
            add_event(uid, sid, "bank_linked", bl, "Payments", v, d)
            activated_users.append((uid, bl, q, d, v))
    else:
        status = rng.choice(["failed", "abandoned"], p=[0.62, 0.38])
        reason = "document_upload_error" if incident and status == "failed" else (
            rng.choice(["blurry_document", "identity_mismatch", "network_error"]) if status == "failed" else ""
        )
        kyc_rows.append([kyc_id, uid, ks, "", status, reason, "5-step"])
        if status == "failed":
            add_event(uid, sid, "kyc_failed", ks + pd.Timedelta(minutes=int(rng.integers(2, 30))), "KYC", v, d,
                      '{"failure_reason":"' + reason + '"}')
    kyc_id += 1

# ---------------- TRANSACTIONS ----------------
transactions = []
txn_id = 500001
txn_types = ["UPI", "Bill Payment", "Mobile Recharge", "Wallet Transfer", "Merchant Payment"]
partners = ["AxisPay", "HDFCPay", "ICICIPay", "SBIPay", "PartnerX"]

for uid, activation_time, q, d, v in activated_users:
    if rng.random() > (0.48 + 0.42*q):
        continue
    n_tx = max(1, int(rng.negative_binomial(2, max(0.15, 0.55 - 0.25*q))))
    n_tx = min(n_tx, 35)
    first_success = False
    for j in range(n_tx):
        tt = activation_time + pd.Timedelta(days=float(rng.exponential(9))) + pd.Timedelta(hours=j*6)
        if tt > END:
            break
        fail_boost = 0.025 if (tt >= pd.Timestamp("2026-06-10") and tt <= pd.Timestamp("2026-06-18")) else 0
        success_p = 0.94 - fail_boost
        status = rng.choice(["success", "failed", "pending"], p=[success_p, 0.05+fail_boost, 0.01])
        amount = round(float(np.clip(rng.lognormal(5.4, 1.0), 10, 25000)), 2)
        failure_reason = "" if status != "failed" else rng.choice(["bank_declined", "timeout", "insufficient_funds"])
        transactions.append([txn_id, uid, tt, rng.choice(txn_types), amount, status, failure_reason, rng.choice(partners)])
        sid = uuid.uuid4().hex[:20]
        add_event(uid, sid, "transaction_" + status, tt, "Payments", v, d)
        if status == "success" and not first_success:
            add_event(uid, sid, "first_successful_transaction", tt, "Activation", v, d)
            first_success = True
        txn_id += 1

# ---------------- EXPERIMENT ----------------
experiment_assignments = []
assignment_id = 1
eligible = users[(users.signup_timestamp >= "2026-04-01") & (users.signup_timestamp < "2026-04-22")]
for row in eligible.itertuples(index=False):
    experiment_assignments.append([
        assignment_id, 1, row.user_id,
        "control" if rng.random() < 0.5 else "treatment",
        row.signup_timestamp
    ])
    assignment_id += 1

# ---------------- SUPPORT TICKETS ----------------
support = []
ticket_id = 900001
categories = ["Payment Failure", "KYC Issues", "App Performance", "Rewards", "Account"]
for row in users.sample(n=min(7000, len(users)), random_state=SEED).itertuples(index=False):
    incident = row.device_type == "Android" and row.signup_app_version == "5.4" and row.signup_timestamp >= pd.Timestamp("2026-05-15")
    category = rng.choice(categories, p=[0.25, 0.38 if incident else 0.22, 0.16, 0.13, 0.24 if not incident else 0.08])
    text_map = {
        "Payment Failure": "My payment failed and I do not know why.",
        "KYC Issues": "I am unable to complete KYC document verification.",
        "App Performance": "The app feels slow and sometimes freezes.",
        "Rewards": "The rewards experience is confusing.",
        "Account": "I need help with my account."
    }
    created = row.signup_timestamp + pd.Timedelta(days=float(rng.uniform(0, 30)))
    if created > END:
        created = END
    support.append([ticket_id, row.user_id, created, category, text_map[category],
                    "negative" if category in ["Payment Failure", "KYC Issues", "App Performance"] else "neutral",
                    round(float(rng.gamma(2, 5)), 2)])
    ticket_id += 1

# Save
pd.DataFrame(events, columns=[
    "event_id","user_id","session_id","event_name","event_timestamp",
    "feature_name","app_version","device_type","event_properties"
]).to_csv(OUT/"events.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")

pd.DataFrame(kyc_rows, columns=[
    "kyc_id","user_id","started_at","completed_at","status","failure_reason","flow_version"
]).to_csv(OUT/"kyc_applications.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")

pd.DataFrame(transactions, columns=[
    "transaction_id","user_id","transaction_timestamp","transaction_type",
    "amount","status","failure_reason","payment_partner"
]).to_csv(OUT/"transactions.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")

pd.DataFrame(experiment_assignments, columns=[
    "assignment_id","experiment_id","user_id","variant","assigned_at"
]).to_csv(OUT/"experiment_assignments.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")

pd.DataFrame(support, columns=[
    "ticket_id","user_id","created_at","category","issue_text",
    "sentiment","resolution_time_hours"
]).to_csv(OUT/"support_tickets.csv", index=False, date_format="%Y-%m-%d %H:%M:%S")

print("\nPulsePay dataset generated successfully.")
for f in sorted(OUT.glob("*.csv")):
    df = pd.read_csv(f)
    print(f"{f.name:30s} {len(df):>10,} rows")
print(f"\nOutput folder: {OUT}")
