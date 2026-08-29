from __future__ import annotations

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from app.api.routes.narration import router as narration_router
from app.api.routes.score import router as score_router

app = FastAPI(
    title="CredNest ML Scoring Service",
    version="1.0.0",
    description="AI credit scoring and narrations for CredNest.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(narration_router, prefix="/v1")
app.include_router(score_router, prefix="/v1")


@app.get("/health")
def health_check() -> dict:
    return {"status": "ok"}
