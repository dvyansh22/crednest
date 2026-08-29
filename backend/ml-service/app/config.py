from dataclasses import dataclass


@dataclass(frozen=True)
class Settings:
    app_name: str = "CredNest ML Scoring Service"
    app_version: str = "1.0.0"
    model_weights: dict = None
    scoring_window_days: int = 45
    max_score: int = 850
    min_score: int = 300

    def __post_init__(self):
        if self.model_weights is None:
            object.__setattr__(
                self,
                "model_weights",
                {
                    "xgboost": 0.42,
                    "bert": 0.2,
                    "lstm": 0.18,
                    "npa": 0.1,
                    "federated": 0.1,
                },
            )


settings = Settings()
