from flask import Blueprint, render_template, request, redirect, url_for
from flask_jwt_extended import decode_token, get_jwt_identity
from app.models import Session, Cohort, Learner, AttendanceRecord
from app import db

dashboard_bp = Blueprint("dashboard", __name__)

@dashboard_bp.route("/dashboard")
def dashboard():
    # Phase 2 restructuring: use Authorization header instead of URL token
    auth_header = request.headers.get("Authorization", "")
    token = None
    if auth_header.startswith("Bearer "):
        token = auth_header[7:]
    session_id = request.args.get("session_id")

    if not token or not session_id:
        return redirect(url_for("dashboard.login"))

    try:
        decoded = decode_token(token)
        coordinator_id = decoded["sub"]
    except Exception:
        return redirect(url_for("dashboard.login"))

    session = Session.query.filter_by(id=session_id).first()
    if not session or session.ended_at:
        return "Session not found or already ended.", 404

    cohort = Cohort.query.filter_by(id=session.cohort_id).first()

    records = AttendanceRecord.query.filter_by(session_id=session_id).all()
    attendance = []
    for r in records:
        learner = Learner.query.filter_by(id=r.learner_id).first()
        attendance.append({
            "seg_id": learner.seg_id,
            "full_name": learner.full_name,
            "checked_in_at": r.checked_in_at.strftime("%H:%M:%S") if r.checked_in_at else "--",
            "checked_out_at": r.checked_out_at.strftime("%H:%M:%S") if r.checked_out_at else "--",
            "is_complete": r.is_complete,
            "verification_method": r.verification_method
        })

    return render_template(
        "dashboard.html",
        session_id=session_id,
        session_title=session.title,
        cohort_name=cohort.name,
        token=token,
        attendance=attendance,
        total=len(attendance),
        checkin_open=session.checkin_open,
        checkout_open=session.checkout_open
    )


@dashboard_bp.route("/dashboard/login")
def login():
    return render_template("login.html")