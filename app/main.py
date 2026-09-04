from fastapi import FastAPI
from sqlalchemy import text
from database import SessionLocal

app = FastAPI(title="ledger-lens")

@app.get("/health")
def health_check():
    return {"status": "ok"}

@app.get("/db-check")
def db_check():
    db = SessionLocal()
    try:
        result = db.execute(text("SELECT 1"))
        return {"database": "connected", "result": result.scalar()}
    finally:
        db.close()