from app import db
import uuid
from datetime import datetime

class Session(db.Model):
    __tablename__ = "sessions"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    cohort_id = db.Column(db.String(36), db.ForeignKey("cohorts.id"), nullable=False)
    coordinator_id = db.Column(db.String(36), db.ForeignKey("coordinators.id"), nullable=False)
    title = db.Column(db.String(100), nullable=False)
    started_at = db.Column(db.DateTime, default=datetime.utcnow)
    ended_at = db.Column(db.DateTime, nullable=True)
    checkin_open = db.Column(db.Boolean, default=False)
    checkout_open = db.Column(db.Boolean, default=False)

    attendance_records = db.relationship("AttendanceRecord", backref="session", lazy=True)


class AttendanceRecord(db.Model):
    __tablename__ = "attendance_records"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    session_id = db.Column(db.String(36), db.ForeignKey("sessions.id"), nullable=False)
    learner_id = db.Column(db.String(36), db.ForeignKey("learners.id"), nullable=False)
    checked_in_at = db.Column(db.DateTime, nullable=True)
    checked_out_at = db.Column(db.DateTime, nullable=True)
    verification_method = db.Column(db.String(20), nullable=False)
    is_complete = db.Column(db.Boolean, default=False)