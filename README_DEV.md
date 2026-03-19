# 🏪 Stuff Storage Manager - Full Stack Project

**Status**: Development in progress

Dự án quản lý kho hàng, bán hàng (POS) và công nợ khách hàng với full-stack: Backend Python + Frontend Flutter

## 📁 Cấu trúc Project

```
StuffStorageManager/
├── backend/                    # Python Flask API
│   ├── api.py
│   ├── database.py
│   ├── server.py
│   ├── requirements.txt
│   ├── Procfile
│   ├── railway.toml
│   └── ...
│
├── frontend/                   # Python Desktop UI (Legacy)
│   ├── ui.py
│   └── ...
│
├── flutter_frontend/           # Flutter Desktop App (Main)
│   ├── lib/
│   │   ├── main.dart
│   │   ├── theme.dart
│   │   ├── screens/           # UI screens
│   │   ├── dialogs/           # Dialog components
│   │   ├── widgets/           # Reusable widgets
│   │   ├── services/          # API services
│   │   ├── models/            # Data models
│   │   └── ...
│   ├── pubspec.yaml
│   ├── .gitignore
│   ├── README.md
│   ├── SETUP.md
│   └── .github/workflows/
│
├── .gitignore                 # Root gitignore
├── PROJECT_CONTEXT.md
├── requirements.txt           # Python dependencies (root)
├── requirements-server.txt    # Server dependencies
├── Procfile                   # Deployment config
├── railway.toml               # Railway deployment
├── server.py                  # Entry point
└── ...
```

---

## 🚀 Khởi động Project

### 1. Backend API (Python)

```bash
# Cài dependencies
pip install -r requirements-server.txt

# Run server
python backend/server.py
# hoặc
python server.py

# Server sẽ chạy tại: http://localhost:5000
```

### 2. Flutter Frontend

```bash
cd flutter_frontend

# Cài dependencies
flutter pub get

# Run Windows app
flutter run -d windows

# Build EXE release
flutter build windows --release
```

### 3. Python Desktop Frontend (Legacy - Optional)

```bash
pip install -r requirements.txt
python frontend/ui.py
```

---

## 🎯 Tính năng chính

### 📊 Dashboard
- Tổng quan doanh số
- Thống kê bán hàng
- Công nợ khách hàng
- Tồn kho sản phẩm

### 🛒 Xuất Hàng (POS)
- ✅ Giao diện bán hàng nhanh
- ✅ Tìm kiếm sản phẩm (không dấu)
- ✅ **Scroll chuột** tăng/giảm số lượng
- ✅ Tính giá tự động

### 📦 Kho Hàng  
- ✅ Thêm/Chỉnh sửa/Xóa sản phẩm
- ✅ Quản lý biến thể (màu, size)
- ✅ **Nhân bản màu** (Duplicate)
- ✅ **Scroll chuột** tăng/giảm giá và số lượng

### 👥 Công Nợ
- ✅ Danh sách khách hàng
- ✅ Theo dõi công nợ
- ✅ Lịch sử giao dịch

### 📋 Hóa Đơn
- ✅ Xem/Chỉnh sửa/Xóa hóa đơn
- ✅ Chi tiết hóa đơn
- ✅ Tìm kiếm (không dấu)

---

## 🔌 API Endpoints

### Base URL
```
http://localhost:5000
```

### Products
```
GET    /api/products              - Lấy danh sách sản phẩm
POST   /api/products              - Tạo sản phẩm mới
PUT    /api/products/<id>         - Cập nhật sản phẩm
DELETE /api/products/<id>         - Xóa sản phẩm
GET    /api/products/search       - Tìm kiếm sản phẩm
```

### Orders (Hóa đơn)
```
POST   /api/checkout              - Tạo hóa đơn
GET    /api/orders                - Lấy danh sách hóa đơn
GET    /api/orders/<id>           - Chi tiết hóa đơn
PUT    /api/orders/<id>           - Cập nhật hóa đơn
DELETE /api/orders/<id>           - Xóa hóa đơn
```

### Customers (Khách hàng)
```
GET    /api/customers             - Lấy danh sách khách hàng
POST   /api/customers             - Tạo khách hàng mới
PUT    /api/customers/<id>        - Cập nhật khách hàng
DELETE /api/customers/<id>        - Xóa khách hàng
```

---

## 🛠️ Công nghệ

### Backend
- **Framework**: Flask
- **Database**: SQLite / PostgreSQL
- **Language**: Python 3.10+

### Frontend
- **Framework**: Flutter
- **Language**: Dart 3.26+
- **UI**: Material Design 3
- **Desktop**: Windows 10+

---

## 📋 Yêu cầu hệ thống

### Backend
- Python >= 3.10
- pip

### Frontend (Flutter)
- Flutter >= 3.41.4
- Dart >= 3.26.0
- Visual Studio Community 2022+ (Windows)
- CMake >= 3.10

---

## 🔄 Quy trình commit

```bash
# 1. Chỉnh sửa code
# ... your changes ...

# 2. Xem thay đổi
git status

# 3. Stage changes
git add .

# 4. Commit
git commit -m "feat: Add scroll wheel quantity adjustment"

# 5. Push
git push
```

---

## 📊 Git Branches

```
main          - Production ready
develop       - Development branch
feature/*     - Feature branches
fix/*         - Bug fix branches
```

---

## 🚀 Deployment

### Railway
- Backend: `python server.py`
- Database: PostgreSQL

Cấu hình tại `railway.toml` và `Procfile`

---

## 📝 Database

### Tables
- `products` - Danh sách sản phẩm
- `variants` - Màu (size, color)
- `customers` - Khách hàng
- `orders` - Hóa đơn
- `order_items` - Chi tiết hóa đơn

---

## 🧪 Testing

### Backend Tests
```bash
python -m pytest backend/
```

### Frontend Tests
```bash
cd flutter_frontend
flutter test
```

---

## 📚 Tài liệu

- [`flutter_frontend/README.md`](flutter_frontend/README.md) - Mô tả Flutter app
- [`flutter_frontend/SETUP.md`](flutter_frontend/SETUP.md) - Setup guide
- [`PROJECT_CONTEXT.md`](PROJECT_CONTEXT.md) - Project context

---

## 🐛 Known Issues

- [ ] Cần thêm unit tests
- [ ] Mobile version (Android/iOS)
- [ ] Dark mode support
- [ ] Multi-language support

---

## 📧 Liên hệ

Để báo cáo bugs hoặc đề xuất tính năng:
- GitHub Issues
- Email: [your-email]

---

## 📄 License

MIT License - Xem `LICENSE` file

---

**Last updated**: 2024
**Status**: 🟢 Active Development
