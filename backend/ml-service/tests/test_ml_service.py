from fastapi.testclient import TestClient

from app.main import app
from app.features.bank_features import compute_bank_features
from app.features.gst_features import compute_gst_features
from app.features.cross_validation import cross_validate_gst_bank


def test_bank_feature_computation():
    data = {
        "transactions": [
            {"date": "2026-01-01", "amount": 45000, "type": "credit", "narration": "SALARY CREDIT"},
            {"date": "2026-01-02", "amount": 45000, "type": "credit", "narration": "SALARY CREDIT"},
            {"date": "2026-01-05", "amount": 12000, "type": "debit", "narration": "EMI PAYMENT"},
            {"date": "2026-01-07", "amount": 18000, "type": "credit", "narration": "BUNDL TECHNOLOGIES PVT LTD NEFT"},
            {"date": "2026-01-11", "amount": 2000, "type": "debit", "narration": "ATM WITHDRAWAL"},
        ]
    }
    result = compute_bank_features(data)
    assert result["monthly_inflow"] > 0
    assert result["gig_income"] >= 0
    assert result["upi_cash_ratio"] >= 0


def test_gst_feature_computation():
    data = {
        "filings": [
            {"month": "2026-01", "turnover": 600000, "on_time": True},
            {"month": "2026-02", "turnover": 700000, "on_time": True},
            {"month": "2026-03", "turnover": 650000, "on_time": False},
        ]
    }
    result = compute_gst_features(data)
    assert result["turnover_trend"] > 0
    assert 0 <= result["filing_punctuality"] <= 100
    assert result["revenue_diversification"] > 0


def test_cross_validation_detects_discrepancy():
    bank = {
        "transactions": [
            {"date": "2026-01-05", "amount": 500000, "type": "credit"},
            {"date": "2026-02-05", "amount": 400000, "type": "credit"},
        ]
    }
    gst = {
        "invoices": [
            {"date": "2026-01-10", "amount": 900000},
            {"date": "2026-02-10", "amount": 400000},
        ]
    }
    result = cross_validate_gst_bank(gst, bank)
    assert "discrepancy_ratio" in result
    assert "matches" in result


def test_score_endpoint_uses_unsupervised_model_prediction():
    client = TestClient(app)
    response = client.post(
        "/v1/score",
        json={
            "person_id": "P-1001",
            "features": {
                "income_regularity": 0.82,
                "gig_income_consistency": 0.74,
                "late_bill_payment_rate": 0.12,
                "avg_days_late": 4.6,
                "spending_volatility": 0.25,
                "spending_to_income_ratio": 0.41,
                "avg_monthly_upi_count": 38.0,
                "avg_monthly_upi_volume": 72000.0,
                "upi_failed_rate": 0.04,
                "p2p_to_p2m_ratio": 0.7,
                "gst_on_time_rate": 0.9,
                "gst_avg_days_late": 2.0,
                "gst_turnover_trend": 0.15,
                "has_gst_data": 1.0,
                "psychometric_discipline_score": 3.4,
                "psychometric_score_variance": 0.7,
                "avg_response_time_seconds": 22.5,
            },
        },
    )
    assert response.status_code == 200, response.text
    payload = response.json()
    assert "predicted_class" in payload
    assert payload["predicted_class"] in {"P1", "P2", "P3", "P4"}
    assert 0.0 <= payload["probability"] <= 1.0
    assert 0 <= payload["credit_score"] <= 850


def test_narration_endpoint():
    client = TestClient(app)
    response = client.post(
        "/v1/narration/classify",
        json={
            "transactions": [
                {"date": "2026-07-01", "narration": "BUNDL TECHNOLOGIES PVT LTD NEFT", "amount": 4200},
                {"date": "2026-07-08", "narration": "ANI TECHNOLOGIES PVT LTD UPI", "amount": 3100},
            ]
        },
    )
    assert response.status_code == 200
    payload = response.json()
    assert len(payload["classified"]) == 2
    assert payload["monthly_gig_income_summary"]["total"] > 0
