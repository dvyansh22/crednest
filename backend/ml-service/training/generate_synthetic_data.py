import os
import random
import uuid
from datetime import datetime, timedelta
import pandas as pd
import numpy as np
from pathlib import Path

PROJECT_ROOT = Path(__file__).resolve().parents[1]
DATA_DIR = PROJECT_ROOT / "data" / "dataset"

NUM_USERS = 8000

def generate_data():
    DATA_DIR.mkdir(parents=True, exist_ok=True)
    
    person_ids = [f"USR_{uuid.uuid4().hex[:8].upper()}" for _ in range(NUM_USERS)]
    
    # 1. Psychometric & Location (All users take the quiz)
    print("Generating psychometric and location data...")
    psych_data = []
    # Major hubs (Delhi, Mumbai, Bglr) + rural spread
    base_lats = [28.61, 19.07, 12.97, 22.90, 26.84]
    base_lons = [77.20, 72.87, 77.59, 79.08, 80.94]
    
    for pid in person_ids:
        # Profile types
        profile = random.choices(['excellent', 'average', 'erratic'], weights=[0.2, 0.6, 0.2])[0]
        
        row = {"person_id": pid}
        for i in range(1, 11):
            if profile == 'excellent':
                row[f"q{i}"] = random.choices(["A", "B", "C", "D"], weights=[0.7, 0.2, 0.05, 0.05])[0]
                row[f"response_time_seconds_{i}"] = round(random.uniform(5, 12), 2)
            elif profile == 'average':
                row[f"q{i}"] = random.choices(["A", "B", "C", "D"], weights=[0.25, 0.4, 0.25, 0.1])[0]
                row[f"response_time_seconds_{i}"] = round(random.uniform(10, 25), 2)
            else:
                row[f"q{i}"] = random.choices(["A", "B", "C", "D"], weights=[0.1, 0.2, 0.3, 0.4])[0]
                row[f"response_time_seconds_{i}"] = round(random.uniform(2, 40), 2)
                
        # Location
        hub_idx = random.randint(0, len(base_lats) - 1)
        row["latitude"] = round(base_lats[hub_idx] + random.uniform(-2, 2), 4)
        row["longitude"] = round(base_lons[hub_idx] + random.uniform(-2, 2), 4)
        psych_data.append(row)
        
    pd.DataFrame(psych_data).to_csv(DATA_DIR / "psychometric_responses.csv", index=False)
    
    # 2. Bank Transactions
    print("Generating bank transactions...")
    bank_data = []
    end_date = datetime(2025, 12, 31)
    
    # User segments:
    # 30% MSME (High income/spend)
    # 40% Gig workers (Frequent small income/spend)
    # 20% Thin file (Very few transactions, no income)
    # 10% No bank account at all
    
    for pid in person_ids:
        segment = random.choices(['msme', 'gig', 'thin', 'none'], weights=[0.3, 0.4, 0.2, 0.1])[0]
        if segment == 'none': continue
        
        months_active = random.randint(3, 12) if segment != 'thin' else random.randint(1, 4)
        
        for m in range(months_active):
            month_date = end_date - timedelta(days=30*m)
            
            # Income
            if segment == 'msme':
                if random.random() > 0.1:  # 90% regular
                    bank_data.append({"person_id": pid, "date": month_date.strftime("%Y-%m-%d"), "type": "credit", "amount": round(random.uniform(50000, 200000), 2), "narration": "NEFT CLIENT PYMT"})
            elif segment == 'gig':
                if random.random() > 0.2:
                    for _ in range(random.randint(2, 6)):
                        day = month_date - timedelta(days=random.randint(0, 28))
                        platform = random.choice(["UBER", "SWIGGY", "ZOMATO"])
                        bank_data.append({"person_id": pid, "date": day.strftime("%Y-%m-%d"), "type": "credit", "amount": round(random.uniform(500, 3000), 2), "narration": f"UPI {platform} PAYOUT"})
            # Thin files have NO income generated here, representing informal cash income.
            
            # Spends
            num_spends = random.randint(5, 20) if segment != 'thin' else random.randint(1, 5)
            for _ in range(num_spends):
                day = month_date - timedelta(days=random.randint(0, 28))
                amt = round(random.uniform(100, 5000) if segment == 'msme' else random.uniform(50, 1000), 2)
                narr = "UPI P2M MERCH" if random.random() > 0.2 else "ATM WITHDRAWAL"
                bank_data.append({"person_id": pid, "date": day.strftime("%Y-%m-%d"), "type": "debit", "amount": amt, "narration": narr})
                
            # Late payments
            if random.random() > (0.8 if segment == 'msme' else 0.5):
                day = month_date - timedelta(days=random.randint(0, 28))
                bank_data.append({"person_id": pid, "date": day.strftime("%Y-%m-%d"), "type": "debit", "amount": round(random.uniform(500, 5000), 2), "narration": "LATE EMI PENALTY"})

    pd.DataFrame(bank_data).to_csv(DATA_DIR / "bank_transactions.csv", index=False)

    # 3. UPI Transactions
    print("Generating UPI transactions...")
    upi_data = []
    for pid in person_ids:
        segment = random.choices(['active', 'low', 'none'], weights=[0.5, 0.3, 0.2])[0]
        if segment == 'none': continue
        
        num_tx = random.randint(20, 100) if segment == 'active' else random.randint(2, 15)
        for _ in range(num_tx):
            day = end_date - timedelta(days=random.randint(0, 360))
            is_p2m = random.random() > 0.3
            tx_type = "P2M" if is_p2m else "P2P"
            cp = "MERCHANT" if is_p2m else "FRIEND"
            status = "SUCCESS" if random.random() > 0.05 else "FAILED"
            upi_data.append({
                "person_id": pid,
                "date": day.strftime("%Y-%m-%d"),
                "type": tx_type,
                "counterparty_type": cp,
                "status": status,
                "amount": round(random.uniform(10, 2000), 2)
            })
    pd.DataFrame(upi_data).to_csv(DATA_DIR / "upi_transactions.csv", index=False)

    # 4. GST Filings
    print("Generating GST filings...")
    gst_data = []
    for pid in person_ids:
        if random.random() < 0.25:  # ~25% have GST
            on_time = random.choices(["TRUE", "FALSE"], weights=[0.8, 0.2])[0]
            for m in range(6):
                month_date = end_date - timedelta(days=30*m)
                due_date1 = month_date.replace(day=11)
                filed_date1 = due_date1 if on_time == "TRUE" else due_date1 + timedelta(days=random.randint(1, 30))
                
                due_date3 = month_date.replace(day=20)
                filed_date3 = due_date3 if on_time == "TRUE" else due_date3 + timedelta(days=random.randint(1, 30))
                
                gst_data.append({
                    "person_id": pid,
                    "on_time_flag": on_time,
                    "declared_turnover": round(random.uniform(100000, 1000000), 2),
                    "gstr1_due_date": due_date1.strftime("%Y-%m-%d"),
                    "gstr1_filed_date": filed_date1.strftime("%Y-%m-%d"),
                    "gstr3b_due_date": due_date3.strftime("%Y-%m-%d"),
                    "gstr3b_filed_date": filed_date3.strftime("%Y-%m-%d")
                })
    pd.DataFrame(gst_data).to_csv(DATA_DIR / "gst_filings.csv", index=False)

    print(f"Synthetic data generation complete. Written to {DATA_DIR}")

if __name__ == "__main__":
    generate_data()
