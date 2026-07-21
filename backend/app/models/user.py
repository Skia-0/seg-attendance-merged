from app import db
import uuid
from datetime import datetime

class Hub(db.Model):
    __tablename__ = "hubs"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(100), nullable=False)
    location = db.Column(db.String(200))
    wifi_ssid = db.Column(db.String(100))
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    cohorts = db.relationship("Cohort", backref="hub", lazy=True)


class Cohort(db.Model):
    __tablename__ = "cohorts"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    name = db.Column(db.String(100), nullable=False)
    hub_id = db.Column(db.String(36), db.ForeignKey("hubs.id"), nullable=False)
    start_date = db.Column(db.DateTime, nullable=False)
    end_date = db.Column(db.DateTime, nullable=False)
    min_attendance_percent = db.Column(db.Integer, default=80)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    learners = db.relationship("Learner", backref="cohort", lazy=True)
    sessions = db.relationship("Session", backref="cohort", lazy=True)


class Learner(db.Model):
    __tablename__ = "learners"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    seg_id = db.Column(db.String(20), unique=True, nullable=False)
    full_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20))
    cohort_id = db.Column(db.String(36), db.ForeignKey("cohorts.id"), nullable=False)
    nfc_uid = db.Column(db.String(100), nullable=True)
    fingerprint_enrolled = db.Column(db.Boolean, default=False)
    registered_at = db.Column(db.DateTime, default=datetime.utcnow)

    attendance_records = db.relationship("AttendanceRecord", backref="learner", lazy=True)


class NFCCard(db.Model):
    __tablename__ = "nfc_cards"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    uid = db.Column(db.String(100), unique=True, nullable=False)
    learner_id = db.Column(db.String(36), db.ForeignKey("learners.id"), nullable=True)
    cohort_id = db.Column(db.String(36), db.ForeignKey("cohorts.id"), nullable=True)
    assigned_at = db.Column(db.DateTime, nullable=True)
    is_active = db.Column(db.Boolean, default=True)


class Coordinator(db.Model):
    __tablename__ = "coordinators"

    id = db.Column(db.String(36), primary_key=True, default=lambda: str(uuid.uuid4()))
    full_name = db.Column(db.String(100), nullable=False)
    phone = db.Column(db.String(20), unique=True, nullable=False)
    password_hash = db.Column(db.String(256), nullable=False)
    hub_id = db.Column(db.String(36), db.ForeignKey("hubs.id"), nullable=False)
    created_at = db.Column(db.DateTime, default=datetime.utcnow)

    sessions = db.relationship("Session", backref="coordinator", lazy=True)