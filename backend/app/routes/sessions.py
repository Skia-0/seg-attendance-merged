from flask import Blueprint, request, jsonify
from flask_jwt_extended import jwt_required, get_jwt_identity
from datetime import datetime
from app import db
from app.models import Cohort, Learner, NFCCard, Coordinator, Session, AttendanceRecord

sessions_bp = Blueprint("sessions", __name__)


@sessions_bp.route("/cohorts", methods=["GET"])
@jwt_required()
def get_cohorts():
    coordinator_id = get_jwt_identity()
    coordinator = Coordinator.query.filter_by(id=coordinator_id).first()
    cohorts = Cohort.query.filter_by(hub_id=coordinator.hub_id).all()
    return jsonify({
        "cohorts": [
            {
                "cohort_id": c.id,
                "name": c.name,
                "start_date": c.start_date.isoformat(),
                "end_date": c.end_date.isoformat(),
                "min_attendance_percent": c.min_attendance_percent
            }
            for c in cohorts
        ]
    }), 200


@sessions_bp.route("/cohort/create", methods=["POST"])
@jwt_required()
def create_cohort():
    data = request.get_json()
    required = ["name", "start_date", "end_date", "hub_id"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400
    cohort = Cohort(
        name=data["name"],
        hub_id=data["hub_id"],
        start_date=datetime.fromisoformat(data["start_date"]),
        end_date=datetime.fromisoformat(data["end_date"]),
        min_attendance_percent=data.get("min_attendance_percent", 80)
    )
    db.session.add(cohort)
    db.session.commit()
    return jsonify({
        "message": "Cohort created",
        "cohort_id": cohort.id,
        "name": cohort.name
    }), 201


@sessions_bp.route("/cohort/<cohort_id>", methods=["GET"])
@jwt_required()
def get_cohort(cohort_id):
    cohort = Cohort.query.filter_by(id=cohort_id).first()
    if not cohort:
        return jsonify({"error": "Cohort not found"}), 404
    learners = Learner.query.filter_by(cohort_id=cohort_id).all()
    return jsonify({
        "cohort_id": cohort.id,
        "name": cohort.name,
        "start_date": cohort.start_date.isoformat(),
        "end_date": cohort.end_date.isoformat(),
        "min_attendance_percent": cohort.min_attendance_percent,
        "total_learners": len(learners)
    }), 200


@sessions_bp.route("/cohort/<cohort_id>/learners", methods=["GET"])
@jwt_required()
def get_cohort_learners(cohort_id):
    cohort = Cohort.query.filter_by(id=cohort_id).first()
    if not cohort:
        return jsonify({"error": "Cohort not found"}), 404
    learners = Learner.query.filter_by(cohort_id=cohort_id).all()
    return jsonify({
        "cohort_id": cohort_id,
        "learners": [
            {
                "learner_id": l.id,
                "seg_id": l.seg_id,
                "full_name": l.full_name,
            }
            for l in learners
        ]
    }), 200


@sessions_bp.route("/cohort/attendance/<cohort_id>", methods=["GET"])
@jwt_required()
def cohort_attendance_summary(cohort_id):
    cohort = Cohort.query.filter_by(id=cohort_id).first()
    if not cohort:
        return jsonify({"error": "Cohort not found"}), 404
    total_sessions = Session.query.filter_by(
        cohort_id=cohort_id
    ).filter(Session.ended_at.isnot(None)).count()
    learners = Learner.query.filter_by(cohort_id=cohort_id).all()
    summary = []
    for learner in learners:
        completed = AttendanceRecord.query.join(Session).filter(
            Session.cohort_id == cohort_id,
            AttendanceRecord.learner_id == learner.id,
            AttendanceRecord.is_complete == True
        ).count()
        percentage = round((completed / total_sessions * 100), 1) if total_sessions > 0 else 0
        qualifies = percentage >= cohort.min_attendance_percent
        summary.append({
            "seg_id": learner.seg_id,
            "full_name": learner.full_name,
            "sessions_attended": completed,
            "total_sessions": total_sessions,
            "attendance_percentage": percentage,
            "qualifies_for_certification": qualifies
        })
    return jsonify({
        "cohort": cohort.name,
        "total_sessions": total_sessions,
        "min_attendance_percent": cohort.min_attendance_percent,
        "learners": summary
    }), 200


@sessions_bp.route("/start", methods=["POST"])
@jwt_required()
def start_session():
    data = request.get_json()
    required = ["cohort_id", "title"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400
    cohort = Cohort.query.filter_by(id=data["cohort_id"]).first()
    if not cohort:
        return jsonify({"error": "Cohort not found"}), 404
    existing = Session.query.filter_by(
        cohort_id=data["cohort_id"], ended_at=None
    ).first()
    if existing:
        return jsonify({"error": "A session is already active for this cohort"}), 409
    coordinator_id = get_jwt_identity()
    session = Session(
        cohort_id=data["cohort_id"],
        coordinator_id=coordinator_id,
        title=data["title"],
        checkin_open=False,
        checkout_open=False
    )
    db.session.add(session)
    db.session.commit()
    return jsonify({
        "message": "Session created",
        "session_id": session.id,
        "title": session.title
    }), 201


@sessions_bp.route("/checkin/open/<session_id>", methods=["PATCH"])
@jwt_required()
def open_checkin(session_id):
    session = Session.query.filter_by(id=session_id).first()
    if not session or session.ended_at:
        return jsonify({"error": "Session not found or already ended"}), 404
    session.checkin_open = True
    session.checkout_open = False
    db.session.commit()
    return jsonify({"message": "Check-in is now open"}), 200


@sessions_bp.route("/checkout/open/<session_id>", methods=["PATCH"])
@jwt_required()
def open_checkout(session_id):
    session = Session.query.filter_by(id=session_id).first()
    if not session or session.ended_at:
        return jsonify({"error": "Session not found or already ended"}), 404
    session.checkin_open = False
    session.checkout_open = True
    db.session.commit()
    return jsonify({"message": "Check-out is now open"}), 200


@sessions_bp.route("/checkin", methods=["POST"])
@jwt_required()
def checkin():
    data = request.get_json()
    required = ["session_id", "learner_id", "verification_method"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400
    session = Session.query.filter_by(id=data["session_id"]).first()
    if not session or session.ended_at:
        return jsonify({"error": "Session not found or already ended"}), 404
    if not session.checkin_open:
        return jsonify({"error": "Check-in is not open for this session"}), 403
    learner = Learner.query.filter_by(id=data["learner_id"]).first()
    if not learner:
        return jsonify({"error": "Learner not found"}), 404
    duplicate = AttendanceRecord.query.filter_by(
        session_id=data["session_id"],
        learner_id=data["learner_id"]
    ).first()
    if duplicate:
        return jsonify({"error": "Learner already checked in"}), 409
    record = AttendanceRecord(
        session_id=data["session_id"],
        learner_id=data["learner_id"],
        checked_in_at=datetime.utcnow(),
        verification_method=data["verification_method"],
        is_complete=False
    )
    db.session.add(record)
    db.session.commit()
    return jsonify({
        "message": "Check-in successful",
        "checked_in_at": record.checked_in_at.isoformat(),
        "seg_id": learner.seg_id
    }), 200


@sessions_bp.route("/checkout", methods=["POST"])
@jwt_required()
def checkout():
    data = request.get_json()
    required = ["session_id", "learner_id"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400
    session = Session.query.filter_by(id=data["session_id"]).first()
    if not session or session.ended_at:
        return jsonify({"error": "Session not found or already ended"}), 404
    if not session.checkout_open:
        return jsonify({"error": "Check-out is not open for this session"}), 403
    record = AttendanceRecord.query.filter_by(
        session_id=data["session_id"],
        learner_id=data["learner_id"]
    ).first()
    if not record:
        return jsonify({"error": "No check-in record found for this learner"}), 404
    if record.checked_out_at:
        return jsonify({"error": "Learner already checked out"}), 409
    record.checked_out_at = datetime.utcnow()
    record.is_complete = True
    db.session.commit()
    learner = Learner.query.filter_by(id=data["learner_id"]).first()
    return jsonify({
        "message": "Check-out successful",
        "checked_out_at": record.checked_out_at.isoformat(),
        "seg_id": learner.seg_id
    }), 200


@sessions_bp.route("/end/<session_id>", methods=["PATCH"])
@jwt_required()
def end_session(session_id):
    session = Session.query.filter_by(id=session_id).first()
    if not session or session.ended_at:
        return jsonify({"error": "Session not found or already ended"}), 404
    session.ended_at = datetime.utcnow()
    session.checkin_open = False
    session.checkout_open = False
    db.session.commit()
    total = AttendanceRecord.query.filter_by(session_id=session_id).count()
    complete = AttendanceRecord.query.filter_by(
        session_id=session_id, is_complete=True
    ).count()
    return jsonify({
        "message": "Session ended",
        "total_checked_in": total,
        "total_completed": complete
    }), 200


@sessions_bp.route("/attendance/<session_id>", methods=["GET"])
@jwt_required()
def get_attendance(session_id):
    session = Session.query.filter_by(id=session_id).first()
    if not session:
        return jsonify({"error": "Session not found"}), 404
    records = AttendanceRecord.query.filter_by(session_id=session_id).all()
    attendance = []
    for r in records:
        learner = Learner.query.filter_by(id=r.learner_id).first()
        attendance.append({
            "seg_id": learner.seg_id,
            "full_name": learner.full_name,
            "checked_in_at": r.checked_in_at.isoformat() if r.checked_in_at else None,
            "checked_out_at": r.checked_out_at.isoformat() if r.checked_out_at else None,
            "verification_method": r.verification_method,
            "is_complete": r.is_complete
        })
    return jsonify({
        "session_id": session_id,
        "title": session.title,
        "total": len(attendance),
        "attendance": attendance
    }), 200


@sessions_bp.route("/cohort/<cohort_id>/clear-cards", methods=["PATCH"])
@jwt_required()
def clear_nfc_cards(cohort_id):
    """Phase 2 restructuring: return cards to pool at cohort end"""
    cards = NFCCard.query.filter_by(cohort_id=cohort_id, is_active=True).all()
    for card in cards:
        card.learner_id = None
        card.assigned_at = None
        card.is_active = False
    db.session.commit()
    return jsonify({"message": f"{len(cards)} cards returned to pool"}), 200


@sessions_bp.route("/cohort/<cohort_id>/certify", methods=["GET"])
@jwt_required()
def certify_cohort(cohort_id):
    """Phase 2 restructuring: certification endpoint based on attendance %"""
    cohort = Cohort.query.filter_by(id=cohort_id).first()
    if not cohort:
        return jsonify({"error": "Cohort not found"}), 404
    total_sessions = Session.query.filter_by(
        cohort_id=cohort_id
    ).filter(Session.ended_at.isnot(None)).count()
    learners = Learner.query.filter_by(cohort_id=cohort_id).all()
    certified = []
    for learner in learners:
        completed = AttendanceRecord.query.join(Session).filter(
            Session.cohort_id == cohort_id,
            AttendanceRecord.learner_id == learner.id,
            AttendanceRecord.is_complete == True
        ).count()
        percentage = round((completed / total_sessions * 100), 1) if total_sessions > 0 else 0
        qualifies = percentage >= cohort.min_attendance_percent
        if qualifies:
            certified.append({
                "seg_id": learner.seg_id,
                "full_name": learner.full_name,
                "attendance_percentage": percentage,
                "status": "certified"
            })
    return jsonify({
        "cohort_id": cohort_id,
        "cohort_name": cohort.name,
        "min_attendance_percent": cohort.min_attendance_percent,
        "total_learners": len(learners),
        "certified_learners": len(certified),
        "certified": certified
    }), 200


@sessions_bp.route("/nfc/assign", methods=["POST"])
@jwt_required()
def assign_nfc():
    data = request.get_json()
    required = ["nfc_uid", "learner_id", "cohort_id"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400
    existing = NFCCard.query.filter_by(uid=data["nfc_uid"]).first()
    if existing and existing.learner_id:
        return jsonify({"error": "Card already assigned to a learner"}), 409
    if existing:
        existing.learner_id = data["learner_id"]
        existing.cohort_id = data["cohort_id"]
        existing.assigned_at = datetime.utcnow()
        existing.is_active = True
    else:
        card = NFCCard(
            uid=data["nfc_uid"],
            learner_id=data["learner_id"],
            cohort_id=data["cohort_id"],
            assigned_at=datetime.utcnow()
        )
        db.session.add(card)
    learner = Learner.query.filter_by(id=data["learner_id"]).first()
    learner.nfc_uid = data["nfc_uid"]
    db.session.commit()
    return jsonify({"message": "NFC card assigned successfully"}), 200


@sessions_bp.route("/nfc/lookup/<nfc_uid>", methods=["GET"])
@jwt_required()
def lookup_nfc(nfc_uid):
    card = NFCCard.query.filter_by(uid=nfc_uid, is_active=True).first()
    if not card:
        return jsonify({"error": "Card not found or inactive"}), 404
    learner = Learner.query.filter_by(id=card.learner_id).first()
    return jsonify({
        "learner_id": learner.id,
        "seg_id": learner.seg_id,
        "full_name": learner.full_name,
        "cohort_id": card.cohort_id
    }), 200