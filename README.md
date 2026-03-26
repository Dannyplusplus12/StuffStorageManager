# StuffStorageManager

Central repo for StuffStorageManager — inventory, POS, orders and debt management.

This repository contains:

- `flutter_frontend/` — Flutter app (mobile + desktop runtime). This is the primary client used today.
- `backend/` — FastAPI backend (development code). Includes database models and API endpoints.
- `server-repo/` — Deployment copy for Railway (production-ready `api.py`, `server.py`, `requirements.txt`, `Procfile`, `railway.toml`).

What changed

- The old Python desktop GUI (PyQt6) has been removed from the main source tree. The project is now focused on the Flutter frontend + FastAPI backend.
  - Legacy PyQt6 frontend was removed from repository and related launcher scripts deleted. Excel import/processing scripts retained under `backend/excel_tasks/`.
- Excel import / processing scripts have been kept and moved to `backend/excel_tasks/`. Any Excel data files used for those scripts should be placed alongside them in that folder.

Quick start (backend)

1. Create a virtual environment and install backend dependencies:

```powershell
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r backend/requirements.txt
```

2. Run the FastAPI app (development):

```powershell
cd backend
uvicorn api:app --reload --port 8000
```

3. Excel import tasks

- Place Excel files used by the import scripts into `backend/excel_tasks/data/`.
- Example scripts are:
  - `backend/excel_tasks/read_data.py` — imports `BÁN HÀNG.xlsx` and `result.xlsx` into a local `shop.db` for testing.
  - `backend/excel_tasks/modify_data.py` — processes vendor debt Excel files and emits `result.xlsx`.
  - `backend/excel_tasks/seed_data.py` — generates sample DB content.

Run them from the repository root or from the `backend/excel_tasks` folder with the virtual environment active.

Quick start (Flutter frontend)

1. Install Flutter SDK and tools (see `flutter_frontend/README.md`).
2. From `flutter_frontend/` run:

```bash
flutter pub get
flutter run
```

Cleaning & notes

- The PyQt6 desktop code and related launcher scripts were removed to simplify the repository. If you need the legacy desktop experience keep a copy before this change.
- `backend/requirements.txt` now includes the libraries required by the Excel processing scripts (pandas, openpyxl).
- Ensure `backend/requirements.txt` contains `pandas` and `openpyxl` for Excel tasks. If missing, add them before running import scripts.

If you want me to open a PR that removes the legacy files and moves the Excel scripts physically in the repo, I can do that and update any CI workflows accordingly.
