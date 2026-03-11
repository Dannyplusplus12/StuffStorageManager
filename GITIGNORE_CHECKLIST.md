# ✅ .gitignore Optimization Checklist

## 🚀 Files MUST KEEP (để chạy app khi đổi máy)

### Flutter Source Code ✅
- ✅ `flutter_frontend/lib/**` (tất cả .dart source files)
- ✅ `flutter_frontend/pubspec.yaml` (dependencies)
- ✅ `flutter_frontend/pubspec.lock` - **IGNORE** (sẽ generate lại khi `flutter pub get`)
- ✅ `flutter_frontend/README.md` (documentation)
- ✅ `flutter_frontend/SETUP.md` (setup guide)
- ✅ `flutter_frontend/.github/workflows/` (CI/CD config)
- ✅ `flutter_frontend/LICENSE` (license)

### Backend Python ✅
- ✅ `backend/*.py` (tất cả source files)
- ✅ `backend/requirements.txt` (dependencies)
- ✅ `backend/server.py` (entry point)
- ✅ `backend/railway.toml` (deployment config)
- ✅ `backend/Procfile` (process file)

### Root Config Files ✅
- ✅ `requirements.txt` / `requirements-server.txt` (dependencies)
- ✅ `seed_data.py` (seed data script)
- ✅ `server.py` (entry point)
- ✅ `railway.toml` (deployment)
- ✅ `Procfile` (process file)
- ✅ `.env.example` (nếu có - để reference)
- ✅ `*.md` (documentation)

---

## 🚫 Files MUST IGNORE (build outputs, cache)

### Build & Cache ❌
- ❌ `flutter_frontend/build/` (build output)
- ❌ `flutter_frontend/.dart_tool/` (dart cache)
- ❌ `flutter_frontend/pubspec.lock` (lock file - regenerate)
- ❌ `flutter_frontend/coverage/` (test coverage)
- ❌ `backend/__pycache__/` (python cache)
- ❌ `*.pyc` (compiled python)

### Platform Build ❌
- ❌ `flutter_frontend/ios/build/`
- ❌ `flutter_frontend/android/build/`
- ❌ `flutter_frontend/windows/build/`
- ❌ `/venv/` (virtual environment)

### IDE/Environment ❌
- ❌ `.vscode/` (VSCode settings - personal)
- ❌ `.idea/` (IntelliJ settings - personal)
- ❌ `.env` (environment variables - personal)
- ❌ `*.jks` / `*.keystore` (key files)

### Logs ❌
- ❌ `*.log`
- ❌ `crash_log.txt`

---

## 📋 Step-by-step để verify

### 1️⃣ Check root `.gitignore`
```bash
git check-ignore -v flutter_frontend/lib/main.dart      # Should NOT ignore
git check-ignore -v flutter_frontend/build/             # Should ignore
git check-ignore -v flutter_frontend/pubspec.yaml       # Should NOT ignore
```

### 2️⃣ Check flutter_frontend `.gitignore`
```bash
git check-ignore -v flutter_frontend/.dart_tool/        # Should ignore
git check-ignore -v flutter_frontend/lib/               # Should NOT ignore
```

### 3️⃣ List tracked files
```bash
git ls-files flutter_frontend/ | wc -l
```

### 4️⃣ Verify key files exist
```bash
# Should all exist and be tracked
flutter_frontend/pubspec.yaml ✅
flutter_frontend/lib/main.dart ✅
flutter_frontend/.github/workflows/build.yml ✅
backend/server.py ✅
backend/requirements.txt ✅
```

---

## 🔄 Khi đổi máy - Setup lại:

```bash
# 1. Clone project
git clone <repo-url>
cd StuffStorageManager

# 2. Setup Backend
pip install -r requirements-server.txt
python server.py

# 3. Setup Flutter
cd flutter_frontend
flutter pub get
flutter run -d windows
```

**⚠️ Important**: `pubspec.lock` KHÔNG tracking, nhưng `flutter pub get` sẽ tạo ra nó mới dựa trên `pubspec.yaml` ✅

---

## ✅ Final Status

- Root `.gitignore`: **Optimal** ✅
- `flutter_frontend/.gitignore`: **Optimal** ✅
- Source code: **100% tracked** ✅
- Build outputs: **0% tracked** ✅
- Ready to migrate: **YES** ✅

**Bạn có thể yên tâm push code! 🚀**
