# SEG Attendance — Unified Project

This workspace contains both halves of the SEG attendance system, merged for review and repair.

```
seg-attendance-project/
├── backend/        # Flask API + web dashboard
│   ├── .env.example
│   ├── requirements.txt  (fixed — was binary/corrupt)
│   └── ...
├── mobile/         # Flutter coordinator app
│   ├── lib/
│   └── ...
└── ANALYSIS_REPORT.md
```

## Critical fixes already applied
- `backend/requirements.txt` reconstructed (was unreadable binary).
- `mobile/lib/services/auth_service.dart` endpoint URLs fixed (`/auth/coordinator/login`, `/auth/coordinator/register`) and response keys corrected (`coordinator_id` instead of `user_id`).
- Added `.env.example` for backend secrets.

## See full analysis
Open `ANALYSIS_REPORT.md` for all mishaps, explanations of why the repos were split, how they connect, and recommendations.
