from flask import Blueprint, request, jsonify
from werkzeug.security import generate_password_hash, check_password_hash
from flask_jwt_extended import create_access_token
from app import db
from app.models import Hub, Cohort, Learner, Coordinator

auth_bp = Blueprint("auth", __name__)

def generate_seg_id(cohort):
    code = cohort.name[:3].upper()
    count = Learner.query.filter_by(cohort_id=cohort.id).count() + 1
    return f"SEG-{code}-{str(count).zfill(4)}"


@auth_bp.route("/hub/create", methods=["POST"])
def create_hub():
    data = request.get_json()

    required = ["name", "location"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400

    hub = Hub(
        name=data["name"],
        location=data["location"],
        wifi_ssid=data.get("wifi_ssid", "")
    )
    db.session.add(hub)
    db.session.commit()

    return jsonify({
        "message": "Hub created",
        "hub_id": hub.id,
        "name": hub.name
    }), 201


@auth_bp.route("/hubs", methods=["GET"])
def get_hubs():
    hubs = Hub.query.all()
    return jsonify({
        "hubs": [
            {
                "hub_id": h.id,
                "name": h.name,
                "location": h.location
            }
            for h in hubs
        ]
    }), 200


@auth_bp.route("/coordinator/register", methods=["POST"])
def register_coordinator():
    data = request.get_json()

    required = ["full_name", "phone", "password", "hub_id"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400

    hub = Hub.query.filter_by(id=data["hub_id"]).first()
    if not hub:
        return jsonify({"error": "Hub not found"}), 404

    if Coordinator.query.filter_by(phone=data["phone"]).first():
        return jsonify({"error": "Phone number already registered"}), 409

    coordinator = Coordinator(
        full_name=data["full_name"],
        phone=data["phone"],
        password_hash=generate_password_hash(data["password"]),
        hub_id=hub.id
    )

    db.session.add(coordinator)
    db.session.commit()

    return jsonify({
        "message": "Coordinator registered successfully",
        "coordinator_id": coordinator.id
    }), 201


@auth_bp.route("/coordinator/login", methods=["POST"])
def login_coordinator():
    data = request.get_json()

    if not all(k in data for k in ["phone", "password"]):
        return jsonify({"error": "Phone and password required"}), 400

    coordinator = Coordinator.query.filter_by(phone=data["phone"]).first()

    if not coordinator or not check_password_hash(coordinator.password_hash, data["password"]):
        return jsonify({"error": "Invalid credentials"}), 401

    token = create_access_token(identity=coordinator.id)

    return jsonify({
        "access_token": token,
        "coordinator_id": coordinator.id,
        "full_name": coordinator.full_name,
        "hub_id": coordinator.hub_id
    }), 200


@auth_bp.route("/learner/register", methods=["POST"])
def register_learner():
    data = request.get_json()

    required = ["full_name", "cohort_id"]
    if not all(k in data for k in required):
        return jsonify({"error": "Missing required fields"}), 400

    cohort = Cohort.query.filter_by(id=data["cohort_id"]).first()
    if not cohort:
        return jsonify({"error": "Cohort not found"}), 404

    seg_id = generate_seg_id(cohort)

    learner = Learner(
        full_name=data["full_name"],
        phone=data.get("phone"),
        cohort_id=cohort.id,
        seg_id=seg_id,
        nfc_uid=data.get("nfc_uid"),
        fingerprint_enrolled=data.get("fingerprint_enrolled", False)
    )

    db.session.add(learner)
    db.session.commit()

    return jsonify({
        "message": "Learner registered successfully",
        "seg_id": seg_id,
        "learner_id": learner.id
    }), 201