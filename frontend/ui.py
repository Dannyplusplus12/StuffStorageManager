import sys
import shutil
import os
import requests
import re
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize, QTimer, QStringListModel
from PyQt6.QtGui import QPixmap, QIntValidator, QColor, QCursor, QStandardItemModel, QStandardItem
from frontend.styles import SHOPEE_THEME

API_URL = "http://127.0.0.1:8000"

# --- CSS TÙY CHỈNH (Đã thêm Style cho Tooltip) ---
HOVER_STYLES = """
    /* Tooltip: Nền Trắng, Chữ Đen, Viền Cam */
    QToolTip { 
        color: #000000; 
        background-color: #ffffff; 
        border: 1px solid #ee4d2d; 
        padding: 5px;
        font-size: 13px;
    }

    /* Menu trái */
    QPushButton#NavButton:hover { background-color: #fff5f2; color: #ee4d2d; border-right: 4px solid #ffccbc; }
    
    /* Nút Chung */
    QPushButton { cursor: pointer; } 

    /* Nút Xóa (X) */
    QPushButton#IconBtn { font-size: 16px; font-weight: 900; color: #d32f2f; }
    QPushButton#IconBtn:hover { background-color: #ffebee; border-radius: 4px; }
    QPushButton#RemoveRowBtn:hover { background-color: #ffebee; border-radius: 12px; }

    /* Nút Chính (Primary) */
    QPushButton[class="PrimaryBtn"] { font-size: 15px; font-weight: bold; border-radius: 4px; }
    QPushButton[class="PrimaryBtn"]:hover { background-color: #d73211; border: 2px solid #bf2b0e; }

    /* Nút Phụ */
    QPushButton[class="SecondaryBtn"]:hover { background-color: #f5f5f5; border-color: #bbb; color: #000; }
    
    /* Nút Xóa Sản Phẩm to */
    QPushButton#DeleteBtn:hover { background-color: #ffebee; border-color: #b71c1c; }
"""

# --- HELPERS ---
def format_currency(value):
    try: return "{:,.0f}".format(int(value)).replace(",", ".")
    except: return "0"

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
    def __init__(self, color_name="", is_even=False, parent_layout=None):
        super().__init__()
        self.parent_layout_ref = parent_layout
        self.setFrameShape(QFrame.Shape.NoFrame)
        bg_color = "#fdfbf7" if is_even else "#ffffff"
        self.setStyleSheet(f"background-color: {bg_color}; border-radius: 6px; margin-bottom: 5px; border: 1px solid #eee;")
        
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(10, 10, 10, 10)
        self.layout.setAlignment(Qt.AlignmentFlag.AlignTop) 
        
        header = QHBoxLayout()
        self.color_inp = QLineEdit(color_name)
        self.color_inp.setPlaceholderText("Nhập tên màu...")
        self.color_inp.setStyleSheet("font-weight: bold; border: 1px solid #ccc; background: white;")
        self.color_inp.returnPressed.connect(self.add_size_row)
        
        btn_del = QPushButton("X") 
        btn_del.setObjectName("IconBtn")
        btn_del.setFixedSize(30, 30)
        btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_del.setStyleSheet("border: 1px solid #ddd; background: #fff;")
        btn_del.clicked.connect(self.delete_self)
        
        header.addWidget(QLabel("Màu:"))
        header.addWidget(self.color_inp)
        header.addWidget(btn_del)
        self.layout.addLayout(header)

        self.sizes_container = QVBoxLayout()
        self.sizes_container.setAlignment(Qt.AlignmentFlag.AlignTop) 
        self.layout.addLayout(self.sizes_container)
        
        btn_add = QPushButton("+ Thêm Size")
        btn_add.setProperty("class", "SecondaryBtn")
        btn_add.setCursor(Qt.CursorShape.PointingHandCursor)
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
        btn_x.setObjectName("RemoveRowBtn")
        btn_x.setFixedSize(25, 25)
        btn_x.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_x.setStyleSheet("color: red; border:none; font-weight:bold; background: transparent; font-size: 14px;")
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
    def delete_self(self): 
        msg = QMessageBox.question(self, "Xác nhận", f"Xóa màu '{self.color_inp.text()}'?", QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No)
        if msg == QMessageBox.StandardButton.Yes: self.setParent(None); self.deleteLater()
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
class OrderDetailDialog(QDialog):
    def __init__(self, order_data, parent=None):
        super().__init__(parent)
        self.order_data = order_data
        self.setWindowTitle(f"Chi tiết: {order_data['customer']}")
        self.setFixedSize(700, 600)
        self.setStyleSheet("""QDialog { background-color: #fff; } QLabel { color: #000; } QTableWidget { border: 1px solid #000; gridline-color: #000; font-size: 13px; selection-background-color: #ddd; selection-color: #000; } QHeaderView::section { background-color: #eee; color: #000; font-weight: bold; border: 1px solid #000; padding: 4px; }""" + HOVER_STYLES)
        
        layout = QVBoxLayout(self)
        info_frame = QFrame()
        info_frame.setStyleSheet("background: #f9f9f9; border: 1px solid #ccc; padding: 5px;")
        l_info = QVBoxLayout(info_frame)
        lbl_title = QLabel("HÓA ĐƠN BÁN HÀNG")
        lbl_title.setAlignment(Qt.AlignmentFlag.AlignCenter)
        lbl_title.setStyleSheet("font-size: 22px; font-weight: bold;")
        l_info.addWidget(lbl_title)
        l_info.addWidget(QLabel(f"Khách hàng:  {order_data['customer'].upper()}"))
        l_info.addWidget(QLabel(f"Mã đơn:      #{order_data['id']}"))
        l_info.addWidget(QLabel(f"Ngày lập:    {order_data['date']}"))
        layout.addWidget(info_frame)
        
        self.table = QTableWidget(0, 5)
        self.table.setHorizontalHeaderLabels(["Tên Sản Phẩm", "Phân Loại", "SL", "Đơn Giá", "T.Tiền"])
        self.table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.table.verticalHeader().setVisible(False)
        layout.addWidget(self.table)
        
        total_money = 0
        total_qty = 0
        for item in order_data['items']:
            r = self.table.rowCount()
            self.table.insertRow(r)
            
            # --- Tooltip cho Tên SP ---
            nm = QTableWidgetItem(item['name'])
            nm.setToolTip(item['name']) 
            self.table.setItem(r, 0, nm)
            
            # --- Tooltip cho Phân loại ---
            var = QTableWidgetItem(item['variant'])
            var.setToolTip(item['variant']) 
            self.table.setItem(r, 1, var)
            
            self.table.setItem(r, 2, QTableWidgetItem(str(item['qty'])))
            self.table.setItem(r, 3, QTableWidgetItem(f"{item['price']:,}"))
            item_total = item['qty'] * item['price']
            total_money += item_total
            total_qty += item['qty']
            self.table.setItem(r, 4, QTableWidgetItem(f"{item_total:,}"))

        footer = QFrame()
        footer.setStyleSheet("background: #eee; border: 1px solid #000;")
        fl = QHBoxLayout(footer)
        fl.addWidget(QLabel(f"Tổng SL: {total_qty}"))
        fl.addStretch()
        fl.addWidget(QLabel(f"TỔNG: {total_money:,} VNĐ"))
        layout.addWidget(footer)
        
        btn_box = QHBoxLayout()
        btn_close = QPushButton("Đóng")
        btn_close.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_close.clicked.connect(self.accept)
        btn_box.addWidget(btn_close)
        layout.addLayout(btn_box)

class CustomerHistoryDialog(QDialog):
    def __init__(self, cust_id, cust_name, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Lịch sử giao dịch - {cust_name}")
        self.resize(800, 600)
        self.setStyleSheet("background: white;" + HOVER_STYLES)
        
        layout = QVBoxLayout(self)
        
        self.table = QTableWidget(0, 4)
        self.table.setHorizontalHeaderLabels(["Ngày giờ", "Loại", "Nội dung", "Số tiền"])
        self.table.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        
        # --- BẤM 1 LẦN (Single Click) LÀ MỞ LUÔN ---
        self.table.cellClicked.connect(self.on_row_click)
        # -------------------------------------------
        
        layout.addWidget(self.table)
        layout.addWidget(QLabel("<i>* Bấm vào dòng 'Hóa Đơn' để xem chi tiết</i>"))
        
        self.load_data(cust_id)
        
    def load_data(self, cid):
        try:
            res = requests.get(f"{API_URL}/customers/{cid}/history").json()
            for r in res:
                row = self.table.rowCount()
                self.table.insertRow(row)
                self.table.setItem(row, 0, QTableWidgetItem(r['date']))
                
                type_item = QTableWidgetItem("Hóa Đơn" if r['type'] == "ORDER" else "Điều chỉnh")
                type_item.setForeground(QColor("blue") if r['type'] == "ORDER" else QColor("green"))
                self.table.setItem(row, 1, type_item)
                
                self.table.setItem(row, 2, QTableWidgetItem(r['desc']))
                
                amount_str = f"{r['amount']:+,}" 
                amt_item = QTableWidgetItem(amount_str)
                amt_item.setFont(self.font_bold())
                if r['amount'] > 0: amt_item.setForeground(QColor("red"))
                else: amt_item.setForeground(QColor("green"))
                self.table.setItem(row, 3, amt_item)
                
                if r['type'] == "ORDER":
                    self.table.item(row, 0).setData(Qt.ItemDataRole.UserRole, r['data'])
        except: pass

    def on_row_click(self, row, col):
        item = self.table.item(row, 0)
        data = item.data(Qt.ItemDataRole.UserRole)
        # Chỉ mở nếu có data (tức là Hóa Đơn)
        if data: 
            OrderDetailDialog(data, self).exec()

    def font_bold(self):
        f = self.font(); f.setBold(True); return f

class ProductBuyDialog(QDialog):
    def __init__(self, product_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Chọn phân loại")
        self.resize(600, 650)
        self.setStyleSheet("QDialog { background-color: #ffffff; } QLabel { color: #333; } " + HOVER_STYLES)
        self.product = product_data
        self.selected_items = []
        
        layout = QVBoxLayout(self)
        layout.setSpacing(5)
        layout.setContentsMargins(10, 10, 10, 10)
        
        header = QHBoxLayout()
        img = QLabel()
        img.setPixmap(get_centered_image(self.product['image'], QSize(90, 90))) 
        info = QVBoxLayout()
        info.setSpacing(2)
        info.addWidget(QLabel(f"<h2>{self.product['name']}</h2>"))
        info.addWidget(QLabel(f"Giá: <span style='color:#ee4d2d; font-weight:bold'>{self.product['price_range']} đ</span>"))
        header.addWidget(img); header.addLayout(info)
        layout.addLayout(header)

        scroll = QScrollArea(); scroll.setWidgetResizable(True)
        content = QWidget(); content.setStyleSheet("background-color: #fff;") 
        form = QVBoxLayout(content)
        form.setSpacing(5) 
        form.setContentsMargins(5,5,5,5)
        
        variants_by_color = {}
        for v in self.product['variants']:
            if v['color'] not in variants_by_color: variants_by_color[v['color']] = []
            variants_by_color[v['color']].append(v)
            
        self.spinboxes = {}
        for i, (color, vars) in enumerate(variants_by_color.items()):
            group_frame = QFrame()
            bg_color = "#ffffff" if i % 2 == 0 else "#f8f9fa"
            group_frame.setStyleSheet(f".QFrame {{ background-color: {bg_color}; border: 1px solid #e9ecef; border-radius: 6px; }}")
            g_layout = QVBoxLayout(group_frame)
            g_layout.setContentsMargins(10, 8, 10, 8) 
            g_layout.setSpacing(2) 
            
            lbl_color = QLabel(color.upper())
            lbl_color.setStyleSheet("font-size: 14px; font-weight: 900; color: #d73211;")
            g_layout.addWidget(lbl_color)
            
            gl = QGridLayout()
            gl.setVerticalSpacing(2) 
            gl.setHorizontalSpacing(10)
            
            for j, v in enumerate(vars):
                l_size = QLabel(f"Size {v['size']}")
                l_size.setStyleSheet("font-weight: bold; font-size: 13px;")
                stock_text = f"(Kho: {v['stock']})"
                price_text = f"{v['price']:,}đ {stock_text}"
                l_price = QLabel(price_text)
                l_price.setStyleSheet("color: #555; font-size: 13px;")
                spin = QSpinBox()
                spin.setRange(0, v['stock'])
                spin.setFixedWidth(100)
                spin.setMinimumHeight(30)
                if v['stock'] <= 0: 
                    spin.setEnabled(False)
                    l_size.setStyleSheet("color: #ccc;")
                    l_price.setText("Hết hàng")
                    l_price.setStyleSheet("color: red; font-size: 13px; font-weight: bold;")
                self.spinboxes[v['id']] = spin
                gl.addWidget(l_size, j, 0)
                gl.addWidget(l_price, j, 1)
                gl.addWidget(spin, j, 2)
            g_layout.addLayout(gl)
            form.addWidget(group_frame)
            
        content.setLayout(form); scroll.setWidget(content)
        layout.addWidget(scroll)
        
        btns = QHBoxLayout()
        btn_cancel = QPushButton("Hủy bỏ")
        btn_cancel.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_cancel.setMinimumHeight(40)
        btn_cancel.clicked.connect(self.reject)
        
        btn_add = QPushButton("Thêm vào đơn")
        btn_add.setProperty("class", "PrimaryBtn")
        btn_add.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_add.setMinimumHeight(45) 
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
                        self.selected_items.append({"variant_id": v['id'], "product_name": self.product['name'], "color": v['color'], "size": v['size'], "price": v['price'], "quantity": qty})
        self.accept()

class EditProductDialog(QDialog):
    def __init__(self, product_data, parent_window):
        super().__init__(parent_window)
        self.setWindowTitle(f"Chỉnh sửa: {product_data['name']}")
        self.resize(500, 600)
        self.setStyleSheet("QDialog { background-color: #ffffff; } " + HOVER_STYLES)
        self.product = product_data; self.main_window = parent_window; self.img_path = product_data['image']
        
        layout = QVBoxLayout(self)
        self.name_inp = QLineEdit(self.product['name']); layout.addWidget(self.name_inp)
        
        img_box = QHBoxLayout()
        self.img_lbl = QLabel()
        self.img_lbl.setPixmap(get_centered_image(self.img_path, QSize(60, 60)))
        btn_img = QPushButton("Đổi ảnh")
        btn_img.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_img.clicked.connect(self.choose_image)
        img_box.addWidget(self.img_lbl); img_box.addWidget(btn_img); layout.addLayout(img_box)

        scroll = QScrollArea(); scroll.setWidgetResizable(True)
        self.variants_container = QWidget()
        self.v_layout = QVBoxLayout(self.variants_container)
        self.v_layout.setAlignment(Qt.AlignmentFlag.AlignTop) 
        
        scroll.setWidget(self.variants_container); layout.addWidget(scroll)
        
        btn_add = QPushButton("+ Thêm Nhóm Màu")
        btn_add.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_add.clicked.connect(self.add_color_group)
        layout.addWidget(btn_add)
        
        btn_save = QPushButton("Lưu Thay Đổi")
        btn_save.setProperty("class", "PrimaryBtn")
        btn_save.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_save.setMinimumHeight(45) 
        btn_save.clicked.connect(self.save_product)
        layout.addWidget(btn_save)
        
        btn_del = QPushButton("XÓA SẢN PHẨM")
        btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_del.setObjectName("DeleteBtn")
        btn_del.clicked.connect(self.delete_product_entirely)
        layout.addWidget(btn_del)
        
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
    def add_color_group(self): grp = ColorGroupWidget("", is_even=(self.v_layout.count()%2==0)); self.v_layout.addWidget(grp); grp.color_inp.setFocus()
    def choose_image(self): 
        f, _ = QFileDialog.getOpenFileName(self, "Chọn ảnh", "", "Images (*.png *.jpg *.jpeg)")
        if f: self.img_path = f; self.img_lbl.setPixmap(get_centered_image(f, QSize(60, 60)))
    def save_product(self):
        vars = []
        for i in range(self.v_layout.count()):
            g = self.v_layout.itemAt(i).widget()
            if g: vars.extend(g.get_data())
        data = {"name": self.name_inp.text(), "image_path": self.img_path, "variants": vars}
        try: requests.put(f"{API_URL}/products/{self.product['id']}", json=data); self.accept(); self.main_window.load_products_for_grid()
        except Exception as e: QMessageBox.critical(self, "Lỗi", str(e))
    def delete_product_entirely(self):
        if QMessageBox.warning(self, "Xóa", "Chắc chắn xóa?", QMessageBox.StandardButton.Yes | QMessageBox.StandardButton.No) == QMessageBox.StandardButton.Yes:
            requests.delete(f"{API_URL}/products/{self.product['id']}"); self.accept(); self.main_window.load_products_for_grid()

class AddProductPanel(QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        l = QVBoxLayout(self); l.setContentsMargins(10, 10, 10, 10)
        l.addWidget(QLabel("Thêm Sản Phẩm Mới"))
        self.name_inp = QLineEdit(); self.name_inp.setPlaceholderText("Tên giày..."); l.addWidget(self.name_inp)
        
        ib = QHBoxLayout()
        self.img_path = ""; self.img_lbl = QLabel("No Img"); self.img_lbl.setFixedSize(60, 60)
        b_img = QPushButton("Chọn ảnh")
        b_img.setCursor(Qt.CursorShape.PointingHandCursor)
        b_img.clicked.connect(self.choose_image)
        ib.addWidget(self.img_lbl); ib.addWidget(b_img); l.addLayout(ib)

        s = QScrollArea(); s.setWidgetResizable(True)
        self.vc = QWidget(); self.vl = QVBoxLayout(self.vc)
        self.vl.setAlignment(Qt.AlignmentFlag.AlignTop)
        s.setWidget(self.vc); l.addWidget(s)
        
        b_add = QPushButton("+ Nhóm Màu")
        b_add.setCursor(Qt.CursorShape.PointingHandCursor)
        b_add.clicked.connect(self.add_color_group)
        l.addWidget(b_add)
        
        b_save = QPushButton("Lưu")
        b_save.setProperty("class", "PrimaryBtn")
        b_save.setCursor(Qt.CursorShape.PointingHandCursor)
        b_save.setMinimumHeight(45)
        b_save.clicked.connect(self.save_product)
        l.addWidget(b_save)
        self.add_color_group()

    def add_color_group(self): g = ColorGroupWidget("", is_even=(self.vl.count()%2==0)); self.vl.addWidget(g); g.color_inp.setFocus()
    def choose_image(self):
        f, _ = QFileDialog.getOpenFileName(self, "Chọn", "", "Images (*.png *.jpg *.jpeg)")
        if f: self.img_path = f; self.img_lbl.setPixmap(get_centered_image(f, QSize(60, 60)))
    def reset_form(self):
        self.name_inp.clear(); self.img_path = ""; self.img_lbl.clear()
        for i in reversed(range(self.vl.count())): self.vl.itemAt(i).widget().setParent(None)
        self.add_color_group()
    def save_product(self):
        vars = []
        for i in range(self.vl.count()):
            g = self.vl.itemAt(i).widget(); 
            if g: vars.extend(g.get_data())
        if not vars: return
        requests.post(f"{API_URL}/products", json={"name":self.name_inp.text(), "image_path":self.img_path, "variants":vars, "description":""})
        self.main_window.load_products_for_grid(); self.reset_form()

# --- MAIN WINDOW ---
class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Quản lý kho & Công nợ")
        self.resize(1280, 800)
        self.setStyleSheet(SHOPEE_THEME + HOVER_STYLES)
        
        self.cart = []
        self.current_products = []
        
        self.search_timer = QTimer()
        self.search_timer.setSingleShot(True)
        self.search_timer.interval = 300 
        self.search_timer.timeout.connect(self.execute_search)
        self.current_query = ""

        c = QWidget(); self.setCentralWidget(c)
        main = QHBoxLayout(c); main.setContentsMargins(0,0,0,0); main.setSpacing(0)

        sb = QWidget(); sb.setObjectName("Sidebar"); sb.setFixedWidth(150)
        sl = QVBoxLayout(sb); sl.setContentsMargins(0,0,0,0)
        self.ng = QButtonGroup(self); self.ng.setExclusive(True)
        def mk_nav(t, i):
            b = QPushButton(t); b.setObjectName("NavButton"); b.setCheckable(True); b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.clicked.connect(lambda: self.switch_page(i)); self.ng.addButton(b); sl.addWidget(b)
            return b
        self.b_pos = mk_nav("📦 Xuất hàng", 0); self.b_pos.setChecked(True)
        mk_nav("✏️ Kho hàng", 1)
        mk_nav("👥 Công nợ", 2)
        mk_nav("🧾 Hóa đơn", 3)
        sl.addStretch(); main.addWidget(sb)

        self.stack = QStackedWidget()
        self.page_grid = QWidget(); self.setup_grid_layout(self.page_grid); self.stack.addWidget(self.page_grid)
        self.page_debt = self.setup_debt_page(); self.stack.addWidget(self.page_debt)
        self.page_his = self.setup_history_page(); self.stack.addWidget(self.page_his)
        
        main.addWidget(self.stack)
        self.switch_page(0) 
        self.load_products_for_grid()
        self.load_customer_suggestions()

    def switch_page(self, i):
        if i == 0: self.mode = "POS"; self.rs.setCurrentIndex(0); self.stack.setCurrentIndex(0); self.ht.setText("Xuất Hàng")
        elif i == 1: self.mode = "INV"; self.rs.setCurrentIndex(1); self.stack.setCurrentIndex(0); self.ht.setText("Quản Lý Kho (Sửa)")
        elif i == 2: self.stack.setCurrentIndex(1); self.refresh_debt_table()
        else: self.stack.setCurrentIndex(2); self.refresh_history()

    def setup_grid_layout(self, p):
        l = QHBoxLayout(p); l.setContentsMargins(10, 10, 10, 10)
        
        lp = QWidget(); ll = QVBoxLayout(lp); ll.setContentsMargins(0,0,0,0)
        h = QHBoxLayout()
        self.ht = QLabel("Xuất Hàng"); self.ht.setObjectName("HeaderTitle")
        s = QLineEdit(); s.setPlaceholderText("🔍 Tìm kiếm..."); 
        s.textChanged.connect(self.on_search_text_changed)
        h.addWidget(self.ht); h.addStretch(); h.addWidget(s); ll.addLayout(h)
        
        self.gs = QScrollArea(); self.gs.setWidgetResizable(True); self.gs.setStyleSheet("border:none; background: #f5f5f5;")
        self.gc = QWidget(); self.pg = QGridLayout(self.gc); self.pg.setAlignment(Qt.AlignmentFlag.AlignTop|Qt.AlignmentFlag.AlignLeft); self.pg.setSpacing(10)
        self.gs.setWidget(self.gc); ll.addWidget(self.gs); l.addWidget(lp, 1)

        self.rp = QWidget(); self.rp.setFixedWidth(400); self.rp.setStyleSheet("background: white; border: 1px solid #ddd;")
        rl = QVBoxLayout(self.rp); rl.setContentsMargins(0,0,0,0)
        self.rs = QStackedWidget()
        
        cw = QWidget(); cl = QVBoxLayout(cw)
        cl.addWidget(QLabel("<b>Thông tin khách hàng:</b>"))
        
        self.cust_completer = QCompleter([])
        self.cust_completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
        self.cust_name_inp = QLineEdit()
        self.cust_name_inp.setPlaceholderText("Nhập tên khách (Tự gợi ý)")
        self.cust_name_inp.setCompleter(self.cust_completer)
        self.cust_name_inp.setStyleSheet("padding: 8px; border: 1px solid #ee4d2d;")
        cl.addWidget(self.cust_name_inp)
        
        self.cust_phone_inp = QLineEdit()
        self.cust_phone_inp.setPlaceholderText("Số điện thoại (Tùy chọn)")
        cl.addWidget(self.cust_phone_inp)

        cl.addWidget(QLabel("<b>Giỏ hàng:</b>"))
        self.ct = QTableWidget(0, 4)
        self.ct.setHorizontalHeaderLabels(["SP", "SL", "Giá", "X"])
        h = self.ct.horizontalHeader()
        h.setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        h.setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed); h.resizeSection(1, 40)
        h.setSectionResizeMode(2, QHeaderView.ResizeMode.ResizeToContents)
        h.setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed); h.resizeSection(3, 30)
        self.ct.verticalHeader().setVisible(False)
        cl.addWidget(self.ct)
        
        self.lbl_total = QLabel("0 món - 0 đ")
        self.lbl_total.setStyleSheet("font-size: 18px; color: #ee4d2d; font-weight: bold; margin: 10px 0;")
        cl.addWidget(self.lbl_total)
        
        bp = QPushButton("Xuất hàng")
        bp.setProperty("class", "PrimaryBtn")
        bp.setCursor(Qt.CursorShape.PointingHandCursor)
        bp.setMinimumHeight(50) 
        bp.clicked.connect(self.checkout)
        cl.addWidget(bp)
        
        self.rs.addWidget(cw)
        self.rs.addWidget(AddProductPanel(self)) 
        rl.addWidget(self.rs)
        l.addWidget(self.rp, 0)

    def on_search_text_changed(self, text):
        self.current_query = text
        self.search_timer.start(300) 
        
    def execute_search(self):
        self.load_products_for_grid(self.current_query)

    def load_products_for_grid(self, q=""):
        query_text = q if isinstance(q, str) else ""
        self.w = APIGetWorker(f"/products?search={query_text}")
        self.w.data_ready.connect(self.on_loaded)
        self.w.start()
    def on_loaded(self, p): self.current_products = p; self.recalc_grid()

    def setup_debt_page(self):
        w = QWidget()
        l = QVBoxLayout(w)
        
        h = QHBoxLayout()
        h.addWidget(QLabel("Quản lý Công Nợ & Khách Hàng", objectName="HeaderTitle"))
        b = QPushButton("Làm mới")
        b.setCursor(Qt.CursorShape.PointingHandCursor)
        b.clicked.connect(self.refresh_debt_table)
        h.addWidget(b)
        h.addStretch()
        l.addLayout(h)
        
        l.addWidget(QLabel("<i>* Thao tác giống Excel: Bấm vào sửa luôn, hoặc gõ phím để ghi đè. Hỗ trợ phép tính (vd: + 500)</i>"))

        self.debt_table = QTableWidget(0, 5) 
        self.debt_table.setHorizontalHeaderLabels(["ID", "Tên Khách", "SĐT", "Dư Nợ (VNĐ)", "Lịch sử"])
        self.debt_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        
        # --- CẤU HÌNH EXCEL-LIKE EDITING (SỬA Ở ĐÂY) ---
        self.debt_table.setEditTriggers(
            QAbstractItemView.EditTrigger.DoubleClicked |  # Double click
            QAbstractItemView.EditTrigger.SelectedClicked | # Click vào ô đã chọn
            QAbstractItemView.EditTrigger.AnyKeyPressed |   # Gõ phím bất kỳ
            QAbstractItemView.EditTrigger.CurrentChanged    # <--- QUAN TRỌNG: Bấm 1 cái là sửa luôn
        )
        # -----------------------------------------------

        self.debt_table.itemChanged.connect(self.on_debt_cell_changed) 
        l.addWidget(self.debt_table)
        return w

    def refresh_debt_table(self):
        self.debt_table.blockSignals(True)
        self.debt_table.setRowCount(0)
        try:
            custs = requests.get(f"{API_URL}/customers").json()
            for i, c in enumerate(custs):
                self.debt_table.insertRow(i)
                item_id = QTableWidgetItem(str(c['id'])); item_id.setFlags(item_id.flags() ^ Qt.ItemFlag.ItemIsEditable)
                self.debt_table.setItem(i, 0, item_id)
                self.debt_table.setItem(i, 1, QTableWidgetItem(c['name']))
                self.debt_table.setItem(i, 2, QTableWidgetItem(c['phone']))
                item_debt = QTableWidgetItem(f"{c['debt']:,}")
                item_debt.setData(Qt.ItemDataRole.UserRole, c['debt']) 
                if c['debt'] > 0: item_debt.setForeground(QColor("red"))
                self.debt_table.setItem(i, 3, item_debt)
                btn = QPushButton("Xem"); btn.setCursor(Qt.CursorShape.PointingHandCursor); btn.clicked.connect(lambda _, cid=c['id'], name=c['name']: CustomerHistoryDialog(cid, name, self).exec())
                self.debt_table.setCellWidget(i, 4, btn)
        except: pass
        self.debt_table.blockSignals(False)

    def on_debt_cell_changed(self, item):
        row = item.row(); col = item.column()
        if col not in [1, 2, 3]: return
        try:
            cid = int(self.debt_table.item(row, 0).text())
            name = self.debt_table.item(row, 1).text()
            phone = self.debt_table.item(row, 2).text()
            if col == 3:
                txt = item.text().replace(".", "").replace(",", "")
                old_val = item.data(Qt.ItemDataRole.UserRole)
                if txt.startswith("+") or txt.startswith("-"):
                     try: new_debt = old_val + int(txt)
                     except: new_debt = old_val
                elif "+" in txt or "-" in txt:
                    try: new_debt = int(eval(txt)) 
                    except: new_debt = old_val
                else:
                    try: new_debt = int(txt)
                    except: new_debt = old_val
                item.setText(f"{new_debt:,}"); debt = new_debt
            else: debt = self.debt_table.item(row, 3).data(Qt.ItemDataRole.UserRole)
            requests.put(f"{API_URL}/customers/{cid}", json={"name": name, "phone": phone, "debt": debt})
            if col == 3: self.debt_table.item(row, 3).setData(Qt.ItemDataRole.UserRole, debt)
        except Exception as e: print("Lỗi:", e)

    def load_customer_suggestions(self):
        try:
            custs = requests.get(f"{API_URL}/customers").json()
            names = [c['name'] for c in custs]
            self.cust_completer.setModel(QStringListModel(names))
        except: pass

    def resizeEvent(self, e): self.recalc_grid(); super().resizeEvent(e)
    def recalc_grid(self):
        if not self.current_products: return
        w = self.gs.width() - 20; cols = max(1, w // 155)
        for i in reversed(range(self.pg.count())): self.pg.itemAt(i).widget().setParent(None)
        r, c = 0, 0
        for p in self.current_products:
            self.pg.addWidget(self.create_card(p), r, c); c += 1
            if c >= cols: c=0; r+=1

    def create_card(self, p):
        card = QFrame(); card.setObjectName("ProductCard"); card.setFixedSize(145, 220); card.setCursor(Qt.CursorShape.PointingHandCursor)
        card.mousePressEvent = lambda e, data=p: self.on_card_click(data)
        total = sum([v['stock'] for v in p['variants']]); has_low = any(v['stock'] < 20 for v in p['variants'])
        bg = "#fff"
        if total < 50: bg = "#ef9a9a"
        elif has_low: bg = "#fff59d"
        card.setStyleSheet(f"QFrame#ProductCard {{ background-color: {bg}; border: 1px solid #eaeaea; border-radius: 4px; }} QFrame#ProductCard:hover {{ border: 1px solid #ee4d2d; }}")
        l = QVBoxLayout(card); l.setContentsMargins(5,5,5,5); l.setSpacing(2)
        img = QLabel(); img.setAlignment(Qt.AlignmentFlag.AlignCenter); img.setPixmap(get_centered_image(p['image'], QSize(135, 135)))
        n = QLabel(p['name']); n.setWordWrap(True); n.setFixedHeight(35); n.setAlignment(Qt.AlignmentFlag.AlignTop)
        l.addWidget(img); l.addWidget(n); l.addWidget(QLabel(f"{p['price_range']} đ"))
        return card

    def on_card_click(self, p):
        if self.mode == "POS":
            d = ProductBuyDialog(p, self)
            if d.exec(): self.cart.extend(d.selected_items); self.update_cart_ui()
        else: EditProductDialog(p, self).exec()

    def update_cart_ui(self):
        self.ct.setRowCount(0); total = 0; qty = 0
        for i, it in enumerate(self.cart):
            self.ct.insertRow(i)
            self.ct.setItem(i, 0, QTableWidgetItem(f"{it['product_name']}\n{it['size']}/{it['color']}"))
            self.ct.setItem(i, 1, QTableWidgetItem(str(it['quantity'])))
            s = it['price']*it['quantity']; total+=s; qty+=it['quantity']
            self.ct.setItem(i, 2, QTableWidgetItem(f"{s:,}"))
            b = QPushButton("x"); b.setCursor(Qt.CursorShape.PointingHandCursor); b.setStyleSheet("color:red; font-weight:bold; border:none;"); b.clicked.connect(lambda _, x=i: self.remove_cart(x)); self.ct.setCellWidget(i, 3, b)
        self.ct.resizeRowsToContents(); self.lbl_total.setText(f"Tổng: {qty} món - {total:,} đ")

    def remove_cart(self, i): del self.cart[i]; self.update_cart_ui()
    
    def checkout(self):
        if not self.cart: return
        payload = {"customer_name": self.cust_name_inp.text(), "customer_phone": self.cust_phone_inp.text(), "cart": self.cart}
        try:
            requests.post(f"{API_URL}/checkout", json=payload)
            QMessageBox.information(self, "OK", "Đã xuất kho!")
            self.cart = []; self.cust_name_inp.clear(); self.cust_phone_inp.clear()
            self.update_cart_ui(); self.load_products_for_grid(); self.load_customer_suggestions()
        except Exception as e: QMessageBox.warning(self, "Lỗi", str(e))

    def setup_history_page(self):
        w = QWidget(); l = QVBoxLayout(w)
        h = QHBoxLayout(); h.addWidget(QLabel("Lịch Sử Hóa Đơn")); b = QPushButton("Làm mới"); b.setCursor(Qt.CursorShape.PointingHandCursor); b.clicked.connect(self.refresh_history); h.addWidget(b); h.addStretch(); l.addLayout(h)
        self.ht_table = QTableWidget(0, 5)
        self.ht_table.setHorizontalHeaderLabels(["Ngày giờ", "Khách hàng", "Tổng tiền", "SL", "Chi tiết"])
        self.ht_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.ht_table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers); self.ht_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.ht_table.cellDoubleClicked.connect(self.open_order_detail)
        l.addWidget(self.ht_table); return w

    def refresh_history(self): self.hw = APIGetWorker("/orders"); self.hw.data_ready.connect(self.on_his_loaded); self.hw.start()
    def on_his_loaded(self, orders):
        self.orders_cache = orders; self.ht_table.setRowCount(0)
        for i, o in enumerate(orders):
            self.ht_table.insertRow(i)
            self.ht_table.setItem(i, 0, QTableWidgetItem(o['date']))
            self.ht_table.setItem(i, 1, QTableWidgetItem(o['customer']))
            self.ht_table.setItem(i, 2, QTableWidgetItem(f"{o['total_money']:,}"))
            self.ht_table.setItem(i, 3, QTableWidgetItem(str(o['total_qty'])))
            btn = QPushButton("Xem"); btn.setCursor(Qt.CursorShape.PointingHandCursor); btn.setStyleSheet("color:blue; text-decoration: underline; border:none;"); btn.clicked.connect(lambda _, row=i: self.open_order_detail(row, 0)); self.ht_table.setCellWidget(i, 4, btn)

    def open_order_detail(self, row, col): OrderDetailDialog(self.orders_cache[row], self).exec()

def run_gui():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.showMaximized()
    sys.exit(app.exec())