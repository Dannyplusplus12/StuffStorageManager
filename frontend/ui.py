import sys
import shutil
import os
import requests
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize
from PyQt6.QtGui import QPixmap, QIntValidator, QColor
from frontend.styles import SHOPEE_THEME

API_URL = "http://127.0.0.1:8000"

# --- HELPERS ---
def format_currency(value):
    try: return "{:,.0f}".format(int(value)).replace(",", ".")
    except: return ""

def get_centered_image(image_path, size):
    target_w, target_h = size.width(), size.height()
    pixmap = QPixmap(image_path)
    if pixmap.isNull(): return QPixmap(size)
    scaled = pixmap.scaled(size, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation)
    x = (scaled.width() - target_w) // 2
    y = (scaled.height() - target_h) // 2
    return scaled.copy(x, y, target_w, target_h)

# --- WORKER ---
class APIGetWorker(QThread):
    data_ready = pyqtSignal(list)
    error_occurred = pyqtSignal(str)
    def __init__(self, endpoint):
        super().__init__()
        self.endpoint = endpoint
    def run(self):
        try:
            resp = requests.get(f"{API_URL}{self.endpoint}", timeout=3)
            if resp.status_code == 200: self.data_ready.emit(resp.json())
            else: self.error_occurred.emit(f"Lỗi Server: {resp.status_code}")
        except Exception as e: self.error_occurred.emit(str(e))

# --- CUSTOM WIDGETS ---
class PriceInput(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setPlaceholderText("0")
        self.textChanged.connect(self.format_text)
        self.validator = QIntValidator()
    def format_text(self, text):
        clean = text.replace(".", "")
        if not clean.isdigit(): 
            if clean: self.setText(clean[:-1])
            return
        self.blockSignals(True)
        self.setText(format_currency(clean))
        self.blockSignals(False)
    def get_value(self):
        return int(self.text().replace(".", "") or 0)

class ColorGroupWidget(QFrame):
    # (GIỮ NGUYÊN CODE CŨ CỦA BẠN - KHÔNG THAY ĐỔI)
    def __init__(self, color_name="", is_even=False, parent_layout=None):
        super().__init__()
        self.parent_layout_ref = parent_layout
        self.setFrameShape(QFrame.Shape.NoFrame)
        bg_color = "#fdfbf7" if is_even else "#ffffff"
        self.setStyleSheet(f"background-color: {bg_color}; border-radius: 6px; margin-bottom: 5px; border: 1px solid #eee;")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(10, 10, 10, 10)
        
        header = QHBoxLayout()
        self.color_inp = QLineEdit(color_name)
        self.color_inp.setPlaceholderText("Nhập tên màu...")
        self.color_inp.setStyleSheet("font-weight: bold; border: 1px solid #ccc; background: white;")
        self.color_inp.returnPressed.connect(self.add_size_row)
        btn_del = QPushButton("🗑")
        btn_del.setFixedSize(30, 30)
        btn_del.setStyleSheet("color: #888; border: none; background: transparent;")
        btn_del.clicked.connect(self.delete_self)
        header.addWidget(QLabel("Màu:"))
        header.addWidget(self.color_inp)
        header.addWidget(btn_del)
        self.layout.addLayout(header)

        self.sizes_container = QVBoxLayout()
        self.layout.addLayout(self.sizes_container)
        
        btn_add = QPushButton("+ Thêm Size")
        btn_add.setProperty("class", "SecondaryBtn")
        btn_add.clicked.connect(self.add_size_row)
        self.layout.addWidget(btn_add)

    def add_size_row(self, data=None):
        row = QWidget()
        row.setStyleSheet("background: transparent;")
        l = QHBoxLayout(row)
        l.setContentsMargins(0, 0, 0, 0)
        
        s_inp = QLineEdit()
        s_inp.setPlaceholderText("Size")
        s_inp.setFixedWidth(60)
        p_inp = PriceInput()
        p_inp.setPlaceholderText("Giá")
        st_inp = QLineEdit()
        st_inp.setPlaceholderText("Kho")
        st_inp.setFixedWidth(60)
        st_inp.setValidator(QIntValidator())
        
        btn_x = QPushButton("x")
        btn_x.setFixedSize(25, 25)
        btn_x.setStyleSheet("color: red; border:none; font-weight:bold; background: transparent;")
        btn_x.clicked.connect(lambda: self.remove_size_row(row))
        
        s_inp.returnPressed.connect(p_inp.setFocus)
        p_inp.returnPressed.connect(st_inp.setFocus)
        st_inp.returnPressed.connect(lambda: self.add_size_row_and_focus())

        if data:
            s_inp.setText(str(data['size']))
            p_inp.setText(str(data['price']))
            st_inp.setText(str(data['stock']))

        l.addWidget(s_inp)
        l.addWidget(p_inp)
        l.addWidget(st_inp)
        l.addWidget(btn_x)
        self.sizes_container.addWidget(row)
        s_inp.setFocus()
        return row

    def add_size_row_and_focus(self): self.add_size_row()
    def remove_size_row(self, w): w.setParent(None)
    def delete_self(self): self.setParent(None); self.deleteLater()
    def get_data(self):
        variants = []
        c_name = self.color_inp.text().strip()
        if not c_name: return []
        for i in range(self.sizes_container.count()):
            row = self.sizes_container.itemAt(i).widget()
            if row:
                inps = row.findChildren(QLineEdit)
                if len(inps) >= 3:
                    size = inps[0].text()
                    price = row.findChild(PriceInput).get_value()
                    stock = int(inps[2].text() or 0)
                    if size: variants.append({"color": c_name, "size": size, "price": price, "stock": stock})
        return variants

# --- DIALOGS ---

# --- CẬP NHẬT CLASS OrderDetailDialog ---

class OrderDetailDialog(QDialog):
    def __init__(self, order_data, parent=None):
        super().__init__(parent)
        self.order_data = order_data
        self.setWindowTitle(f"Chi tiết: {order_data['customer']}")
        self.setFixedSize(700, 600) # To hơn chút để nhìn rõ
        
        # Style chuyên nghiệp, rõ ràng, nét căng (High Contrast)
        self.setStyleSheet("""
            QDialog { background-color: #fff; }
            QLabel { color: #000; }
            QTableWidget { 
                border: 1px solid #000; 
                gridline-color: #000; 
                font-size: 13px;
                selection-background-color: #ddd;
                selection-color: #000;
            }
            QHeaderView::section {
                background-color: #eee;
                color: #000;
                font-weight: bold;
                border: 1px solid #000;
                padding: 4px;
            }
        """)
        
        layout = QVBoxLayout(self)
        layout.setSpacing(5)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # 1. Header Thông tin
        # Dùng font Monospace (kiểu máy đánh chữ) cho phần thông tin để dễ gióng hàng
        info_frame = QFrame()
        info_frame.setStyleSheet("background: #f9f9f9; border: 1px solid #ccc; padding: 5px;")
        l_info = QVBoxLayout(info_frame)
        l_info.setSpacing(2)
        
        # Tiêu đề hoá đơn
        lbl_title = QLabel("HÓA ĐƠN BÁN HÀNG")
        lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl_title.setStyleSheet("font-size: 22px; font-weight: bold; margin-bottom: 5px;")
        l_info.addWidget(lbl_title)
        
        l_info.addWidget(QLabel(f"Khách hàng:  {order_data['customer'].upper()}"))
        l_info.addWidget(QLabel(f"Mã đơn:      #{order_data['id']}"))
        l_info.addWidget(QLabel(f"Ngày lập:    {order_data['date']}"))
        layout.addWidget(info_frame)
        
        # 2. Bảng Hàng Hóa (Compact Mode)
        # Cột: Tên SP | Màu/Size | SL | Đơn Giá | Thành Tiền
        self.table = QTableWidget(0, 5)
        self.table.setHorizontalHeaderLabels(["Tên Sản Phẩm", "Phân Loại", "SL", "Đơn Giá", "T.Tiền"])
        
        # Chỉnh kích thước cột thủ công cho hợp lý
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch) # Tên SP co giãn
        self.table.setColumnWidth(1, 120) # Màu/Size
        self.table.setColumnWidth(2, 60)  # SL
        self.table.setColumnWidth(3, 100) # Đơn giá
        self.table.setColumnWidth(4, 110) # Thành tiền
        
        self.table.verticalHeader().setVisible(False)
        self.table.verticalHeader().setDefaultSectionSize(28) # Dòng thấp lại (Compact)
        
        layout.addWidget(self.table)
        
        # Load dữ liệu vào bảng
        total_money = 0
        total_qty = 0
        
        for item in order_data['items']:
            r = self.table.rowCount()
            self.table.insertRow(r)
            
            # Tên SP
            self.table.setItem(r, 0, QTableWidgetItem(item['name']))
            
            # Phân loại (Quan trọng: Căn giữa cho dễ nhìn)
            it_var = QTableWidgetItem(item['variant'])
            it_var.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            self.table.setItem(r, 1, it_var)
            
            # Số lượng (Đậm để gây chú ý)
            it_qty = QTableWidgetItem(str(item['qty']))
            it_qty.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            it_qty.setFont(self.font_bold())
            self.table.setItem(r, 2, it_qty)
            
            # Đơn giá
            item_total = item['qty'] * item['price']
            total_money += item_total
            total_qty += item['qty']
            
            self.table.setItem(r, 3, QTableWidgetItem(f"{item['price']:,}"))
            self.table.setItem(r, 4, QTableWidgetItem(f"{item_total:,}"))

        # 3. Footer Tổng kết
        footer = QFrame()
        footer.setStyleSheet("background: #eee; border: 1px solid #000;")
        fl = QHBoxLayout(footer)
        
        lbl_sum_qty = QLabel(f"Tổng SL: {total_qty}")
        lbl_sum_qty.setStyleSheet("font-weight: bold; font-size: 14px;")
        
        lbl_sum_money = QLabel(f"TỔNG THANH TOÁN: {total_money:,} VNĐ")
        lbl_sum_money.setStyleSheet("font-weight: bold; font-size: 18px; color: #cc0000;")
        
        fl.addWidget(lbl_sum_qty)
        fl.addStretch()
        fl.addWidget(lbl_sum_money)
        layout.addWidget(footer)

        # 4. Nút Chức năng (Xuất File)
        btn_box = QHBoxLayout()
        btn_export = QPushButton("⬇ Xuất File Hóa Đơn (.TXT)")
        btn_export.setMinimumHeight(40)
        btn_export.setStyleSheet("""
            QPushButton { background-color: #2196F3; color: white; font-weight: bold; font-size: 14px; border-radius: 4px; }
            QPushButton:hover { background-color: #1976D2; }
        """)
        btn_export.clicked.connect(self.save_invoice_to_txt)
        
        btn_close = QPushButton("Đóng")
        btn_close.setMinimumHeight(40)
        btn_close.clicked.connect(self.accept)
        
        btn_box.addWidget(btn_export)
        btn_box.addWidget(btn_close)
        layout.addLayout(btn_box)

    def font_bold(self):
        # Helper tạo font đậm
        from PyQt6.QtGui import QFont
        f = QFont()
        f.setBold(True)
        return f

    def save_invoice_to_txt(self):
        # 1. Tạo thư mục invoices nếu chưa có
        folder = "invoices"
        if not os.path.exists(folder):
            os.makedirs(folder)
            
        # 2. Tạo tên file: HoaDon_{ID}_{TênKhach}.txt (Xóa ký tự đặc biệt)
        safe_name = "".join([c for c in self.order_data['customer'] if c.isalnum() or c in (' ', '_')]).strip()
        filename = f"{folder}/HoaDon_{self.order_data['id']}_{safe_name}.txt"
        
        # 3. Nội dung file (Trình bày kiểu bill máy in nhiệt)
        lines = []
        lines.append("==========================================")
        lines.append("           HOA DON BAN HANG")
        lines.append("==========================================")
        lines.append(f"Ma Don:   #{self.order_data['id']}")
        lines.append(f"Ngay:     {self.order_data['date']}")
        lines.append(f"Khach:    {self.order_data['customer']}")
        lines.append("------------------------------------------")
        # Header cột: Tên (viết tắt) | PL | SL | Thành tiền
        lines.append(f"{'SAN PHAM':<20} | {'LOAI':<12} | {'SL':<3} | {'THANH TIEN':>10}")
        lines.append("------------------------------------------")
        
        total = 0
        total_qty = 0
        for item in self.order_data['items']:
            t_money = item['price'] * item['qty']
            total += t_money
            total_qty += item['qty']
            
            # Cắt tên ngắn lại nếu dài quá để vừa khổ giấy text
            short_name = (item['name'][:18] + '..') if len(item['name']) > 20 else item['name']
            short_var = item['variant'].replace("Size ", "") # Rút gọn chữ Size
            
            lines.append(f"{short_name:<20} | {short_var:<12} | {item['qty']:<3} | {t_money:10,}".replace(",", "."))
            
        lines.append("------------------------------------------")
        lines.append(f"{'TONG CONG:':<30} {total:10,}".replace(",", "."))
        lines.append(f"Tong so luong: {total_qty}")
        lines.append("==========================================")
        lines.append("       Cam on quy khach & Hen gap lai!")
        
        content = "\n".join(lines)
        
        try:
            with open(filename, "w", encoding="utf-8") as f:
                f.write(content)
            
            # Mở thư mục chứa file để người dùng biết
            os.startfile(os.path.abspath(folder)) 
            QMessageBox.information(self, "Thành công", f"Đã xuất hóa đơn:\n{filename}")
        except Exception as e:
            QMessageBox.warning(self, "Lỗi", f"Không ghi được file: {str(e)}")

# ... (Các phần còn lại của ui.py giữ nguyên) ...

# Dialog Mua hàng (POS)
class ProductBuyDialog(QDialog):
    def __init__(self, product_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Chọn phân loại")
        self.setFixedSize(600, 500)
        self.setStyleSheet("QDialog { background-color: #ffffff; } QLabel { color: #333; }")
        self.product = product_data
        self.selected_items = []
        
        layout = QVBoxLayout(self)
        
        header = QHBoxLayout()
        img = QLabel()
        img.setPixmap(get_centered_image(self.product['image'], QSize(100, 100)))
        img.setStyleSheet("border: 1px solid #eee; border-radius: 4px;")
        info = QVBoxLayout()
        info.addWidget(QLabel(f"<h2>{self.product['name']}</h2>"))
        info.addWidget(QLabel(f"Giá: <span style='color:#ee4d2d; font-weight:bold'>{self.product['price_range']} đ</span>"))
        header.addWidget(img)
        header.addLayout(info)
        layout.addLayout(header)

        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        content = QWidget()
        content.setStyleSheet("background-color: #ffffff;") 
        form = QVBoxLayout(content)
        
        variants_by_color = {}
        for v in self.product['variants']:
            if v['color'] not in variants_by_color: variants_by_color[v['color']] = []
            variants_by_color[v['color']].append(v)
            
        self.spinboxes = {}
        for color, vars in variants_by_color.items():
            grp = QGroupBox(color)
            grp.setStyleSheet("font-weight:bold; margin-top:10px; border:1px solid #eee;")
            gl = QGridLayout()
            for i, v in enumerate(vars):
                gl.addWidget(QLabel(f"Size {v['size']}"), i, 0)
                gl.addWidget(QLabel(f"{v['price']:,}đ"), i, 1)
                spin = QSpinBox()
                spin.setRange(0, v['stock'])
                spin.setFixedWidth(100)
                self.spinboxes[v['id']] = spin
                gl.addWidget(spin, i, 2)
            grp.setLayout(gl)
            form.addWidget(grp)
            
        content.setLayout(form)
        scroll.setWidget(content)
        layout.addWidget(scroll)
        
        btns = QHBoxLayout()
        btn_cancel = QPushButton("Hủy bỏ")
        btn_cancel.clicked.connect(self.reject)
        btn_add = QPushButton("Thêm vào đơn")
        btn_add.setProperty("class", "PrimaryBtn")
        btn_add.clicked.connect(self.add_to_cart)
        btns.addStretch()
        btns.addWidget(btn_cancel)
        btns.addWidget(btn_add)
        layout.addLayout(btns)

    def add_to_cart(self):
        for vid, spin in self.spinboxes.items():
            qty = spin.value()
            if qty > 0:
                for v in self.product['variants']:
                    if v['id'] == vid:
                        self.selected_items.append({
                            "variant_id": v['id'], "product_name": self.product['name'],
                            "color": v['color'], "size": v['size'],
                            "price": v['price'], "quantity": qty
                        })
        self.accept()

# Dialog Sửa (Inventory)
class EditProductDialog(QDialog):
    # (GIỮ NGUYÊN CODE CŨ - LOGIC EDIT ĐÃ OK)
    def __init__(self, product_data, parent_window):
        super().__init__(parent_window)
        self.setWindowTitle(f"Chỉnh sửa: {product_data['name']}")
        self.setFixedSize(500, 700)
        self.setStyleSheet("QDialog { background-color: #ffffff; }")
        self.product = product_data
        self.main_window = parent_window
        self.img_path = product_data['image']
        
        layout = QVBoxLayout(self)
        layout.addWidget(QLabel("Tên sản phẩm:"))
        self.name_inp = QLineEdit(self.product['name'])
        layout.addWidget(self.name_inp)
        
        img_box = QHBoxLayout()
        self.img_lbl = QLabel()
        self.img_lbl.setPixmap(get_centered_image(self.img_path, QSize(60, 60)))
        btn_img = QPushButton("Đổi ảnh")
        btn_img.clicked.connect(self.choose_image)
        img_box.addWidget(self.img_lbl)
        img_box.addWidget(btn_img)
        img_box.addStretch()
        layout.addLayout(img_box)

        layout.addWidget(QLabel("<b>Phân loại hàng:</b>"))
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self.variants_container = QWidget()
        self.v_layout = QVBoxLayout(self.variants_container)
        self.v_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(self.variants_container)
        layout.addWidget(scroll)
        
        btn_add = QPushButton("+ Thêm Nhóm Màu")
        btn_add.clicked.connect(self.add_color_group)
        layout.addWidget(btn_add)

        btn_save = QPushButton("Lưu Thay Đổi")
        btn_save.setProperty("class", "PrimaryBtn")
        btn_save.clicked.connect(self.save_product)
        layout.addWidget(btn_save)
        self.load_data()

    def load_data(self):
        v_by_color = {}
        for v in self.product['variants']:
            if v['color'] not in v_by_color: v_by_color[v['color']] = []
            v_by_color[v['color']].append(v)
        for i, (c, vars) in enumerate(v_by_color.items()):
            grp = ColorGroupWidget(c, is_even=(i%2==0))
            self.v_layout.addWidget(grp)
            for v in vars: grp.add_size_row(v)

    def add_color_group(self):
        grp = ColorGroupWidget("", is_even=(self.v_layout.count()%2==0))
        self.v_layout.addWidget(grp)
        grp.color_inp.setFocus()

    def choose_image(self):
        f, _ = QFileDialog.getOpenFileName(self, "Chọn ảnh", "", "Images (*.png *.jpg *.jpeg)")
        if f:
            d = f"assets/images/{os.path.basename(f)}"
            if not os.path.exists(d): shutil.copy(f, d)
            self.img_path = d
            self.img_lbl.setPixmap(get_centered_image(d, QSize(60, 60)))

    def save_product(self):
        vars = []
        for i in range(self.v_layout.count()):
            g = self.v_layout.itemAt(i).widget()
            if g: vars.extend(g.get_data())
        data = {"name": self.name_inp.text(), "image_path": self.img_path, "variants": vars, "description": ""}
        try:
            requests.put(f"{API_URL}/products/{self.product['id']}", json=data)
            QMessageBox.information(self, "OK", "Đã cập nhật!")
            self.main_window.load_products_for_grid()
            self.accept()
        except Exception as e: QMessageBox.critical(self, "Lỗi", str(e))

# --- PANEL THÊM MỚI ---
class AddProductPanel(QWidget):
    # (GIỮ NGUYÊN CODE CŨ)
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        l = QVBoxLayout(self)
        l.setContentsMargins(10, 10, 10, 10)
        
        t = QLabel("Thêm Sản Phẩm Mới")
        t.setObjectName("HeaderTitle")
        t.setStyleSheet("color: #ee4d2d;")
        l.addWidget(t)
        
        l.addWidget(QLabel("Tên sản phẩm:"))
        self.name_inp = QLineEdit()
        self.name_inp.setPlaceholderText("Nhập tên giày...")
        l.addWidget(self.name_inp)
        
        ib = QHBoxLayout()
        self.img_path = ""
        self.img_lbl = QLabel("Chưa có ảnh")
        self.img_lbl.setFixedSize(60, 60)
        self.img_lbl.setStyleSheet("border: 1px dashed #ccc;")
        b_img = QPushButton("Chọn ảnh")
        b_img.clicked.connect(self.choose_image)
        ib.addWidget(self.img_lbl)
        ib.addWidget(b_img)
        ib.addStretch()
        l.addLayout(ib)

        l.addWidget(QLabel("<b>Phân loại hàng:</b>"))
        s = QScrollArea()
        s.setWidgetResizable(True)
        s.setStyleSheet("border: none;")
        self.vc = QWidget()
        self.vl = QVBoxLayout(self.vc)
        self.vl.setAlignment(Qt.AlignmentFlag.AlignTop)
        s.setWidget(self.vc)
        l.addWidget(s)

        b_add = QPushButton("+ Thêm Nhóm Màu")
        b_add.clicked.connect(self.add_color_group)
        l.addWidget(b_add)

        b_save = QPushButton("Lưu Sản Phẩm")
        b_save.setProperty("class", "PrimaryBtn")
        b_save.setMinimumHeight(45)
        b_save.clicked.connect(self.save_product)
        l.addWidget(b_save)
        self.add_color_group()

    def add_color_group(self):
        g = ColorGroupWidget("", is_even=(self.vl.count()%2==0))
        self.vl.addWidget(g)
        g.color_inp.setFocus()
    def choose_image(self):
        f, _ = QFileDialog.getOpenFileName(self, "Chọn ảnh", "", "Images (*.png *.jpg *.jpeg)")
        if f:
            d = f"assets/images/{os.path.basename(f)}"
            if not os.path.exists(d): shutil.copy(f, d)
            self.img_path = d
            self.img_lbl.setPixmap(get_centered_image(d, QSize(60, 60)))
    def reset_form(self):
        self.name_inp.clear()
        self.img_path = ""
        self.img_lbl.clear()
        self.img_lbl.setText("No Image")
        for i in reversed(range(self.vl.count())): self.vl.itemAt(i).widget().setParent(None)
        self.add_color_group()
    def save_product(self):
        n = self.name_inp.text()
        if not n: return QMessageBox.warning(self, "Lỗi", "Nhập tên!")
        vars = []
        for i in range(self.vl.count()):
            g = self.vl.itemAt(i).widget()
            if g: vars.extend(g.get_data())
        if not vars: return QMessageBox.warning(self, "Lỗi", "Nhập ít nhất 1 biến thể")
        try:
            requests.post(f"{API_URL}/products", json={"name":n, "image_path":self.img_path, "variants":vars, "description":""})
            QMessageBox.information(self, "OK", "Đã thêm!")
            self.main_window.load_products_for_grid()
            self.reset_form()
        except Exception as e: QMessageBox.critical(self, "Lỗi", str(e))

# --- MAIN WINDOW ---
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("POS Giày Dép (Pro)")
        self.resize(1280, 800)
        self.setStyleSheet(SHOPEE_THEME)
        self.cart = []
        self.current_products = []
        self.mode = "POS"

        c = QWidget()
        self.setCentralWidget(c)
        main = QHBoxLayout(c)
        main.setContentsMargins(0,0,0,0)
        main.setSpacing(0)

        # Sidebar
        sb = QWidget()
        sb.setObjectName("Sidebar")
        sb.setFixedWidth(150)
        sl = QVBoxLayout(sb)
        sl.setContentsMargins(0,0,0,0)
        self.ng = QButtonGroup(self)
        self.ng.setExclusive(True)
        def mk_nav(t, i):
            b = QPushButton(t)
            b.setObjectName("NavButton")
            b.setCheckable(True)
            b.clicked.connect(lambda: self.switch_page(i))
            self.ng.addButton(b)
            sl.addWidget(b)
            return b
        self.b_pos = mk_nav("📦 Xuất hàng", 0)
        self.b_pos.setChecked(True)
        mk_nav("✏️ Kho hàng", 1)
        mk_nav("🧾 Hóa đơn", 2)
        sl.addStretch()
        main.addWidget(sb)

        # Content
        self.stack = QStackedWidget()
        self.page_grid = QWidget()
        self.setup_grid_layout(self.page_grid)
        self.stack.addWidget(self.page_grid)
        self.page_his = self.setup_history_page()
        self.stack.addWidget(self.page_his)
        main.addWidget(self.stack)
        self.load_products_for_grid()

    def switch_page(self, i):
        if i == 0:
            self.mode = "POS"
            self.rs.setCurrentIndex(0)
            self.stack.setCurrentIndex(0)
            self.ht.setText("Xuất Hàng")
        elif i == 1:
            self.mode = "INV"
            self.rs.setCurrentIndex(1)
            self.stack.setCurrentIndex(0)
            self.ht.setText("Quản Lý Kho (Sửa)")
        else:
            self.stack.setCurrentIndex(1)
            self.refresh_history()

    def setup_grid_layout(self, p):
        l = QHBoxLayout(p)
        l.setContentsMargins(10, 10, 10, 10)
        
        # Left Grid
        lp = QWidget()
        ll = QVBoxLayout(lp)
        ll.setContentsMargins(0,0,0,0)
        h = QHBoxLayout()
        self.ht = QLabel("Xuất Hàng")
        self.ht.setObjectName("HeaderTitle")
        s = QLineEdit()
        s.setPlaceholderText("🔍 Tìm kiếm...")
        s.textChanged.connect(self.load_products_for_grid)
        h.addWidget(self.ht)
        h.addStretch()
        h.addWidget(s)
        ll.addLayout(h)
        
        self.gs = QScrollArea()
        self.gs.setWidgetResizable(True)
        self.gs.setStyleSheet("border:none; background: #f5f5f5;")
        self.gc = QWidget()
        self.pg = QGridLayout(self.gc)
        self.pg.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft)
        self.pg.setSpacing(10)
        self.gs.setWidget(self.gc)
        ll.addWidget(self.gs)
        l.addWidget(lp, 1)

        # Right Panel
        self.rp = QWidget()
        self.rp.setFixedWidth(400)
        self.rp.setStyleSheet("background: white; border: 1px solid #ddd; border-radius: 4px;")
        rl = QVBoxLayout(self.rp)
        rl.setContentsMargins(0,0,0,0)
        self.rs = QStackedWidget()
        
        # 1. Cart
        cw = QWidget()
        cl = QVBoxLayout(cw)
        
        # Nhập tên khách hàng
        self.cust_name_inp = QLineEdit()
        self.cust_name_inp.setPlaceholderText("Nhập tên khách hàng")
        self.cust_name_inp.setStyleSheet("padding: 10px; font-weight: bold; border: 1px solid #ee4d2d;")
        cl.addWidget(QLabel("<b>Thông tin khách hàng:</b>"))
        cl.addWidget(self.cust_name_inp)

        cl.addWidget(QLabel("<b>Giỏ hàng:</b>"))
        
        # --- [ĐÃ CẬP NHẬT] Bảng giỏ hàng tự co giãn ---
        self.ct = QTableWidget(0, 4)
        self.ct.setHorizontalHeaderLabels(["SP", "SL", "Giá", "X"])
        
        header = self.ct.horizontalHeader()
        # Cột 0 (Tên SP): Giãn hết cỡ để lấp đầy
        header.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        # Cột 1 (SL): Cố định nhỏ
        header.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        header.resizeSection(1, 40)
        # Cột 2 (Giá): Vừa khít nội dung
        header.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)
        # Cột 3 (Xóa): Cố định nhỏ
        header.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        header.resizeSection(3, 30)
        
        self.ct.verticalHeader().setVisible(False)
        # ---------------------------------------------

        cl.addWidget(self.ct)
        
        self.lbl_total = QLabel("0 món - 0 đ")
        self.lbl_total.setStyleSheet("font-size: 18px; color: #ee4d2d; font-weight: bold; margin: 10px 0;")
        cl.addWidget(self.lbl_total)
        
        bp = QPushButton("Xuất hàng")
        bp.setProperty("class", "PrimaryBtn")
        bp.setMinimumHeight(45)
        bp.clicked.connect(self.checkout)
        cl.addWidget(bp)
        
        # 2. Add Form
        self.af = AddProductPanel(self)

        self.rs.addWidget(cw)
        self.rs.addWidget(self.af)
        rl.addWidget(self.rs)
        l.addWidget(self.rp, 0)

    # --- LOGIC GRID & MÀU NỀN ---
    def resizeEvent(self, e): self.recalc_grid(); super().resizeEvent(e)
    def recalc_grid(self):
        if not self.current_products: return
        w = self.gs.width() - 20
        cols = max(1, w // 155)
        for i in reversed(range(self.pg.count())): self.pg.itemAt(i).widget().setParent(None)
        r, c = 0, 0
        for p in self.current_products:
            self.pg.addWidget(self.create_card(p), r, c)
            c += 1
            if c >= cols: c=0; r+=1

    def create_card(self, p):
        card = QFrame()
        card.setObjectName("ProductCard")
        card.setFixedSize(145, 220)
        card.setCursor(Qt.CursorShape.PointingHandCursor)
        card.mousePressEvent = lambda e, data=p: self.on_card_click(data)
        
        # --- LOGIC MÀU NỀN (MỚI) ---
        total_stock = sum([v['stock'] for v in p['variants']])
        # Kiểm tra xem có size nào dưới 20 không
        has_low_size = any(v['stock'] < 20 for v in p['variants'])
        
        bg_style = "#ffffff" # Mặc định Trắng
        if total_stock < 50:
            bg_style = "#ef9a9a" # Đỏ nhạt (Ưu tiên cao nhất)
        elif has_low_size:
            bg_style = "#fff59d" # Vàng nhạt
            
        card.setStyleSheet(f"QFrame#ProductCard {{ background-color: {bg_style}; border: 1px solid #eaeaea; border-radius: 4px; }} QFrame#ProductCard:hover {{ border: 1px solid #ee4d2d; }}")
        # ---------------------------

        l = QVBoxLayout(card)
        l.setContentsMargins(5,5,5,5)
        l.setSpacing(2)
        
        img = QLabel()
        img.setAlignment(Qt.AlignmentFlag.AlignCenter)
        img.setPixmap(get_centered_image(p['image'], QSize(135, 135)))
        img.setStyleSheet("background: transparent;")
        
        n = QLabel(p['name'])
        n.setObjectName("NameLabel")
        n.setWordWrap(True)
        n.setFixedHeight(35) 
        n.setAlignment(Qt.AlignmentFlag.AlignTop)
        
        pr = QLabel(f"{p['price_range']} đ")
        pr.setObjectName("PriceLabel")
        
        l.addWidget(img)
        l.addWidget(n)
        l.addWidget(pr)
        return card

    def load_products_for_grid(self, q=""):
        self.w = APIGetWorker(f"/products?search={q}")
        self.w.data_ready.connect(self.on_loaded)
        self.w.error_occurred.connect(lambda s: print(s))
        self.w.start()
    def on_loaded(self, p): self.current_products = p; self.recalc_grid()

    def on_card_click(self, p):
        if self.mode == "POS":
            d = ProductBuyDialog(p, self)
            if d.exec(): self.cart.extend(d.selected_items); self.update_cart_ui()
        else:
            EditProductDialog(p, self).exec()

    # --- CART ---
    def update_cart_ui(self):
        self.ct.setRowCount(0)
        total_money = 0
        total_qty = 0
        for i, it in enumerate(self.cart):
            self.ct.insertRow(i)
            self.ct.setItem(i, 0, QTableWidgetItem(f"{it['product_name']}\n{it['size']}/{it['color']}"))
            self.ct.setItem(i, 1, QTableWidgetItem(str(it['quantity'])))
            sum_item = it['price'] * it['quantity']
            total_money += sum_item
            total_qty += it['quantity']
            self.ct.setItem(i, 2, QTableWidgetItem(f"{sum_item:,}"))
            b = QPushButton("x")
            b.setStyleSheet("color: red; border:none; font-weight:bold;")
            b.clicked.connect(lambda _, x=i: self.remove_cart(x))
            self.ct.setCellWidget(i, 3, b)
        self.ct.resizeRowsToContents()
        # Hiển thị tổng số lượng
        self.lbl_total.setText(f"Tổng: {total_qty} món - {total_money:,} đ")

    def remove_cart(self, i): del self.cart[i]; self.update_cart_ui()
    def checkout(self):
        if not self.cart: return
        payload = {
            "customer_name": self.cust_name_inp.text(),
            "cart": self.cart
        }
        try:
            requests.post(f"{API_URL}/checkout", json=payload)
            QMessageBox.information(self, "OK", "Đã xuất kho!")
            self.cart = []
            self.cust_name_inp.clear()
            self.update_cart_ui()
            self.load_products_for_grid()
        except Exception as e: QMessageBox.warning(self, "Lỗi", str(e))

    # --- HISTORY (MỚI) ---
    def setup_history_page(self):
        w = QWidget()
        l = QVBoxLayout(w)
        
        h = QHBoxLayout()
        h.addWidget(QLabel("Lịch Sử Hóa Đơn", objectName="HeaderTitle"))
        b = QPushButton("Làm mới")
        b.clicked.connect(self.refresh_history)
        h.addWidget(b)
        h.addStretch()
        l.addLayout(h)

        # Bảng lịch sử cập nhật cột
        self.ht_table = QTableWidget(0, 5)
        self.ht_table.setHorizontalHeaderLabels(["Ngày giờ", "Khách hàng", "Tổng tiền", "SL", "Chi tiết"])
        self.ht_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.ht_table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.ht_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        # Sự kiện click vào dòng
        self.ht_table.cellDoubleClicked.connect(self.open_order_detail)
        
        l.addWidget(self.ht_table)
        l.addWidget(QLabel("<i>* Click đúp vào dòng để xem chi tiết</i>"))
        return w

    def refresh_history(self):
        self.hw = APIGetWorker("/orders")
        self.hw.data_ready.connect(self.on_his_loaded)
        self.hw.start()

    def on_his_loaded(self, orders):
        self.orders_cache = orders # Lưu lại để dùng khi click
        self.ht_table.setRowCount(0)
        for i, o in enumerate(orders):
            self.ht_table.insertRow(i)
            self.ht_table.setItem(i, 0, QTableWidgetItem(o['date']))
            self.ht_table.setItem(i, 1, QTableWidgetItem(o['customer']))
            self.ht_table.setItem(i, 2, QTableWidgetItem(f"{o['total_money']:,}"))
            self.ht_table.setItem(i, 3, QTableWidgetItem(str(o['total_qty'])))
            
            btn_view = QPushButton("Xem")
            btn_view.setStyleSheet("color: blue; border: none; text-decoration: underline;")
            btn_view.clicked.connect(lambda _, row=i: self.open_order_detail(row, 0))
            self.ht_table.setCellWidget(i, 4, btn_view)

    def open_order_detail(self, row, col):
        order_data = self.orders_cache[row]
        OrderDetailDialog(order_data, self).exec()

def run_gui():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())