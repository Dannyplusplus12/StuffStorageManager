# iOS IPA Build Setup

Mục tiêu của setup này là tạo ra file `.ipa` cho `flutter_frontend` bằng GitHub Actions để cài thử lên iPhone, không dùng để phát hành App Store.

## Đã thêm gì

- `flutter_frontend/ios/` — iOS platform cho app Flutter
- `.github/workflows/build-ios-unsigned-ipa.yml` — workflow build `.ipa` không ký

## Cách hoạt động

Workflow chạy trên máy `macos-latest` của GitHub Actions:

1. Checkout repo
2. Cài Flutter `3.41.4`
3. Chạy `flutter pub get`
4. Build iOS bằng:
   - `flutter build ios --release --no-codesign`
5. Đóng gói `Runner.app` thành file:
   - `StuffStorageManager-ios-unsigned.ipa`
6. Upload file đó vào `Actions artifacts`

## Cách dùng

### 1. Push code lên GitHub

Từ repo chính:

```powershell
cd "D:\Dev\APP\StuffStorageManager"
git add .
git commit -m "Add iOS unsigned IPA build workflow"
git push
```

### 2. Chạy workflow

Trên GitHub repo `StuffStorageManager`:

- vào tab `Actions`
- chọn workflow `Build iOS Unsigned IPA`
- bấm `Run workflow`

Hoặc workflow cũng tự chạy khi có thay đổi trong `flutter_frontend/**` trên branch `main`.

### 3. Tải file `.ipa`

Sau khi workflow xong:

- mở run tương ứng trong `Actions`
- tải artifact tên `StuffStorageManager-ios-unsigned-ipa`

## Cài lên iPhone

Vì file này là **unsigned IPA**, bạn cần một công cụ sideload để ký và cài lên iPhone:

- `Sideloadly`
- `AltStore`

Thông thường quy trình là:

1. tải artifact `.ipa`
2. mở bằng `Sideloadly` hoặc `AltStore`
3. đăng nhập Apple ID của bạn trong công cụ đó
4. công cụ sẽ ký lại rồi cài lên iPhone

## Giới hạn

- Workflow này **không** phát hành App Store/TestFlight
- Workflow này **không** thay thế Apple code signing chính thức
- App có thể cần ký lại định kỳ nếu dùng Apple ID miễn phí
- Nếu dùng một số entitlement/plugin đặc biệt, sideload có thể cần cấu hình thêm

## Ghi chú

- Workflow phải nằm ở **repo root**: `.github/workflows/...`
- File workflow cũ trong `flutter_frontend/.github/workflows/` không phải vị trí chuẩn của GitHub Actions cho repo chính
