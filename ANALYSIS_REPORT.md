# SEG Attendance Project — Merged & Analyzed

## Why they were split
Both repositories (`seg-attendance-flask` and `seg-attendance-app`) are halves of one full-stack attendance system for Social Enterprise Ghana (SEG). They were separated likely because:
- **Flask repo** (`seg-attendance-flask`) = backend API + web dashboard
- **Flutter repo** (`seg-attendance-app`) = mobile coordinator app

There is no technical reason they must stay split; they share the same domain (cohorts, learners, NFC, fingerprint, attendance, certification).

## Merged structure
```
seg-attendance-project/
├── backend/          # Python Flask API
│   ├── app/
│   ├── requirements.txt   (reconstructed — original was binary/corrupt)
│   └── run.py
├── mobile/           # Flutter coordinator app
│   ├── lib/
│   ├── pubspec.yaml
│   └── android/, ios/, windows/, macos/, linux/, web/
└── ANALYSIS_REPORT.md  (this file)
```

---

## Critical Mishaps Found

### 1. Backend: `requirements.txt` was binary/corrupted
**Severity:** CRITICAL  
The file `flask_repo/requirements.txt` was encoded as binary/gibberish instead of plain text. No one could install dependencies from it.  
**Fix:** Reconstructed from source imports (`Flask`, `Flask-SQLAlchemy`, `Flask-JWT-Extended`, `python-dotenv`, `Werkzeug`).

---

### 2. App: Endpoint mismatches against backend
**Severity:** CRITICAL  
The mobile app (`auth_service.dart`) called endpoints that do not exist on the Flask backend:

| App called | Flask actually provides | Status before fix |
|---|---|---|
| `/auth/register` | `/api/auth/coordinator/register` | Broken |
| `/auth/login` | `/api/auth/coordinator/login` | Broken |
| `/auth/learner/register` | `/api/auth/learner/register` | Broken (missing `/coordinator` for login, but learner endpoint is correct) |

Additionally, the response key was wrong:
- App expected `user_id`; Flask returns `coordinator_id`.
**Fix:** Updated `auth_service.dart` to use the correct paths and keys.

---

### 3. App: `baseUrl` hardcoded to a public ngrok tunnel
**Severity:** HIGH  
`lib/services/api_service.dart` has:
```dart
static const String baseUrl = 'https://vice-reoccupy-rebuilt.ngrok-free.dev/api';
```
This is a temporary/ngrok URL. It can expire or expose production traffic to an unknown tunnel endpoint.  
**Fix needed:** Replace with a configurable environment variable or build-time config (`.env` or `--dart-define`).

---

### 4. Backend: JWT token passed in URL query string (`?token=...`)
**Severity:** HIGH  
`dashboard.html` and `dashboard.py` expect authentication via URL parameter:
```python
token = request.args.get("token")
```
This leaks tokens into:
- Browser history
- Server access logs
- Referrer headers
- Proxy logs
**Fix needed:** Use `HttpOnly` cookies or `Authorization: Bearer` headers exclusively.

---

### 5. Backend: No input authorization checks on session routes
**Severity:** MEDIUM  
In `routes/sessions.py`, endpoints like `/start`, `/checkin/open/<session_id>`, `/end/<session_id>` verify `@jwt_required()` but do **not** verify that the authenticated coordinator owns the cohort/hub being modified. Any coordinator with a valid JWT could start/end/checkin for any cohort.  
**Fix needed:** Add `coordinator = Coordinator.query.filter_by(id=get_jwt_identity()).first()` and validate `coordinator.hub_id == cohort.hub_id`.

---

### 6. Backend: `generate_seg_id()` can create duplicates
**Severity:** MEDIUM  
In `routes/auth.py`:
```python
def generate_seg_id(cohort):
    code = cohort.name[:3].upper()
    count = Learner.query.filter_by(cohort_id=cohort.id).count() + 1
    return f"SEG-{code}-{str(count).zfill(4)}"
```
- If cohort name changes, the prefix changes, but old IDs remain.
- If learners are deleted, `count` decreases and can reuse IDs.
- No database-level `UNIQUE` constraint on `seg_id` is visible (though `unique=True` is set in model).
**Fix needed:** Use UUID-based or sequential ID with a separate sequence table, or enforce strict uniqueness checks before insert.

---

### 7. Backend: `run.py` runs with `debug=True` and `host='0.0.0.0'`
**Severity:** MEDIUM  
```python
app.run(debug=True, host='0.0.0.0')
```
`debug=True` enables the interactive Werkzeug debugger (remote code execution if accessed by an attacker). `host='0.0.0.0'` exposes to all interfaces without a production server (gunicorn/uwsgi).  
**Fix needed:** Use `gunicorn` or similar for production; disable `debug`.

---

### 8. Backend: No `.env` or `.env.example` file
**Severity:** LOW-MEDIUM  
`load_dotenv()` is called but no `.env` exists. `DATABASE_URL` and `JWT_SECRET_KEY` will be `None`, causing crashes or insecure defaults.  
**Fix needed:** Add `.env.example` and instruct users to create `.env`.

---

### 9. App: `nfc_service.dart` imports internal `pigeon.g.dart`
**Severity:** MEDIUM  
```dart
import 'package:nfc_manager/src/nfc_manager_android/pigeon.g.dart';
```
This accesses a package-internal file. If `nfc_manager` updates its internal structure, the import breaks.  
**Fix needed:** Use only public API surfaces from the package.

---

### 10. App: `register_learner_screen.dart` requires `cohort_id` as free text
**Severity:** LOW  
The user must type a cohort UUID manually into a `TextField` (`_cohortIdController`). There is no cohort picker/dropdown (unlike `cohort_screen.dart`). This is error-prone.  
**Fix needed:** Reuse `_loadCohorts()` logic from `CohortScreen` to provide a dropdown.

---

### 11. App / Backend: No rate limiting
**Severity:** LOW  
Both mobile and backend have no rate limits on login, register, or session actions. Brute-force attacks on `coordinator/login` are possible.  
**Fix needed:** Add Flask-Limiter and app-level retry limits.

---

### 12. Backend: `.gitignorecls` file (typo?)
**Severity:** LOW  
There is a file named `.gitignorecls` alongside `.gitignore`. It may be a typo or leftover from an editor. It does not affect runtime but creates confusion.

---

### 13. App: `auth_service.dart` saves `segId: ''` for coordinator login
**Severity:** LOW  
The coordinator login flow saves an empty `segId`. This is fine for coordinators, but the storage key is shared. If the app is later used by learners, this could cause confusion. It is not a bug per se, but the schema mixing (`user_id` vs `coordinator_id`) is fragile.

---

### 14. App: `attendance_screen.dart` fingerprint flow shows learner selector without checking session state properly
**Severity:** LOW  
`_fingerprintScan()` allows fingerprint authentication but then opens `_LearnerSelectorDialog`. If a learner taps fingerprint for check-in/check-out, the system already knows the learner via fingerprint? Actually the current flow requires the user to manually select a learner after fingerprint success. This is a UX issue: if fingerprint is meant to identify the learner uniquely, the selector should be skipped. However, the backend requires `learner_id`, not fingerprint data.  
**Note:** This is a design choice, not necessarily a bug, but it makes the fingerprint feature less useful.

---

### 15. Backend: `dashboard.html` JavaScript uses unescaped variables
**Severity:** LOW  
Template variables (`{{ session_id }}`, `{{ token }}`) are embedded directly into JavaScript without escaping. If a session title or token contains malicious quotes, XSS is possible.  
**Fix needed:** Use `tojson` filter or ensure JSON-safe escaping.

---

## How the two halves work together

```
Mobile App (Flutter)
  │ login / register → POST /api/auth/coordinator/login
  │ cohort list → GET /api/sessions/cohorts
  │ start session → POST /api/sessions/start
  │ check-in (NFC / fingerprint) → POST /api/sessions/checkin
  │ check-out → POST /api/sessions/checkout
  │ end session → PATCH /api/sessions/end/<id>
  │ attendance view → GET /api/sessions/attendance/<id>
  │ NFC lookup → GET /api/sessions/nfc/lookup/<uid>
  │ learner register → POST /api/auth/learner/register
  │ NFC assign → POST /api/sessions/nfc/assign

Web Dashboard (Flask templates)
  │ /dashboard?token=<jwt>&session_id=<id>
  │ Reads session + attendance records
  │ Allows opening/closing check-in/check-out and ending session
```

---

## Recommendations for the merged project

1. **Environment & Config:**
   - Create `.env.example` in `backend/`.
   - Make `baseUrl` configurable in `mobile/lib/services/api_service.dart` (e.g., via `--dart-define`).

2. **Security:**
   - Remove `token` from URL params in dashboard; use `HttpOnly` cookies.
   - Add `coordinator.hub_id` checks to all session/route endpoints.
   - Disable Flask `debug` mode; deploy behind `gunicorn` + `nginx`.
   - Add `Flask-Limiter` for brute-force protection.

3. **Data Integrity:**
   - Strengthen `generate_seg_id()` logic or switch to UUID-based IDs with a display label.
   - Ensure `seg_id` has DB-level `UNIQUE` constraint (it does in model, but verify migration).

4. **App Fixes:**
   - Update all endpoint URLs in mobile services to match backend exactly.
   - Replace hardcoded `baseUrl`.
   - Fix `nfc_service.dart` import of internal package file.
   - Improve `register_learner_screen.dart` with a cohort picker dropdown.
   - Make fingerprint flow identify the learner without requiring a manual dropdown (if fingerprint enrollment is linked to `learner_id` in DB).

5. **Code Quality:**
   - Remove `.gitignorecls` typo file.
   - Add migrations (`Flask-Migrate`) instead of `db.create_all()` on startup.
   - Add basic tests for both backend routes and mobile providers.

---

## Files changed / reconstructed in this merge

| File / Path | Action | Reason |
|---|---|---|
| `backend/requirements.txt` | Rewritten from scratch | Original was binary/corrupt |
| `mobile/lib/services/auth_service.dart` | Edited endpoints & response keys | Mismatched Flask routes |
| `seg-attendance-project/` | Created root folder | Unified workspace |

---

## Quick start (after fixing `.env`)

```bash
# Backend
cd backend
python -m venv venv
source venv/bin/activate  # or venv\Scripts\activate on Windows
pip install -r requirements.txt
# Create .env with DATABASE_URL and JWT_SECRET_KEY
python run.py

# Mobile (Flutter)
cd mobile
flutter pub get
flutter run
```

---

*Report generated: 2026-07-21*  
*Analyzed by Arena Agent Mode*
