from fastapi import FastAPI, Request, Depends, HTTPException
from pydantic import BaseModel
from sqlalchemy.orm import Session
import logging
import os

from database import engine, Base, get_db
from models import ContactSubmissionDB

# Initialize DB tables
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Acme Corp API", root_path="/api")

# Configure basic logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

class ContactSubmission(BaseModel):
    name: str
    email: str
    message: str

@app.get("/health")
async def health_check():
    """Simple health check endpoint"""
    return {"status": "healthy", "service": "static-app-backend"}

@app.get("/info")
async def get_info():
    """Returns application environment info"""
    return {
        "version": "1.0.0",
        "environment": os.getenv("ENVIRONMENT", "development")
    }

@app.post("/contact")
async def submit_contact(submission: ContactSubmission, db: Session = Depends(get_db)):
    """Handles contact form submissions and saves them to PostgreSQL"""
    try:
        new_submission = ContactSubmissionDB(
            name=submission.name,
            email=submission.email,
            message=submission.message
        )
        db.add(new_submission)
        db.commit()
        db.refresh(new_submission)
        logger.info(f"Saved contact submission to DB: ID={new_submission.id}, Name={submission.name}")
        return {"status": "success", "message": "Contact submission received and saved securely"}
    except Exception as e:
        db.rollback()
        logger.error(f"Failed to save submission: {str(e)}")
        raise HTTPException(status_code=500, detail="Failed to save submission to database")
