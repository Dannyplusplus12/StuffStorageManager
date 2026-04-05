# PROJECT CONTEXT — StuffStorageManager
> **Mục đích file này:** Copy nội dung bên dưới và paste vào đầu cuộc hội thoại mới với AI để AI hiểu toàn bộ tình hình dự án, không cần giải thích lại.
> 
> **Cập nhật lần cuối:** Tháng 3/2026

## CẬP NHẬT NHANH GẦN NHẤT
- Đã áp logo mới từ `frontend/logo.png` cho app Flutter bằng `flutter_launcher_icons`: cập nhật icon launcher Android (`mipmap-*`), iOS (`Runner/Assets.xcassets/AppIcon.appiconset`) và Windows (`windows/runner/resources/app_icon.ico`).
- Đã đổi tên app sang `fisd` cho launcher/desktop: Android label (`AndroidManifest.xml`), iOS display/bundle name (`Info.plist`), Windows executable + metadata + title (`fisd.exe`, `Runner.rc`, `main.cpp`, `windows/CMakeLists.txt`).
- Đã đổi flow trang `Bán hàng` desktop sang giống `Xuất hàng`: dùng `checkoutDesktopDispatch` để gửi đơn cho picker (không trừ kho/cộng nợ ngay), đơn vẫn vào lịch sử quản lý và đi đủ trạng thái receive/deliver/confirm.
- Đã tinh chỉnh typography/màu của popup `Kho hàng` picker theo hướng gọn/hiện đại (giảm tình trạng chữ quá đậm, giảm độ gắt màu nhấn), đồng thời giới hạn chiều cao bottom-sheet `Kho hàng` còn `95%` màn hình.
- Đã tinh chỉnh thêm popup `Kho hàng` picker theo đúng phong cách `Nhận đơn`: bố cục compact hơn (header + badge tổng kho, ảnh thu gọn), nhóm `màu` rõ ràng và hiển thị `size:tồn` dạng chip/wrap để nhìn nhanh như thẻ nhóm trong nhận đơn.
- Đã sửa popup `Kho hàng` của picker (mobile): hiển thị lại theo nhóm `màu -> size`, có tổng tồn từng màu và style card gọn/hiện đại hơn; giữ highlight biến thể đang được focus khi nhảy từ đơn hàng.
- Đã đồng bộ phần đơn chờ duyệt ở panel trái màn `Quản lý`: chi tiết hàng hiển thị theo bảng kiểu Excel (`Mẫu/Màu/SL/Tiền`) giống panel phải, thay cho dạng text gạch đầu dòng.
- Mobile app đã bỏ popup nhập PIN: màn vào app giờ hiển thị trực tiếp ô PIN + nút `Vào app` (PIN-only login, auto map role như cũ).
- Đã chỉnh lại UI popup mobile orderer theo yêu cầu gọn/modern: popup chọn 1 mẫu và popup `Xem tất cả` đều group rõ theo `mẫu -> màu -> size`, có tổng theo model/màu và sắp xếp ổn định để dễ quan sát.
- Theo yêu cầu mới, đã bỏ hẳn tăng/giảm bằng con lăn chuột cho ô `Giá` ở `Nhập hàng` (`add_product_panel.dart`) để tránh đổi giá ngoài ý muốn khi thao tác nhanh.
- Đã bổ sung cấu hình iOS cho mobile: thêm quyền camera/thư viện/thông báo trong `frontend/ios/Runner/Info.plist` và bật explicit presentation cho local notifications trong `mobile_notification_service.dart` (alert/badge/sound) để tăng tương thích trên iPhone.
- Đã fix lỗi mở trang `Công nợ` thỉnh thoảng đỏ màn hình rồi tự hết (assert `DropdownButton`): các dropdown filter/khu vực trong `debt_screen.dart` giờ chỉ nhận `initialValue` khi value còn tồn tại trong danh sách `areas` đã load.
- Trang `Nhập hàng` thêm thông báo thành công dạng `SnackBar` ở đáy màn hình sau khi lưu sản phẩm mới (`Đã thêm sản phẩm mới`), đồng bộ kiểu hiển thị với thông báo lỗi.
- `Kho hàng` (popup sửa sản phẩm) đã bỏ tính năng lăn chuột để tăng/giảm ở ô `Giá` nhằm tránh đổi giá ngoài ý muốn; vẫn giữ nhập tay và chỉnh bằng ô số như cũ.
- `Xuất hàng` popup chọn mẫu (`ProductBuyDialog`): lăn chuột trên ô số lượng giờ chỉ đổi số lượng, không kéo trôi danh sách màu/size bên ngoài nữa.
- Mobile picker tab `Nhận đơn` đã thiết kế lại phần liệt kê chi tiết theo nhóm `mẫu -> màu -> chip size:SL` nhiều dòng, tránh dồn 1 dòng dài và giúp đọc chuyên nghiệp hơn.
- Đã cập nhật điều hướng từ `Khu vực` -> `Công nợ`: bấm vào một dòng khu vực trong bảng sẽ chuyển thẳng sang trang `Công nợ` và tự áp filter theo đúng khu vực vừa chọn.
- Đã fix crash `A FocusNode was used after being disposed` ở màn `Nhập hàng` khi thêm/xóa nhiều dòng (có dòng trống): thao tác xóa nhóm màu/xóa dòng size giờ chuyển focus an toàn rồi mới dispose node sau frame, đồng thời thêm key ổn định cho group/row động.
- Đã cập nhật UI theo yêu cầu quan sát: panel phải `Xuất hàng` được gom giỏ theo nhóm `mẫu + màu` (giữ chỉnh số lượng theo từng size), và `Quản lý > Lịch sử` đổi sang thẻ `dropdown` để bung chi tiết mặt hàng theo bảng kiểu Excel (`Mẫu/Màu/SL/Tiền`), đồng thời tăng độ rộng cột lịch sử.
- Mobile `orderer` đã có thanh điều hướng đáy riêng: thêm tab `Soạn đơn` + `Công nợ`. Tab `Công nợ` cho phép xem danh sách khách nợ trên mobile và thực hiện `điều chỉnh thủ công` nhanh (tạo debt log +/-) để thử nghiệm/hoàn thiện dần theo nhu cầu thực tế.
- Theo yêu cầu mới, đã **bật lại `mã hàng` (`products.code`)** cho desktop flow `Nhập hàng/Kho hàng/Xuất hàng/Bán hàng`: backend ORM + API + runtime migration đã thêm cột `products.code` (backfill mặc định từ `name` nếu trống); frontend model/service đã gửi/nhận `code`; form `Nhập hàng` và popup `Sửa sản phẩm` đã có input mã hàng; card sản phẩm và tìm kiếm nội bộ hỗ trợ theo mã.
- Đã đồng bộ popup `Sửa/Xóa` ở màn `Khu vực` theo style dialog mới (bo góc, spacing gọn, hành động rõ), và chuyển thao tác bảng `Khu vực` sang menu popup action để thống nhất UX với `Công nợ`.
- Đã đồng bộ popup nhỏ cho `Xuất hàng/Kho hàng` (manual quantity popup trong `ProductBuyDialog`, confirm xóa trong `EditProductDialog`) sang cùng ngôn ngữ UI mới.
- Trang `Nhập hàng` đã thử layout mới: tiêu đề/phụ đề rõ hơn, input `Mã hàng (*)` + `Tên giày (*)` cùng hàng thông tin chung, panel rộng/cân lại, và giữ ảnh upload riêng để thao tác nhanh.
- Đã đồng bộ style popup nhỏ theo phong cách mới ở màn `Công nợ`: các dialog xác nhận/xóa (xóa khách, xóa log, xóa hóa đơn) chuyển sang custom `Dialog` nền trắng, bo góc, spacing gọn và nút hành động rõ ràng.
- `Tổng nợ` ở panel trái màn `Công nợ` giờ đã follow filter khu vực: khi chọn khu vực, số `Tổng nợ` hiển thị đúng tổng nợ trong khu vực đó (label vẫn giữ nguyên `Tổng nợ`).
- Đã đổi icon placeholder card ở `Xuất hàng/Kho hàng` sang icon chân (`directions_walk`) theo yêu cầu.
- Đã chỉnh lại giao diện `Nhập hàng` để gọn và cân hơn: panel nhập liệu được căn giữa thay vì dồn trái, title rõ hơn (`Nhập hàng — Thêm sản phẩm mới`), và nút `Lưu` nổi bật hơn.
- Đã fix crash màn `Bán hàng` do `RawAutocomplete` (assert `focusNode`/`textEditingController`): bổ sung `FocusNode` tương ứng cho từng input autocomplete (`khách hàng`, `mã`, `màu`, `size`) để đảm bảo chạy ổn định khi nhập realtime.
- Đã chỉnh lại thứ tự bottom navigation theo phản hồi mới: đổi vị trí `Bán hàng` với `Công nợ`.
- Đã thêm trang desktop Flutter mới `Bán hàng` (tách biệt với `Xuất hàng`) và đưa vào bottom navigation; luồng thanh toán dùng lại nghiệp vụ checkout hiện có nhưng UI theo kiểu nhập liệu bảng.
- Trang `Bán hàng` hỗ trợ autocomplete realtime cho các cột `Mã hàng`/`Màu sắc`/`Size`: focus có danh sách gợi ý ngay, vừa gõ vừa lọc, so khớp không phân biệt hoa-thường và không dấu; khi nhập khớp chính xác sẽ tự điền tên mặt hàng, đơn giá và thành tiền theo biến thể tương ứng.
- Đã tinh chỉnh lớn UX desktop Flutter theo yêu cầu mới: ở `Công nợ` thêm filter khu vực dạng dropdown cạnh search (mặc định `Tất cả`) và lọc danh sách khách theo khu vực; phần lịch sử bỏ cơ chế dropdown nội dung, chuyển sang hiển thị chi tiết luôn theo từng dòng, chỉ giữ menu dropdown hành động `Sửa/Xóa`; chi tiết đơn hàng trong lịch sử được trình bày lại rõ hơn theo nhóm `mẫu` rồi nhóm `màu`.
- Đã sắp xếp lại thanh điều hướng: đổi vị trí `Nhập hàng` với `Xuất hàng`.
- Đã cải tiến thẻ sản phẩm ở POS/Kho: đổi icon mặc định sang icon liên quan giày hơn (`directions_run`), và thêm dòng `Mã: ...` dưới tên (font nhỏ, màu xám).
- Đã fix tìm kiếm sản phẩm theo hướng tiện dụng: lọc local không phân biệt hoa/thường và không dấu để tránh tình trạng gõ không ra kết quả.
- Đã triển khai phase đầu tính năng `Khu vực` cho Flutter frontend (`frontend/`) + backend: thêm menu `Khu vực`; tạo màn quản lý khu vực riêng (thêm/sửa/xóa, hiển thị số khách + tổng nợ theo khu vực); thêm API `GET/POST/PUT/DELETE /areas`; và cập nhật `customers` API để bắt buộc `area_id` khi tạo/sửa khách, trả thêm `area_name`.
- Màn `Công nợ` đã đổi layout theo yêu cầu: form nhập khách mới nằm bên trái, danh sách khách ở giữa, lịch sử vẫn bên phải; input tên khách mới dùng autocomplete mở toàn bộ danh sách khi focus và lọc dần khi gõ; thêm dropdown chọn khu vực bắt buộc khi tạo khách; popup sửa khách cũng có chọn khu vực.
- Input tên khách ở POS (`frontend/lib/screens/pos_screen.dart`) đã đổi autocomplete để mở ngay toàn bộ danh sách khách khi focus (không cần gõ trước), vẫn giữ logic lọc dần khi nhập.
- Đã cập nhật `migrate_to_cloud.py` để migrate đầy đủ schema mới lên PostgreSQL Railway: thêm hỗ trợ bảng `areas`, `customers.area_id`, và các cột mở rộng của `orders` (`is_draft`, `status`, `picker_note`) khi tạo bảng + import dữ liệu.
- Đã rollback quyết định bỏ `variant_info` trong script migrate DB: `backend/migrate_old_db_to_new.py` hiện giữ lại cột `order_items.variant_info` để bảo toàn dữ liệu hiển thị lịch sử hóa đơn ngay cả khi biến thể gốc (`variant_id`) bị xóa sau này.
- Đã cập nhật script migrate DB `backend/migrate_old_db_to_new.py` để bỏ cột `variant_info` trong bảng `order_items` của DB mới; dữ liệu migrate giữ các cột cần thiết (`id`, `order_id`, `product_name`, `variant_id`, `quantity`, `price`).
- Đã thêm schema `areas` vào backend: tạo bảng `areas` (seed mặc định: `Chợ đêm`, `Chợ hàn`, `Hội An`, `Nha Trang`) và thêm cột `customers.area_id`; migration runtime trong `backend/api.py` tự đảm bảo bảng/cột tồn tại và tạm gán toàn bộ khách hàng về `Chợ hàn`.
- Đã đổi DB local theo yêu cầu: file cũ `shop.db` được đổi thành `s.db`, sau đó tạo mới `shop.db` bằng script migrate (`backend/migrate_old_db_to_new.py`) với schema mới có `areas` + `customers.area_id`; dữ liệu khách hiện tại đã được gán `area_id` = `Chợ hàn`.
- Theo yêu cầu mới, đã rollback thay đổi `mã hàng` (`products.code`): bỏ khỏi backend model/API/runtime migration, bỏ khỏi frontend model/form/payload, và cập nhật script `backend/migrate_old_db_to_new.py` để tạo DB mới không còn cột `code`.
- Đã chuẩn bị big-update cho schema sản phẩm: thêm trường `code` (mã hàng dạng chuỗi) vào backend (`Product.code`), API products (`/products` get/create/update), và frontend Flutter (`Product model`, `ApiService`, form `Nhập hàng`, dialog sửa sản phẩm). Runtime migration backend tự thêm cột `products.code` nếu thiếu và backfill tạm `code = name`.
- Đã thêm script chuyển DB cũ sang DB mới: `backend/migrate_old_db_to_new.py` (đọc SQLite cũ, tạo DB mới theo schema mới, giữ dữ liệu hiện có; riêng sản phẩm gán `code = name` theo yêu cầu tạm thời).
- Đã cập nhật frontend sang backend Railway mới: đổi `api_url` sang `https://web-production-e5558.up.railway.app` ở cả `frontend/lib/config.dart` (default), `frontend/config.json` (dev run), và `config.json` root.
- Đã dọn `backend/` về đúng bộ deploy Railway tối thiểu để giảm nhầm lẫn: giữ `api.py`, `database.py`, `server.py`, `requirements.txt`, `Procfile`, `railway.toml`; loại bỏ các file/script không cần cho deploy (`excel_tasks/`, `mark_orders_approved.py`, `__init__.py`, `__pycache__/`). Đồng thời thêm `backend/README_DEPLOY.md` mô tả ngắn các file bắt buộc và start command.
- Desktop Flutter UI tiếp tục cập nhật theo yêu cầu mới: đã bỏ trang `Hóa đơn` khỏi điều hướng desktop; chuẩn hóa search để không phân biệt chữ hoa/thường (đặc biệt ở POS và lọc công nợ); và ở trang `Công nợ` đã bỏ nút `Thêm mới` dạng popup, thay bằng form thêm khách hàng trực tiếp nằm ngay phía trên danh sách công nợ.
- Đã khôi phục source Flutter đầy đủ và đảm bảo thư mục `frontend/` chạy lại được bằng `flutter run` (đã restore source từ Git local, đồng bộ lại nội dung từ `flutter_frontend/` sang `frontend/`, chạy `flutter pub get`, `flutter analyze` và `flutter run -d windows --no-resident` thành công).
- Đã dọn cấu trúc root theo yêu cầu mới: chuyển `server-repo/` thành backend chính bằng cách đổi tên thành `backend/`, đồng thời chuyển toàn bộ `backend/excel_tasks/` cũ sang `backend/excel_tasks/` mới (thuộc backend deploy chính). Đã xóa thư mục `assets/` ở root và loại bỏ các file root không còn dùng (`api_tester.py`, `crash_log.txt`, `note.txt`, `frontend.spec`, `ShopManager.spec`, `run_frontend.py`, file lock Excel tạm). Đã tạo `frontend/` từ mã Flutter để chuẩn hóa tên thư mục client.
- Đã dọn lại cấu trúc thư mục theo hướng backend deploy chuẩn là `server-repo/`: xóa hẳn thư mục legacy `frontend/`; loại bỏ các file runtime server trùng lặp trong `backend/` (`api.py`, `database.py`, `server.py`, `Procfile`, `railway.toml`, `requirements.txt`, ...), giữ `backend/` cho nhóm công cụ dữ liệu. Các script/file Excel rời ở root (`read_data.py`, `modify_data.py`, `seed_data.py`, `BÁN HÀNG.xlsx`, `CÔNG NỢ CHỢ HÀN.xlsx`, `result.xlsx`) đã gom vào `backend/excel_tasks/legacy_root/`. Đồng thời cập nhật `run_app.py` để load app trực tiếp từ `server-repo/api.py`; `run_frontend.py` chuyển thành thông báo deprecate.
- Đã fix thông báo trùng của mobile picker khi thoát/mở lại app: lưu danh sách `accepted order IDs` đã thấy bằng `SharedPreferences`, chỉ bắn thông báo cho đơn mới lần đầu xuất hiện; đơn cũ không báo lại khi vào app lại.
- Desktop `Duyệt đơn` đã thêm auto-refresh nền mỗi 2 giây để cập nhật đơn mới từ mobile gần như realtime (không nhấp nháy loading). Mobile đã cập nhật popup chọn mẫu cho orderer: tách thành 2 nút riêng `Đóng` và `Xác nhận` (giữ nguyên tác dụng). Đồng thời bổ sung local notification cho mobile: cả orderer và picker đều nhận thông báo hệ thống điện thoại khi có notice liên quan đơn hàng/trạng thái xác nhận.
- Desktop Flutter đã đổi điều hướng chính theo yêu cầu mới: bỏ nav dọc bên trái và chuyển toàn bộ thành thanh điều hướng ngang sáng ở phía dưới (bottom nav), vẫn giữ đủ các mục trang và badge chờ duyệt.
- Đã giảm độ màu sắc ở cả 2 màn desktop `Hóa đơn` và `Duyệt đơn`: các badge/chip trạng thái và tổng hợp được chuyển sang tông trung tính (nền xám nhạt + viền), giữ bố cục gọn hiện tại nhưng giao diện đơn giản và hiện đại hơn.
- Đã đồng bộ giao diện `Hóa đơn` theo phong cách gọn/rõ của `Duyệt đơn`: layout tập trung bên trái (`ConstrainedBox`), card dropdown có badge trạng thái, thông tin tóm tắt theo chip; vẫn giữ yêu cầu bỏ nút `Xem`.
- Màn `Hóa đơn` desktop đã được đổi từ bảng có nút `Xem` sang dạng dropdown (`ExpansionTile`): bỏ nút `Xem`, hiển thị chi tiết sản phẩm ngay khi bung từng hóa đơn; giữ thao tác `Sửa ngày`, `Sửa`, `Xóa` trong phần mở rộng.
- Đã đổi thêm UI trang `Duyệt đơn` theo yêu cầu mới: giao diện được dồn về bên trái bằng `ConstrainedBox`, bỏ nút `Chi tiết`, và chuyển từng đơn sang dạng dropdown (`ExpansionTile`) để xem chi tiết dòng hàng ngay trong card.
- Đã chỉnh thêm UI desktop: ở trang `Nhập hàng`, input `Size` và `SL` được đặt cạnh nhau để nhập nhanh hơn; trang `Duyệt đơn` được làm mới giao diện theo hướng rõ thông tin và thao tác tiện hơn (badge trạng thái, chip tóm tắt SL/tổng tiền, khối preview dòng hàng, nút `Chi tiết`/`Từ chối`/`Duyệt` trực quan hơn).
- Đã cập nhật layout trang `Nhập hàng`: nút `Lưu` được đẩy sát đáy khu vực thao tác bên trái; đồng thời thêm một box riêng bao toàn bộ phần `Nhóm màu` để tách lớp thị giác rõ ràng với `Thông tin chung`.
- Đã tinh chỉnh UI trang `Nhập hàng` để thao tác nhanh hơn: tăng kích thước input `Size` và `SL` (rộng hơn, padding lớn hơn, chữ rõ hơn) và nới nhẹ khoảng cách giữa các ô trong mỗi dòng biến thể.
- Đã tách hẳn khu vực ảnh ở trang `Nhập hàng` thành **cột riêng bên phải** (preview + nút `Tải ảnh`), không còn chiếm không gian phần form bên trái (`Thông tin chung` + `Nhóm màu`).
- Đã điều chỉnh lại trang `Nhập hàng` theo phản hồi mới: bỏ ô input ảnh thủ công, chỉ dùng nút `Tải ảnh`; phần preview + nút tải được chuyển sang cột bên phải của khối thông tin chung. Cơ chế chọn ảnh dùng lại hướng cũ đã từng hoạt động: mở dialog chọn file, tự copy ảnh vào `assets/images` (nếu chưa ở đó) và lưu `image_path` dạng tương đối để gửi API.
- Đã tinh chỉnh lại UI desktop trang `Nhập hàng`: dồn form về bên trái (không trải full màn), phân tách rõ cấp `Thông tin chung` và `Nhóm màu`, bỏ các nút `Nhóm màu/Đặt lại` ở header và cạnh nút lưu; nút thêm nhóm chuyển lại dạng `Thêm màu` nằm bên dưới danh sách màu như layout cũ; nút `Lưu` làm to và nổi bật hơn. Đồng thời ảnh sản phẩm dùng lại cơ chế mở cửa sổ chọn file (upload) thay vì chỉ nhập tay path/URL.
- Đã nâng cấp desktop Flutter UI theo yêu cầu mới: trang `Nhập hàng` được tối ưu thao tác (gom cụm nút để giảm di chuyển chuột), bổ sung nhập ảnh sản phẩm (URL/đường dẫn), nút dán nhanh từ clipboard và khung preview ảnh; màn `Công nợ` phần lịch sử bên phải hỗ trợ dạng dropdown/expand theo từng dòng, khi mở dòng `ORDER` sẽ hiển thị chi tiết các món hàng trong đơn ngay bên dưới.
- Desktop Flutter UI tiếp tục đổi theo yêu cầu mới: trang `Nhập hàng` chỉ còn form thêm sản phẩm (bỏ grid kho); màn `Công nợ` bỏ panel thêm khách cố định, thay bằng nút `Thêm mới` mở popup, và khi chọn khách sẽ hiển thị lịch sử ngay panel bên phải (thay cho popup lịch sử).
- Desktop Flutter UI đã đổi điều hướng theo yêu cầu: bỏ trang `Tổng quan`; tách luồng kho thành 2 mục riêng trong sidebar gồm `Kho hàng` (chỉ xem tồn kho) và `Nhập hàng` (form thêm sản phẩm). Phần còn lại giữ nguyên.
- Đã tạo README GitHub mới ở root `README.md` để tổng hợp trạng thái hiện tại của dự án (kiến trúc, role mobile VIEWER/STAFF, luồng đơn pending/accepted/completed, setup local, deploy Railway, cấu trúc thư mục và API chính) thay cho mô tả cũ không còn khớp.
- Desktop `Duyệt hóa đơn` đã thêm nút `Xem` ở góc dưới bên trái mỗi thẻ đơn chờ duyệt (`flutter_frontend/lib/screens/pending_approval_screen.dart`), mở popup chi tiết đầy đủ tất cả dòng hàng (mẫu/size-sai màu/số lượng) theo kiểu xem chi tiết tương tự popup picker.
- Mobile orderer UI tiếp tục chỉnh theo phản hồi: phần tóm tắt mẫu đã chọn dưới `Tổng tồn` đổi sang hiển thị **mỗi size/màu một dòng** (không nối bằng dấu phẩy); bỏ nút `Xem` khỏi popup chọn mẫu; thêm nút `Xem` cạnh nút `Gửi đơn` ở thanh dưới để mở popup xem/chỉnh đơn hiện tại (kiểu popup giống picker, có chỉnh số lượng trực tiếp).
- Đã nâng cấp UI mobile popup cho orderer/picker trong `flutter_frontend/lib/screens/mobile_home_screen.dart`: popup chuyển sang kiểu bottom-sheet hiện đại (picker), giới hạn chiều cao ~90% màn hình, popup orderer có nút `Xem` để rà soát/chỉnh số lượng trước khi xác nhận, nút chính đổi logic text `Xác nhận/Đóng` theo trạng thái thay đổi số lượng; đồng thời danh sách sản phẩm orderer bỏ badge `Còn hàng` và hiển thị tóm tắt mẫu đã chọn ngay dưới `Tổng tồn`.
- Đã sửa API xóa khách hàng trong `backend/api.py`: khi xóa khách sẽ duyệt toàn bộ đơn liên quan và xóa theo **cùng logic xóa hóa đơn** (đơn `completed` hoàn tác kho + công nợ trước khi xóa; đơn `pending/accepted` xóa dữ liệu đơn), sau đó mới xóa khách hàng để tránh lỗi ràng buộc và đồng bộ nghiệp vụ.
- Đã fix lỗi trùng lịch sử công nợ khi picker xác nhận đơn: trong `backend/api.py` endpoint `/orders/{id}/confirm` chỉ cộng nợ khách hàng, **không tạo thêm `DebtLog`** để tránh trùng với dòng lịch sử `ORDER` (Xuất đơn hàng).
- Đã cập nhật flow desktop staff trong `frontend/ui.py`: nút xuất hàng giờ tạo `/checkout/draft` rồi tự động `/orders/{id}/approve` để chuyển cho picker; kho + công nợ chỉ cập nhật khi picker xác nhận `/orders/{id}/confirm`.
- Đã sửa lỗi cú pháp ở `flutter_frontend/lib/screens/mobile_home_screen.dart` trong `_RoleSelectionScreen`: thay `doubleInfinity` -> `double.infinity` và sửa dấu `)` của `ElevatedButton.styleFrom(...)` cho nút `Người soạn hàng` (fix các lỗi build quanh dòng ~88-96).
- Đã sửa lỗi build Flutter ở `flutter_frontend/lib/screens/mobile_home_screen.dart`: thiếu dấu đóng `)` trong `_openOrdererProductQuickView()` (khối `SafeArea` trong `showModalBottomSheet`), gây lỗi `Can't find ')' to match '('` tại dòng ~502.
- Đã cập nhật tính năng picker trên mobile (`flutter_frontend/lib/screens/mobile_home_screen.dart`): danh sách đơn accepted giờ mở popup chi tiết đơn để thao tác tập trung hơn; popup có nút đóng, bấm ra ngoài để tắt, và vẫn cho phép bấm từng món để nhảy sang kho như cũ.
- Trong popup picker, mỗi món có input số lượng thực tế + nút tăng/giảm (UI tương tự popup chọn món của orderer). Picker có thể xác nhận một phần theo số lượng thực có.
- Backend `PUT /orders/{id}/confirm` đã hỗ trợ nhận số lượng picker nhập theo từng `order_item_id`/`variant_id`:
  - Trừ kho theo số thực nhận
  - Cập nhật lại `order_items` và `total_amount` theo phần giao được
  - Sau đó mới chuyển `completed`
- Đơn giao thiếu một phần sẽ lưu `picker_note` (thiếu hàng) trong `orders`; orderer polling trạng thái sẽ nhận và hiển thị thông báo để staff báo lại khách.
- Đã thêm migration/runtime support cho cột `orders.picker_note` (trong `backend/database.py` + `backend/api.py`).
- Đã cập nhật model/API Flutter (`order.dart`, `api_service.dart`) để hỗ trợ `order_item_id`, `picker_note` và payload confirm theo số lượng thực tế.
- Đã tạm thời xóa toàn bộ đơn `status='accepted'` trong DB local `shop.db` theo yêu cầu (queue picker được làm trống).
- Đã chỉnh giao diện POS desktop (`flutter_frontend/lib/screens/pos_screen.dart`) để không còn báo lỗi tràn khi thu nhỏ cửa sổ: thanh bên co giãn/đưa xuống dưới, cụm tiêu đề + ô tìm kiếm dùng `Wrap`, chấp nhận thu hẹp mà không xuất hiện dải cảnh báo.
- Đã chuẩn hóa lại các chuỗi tiếng Việt có dấu ở POS desktop (tiêu đề, placeholder tìm kiếm, nhãn giỏ hàng, snackbar...) để tránh hiển thị chữ không dấu.
- Dải tìm kiếm POS desktop đã chuyển sang bố cục flex: ô tìm kiếm và nút "Làm mới" luôn đi cùng nhau; khi không đủ chỗ cả cụm sẽ xuống hàng, tránh tình trạng chỉ riêng nút bị đẩy xuống dưới.
- Form thêm sản phẩm mới hiển thị rõ placeholder "Size" và "SL" nhờ giảm padding + căn giữa, không còn hiện "...".
- Đã áp dụng cùng layout flex cho phần tiêu đề + tìm kiếm ở màn hình `Công nợ khách hàng` và `Hóa đơn`, đảm bảo ô tìm kiếm và nút "Làm mới" luôn nằm chung một cụm và tự xuống hàng khi thiếu chỗ; đồng thời chuẩn hóa lại các nhãn/tooltip tiếng Việt (ví dụ "Hóa đơn", "Không có hóa đơn", "Sửa", "Xóa", "Chỉnh sửa ngày giờ"...).

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
| POST | `/checkout` | Luồng cũ xuất trực tiếp (trừ kho + cộng nợ ngay) |
| PUT | `/orders/{id}` | Sửa đơn hàng đã hoàn thành |
| GET | `/orders?page=&limit=` | Danh sách hóa đơn hoàn thành (phân trang) |
| DELETE | `/orders/{id}` | Xóa hóa đơn (hoàn tác kho + nợ) |
| PUT | `/orders/{id}/date` | Sửa ngày giờ đơn hàng |
| POST | `/checkout/draft` | Tạo hóa đơn nháp (pending), chưa trừ kho/chưa cộng nợ |
| POST | `/checkout/desktop-dispatch` | Desktop xuất hàng gửi thẳng cho picker (`approved`), bỏ qua bước duyệt |
| GET | `/orders/pending` | Danh sách đơn chờ tiếp nhận |
| PUT | `/orders/{id}/approve` | Chuyển pending → accepted cho picker (chưa trừ kho/chưa cộng nợ) |
| GET | `/orders/accepted` | Danh sách đơn picker cần xác nhận |
| PUT | `/orders/{id}/confirm` | Picker xác nhận: trừ kho + cộng nợ, chuyển completed |
| DELETE | `/orders/{id}/reject` | Từ chối đơn pending (xóa hoàn toàn) |

### database.py hỗ trợ dual-mode:
```python
DATABASE_URL = os.environ.get("DATABASE_URL")  # Railway set env var này
if not DATABASE_URL:
    DATABASE_URL = f"sqlite:///{db_path}"       # Local fallback
is_sqlite = DATABASE_URL.startswith("sqlite")   # Flag cho migration conditional
```

---

## 11. MOBILE CHILD APP FLOW (Flutter)

### Quy tắc nghiệp vụ
- App mở lên mặc định `VIEWER`
- Nhấn `Kích hoạt staff` → nhập PIN `1111` để vào `STAFF`
- `STAFF` tạo hóa đơn mới dưới dạng **draft** (`status=pending`)
- Đơn sẽ đi qua các trạng thái:
  - `pending` → staff/desktop tiếp nhận (`/approve`) thành `accepted`
  - `accepted` → picker xác nhận (`/confirm`) thành `completed`
- Chỉ khi picker xác nhận thì mới cập nhật kho + công nợ

### Khả năng theo role
- **VIEWER**: chỉ xem sản phẩm + tồn kho
- **STAFF (mobile)**: xem tồn kho, xem công nợ, xem lịch sử hóa đơn đã hoàn thành, tạo draft order
- **Desktop**: điều phối đơn (tiếp nhận/từ chối), quản trị đầy đủ

### Notification chiều ngược về staff
- Mobile polling trạng thái draft đã gửi
- Khi draft chuyển khỏi pending:
  - sang `accepted` → thông báo đã được tiếp nhận
  - sang `completed` → thông báo đã hoàn thành
  - không còn tồn tại → thông báo đã bị từ chối

---

## 12. DESKTOP STAFF FLOW (HIỆN TẠI)

- Nút `Xuất hàng` desktop Flutter (`frontend/lib/screens/pos_screen.dart`) dùng flow mới:
  1. `POST /checkout/desktop-dispatch` (tạo đơn ở trạng thái `approved`)
  2. Picker nhận đơn (`/orders/{id}/receive`) → `assigned`
  3. Picker giao + xác nhận (`/orders/{id}/deliver`/`confirm`) → `completed`
- Đặc điểm:
  - **Bỏ qua bước duyệt desktop**
  - **Vẫn chưa trừ kho/chưa cộng công nợ tại lúc tạo đơn**
  - Kho + công nợ chỉ thay đổi ở bước picker xác nhận hoàn tất
