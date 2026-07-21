#!/usr/bin/env python3
"""Simple API test script — replaces Thunder Client.
Usage: python test_api.py [login | cohorts | register_learner | quick_setup]
Requires: requests (pip install requests)
"""
import sys
import os
sys.path.insert(0, '.')

from app import create_app
from app import db
from app.models import Hub, Cohort, Coordinator
from datetime import datetime

BASE = "http://localhost:5000"

def quick_setup():
    print("=== Quick Setup (creates Hub + Cohort + Coordinator) ===")
    app = create_app()
    with app.app_context():
        hub = Hub.query.first()
        if not hub:
            hub = Hub(name="SEG Test Hub", location="Accra")
            db.session.add(hub)
            db.session.commit()
            print(f"Created Hub: {hub.id}")
        else:
            print(f"Hub exists: {hub.id}")

        cohort = Cohort.query.first()
        if not cohort:
            cohort = Cohort(
                name="Tech Cohort",
                hub_id=hub.id,
                start_date=datetime(2026, 7, 1),
                end_date=datetime(2026, 12, 31),
                min_attendance_percent=80
            )
            db.session.add(cohort)
            db.session.commit()
            print(f"Created Cohort: {cohort.id} (name: {cohort.name})")
        else:
            print(f"Cohort exists: {cohort.id}")

        coord = Coordinator.query.filter_by(full_name="Test Coordinator").first()
        if not coord:
            from werkzeug.security import generate_password_hash
            coord = Coordinator(
                full_name="Test Coordinator",
                phone="0240000000",
                password_hash=generate_password_hash("password123"),
                hub_id=hub.id
            )
            db.session.add(coord)
            db.session.commit()
            print(f"Created Coordinator: {coord.id}")
        else:
            print(f"Coordinator exists: {coord.id}")

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python test_api.py quick_setup")
    else:
        cmd = sys.argv[1]
        if cmd == "quick_setup":
            quick_setup()
        else:
            print(f"Unknown command: {cmd}")
