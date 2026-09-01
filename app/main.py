from fastapi import FastAPI

app = FastAPI(title = "Ledger-Lens")

@app.get("/health")
def health_check():
    return {"status": "ok"}