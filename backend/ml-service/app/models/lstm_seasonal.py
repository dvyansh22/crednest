"""LSTM autoencoder component for 12-month income and spending patterns."""
from __future__ import annotations

from typing import Any, Iterable

import numpy as np
import pandas as pd


class LSTMSeasonalAutoencoder:
    """Learns to reconstruct normal monthly income/spending sequences."""

    def __init__(self, epochs: int = 12, batch_size: int = 256, hidden_size: int = 16, random_state: int = 42):
        self.epochs = epochs
        self.batch_size = batch_size
        self.hidden_size = hidden_size
        self.random_state = random_state
        self.model: Any = None
        self.mean_: np.ndarray | None = None
        self.std_: np.ndarray | None = None
        self.error_reference_: np.ndarray | None = None
        self.person_scores_: dict[str, float] = {}

    @staticmethod
    def _monthly_sequences(bank_df: pd.DataFrame, person_ids: Iterable[str]) -> tuple[np.ndarray, list[str]]:
        data = bank_df[["person_id", "date", "type", "amount"]].copy()
        data["date"] = pd.to_datetime(data["date"], errors="coerce")
        data["amount"] = pd.to_numeric(data["amount"], errors="coerce").fillna(0.0)
        data = data.dropna(subset=["date"])
        months = pd.period_range(data["date"].min().to_period("M"), data["date"].max().to_period("M"), freq="M")[-12:]
        ids = [str(person_id) for person_id in person_ids]
        data["month"] = data["date"].dt.to_period("M")
        data["channel"] = np.where(data["type"].astype(str).str.lower().eq("credit"), "income", "spending")
        totals = data.groupby(["person_id", "month", "channel"])["amount"].sum().unstack("channel", fill_value=0.0)
        totals = totals.reindex(columns=["income", "spending"], fill_value=0.0)
        index = pd.MultiIndex.from_product([ids, months], names=["person_id", "month"])
        matrix = totals.reindex(index, fill_value=0.0).to_numpy(dtype=np.float32).reshape(len(ids), len(months), 2)
        return np.log1p(matrix), ids

    def fit_predict(self, bank_df: pd.DataFrame, feature_table: pd.DataFrame, normal_mask: pd.Series | None = None) -> pd.Series:
        try:
            import torch
            from torch import nn
            from torch.utils.data import DataLoader, TensorDataset
        except ImportError as exc:
            raise RuntimeError("A real LSTM autoencoder requires PyTorch. Install the 'torch' package to train the ensemble.") from exc

        torch.manual_seed(self.random_state)
        sequences, ids = self._monthly_sequences(bank_df, feature_table["person_id"])
        normal = np.asarray(normal_mask, dtype=bool) if normal_mask is not None else np.ones(len(sequences), dtype=bool)
        if normal.sum() < 32:
            normal = np.ones(len(sequences), dtype=bool)
        self.mean_ = sequences[normal].reshape(-1, 2).mean(axis=0)
        self.std_ = sequences[normal].reshape(-1, 2).std(axis=0)
        self.std_[self.std_ < 1e-6] = 1.0
        normalized = (sequences - self.mean_) / self.std_

        class Autoencoder(nn.Module):
            def __init__(self, hidden_size: int):
                super().__init__()
                self.encoder = nn.LSTM(input_size=2, hidden_size=hidden_size, batch_first=True)
                self.decoder = nn.LSTM(input_size=hidden_size, hidden_size=hidden_size, batch_first=True)
                self.output = nn.Linear(hidden_size, 2)

            def forward(self, x):
                _, (hidden, _) = self.encoder(x)
                repeated = hidden[-1].unsqueeze(1).repeat(1, x.size(1), 1)
                decoded, _ = self.decoder(repeated)
                return self.output(decoded)

        self.model = Autoencoder(self.hidden_size)
        optimizer = torch.optim.Adam(self.model.parameters(), lr=1e-3)
        criterion = nn.MSELoss()
        train = torch.tensor(normalized[normal], dtype=torch.float32)
        loader = DataLoader(TensorDataset(train), batch_size=self.batch_size, shuffle=True)
        self.model.train()
        for _ in range(self.epochs):
            for (batch,) in loader:
                optimizer.zero_grad()
                loss = criterion(self.model(batch), batch)
                loss.backward()
                optimizer.step()

        self.model.eval()
        with torch.no_grad():
            tensor = torch.tensor(normalized, dtype=torch.float32)
            errors = ((self.model(tensor) - tensor) ** 2).mean(dim=(1, 2)).cpu().numpy()
        self.error_reference_ = np.sort(errors)
        scores = np.searchsorted(self.error_reference_, errors, side="right") / len(self.error_reference_)
        self.person_scores_ = dict(zip(ids, scores.astype(float)))
        return pd.Series(scores, index=feature_table.index, name="lstm_seasonal_risk")

    def predict_one(self, person_id: str | None = None) -> float:
        return float(np.clip(self.person_scores_.get(str(person_id), 0.5), 0.0, 1.0))
