import sys
import shutil
import os
import requests
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize
from PyQt6.QtGui import QPixmap, QIntValidator
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
    def __init__(self, endpoint):
        super().__init__()
        self.endpoint = endpoint
    def run(self):
        try:
            resp = requests.get(f"{API_URL}{self.endpoint}")
            if resp.status_code == 200: self.data_ready.emit(resp.json())
        except: pass

# --- CUSTOM WIDGETS (DÙNG CHUNG CHO CẢ EDIT VÀ ADD) ---

class PriceInput(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setPlaceholderText("0")
        self.textChanged.connect(self.format_text)
        self.validator = QIntValidator()

    def format_text(self, text):
        clean_text = text.replace(".", "")
        if not clean_text.isdigit(): 
            if clean_text: self.setText(clean_text[:-1])
            return
        self.blockSignals(True)
        self.setText(format_currency(clean_text))
        self.blockSignals(False)

    def get_value(self):
        return int(self.text().replace(".", "") or 0)

class ColorGroupWidget(QFrame):
    """Widget quản lý 1 nhóm màu (Input thông minh)"""
    def __init__(self, color_name="", is_even=False, parent_layout=None):
        super().__init__()
        self.parent_layout_ref = parent_layout # Tham chiếu để tự xóa mình
        self.setFrameShape(QFrame.Shape.NoFrame)
        bg_color = "#fdfbf7" if is_even else "#ffffff"
        self.setStyleSheet(f"background-color: {bg_color}; border-radius: 6px; margin-bottom: 5px; border: 1px solid #eee;")
        
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(10, 10, 10, 10)
        
        # Header Màu
        header = QHBoxLayout()
        self.color_inp = QLineEdit(color_name)
        self.color_inp.setPlaceholderText("Nhập tên màu...")
        self.color_inp.setStyleSheet("font-weight: bold; border: 1px solid #ccc; background: white;")
        self.color_inp.returnPressed.connect(self.add_size_row)

        btn_del_color = QPushButton("🗑")
        btn_del_color.setFixedSize(30, 30)
        btn_del_color.setStyleSheet("color: #888; border: none; background: transparent;")
        btn_del_color.clicked.connect(self.delete_self)

        header.addWidget(QLabel("Màu:"))
        header.addWidget(self.color_inp)
        header.addWidget(btn_del_color)
        self.layout.addLayout(header)

        # Danh sách size
        self.sizes_container = QVBoxLayout()
        self.sizes_container.setSpacing(5)
        self.layout.addLayout(self.sizes_container)

        # Nút thêm size
        btn_add_size = QPushButton("+ Thêm Size")
        btn_add_size.setProperty("class", "SecondaryBtn")
        btn_add_size.clicked.connect(self.add_size_row)
        self.layout.addWidget(btn_add_size)

    def add_size_row(self, data=None):
        row_widget = QWidget()
        row_widget.setStyleSheet("background: transparent;") # Fix nền trắng đè lên màu
        row_layout = QHBoxLayout(row_widget)
        row_layout.setContentsMargins(0, 0, 0, 0)
        
        size_inp = QLineEdit()
        size_inp.setPlaceholderText("Size")
        size_inp.setFixedWidth(60)
        
        price_inp = PriceInput()
        price_inp.setPlaceholderText("Giá bán")
        
        stock_inp = QLineEdit()
        stock_inp.setPlaceholderText("SL Tồn")
        stock_inp.setFixedWidth(60)
        stock_inp.setValidator(QIntValidator())
        
        btn_del = QPushButton("x")
        btn_del.setFixedSize(25, 25)
        btn_del.setStyleSheet("color: red; border:none; font-weight:bold; background: transparent;")
        btn_del.clicked.connect(lambda: self.remove_size_row(row_widget))

        # Flow nhập liệu
        size_inp.returnPressed.connect(price_inp.setFocus)
        price_inp.returnPressed.connect(stock_inp.setFocus)
        stock_inp.returnPressed.connect(lambda: self.add_size_row_and_focus())

        if data:
            size_inp.setText(str(data['size']))
            price_inp.setText(str(data['price']))
            stock_inp.setText(str(data['stock']))

        row_layout.addWidget(size_inp)
        row_layout.addWidget(price_inp)
        row_layout.addWidget(stock_inp)
        row_layout.addWidget(btn_del)
        
        self.sizes_container.addWidget(row_widget)
        size_inp.setFocus()
        return row_widget

    def add_size_row_and_focus(self):
        self.add_size_row()

    def remove_size_row(self, widget):
        widget.setParent(None)

    def delete_self(self):
        self.setParent(None)
        self.deleteLater()

    def get_data(self):
        variants = []
        color_name = self.color_inp.text().strip()
        if not color_name: return []
        for i in range(self.sizes_container.count()):
            row = self.sizes_container.itemAt(i).widget()
            if row:
                inputs = row.findChildren(QLineEdit)
                if len(inputs) >= 3:
                    size = inputs[0].text()
                    price = row.findChild(PriceInput).get_value()
                    stock = int(inputs[2].text() or 0)
                    if size:
                        variants.append({"color": color_name, "size": size, "price": price, "stock": stock})
        return variants

# --- POPUP DIALOGS ---

class ProductBuyDialog(QDialog):
    """Popup Mua Hàng (POS) - Fix màu nền trắng"""
    def __init__(self, product_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Chọn phân loại")
        self.setFixedSize(600, 500)
        # Style ép nền trắng
        self.setStyleSheet("QDialog { background-color: #ffffff; } QLabel { color: #333; }")
        
        self.product = product_data
        self.selected_items = []
        
        layout = QVBoxLayout(self)
        
        # Header
        header = QHBoxLayout()
        img = QLabel()
        img.setPixmap(get_centered_image(self.product['image'], QSize(100, 100)))
        img.setStyleSheet("border: 1px solid #eee; border-radius: 4px;")
        
        info = QVBoxLayout()
        name = QLabel(self.product['name'])
        name.setObjectName("DialogTitle")
        info.addWidget(name)
        info.addWidget(QLabel(f"Giá: <span style='color:#ee4d2d; font-weight:bold'>{self.product['price_range']} đ</span>"))
        header.addWidget(img)
        header.addLayout(info)
        layout.addLayout(header)

        # Body
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
                spin.setFixedWidth(100) # Nút to hơn
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

class EditProductDialog(QDialog):
    """Popup Sửa Sản Phẩm (Inventory) - Tách biệt hoàn toàn"""
    def __init__(self, product_data, parent_window):
        super().__init__(parent_window)
        self.setWindowTitle(f"Chỉnh sửa: {product_data['name']}")
        self.setFixedSize(500, 700) # Form dọc dễ nhìn
        self.setStyleSheet("QDialog { background-color: #ffffff; }")
        
        self.product = product_data
        self.main_window = parent_window
        self.img_path = product_data['image']
        
        layout = QVBoxLayout(self)
        
        # 1. Thông tin chung
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

        # 2. Variants (Dùng lại ColorGroupWidget để có Smart Input)
        layout.addWidget(QLabel("<b>Phân loại hàng:</b>"))
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        self.variants_container = QWidget()
        self.v_layout = QVBoxLayout(self.variants_container)
        self.v_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(self.variants_container)
        layout.addWidget(scroll)
        
        btn_add_color = QPushButton("+ Thêm Nhóm Màu")
        btn_add_color.clicked.connect(self.add_color_group)
        layout.addWidget(btn_add_color)

        # 3. Save
        btn_save = QPushButton("Lưu Thay Đổi")
        btn_save.setProperty("class", "PrimaryBtn")
        btn_save.clicked.connect(self.save_product)
        layout.addWidget(btn_save)

        # Load Data
        self.load_data()

    def load_data(self):
        variants_by_color = {}
        for v in self.product['variants']:
            if v['color'] not in variants_by_color: variants_by_color[v['color']] = []
            variants_by_color[v['color']].append(v)
        
        for i, (color, vars) in enumerate(variants_by_color.items()):
            # Thêm group màu (xen kẽ màu nền)
            group = ColorGroupWidget(color, is_even=(i % 2 == 0))
            self.v_layout.addWidget(group)
            for v in vars:
                group.add_size_row(v)

    def add_color_group(self):
        count = self.v_layout.count()
        group = ColorGroupWidget("", is_even=(count % 2 == 0))
        self.v_layout.addWidget(group)
        group.color_inp.setFocus()

    def choose_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Chọn ảnh", "", "Images (*.png *.jpg *.jpeg)")
        if fname:
            dest = f"assets/images/{os.path.basename(fname)}"
            if not os.path.exists(dest): shutil.copy(fname, dest)
            self.img_path = dest
            self.img_lbl.setPixmap(get_centered_image(dest, QSize(60, 60)))

    def save_product(self):
        all_variants = []
        for i in range(self.v_layout.count()):
            group = self.v_layout.itemAt(i).widget()
            if group: all_variants.extend(group.get_data())
            
        payload = {
            "name": self.name_inp.text(),
            "image_path": self.img_path,
            "variants": all_variants,
            "description": ""
        }
        try:
            requests.put(f"{API_URL}/products/{self.product['id']}", json=payload)
            QMessageBox.information(self, "OK", "Đã cập nhật!")
            self.main_window.load_products_for_grid() # Refresh grid
            self.accept()
        except Exception as e: QMessageBox.critical(self, "Lỗi", str(e))


# --- PANEL BÊN PHẢI (CHỈ THÊM MỚI) ---

class AddProductPanel(QWidget):
    """Panel Bên Phải: Chỉ dùng để Thêm Sản Phẩm Mới"""
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        
        layout = QVBoxLayout(self)
        layout.setContentsMargins(10, 10, 10, 10)
        
        title = QLabel("Thêm Sản Phẩm Mới")
        title.setObjectName("HeaderTitle")
        title.setStyleSheet("color: #ee4d2d;")
        layout.addWidget(title)
        
        layout.addWidget(QLabel("Tên sản phẩm:"))
        self.name_inp = QLineEdit()
        self.name_inp.setPlaceholderText("Nhập tên giày...")
        layout.addWidget(self.name_inp)
        
        img_box = QHBoxLayout()
        self.img_path = ""
        self.img_lbl = QLabel("Chưa có ảnh")
        self.img_lbl.setFixedSize(60, 60)
        self.img_lbl.setStyleSheet("border: 1px dashed #ccc;")
        btn_img = QPushButton("Chọn ảnh")
        btn_img.clicked.connect(self.choose_image)
        img_box.addWidget(self.img_lbl)
        img_box.addWidget(btn_img)
        img_box.addStretch()
        layout.addLayout(img_box)

        layout.addWidget(QLabel("<b>Phân loại hàng:</b>"))
        scroll = QScrollArea()
        scroll.setWidgetResizable(True)
        scroll.setStyleSheet("border: none;")
        self.variants_container = QWidget()
        self.v_layout = QVBoxLayout(self.variants_container)
        self.v_layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        scroll.setWidget(self.variants_container)
        layout.addWidget(scroll)

        btn_add_color = QPushButton("+ Thêm Nhóm Màu")
        btn_add_color.clicked.connect(self.add_color_group)
        layout.addWidget(btn_add_color)

        btn_save = QPushButton("Lưu Sản Phẩm")
        btn_save.setProperty("class", "PrimaryBtn")
        btn_save.setMinimumHeight(45)
        btn_save.clicked.connect(self.save_product)
        layout.addWidget(btn_save)

        # Mặc định có 1 group màu
        self.add_color_group()

    def add_color_group(self):
        count = self.v_layout.count()
        group = ColorGroupWidget("", is_even=(count % 2 == 0))
        self.v_layout.addWidget(group)
        group.color_inp.setFocus()

    def choose_image(self):
        fname, _ = QFileDialog.getOpenFileName(self, "Chọn ảnh", "", "Images (*.png *.jpg *.jpeg)")
        if fname:
            dest = f"assets/images/{os.path.basename(fname)}"
            if not os.path.exists(dest): shutil.copy(fname, dest)
            self.img_path = dest
            self.img_lbl.setPixmap(get_centered_image(dest, QSize(60, 60)))

    def reset_form(self):
        self.name_inp.clear()
        self.img_path = ""
        self.img_lbl.clear()
        self.img_lbl.setText("Chưa có ảnh")
        for i in reversed(range(self.v_layout.count())):
            self.v_layout.itemAt(i).widget().setParent(None)
        self.add_color_group()

    def save_product(self):
        name = self.name_inp.text()
        if not name: return QMessageBox.warning(self, "Thiếu tin", "Nhập tên sản phẩm!")
        
        all_variants = []
        for i in range(self.v_layout.count()):
            group = self.v_layout.itemAt(i).widget()
            if group: all_variants.extend(group.get_data())
        
        if not all_variants: return QMessageBox.warning(self, "Thiếu tin", "Nhập ít nhất 1 biến thể!")

        payload = {
            "name": name, "image_path": self.img_path, "variants": all_variants, "description": ""
        }
        try:
            requests.post(f"{API_URL}/products", json=payload)
            QMessageBox.information(self, "OK", "Đã thêm mới!")
            self.main_window.load_products_for_grid()
            self.reset_form()
        except Exception as e: QMessageBox.critical(self, "Lỗi", str(e))

# --- MAIN WINDOW ---

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("POS Giày Dép (Clean UX)")
        self.resize(1280, 800)
        self.setStyleSheet(SHOPEE_THEME)
        
        self.cart = []
        self.current_products = [] 
        self.mode = "POS" # POS hoặc INV

        central = QWidget()
        self.setCentralWidget(central)
        main_layout = QHBoxLayout(central)
        main_layout.setContentsMargins(0,0,0,0)
        main_layout.setSpacing(0)

        # 1. SIDEBAR
        sidebar = QWidget()
        sidebar.setObjectName("Sidebar")
        sidebar.setFixedWidth(150)
        side_layout = QVBoxLayout(sidebar)
        side_layout.setContentsMargins(0,0,0,0)
        self.nav_group = QButtonGroup(self)
        self.nav_group.setExclusive(True)

        def create_nav(text, idx):
            btn = QPushButton(text)
            btn.setObjectName("NavButton")
            btn.setCheckable(True)
            btn.clicked.connect(lambda: self.switch_page(idx))
            self.nav_group.addButton(btn)
            side_layout.addWidget(btn)
            return btn

        self.btn_pos = create_nav("📦 Xuất hàng", 0)
        self.btn_pos.setChecked(True)
        self.btn_inv = create_nav("✏️ Kho hàng", 1)
        create_nav("🧾 Hóa đơn", 2)
        side_layout.addStretch()
        main_layout.addWidget(sidebar)

        # 2. CONTENT AREA
        self.stack = QStackedWidget()
        
        # Page POS/INV Grid
        self.page_grid = QWidget()
        self.setup_grid_layout(self.page_grid)
        self.stack.addWidget(self.page_grid)
        
        # Page History
        self.page_his = self.setup_history_page()
        self.stack.addWidget(self.page_his)

        main_layout.addWidget(self.stack)
        self.load_products_for_grid()

    def switch_page(self, idx):
        if idx == 0:
            self.mode = "POS"
            self.right_stack.setCurrentIndex(0) # Show Cart
            self.stack.setCurrentIndex(0)
            self.header_title.setText("Xuất Hàng")
        elif idx == 1:
            self.mode = "INV"
            self.right_stack.setCurrentIndex(1) # Show Add Form
            self.stack.setCurrentIndex(0)
            self.header_title.setText("Quản Lý Kho (Bấm vào sản phẩm để Sửa)")
        else:
            self.stack.setCurrentIndex(1) # History
            self.refresh_history()

    def setup_grid_layout(self, parent_widget):
        layout = QHBoxLayout(parent_widget)
        layout.setContentsMargins(10, 10, 10, 10)
        
        # CỘT TRÁI
        left_panel = QWidget()
        l_layout = QVBoxLayout(left_panel)
        l_layout.setContentsMargins(0,0,0,0)
        
        header = QHBoxLayout()
        self.header_title = QLabel("Xuất Hàng")
        self.header_title.setObjectName("HeaderTitle")
        search = QLineEdit()
        search.setPlaceholderText("🔍 Tìm tên sản phẩm...")
        search.textChanged.connect(self.load_products_for_grid)
        header.addWidget(self.header_title)
        header.addStretch()
        header.addWidget(search)
        l_layout.addLayout(header)

        self.grid_scroll = QScrollArea()
        self.grid_scroll.setWidgetResizable(True)
        self.grid_scroll.setStyleSheet("border:none; background: #f5f5f5;")
        self.grid_container = QWidget()
        self.product_grid = QGridLayout(self.grid_container)
        self.product_grid.setAlignment(Qt.AlignmentFlag.AlignTop | Qt.AlignmentFlag.AlignLeft)
        self.product_grid.setSpacing(10)
        self.grid_scroll.setWidget(self.grid_container)
        l_layout.addWidget(self.grid_scroll)
        layout.addWidget(left_panel, 1)

        # CỘT PHẢI
        self.right_panel_container = QWidget()
        self.right_panel_container.setFixedWidth(400) # Rộng chút để form đẹp
        self.right_panel_container.setStyleSheet("background: white; border: 1px solid #ddd; border-radius: 4px;")
        r_layout = QVBoxLayout(self.right_panel_container)
        r_layout.setContentsMargins(0,0,0,0)
        
        self.right_stack = QStackedWidget()
        
        # 1. Giỏ hàng (POS)
        self.cart_widget = QWidget()
        c_layout = QVBoxLayout(self.cart_widget)
        c_layout.addWidget(QLabel("<b>Đơn hàng chờ xuất</b>"))
        self.cart_table = QTableWidget(0, 4)
        self.cart_table.setHorizontalHeaderLabels(["SP", "SL", "Giá", "X"])
        self.cart_table.horizontalHeader().resizeSection(1, 40)
        self.cart_table.horizontalHeader().resizeSection(3, 30)
        self.cart_table.verticalHeader().setVisible(False)
        c_layout.addWidget(self.cart_table)
        self.lbl_total = QLabel("Tổng: 0 đ")
        self.lbl_total.setStyleSheet("font-size: 18px; color: #ee4d2d; font-weight: bold; margin: 10px 0;")
        c_layout.addWidget(self.lbl_total)
        btn_pay = QPushButton("Thanh toán xuất kho")
        btn_pay.setProperty("class", "PrimaryBtn")
        btn_pay.setMinimumHeight(45)
        btn_pay.clicked.connect(self.checkout)
        c_layout.addWidget(btn_pay)
        
        # 2. Add Form (INV)
        self.add_form = AddProductPanel(self)

        self.right_stack.addWidget(self.cart_widget)
        self.right_stack.addWidget(self.add_form)
        r_layout.addWidget(self.right_stack)
        layout.addWidget(self.right_panel_container, 0)

    # --- GRID LOGIC ---
    def resizeEvent(self, event):
        self.recalculate_grid_columns()
        super().resizeEvent(event)

    def recalculate_grid_columns(self):
        if not self.current_products: return
        avail_width = self.grid_scroll.width() - 20
        card_width = 145
        gap = 10
        n_cols = max(1, avail_width // (card_width + gap))
        
        for i in reversed(range(self.product_grid.count())): 
            self.product_grid.itemAt(i).widget().setParent(None)

        row, col = 0, 0
        for p in self.current_products:
            card = self.create_product_card(p)
            self.product_grid.addWidget(card, row, col)
            col += 1
            if col >= n_cols: col = 0; row += 1

    def create_product_card(self, p):
        card = QFrame()
        card.setObjectName("ProductCard")
        card.setFixedSize(145, 220)
        card.setCursor(Qt.CursorShape.PointingHandCursor)
        card.mousePressEvent = lambda e, data=p: self.on_card_click(data)
        
        layout = QVBoxLayout(card)
        layout.setContentsMargins(5,5,5,5)
        layout.setSpacing(2)
        
        img = QLabel()
        img.setAlignment(Qt.AlignmentFlag.AlignCenter)
        img.setPixmap(get_centered_image(p['image'], QSize(135, 135)))
        img.setStyleSheet("border-radius: 4px;")
        
        name = QLabel(p['name'])
        name.setObjectName("NameLabel")
        name.setWordWrap(True)
        name.setFixedHeight(35) 
        name.setAlignment(Qt.AlignmentFlag.AlignTop)
        
        price = QLabel(f"{p['price_range']} đ")
        price.setObjectName("PriceLabel")
        
        layout.addWidget(img)
        layout.addWidget(name)
        layout.addWidget(price)
        return card

    def load_products_for_grid(self, query=""):
        if isinstance(query, str): q = query
        else: q = ""
        self.worker = APIGetWorker(f"/products?search={q}")
        self.worker.data_ready.connect(self.on_products_loaded)
        self.worker.start()

    def on_products_loaded(self, products):
        self.current_products = products
        self.recalculate_grid_columns()

    def on_card_click(self, product_data):
        if self.mode == "POS":
            # POS: Popup Mua
            dlg = ProductBuyDialog(product_data, self)
            if dlg.exec():
                self.cart.extend(dlg.selected_items)
                self.update_cart_ui()
        else:
            # INV: Popup Edit (Mở EditProductDialog)
            dlg = EditProductDialog(product_data, self)
            dlg.exec() # Edit xong tự reload grid thông qua callback trong dialog

    # --- CART & HISTORY ---
    def update_cart_ui(self):
        self.cart_table.setRowCount(0)
        total = 0
        for i, item in enumerate(self.cart):
            self.cart_table.insertRow(i)
            self.cart_table.setItem(i, 0, QTableWidgetItem(f"{item['product_name']}\n{item['size']}/{item['color']}"))
            self.cart_table.setItem(i, 1, QTableWidgetItem(str(item['quantity'])))
            sum_item = item['price'] * item['quantity']
            total += sum_item
            self.cart_table.setItem(i, 2, QTableWidgetItem(f"{sum_item:,}"))
            btn_del = QPushButton("x")
            btn_del.setStyleSheet("color: red; border:none; font-weight:bold;")
            btn_del.clicked.connect(lambda _, idx=i: self.remove_cart_item(idx))
            self.cart_table.setCellWidget(i, 3, btn_del)
        self.cart_table.resizeRowsToContents()
        self.lbl_total.setText(f"Tổng: {total:,} đ")

    def remove_cart_item(self, idx):
        del self.cart[idx]
        self.update_cart_ui()

    def checkout(self):
        if not self.cart: return
        try:
            requests.post(f"{API_URL}/checkout", json=self.cart)
            QMessageBox.information(self, "OK", "Đã xuất kho!")
            self.cart = []
            self.update_cart_ui()
            self.load_products_for_grid()
        except Exception as e: QMessageBox.warning(self, "Lỗi", str(e))

    def setup_history_page(self):
        w = QWidget()
        l = QVBoxLayout(w)
        btn = QPushButton("Làm mới")
        btn.clicked.connect(self.refresh_history)
        l.addWidget(btn)
        self.his_table = QTableWidget(0, 4)
        self.his_table.setHorizontalHeaderLabels(["ID", "Ngày", "Tổng", "Chi tiết"])
        self.his_table.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Stretch)
        l.addWidget(self.his_table)
        return w

    def refresh_history(self):
        try:
            orders = requests.get(f"{API_URL}/orders").json()
            self.his_table.setRowCount(0)
            for i, o in enumerate(orders):
                self.his_table.insertRow(i)
                self.his_table.setItem(i, 0, QTableWidgetItem(str(o['id'])))
                self.his_table.setItem(i, 1, QTableWidgetItem(o['date']))
                self.his_table.setItem(i, 2, QTableWidgetItem(f"{o['total']:,}"))
                self.his_table.setItem(i, 3, QTableWidgetItem(o['details']))
        except: pass

def run_gui():
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()
    sys.exit(app.exec())