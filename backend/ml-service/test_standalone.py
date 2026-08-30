from app.models.xgboost_engine.xgboost_engine import XGBoostEngine
from app.models.npa_early_warning.npa_early_warning import NPAEarlyWarningModel
from app.models.lstm_seasonal.lstm_seasonal import SeasonalIncomeModel
from app.models.bert_psychometric.bert_psychometric import PsychometricModel
from app.ensemble.score_aggregator import ScoreAggregator

def run_tests():
    print("--- Testing XGBoostEngine ---")
    xgb = XGBoostEngine()
    features = {
        "income_regularity": 0.8, "gig_income_consistency": 1.0, 
        "late_bill_payment_rate": 0.1, "avg_days_late": 2.0,
        "spending_volatility": 0.3, "spending_to_income_ratio": 0.5,
        "avg_monthly_upi_count": 10.0, "avg_monthly_upi_volume": 50.0,
        "upi_failed_rate": 0.05, "p2p_to_p2m_ratio": 1.2,
        "gst_on_time_rate": 0.9, "gst_avg_days_late": 1.5,
        "gst_turnover_trend": 0.1, "has_gst_data": 1.0,
        "psychometric_discipline_score": 0.8,
        "psychometric_score_variance": 0.2, "avg_response_time_seconds": 15.0
    }
    xgb_out = xgb.predict(features)
    print("XGBoost output:", xgb_out)
    
    print("\n--- Testing NPAEarlyWarningModel ---")
    npa = NPAEarlyWarningModel()
    npa_out = npa.predict({"salary_gap_days": 40, "gst_filing_gap_days": 15})
    print("NPA output:", npa_out)
    
    print("\n--- Testing SeasonalIncomeModel (LSTM) ---")
    lstm = SeasonalIncomeModel()
    lstm_out = lstm.predict([50000, 48000, 52000, 49000, 51000])
    print("LSTM output:", lstm_out)
    
    print("\n--- Testing PsychometricModel (BERT) ---")
    bert = PsychometricModel()
    quiz_data = [{"question_id": "Q01", "answer": "never"}, {"question_id": "Q02", "answer": "4"}, {"question_id": "Q07", "answer": "1"}]
    bert_out = bert.predict(quiz_data)
    print("BERT output:", bert_out)
    
    print("\n--- Testing ScoreAggregator ---")
    agg = ScoreAggregator()
    bank_data = {
        "transactions": [
            {"amount": 50000, "type": "credit", "date": "2026-01-01"},
            {"amount": 50000, "type": "credit", "date": "2026-02-01"}
        ]
    }
    agg_out = agg.score("B123", bank_statement=bank_data, gst_data={}, quiz_responses=quiz_data, federated_delta={})
    print("Aggregator output keys:", agg_out.keys())
    print("Aggregator output:", agg_out)

if __name__ == "__main__":
    run_tests()
