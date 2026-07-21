# Run this from the backend folder to quickly create test data
# Usage: python quick_setup.py
# Note: Uses PostgreSQL (per .env) instead of SQLite. Make sure PostgreSQL is running.

import sys
sys.path.insert(0, '.')

from app import create_app
from app import db
from app.models import Hub, Cohort, Coordinator, Learner
from datetime import datetime

app = create_app()

with app.app_context():
    # Create a hub if none exists
    hub = Hub.query.first()
    if not hub:
        hub = Hub(name="SEG Test Hub", location="Accra")
        db.session.add(hub)
        db.session.commit()
        print(f"Created Hub: {hub.id}")

    # Create a cohort if none exists
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
        print(f"Cohort UUID to copy: {cohort.id}")
    else:
        print(f"Cohort already exists: {cohort.id}")

    # Create a test coordinator linked to this hub
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
        print(f"Coordinator already exists: {coord.id}")

    print("\nDone! Copy the Cohort UUID above and paste it into the mobile app.")
