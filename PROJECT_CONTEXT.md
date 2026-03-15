# PROJECT CONTEXT — StuffStorageManager
> **Mục đích file này:** Copy nội dung bên dưới và paste vào đầu cuộc hội thoại mới với AI để AI hiểu toàn bộ tình hình dự án, không cần giải thích lại.
> 
> **Cập nhật lần cuối:** Tháng 3/2026

---

## 1. TỔNG QUAN DỰ ÁN

**StuffStorageManager** — Hệ thống quản lý kho hàng, xuất hàng, công nợ khách hàng.

Hiện có 2 nhóm client:
- **Desktop app (chính)**: quản trị đầy đủ + duyệt hóa đơn nháp từ mobile staff
- **Flutter app (mobile child app)**: phân quyền VIEWER/STAFF bằng PIN nội bộ

### Kiến trúc: Client-Server tách biệt
```
┌─────────────────────┐         HTTPS         ┌──────────────────────────────┐
│  Frontend (.exe)    │ ◄──────────────────►   │  Backend (Railway Cloud)     │
│  PyQt6 Desktop App  │    REST API (JSON)     │  FastAPI + PostgreSQL        │
│  Máy người dùng     │                        │  Auto-deploy từ GitHub       │
└─────────────────────┘                        └──────────────────────────────┘
```

- **Frontend**: Desktop app PyQt6, đóng gói thành `.exe` bằng PyInstaller
- **Backend**: FastAPI REST API, deploy trên Railway, database PostgreSQL (Railway Plugin)
- Frontend đọc URL server từ file `config.json` cạnh exe

---

## 2. CẤU TRÚC THƯ MỤC

```
D:\Dev\APP\StuffStorageManager\          ← Git repo chính (GitHub: Dannyplusplus12/StuffStorageManager)
│
├── frontend\
│   └── ui.py                            ← TOÀN BỘ GUI (PyQt6) — POS, Kho, Công nợ, Hóa đơn

├── flutter_frontend\                    ← Flutter app (mobile + desktop runtime)
│   ├── lib\main.dart                    ← Entry app, route desktop/mobile theo device
│   ├── lib\screens\home_screen.dart    ← Desktop Flutter UI (sidebar)
│   ├── lib\screens\mobile_home_screen.dart ← Mobile child app UI theo role
│   ├── lib\utils\app_mode_manager.dart ← PIN mode manager (VIEWER/STAFF)
│   ├── lib\dialogs\staff_pin_dialog.dart ← Popup nhập PIN (mặc định 1111)
│   ├── lib\services\notification_service.dart ← Polling trạng thái pending
│   └── lib\utils\device_detector.dart  ← Detect mobile/desktop
│
├── backend\
│   ├── api.py                           ← FastAPI app (bản dev, copy sang server-repo khi deploy)
│   ├── database.py                      ← SQLAlchemy models + engine (bản dev)
│   └── requirements.txt                 ← Dependencies server (bản dev)
│
├── server-repo\                         ← Git repo RIÊNG → deploy lên Railway
│   ├── api.py                           ← (GitHub: Dannyplusplus12/StuffStorageManager-Server)
│   ├── database.py                      ← SQLAlchemy models, hỗ trợ DATABASE_URL env var
│   ├── server.py                        ← Entry: `from api import app`
│   ├── requirements.txt                 ← Có psycopg2-binary==2.9.10
│   ├── Procfile                         ← `web: uvicorn api:app --host 0.0.0.0 --port $PORT`
│   └── railway.toml                     ← nixpacks builder config
│
├── config.json                          ← {"api_url": "https://web-production-fbfbb.up.railway.app"}
├── run_frontend.py                      ← Launcher frontend (không khởi server local)
├── frontend.spec                        ← PyInstaller config (console=False, onefile)
├── migrate_to_cloud.py                  ← Script upload SQLite → Railway PostgreSQL
├── download_from_cloud.py               ← Script download Railway PostgreSQL → SQLite local
├── shop.db                              ← SQLite database gốc (data đã migrate lên cloud)
│
├── dist\
│   ├── StuffStorageManager.exe          ← Frontend exe (39.8 MB)
│   └── config.json                      ← ⚠️ PHẢI CÓ cạnh exe, nếu thiếu → fallback localhost
│
└── requirements.txt                     ← Dependencies đầy đủ (có PyQt6, KHÔNG có psycopg2)
```

---

## 3. GIT REPOSITORIES

### Repo 1: Main project
- **Path local:** `D:\Dev\APP\StuffStorageManager`
- **GitHub:** `https://github.com/Dannyplusplus12/StuffStorageManager`
- **Branch:** `main`
- **Chứa:** frontend, backend (dev), scripts, .exe config
- **⚠️ .gitignore rất strict** — chỉ push source/config cần thiết; không push build output, log, DB local backup

### Repo 2: Server deploy (nằm trong thư mục `server-repo/`)
- **Path local:** `D:\Dev\APP\StuffStorageManager\server-repo`
- **GitHub:** `https://github.com/Dannyplusplus12/StuffStorageManager-Server`
- **Branch:** `main`
- **Chứa:** `api.py`, `database.py`, `server.py`, `Procfile`, `railway.toml`, `requirements.txt`
- **Railway auto-deploy** khi push lên GitHub

---

## 4. RAILWAY DEPLOYMENT

| Thông tin | Giá trị |
|---|---|
| **Server URL** | `https://web-production-fbfbb.up.railway.app` |
| **Builder** | nixpacks |
| **Start command** | `uvicorn api:app --host 0.0.0.0 --port $PORT` |
| **Database** | PostgreSQL Plugin (tách biệt khỏi server container) |
| **PostgreSQL Internal** | `postgres.railway.internal:5432` |
| **PostgreSQL Public** | `centerbeam.proxy.rlwy.net:21122` |
| **Env var** | `DATABASE_URL` = PostgreSQL connection string (Railway tự set) |
| **Status** | ✅ ONLINE |

### Quy trình deploy server:
1. Sửa code trong `backend/api.py` hoặc `backend/database.py`
2. Copy file đã sửa vào `server-repo/`
3. `cd server-repo && git add . && git commit -m "..." && git push`
4. Railway tự detect → rebuild → redeploy (2-3 phút)

---

## 5. DATABASE SCHEMA (6 bảng + cột draft)

```sql
products (id, name, description, image_path)
variants (id, product_id FK, color, size, price, stock)
customers (id, name UNIQUE, phone, debt)
debt_logs (id, customer_id FK, change_amount, new_balance, note, created_at, created_ts)
orders (id, customer_name, customer_id FK, created_at, created_ts, total_amount, is_draft)
order_items (id, order_id FK, product_name, variant_id FK, variant_info, quantity, price)
```

### Lưu ý quan trọng về migration:
- `Base.metadata.create_all()` **CHỈ tạo bảng MỚI**, KHÔNG sửa bảng đã tồn tại
- Thêm bảng mới → tự động
- Sửa/thêm cột bảng cũ → phải viết migration thủ công bằng `ALTER TABLE`
- Xem ví dụ: function `ensure_created_ts_columns()` trong `api.py`
- **Database PostgreSQL KHÔNG mất khi server crash/redeploy** (service tách biệt)

---

## 6. FRONTEND (PyQt6)

### File duy nhất: `frontend/ui.py`
- **4 trang:** Xuất hàng (POS), Kho hàng (Inventory), Công nợ (Debt), Hóa đơn (History)
- Đọc `API_URL` từ `config.json` qua function `_load_api_url()`
- Fallback `http://127.0.0.1:8000` nếu không tìm thấy config
- Dùng `requests` library gọi REST API
- Thread-safe: `APIGetWorker(QThread)` cho async API calls

### Build exe:
```powershell
pyinstaller frontend.spec
# Output: dist/StuffStorageManager.exe
# ⚠️ SAU KHI BUILD: Copy config.json vào dist/ folder
copy config.json dist\config.json
```

---

## 7. BACKEND API (FastAPI)

### File chính: `backend/api.py` (dev) → copy sang `server-repo/api.py` (deploy)

### Endpoints:
| Method | Endpoint | Mô tả |
|--------|----------|-------|
| GET | `/products?search=` | Lấy danh sách sản phẩm |
| POST | `/products` | Tạo sản phẩm mới |
| PUT | `/products/{id}` | Cập nhật sản phẩm |
| DELETE | `/products/{id}` | Xóa sản phẩm |
| GET | `/customers` | Danh sách khách hàng |
| POST | `/customers` | Tạo khách hàng |
| PUT | `/customers/{id}` | Cập nhật tên/SĐT/nợ |
| DELETE | `/customers/{id}` | Xóa khách hàng + lịch sử |
| GET | `/customers/{id}/history` | Lịch sử giao dịch (orders + debt logs) |
| POST | `/customers/{id}/history` | Tạo điều chỉnh công nợ |
| PUT | `/customers/{id}/history/{log_id}` | Sửa log công nợ |
| DELETE | `/customers/{id}/history/{log_id}` | Xóa log công nợ |
| POST | `/checkout` | Xuất hàng (tạo order + trừ kho + cộng nợ) |
| PUT | `/orders/{id}` | Sửa đơn hàng (hoàn tác cũ → áp dụng mới) |
| GET | `/orders?page=&limit=` | Danh sách hóa đơn (phân trang) |
| DELETE | `/orders/{id}` | Xóa hóa đơn (hoàn tác kho + nợ) |
| PUT | `/orders/{id}/date` | Sửa ngày giờ đơn hàng |
| POST | `/checkout/draft` | Tạo hóa đơn nháp từ mobile staff |
| GET | `/orders/pending` | Danh sách hóa đơn chờ desktop duyệt |
| PUT | `/orders/{id}/approve` | Desktop duyệt nháp (trừ kho, cộng nợ, chốt đơn) |
| DELETE | `/orders/{id}/reject` | Desktop từ chối nháp (xóa hoàn toàn) |

### database.py hỗ trợ dual-mode:
```python
DATABASE_URL = os.environ.get("DATABASE_URL")  # Railway set env var này
if not DATABASE_URL:
    DATABASE_URL = f"sqlite:///{db_path}"       # Local fallback
is_sqlite = DATABASE_URL.startswith("sqlite")   # Flag cho migration conditional
```

---

## 8. SCRIPTS TIỆN ÍCH

| Script | Công dụng | Khi nào dùng |
|--------|-----------|--------------|
| `migrate_to_cloud.py` | Upload SQLite → Railway PostgreSQL | Lần đầu deploy hoặc reset data |
| `download_from_cloud.py` | Download PostgreSQL → `shop_backup.db` | Backup định kỳ |
| `run_frontend.py` | Chạy frontend trực tiếp (dev) | Khi dev, không cần build exe |

---

## 9. TECH STACK

| Layer | Công nghệ | Version |
|-------|-----------|---------|
| Mobile app | Flutter | 3.41.x |
| Dart | Dart SDK | 3.11.x |
| Frontend | PyQt6 | 6.10.2 |
| Backend | FastAPI | 0.128.8 |
| ORM | SQLAlchemy | 2.0.46 |
| DB (Cloud) | PostgreSQL | Railway Plugin |
| DB (Local) | SQLite | (fallback) |
| PG Driver | psycopg2-binary | 2.9.10 |
| HTTP Client | requests | 2.32.5 |
| Packaging | PyInstaller | 6.19.0 |
| Cloud | Railway | nixpacks builder |

---

## 10. NHỮNG LƯU Ý QUAN TRỌNG (DỄ QUÊN)

1. **2 Git repo riêng biệt**: Main project ≠ Server deploy. Sửa backend → phải copy + push cả `server-repo/`
2. **`dist/config.json`**: Sau mỗi lần build exe, PHẢI copy `config.json` vào `dist/`. Thiếu → exe dùng localhost
3. **`.gitignore` rất strict**: Main repo chỉ track vài file. Nếu thêm file mới, phải sửa `.gitignore`
4. **Migration database**: `create_all()` không sửa bảng cũ. Thêm cột → viết ALTER TABLE thủ công
5. **Server crash ≠ mất data**: PostgreSQL là service riêng trên Railway
6. **Backup**: Nên chạy `download_from_cloud.py` định kỳ (tuần/tháng)
7. **Railway free tier**: Có giới hạn credit. Nếu hết → server tắt (DB vẫn còn)
8. **`backend/` vs `server-repo/`**: `backend/` là bản dev, `server-repo/` là bản deploy. Luôn giữ sync

9. **Mobile là app con, không bê UI desktop**: mobile có flow riêng, nhẹ hơn desktop
10. **Phân quyền mobile bắt buộc**:
   - VIEWER mặc định: chỉ xem kho (read-only)
   - STAFF (PIN 1111): xem kho + công nợ + lịch sử hóa đơn + tạo hóa đơn nháp
11. **Chỉ desktop được duyệt/từ chối hóa đơn**: mobile staff không có quyền duyệt
12. **Nếu `/orders/pending` lỗi trên môi trường cũ**: mobile vẫn phải hiển thị lịch sử từ `/orders`

---

## 11. MOBILE CHILD APP FLOW (Flutter)

### Quy tắc nghiệp vụ
- App mở lên mặc định `VIEWER`
- Nhấn `Kích hoạt staff` → nhập PIN `1111` để vào `STAFF`
- `STAFF` tạo hóa đơn mới dưới dạng **draft** (`is_draft=1`)
- Desktop nhận pending và quyết định:
  - `Approve` → chốt đơn + trừ kho + cập nhật công nợ
  - `Reject` → xóa draft hoàn toàn

### Khả năng theo role
- **VIEWER**: chỉ xem sản phẩm + tồn kho
- **STAFF**: xem tồn kho, xem công nợ, xem lịch sử hóa đơn đã duyệt, tạo draft order
- **Desktop**: đầy đủ quyền + duyệt/từ chối pending

### Notification chiều ngược về staff
- Mobile polling trạng thái draft đã gửi
- Khi draft chuyển khỏi pending:
  - còn tồn tại trong orders → thông báo đã duyệt
  - không tồn tại → thông báo đã bị từ chối
