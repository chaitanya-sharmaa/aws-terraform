from sqlalchemy import Column, Integer, String, Text, DateTime
from database import Base
import datetime

class ContactSubmissionDB(Base):
    __tablename__ = "contact_submissions"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    email = Column(String(255), nullable=False)
    message = Column(Text, nullable=False)
    submitted_at = Column(DateTime, default=datetime.datetime.utcnow)
