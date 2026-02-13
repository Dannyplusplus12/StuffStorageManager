import sys
import shutil
import os
import requests
import re
import time
import subprocess
from PyQt6.QtWidgets import *
from PyQt6.QtCore import Qt, QThread, pyqtSignal, QSize, QTimer, QStringListModel, QDateTime
from PyQt6.QtGui import QPixmap, QIntValidator, QColor, QCursor, QStandardItemModel, QStandardItem, QKeySequence

API_URL = "http://127.0.0.1:8000"

# --- 1. CSS GIAO DIỆN CHUẨN ---
SHOPEE_THEME = """
    * { font-family: 'Segoe UI', sans-serif; color: #333; }
    QMainWindow, QDialog { background-color: #ffffff; }
    QToolTip { color: #000; background-color: #fff; border: 1px solid #ee4d2d; padding: 5px; font-weight: normal; }
    QScrollBar:vertical { border: none; background: #f0f0f0; width: 10px; margin: 0px; }
    QScrollBar::handle:vertical { background: #bbb; min-height: 20px; border-radius: 5px; margin: 2px; }
    QScrollBar::handle:vertical:hover { background: #999; }
    QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0px; }
    QScrollBar:horizontal { border: none; background: #f0f0f0; height: 10px; }
    QScrollBar::handle:horizontal { background: #bbb; min-width: 20px; border-radius: 5px; margin: 2px; }
    QPushButton { border-radius: 4px; font-size: 13px; }
    QPushButton#NavButton { text-align: left; padding: 15px 20px; border: none; font-size: 14px; color: #555; background: transparent; }
    QPushButton#NavButton:hover { background-color: #fff5f2; color: #ee4d2d; border-right: 4px solid #ffccbc; }
    QPushButton#NavButton:checked { background-color: #fff5f2; color: #ee4d2d; border-right: 4px solid #ee4d2d; font-weight: bold; }
    QPushButton#IconBtn, QPushButton#RemoveRowBtn, QPushButton#DelCustBtn, QPushButton#DeleteBtn { 
        padding: 0px; margin: 0px; text-align: center; border: 1px solid #ddd;
    }
    QPushButton#IconBtn { font-weight: 900; color: #d32f2f; background: #fff; }
    QPushButton#IconBtn:hover { background-color: #ffebee; }
    QPushButton#RemoveRowBtn { border: none; background: transparent; color: red; font-weight: bold; font-size: 14px; }
    QPushButton#RemoveRowBtn:hover { background-color: #ffebee; border-radius: 4px; }
    QPushButton#DelCustBtn, QPushButton#DeleteBtn { 
        background-color: #ffffff; color: #d32f2f; border: 1px solid #d32f2f; font-weight: bold; border-radius: 4px;
    }    
    QPushButton#DelCustBtn:hover, QPushButton#DeleteBtn:hover { 
        background-color: #ef9a9a !important; border: 1px solid #b71c1c !important; 
    }
    QPushButton#PrimaryBtn { 
        background-color: #ee4d2d !important; color: #000000 !important; border: none; padding: 8px 16px; font-weight: bold; font-size: 14px;
    }
    /* hover: darker background (keep text color unchanged for submit buttons) */
    QPushButton#PrimaryBtn:hover { background-color: #d73211 !important; }
    QPushButton#PrimaryBtn:pressed { background-color: #bf2b0e !important; }
    QPushButton#PrimaryBtn:disabled { background-color: #e0e0e0 !important; color: #999999 !important; }
    QPushButton#SecondaryBtn { background-color: #ffffff; color: #333333; border: 1px solid #cccccc; padding: 6px 12px; }
    /* hover: subtle background change, do not change text color */
    QPushButton#SecondaryBtn:hover { background-color: #fff5f2; border-color: #ee4d2d; }
    QLineEdit { border: 1px solid #ddd; padding: 6px; border-radius: 2px; background: white; color: #333; }
    QLineEdit:focus { border: 1px solid #ee4d2d; background: #fffdfb; }
    QTableWidget { border: 1px solid #ddd; background: white; gridline-color: #eee; color: #333; selection-background-color: #fff5f2; selection-color: #ee4d2d; font-size: 13px; }
    QHeaderView::section { background-color: #f8f8f8; padding: 6px; border: none; border-bottom: 1px solid #ddd; font-weight: bold; color: #555; }
    QScrollArea { border: none; background: transparent; }
"""

# --- HELPERS ---
def format_currency(value):
    try:
        return "{:,.0f}".format(int(value)).replace(",", ".")
    except:
        return "0"

def get_centered_image(image_path, size):
    target_w, target_h = size.width(), size.height()
    pixmap = QPixmap(image_path)
    if pixmap.isNull():
        return QPixmap(size)
    scaled = pixmap.scaled(size, Qt.AspectRatioMode.KeepAspectRatioByExpanding, Qt.TransformationMode.SmoothTransformation)
    x = (scaled.width() - target_w) // 2
    y = (scaled.height() - target_h) // 2
    return scaled.copy(x, y, target_w, target_h)

def open_file_dialog_safe():
    script = """
import tkinter as tk
from tkinter import filedialog
import os
try:
    root = tk.Tk()
    root.withdraw()
    root.attributes('-topmost', True)
    file_path = filedialog.askopenfilename(
        title="Chọn ảnh sản phẩm",
        filetypes=[("Image Files", "*.png *.jpg *.jpeg")]
    )
    if file_path:
        print(file_path)
    root.destroy()
except Exception:
    pass
"""
    try:
        creationflags = 0x08000000 if os.name == 'nt' else 0
        result = subprocess.run([sys.executable, "-c", script], capture_output=True, text=True, creationflags=creationflags)
        path = result.stdout.strip()
        return path if path else None
    except Exception as e:
        print(f"Lỗi subprocess dialog: {e}")
        return None

# --- WORKER ---
class APIGetWorker(QThread):
    data_ready = pyqtSignal(object)
    error_occurred = pyqtSignal(str)
    def __init__(self, endpoint):
        super().__init__()
        self.endpoint = endpoint
    def run(self):
        try:
            r = requests.get(f"{API_URL}{self.endpoint}", timeout=10)
            if r.status_code == 200:
                self.data_ready.emit(r.json())
            else:
                self.error_occurred.emit(f"Err: {r.status_code}")
        except Exception as e:
            self.error_occurred.emit(str(e))

# --- CUSTOM WIDGETS ---
class PriceInput(QLineEdit):
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setPlaceholderText("0")
        self.textChanged.connect(self.format_text)
        self.validator = QIntValidator()
    def format_text(self, text):
        clean = text.replace(".", "")
        if not clean:
            # allow empty
            return
        # allow single leading sign while typing
        if clean in ('+', '-'):
            return
        # Allow optional leading + or - followed by digits
        m = re.match(r'^([+-]?)(\d+)$', clean)
        if not m:
            # remove last entered char to keep input valid
            if clean:
                self.blockSignals(True)
                self.setText(clean[:-1])
                self.blockSignals(False)
            return
        sign, digits = m.group(1), m.group(2)
        self.blockSignals(True)
        formatted = format_currency(digits)
        if sign == '-':
            formatted = '-' + formatted
        self.setText(formatted)
        self.blockSignals(False)
    def get_value(self):
        try:
            return int(self.text().replace(".", "") or 0)
        except:
            return 0

# --- SMART MONEY INPUT (CỐT LÕI CỦA TÍNH NĂNG MỚI) ---
class SmartMoneyInput(QLineEdit):
    """
    Widget nhập tiền thông minh: 
    - Cho phép nhập số và các toán tử (+, -, *, /).
    - Tự động format dấu chấm phân cách hàng nghìn cho MỌI CON SỐ trong chuỗi phép tính.
    - Ví dụ: Nhập "1000000+20000" -> Tự hiện "1.000.000+20.000"
    """
    def __init__(self, parent=None):
        super().__init__(parent)
        self.setPlaceholderText("Nhập số hoặc phép tính...")
        self.textChanged.connect(self.format_text)
        
    def format_text(self, text):
        if not text: return
        
        # Lưu vị trí con trỏ hiện tại để khôi phục sau khi format
        cursor_pos = self.cursorPosition()
        old_len = len(text)
        
        # 1. Tách chuỗi thành các phần: Số và Toán tử
        # Regex tách số và các dấu +, -, *, /
        parts = re.split(r'([+\-*/])', text)
        
        formatted_parts = []
        for part in parts:
            # Nếu là toán tử thì giữ nguyên
            if part in ['+', '-', '*', '/']:
                formatted_parts.append(part)
            else:
                # Nếu là số: Xóa ký tự không phải số, format lại
                # Cho phép nhập trống tạm thời
                clean_num = re.sub(r'[^\d]', '', part)
                if clean_num:
                    formatted_num = "{:,.0f}".format(int(clean_num)).replace(",", ".")
                    formatted_parts.append(formatted_num)
                else:
                    formatted_parts.append("")
        
        new_text = "".join(formatted_parts)
        
        # Chỉ cập nhật nếu text thực sự thay đổi để tránh vòng lặp
        if new_text != text:
            self.blockSignals(True)
            self.setText(new_text)
            
            # Tính toán vị trí con trỏ mới thông minh
            # Nếu độ dài chuỗi tăng thêm (do thêm dấu chấm), dịch con trỏ sang phải
            new_len = len(new_text)
            diff = new_len - old_len
            new_cursor_pos = max(0, min(cursor_pos + diff, new_len))
            self.setCursorPosition(new_cursor_pos)
            
            self.blockSignals(False)

class MathDelegate(QStyledItemDelegate):
    """Delegate gắn vào bảng để kích hoạt SmartMoneyInput"""
    def createEditor(self, parent, option, index):
        editor = SmartMoneyInput(parent)
        return editor

    def setEditorData(self, editor, index):
        # Lấy giá trị hiển thị (đang có dấu chấm) đưa vào ô edit
        # Ví dụ: Trên bảng là "3.000.000", khi click vào editor cũng là "3.000.000"
        text = index.model().data(index, Qt.ItemDataRole.DisplayRole)
        if text:
            editor.setText(str(text))

    def setModelData(self, editor, model, index):
        text = editor.text()
        # 1. Loại bỏ toàn bộ dấu chấm phân cách ngàn để chuẩn bị tính toán
        # "1.000.000+20.000" -> "1000000+20000"
        clean_text = text.replace('.', '')
        
        try:
            # 2. Kiểm tra an toàn: Chỉ cho phép số và toán tử
            if not re.match(r'^[0-9+\-*/\s]+$', clean_text):
                return # Dữ liệu không hợp lệ, không làm gì cả

            # 3. Tính toán giá trị (eval)
            value = int(eval(clean_text))
            
            # 4. Lưu vào Model
            # UserRole: Lưu số nguyên (Int) để tính toán cộng trừ sau này
            model.setData(index, value, Qt.ItemDataRole.UserRole)
            
            # EditRole: Lưu chuỗi số nguyên
            model.setData(index, str(value), Qt.ItemDataRole.EditRole)
            
            # DisplayRole: Format lại có dấu chấm để hiển thị đẹp trên bảng
            model.setData(index, f"{value:,}".replace(",", "."), Qt.ItemDataRole.DisplayRole)
            
        except Exception as e:
            print(f"Lỗi tính toán: {e}")
            pass # Không lưu nếu lỗi

class ColorGroupWidget(QFrame):
    def __init__(self, color_name="", is_even=False, parent_layout=None):
        super().__init__()
        self.setFrameShape(QFrame.Shape.NoFrame)
        self.setStyleSheet(f"background-color: {'#fdfbf7' if is_even else '#ffffff'}; border-radius: 6px; margin-bottom: 5px; border: 1px solid #eee;")
        self.layout = QVBoxLayout(self)
        self.layout.setContentsMargins(10,10,10,10)
        self.layout.setAlignment(Qt.AlignmentFlag.AlignTop)
        
        h = QHBoxLayout()
        self.color_inp = QLineEdit(color_name)
        self.color_inp.setPlaceholderText("Nhập tên màu...")
        self.color_inp.setStyleSheet("font-weight: bold; border: 1px solid #ccc; background: white;")
        self.color_inp.returnPressed.connect(self.add_size_row)
        
        btn_del = QPushButton("X")
        btn_del.setObjectName("IconBtn")
        btn_del.setFixedSize(30,30)
        btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_del.clicked.connect(self.delete_self)
        
        h.addWidget(QLabel("Màu:"))
        h.addWidget(self.color_inp)
        h.addWidget(btn_del)
        self.layout.addLayout(h)
        
        self.sizes_container = QVBoxLayout()
        self.sizes_container.setAlignment(Qt.AlignmentFlag.AlignTop)
        self.layout.addLayout(self.sizes_container)
        
        btn_add = QPushButton("+ Thêm Size")
        btn_add.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_add.setObjectName("SecondaryBtn")
        btn_add.clicked.connect(self.add_size_row)
        self.layout.addWidget(btn_add)

    def add_size_row(self, data=None):
        row = QWidget()
        row_style = "background: transparent;"
        if data:
            try:
                stk = int(data.get('stock', 0))
                if stk <= 0: row_style = "background: #ef9a9a; border-radius: 4px;"
                elif stk < 20: row_style = "background: #fff59d; border-radius: 4px;"
            except: pass
        row.setStyleSheet(row_style)
        
        l = QHBoxLayout(row)
        l.setContentsMargins(5,2,5,2)
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
        btn_x.setFixedSize(25,25)
        btn_x.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_x.clicked.connect(lambda: self.remove_size_row(row))
        
        s_inp.returnPressed.connect(p_inp.setFocus)
        p_inp.returnPressed.connect(st_inp.setFocus)
        st_inp.returnPressed.connect(lambda: self.add_size_row())
        
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
    
    def remove_size_row(self, w): w.setParent(None)
    def delete_self(self):
        msg = QMessageBox(self)
        msg.setWindowTitle("Xác nhận")
        msg.setText(f"Bạn có chắc muốn xóa nhóm màu '{self.color_inp.text()}'?")
        msg.setIcon(QMessageBox.Icon.Question)
        btn_co = msg.addButton("Có", QMessageBox.ButtonRole.YesRole)
        btn_co.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_khong = msg.addButton("Không", QMessageBox.ButtonRole.NoRole)
        btn_khong.setCursor(Qt.CursorShape.PointingHandCursor)
        msg.exec()
        if msg.clickedButton() == btn_co:
            self.setParent(None)
            self.deleteLater()

    def get_data(self):
        vars = []
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
                    if size:
                        vars.append({"color": c_name, "size": size, "price": price, "stock": stock})
        return vars

class AddCustomerPanel(QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        l = QVBoxLayout(self)
        l.setContentsMargins(10, 10, 10, 10)
        l.setAlignment(Qt.AlignmentFlag.AlignTop)
        
        l.addWidget(QLabel("Thêm Khách Hàng Mới", objectName="HeaderTitle"))
        l.addSpacing(10)
        
        l.addWidget(QLabel("Tên khách hàng (*):"))
        self.name_inp = QLineEdit()
        self.name_inp.setPlaceholderText("VD: Anh Tuấn")
        self.name_inp.setStyleSheet("padding: 8px; font-weight: bold;")
        l.addWidget(self.name_inp)
        
        l.addWidget(QLabel("Số điện thoại:"))
        self.phone_inp = QLineEdit()
        self.phone_inp.setPlaceholderText("VD: 0912345678")
        l.addWidget(self.phone_inp)
        
        l.addWidget(QLabel("Dư nợ ban đầu (VNĐ):"))
        self.debt_inp = PriceInput()
        self.debt_inp.setPlaceholderText("0")
        l.addWidget(self.debt_inp)
        
        l.addSpacing(20)
        btn_add = QPushButton("Lưu Khách Hàng")
        btn_add.setObjectName("PrimaryBtn")
        btn_add.setMinimumHeight(45)
        btn_add.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_add.clicked.connect(self.save_customer)
        l.addWidget(btn_add)
        l.addStretch()

    def save_customer(self):
        name = self.name_inp.text().strip()
        if not name:
            return QMessageBox.warning(self, "Lỗi", "Vui lòng nhập tên")
        try:
            resp = requests.post(f"{API_URL}/customers", json={ "name": name, "phone": self.phone_inp.text().strip(), "debt": self.debt_inp.get_value() })
            if resp.status_code == 200:
                QMessageBox.information(self, "Thành công", "Đã thêm khách hàng mới!")
                self.name_inp.clear()
                self.phone_inp.clear()
                self.debt_inp.setText("0")
                if hasattr(self.main_window, 'refresh_debt_table'):
                    self.main_window.refresh_debt_table()
                if hasattr(self.main_window, 'load_customer_suggestions'):
                    self.main_window.load_customer_suggestions()
            else:
                QMessageBox.warning(self, "Lỗi", str(resp.json().get('detail', 'Lỗi')))
        except Exception as e:
            QMessageBox.critical(self, "Lỗi kết nối", str(e))

class OrderDetailDialog(QDialog):
    def __init__(self, order_data, parent=None):
        super().__init__(parent)
        c_name = order_data.get('customer_name') or order_data.get('customer') or "Khách lẻ"
        oid = order_data.get('id', 'N/A')
        date_str = order_data.get('created_at') or order_data.get('date', '')
        
        self.setWindowTitle(f"Chi tiết đơn #{oid} - {c_name}")
        self.setFixedSize(700, 600)
        layout = QVBoxLayout(self)
        
        info = QLabel(f"<b>Khách hàng:</b> {c_name}<br><b>Ngày mua:</b> {date_str}")
        info.setStyleSheet("font-size: 14px; margin-bottom: 10px;")
        layout.addWidget(info)
        
        table = QTableWidget(0, 4)
        table.setHorizontalHeaderLabels(["Sản phẩm", "Phân loại", "SL", "Thành tiền"])
        table.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        layout.addWidget(table)
        
        table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        
        items = order_data.get('items', [])
        total_verify = 0
        for i, item in enumerate(items):
            table.insertRow(i)
            qty = item.get('quantity') or item.get('qty', 0)
            price = item.get('price') or item.get('price_at_purchase', 0)
            total_line = qty * price
            total_verify += total_line
            
            i_name = QTableWidgetItem(str(item.get('product_name') or item.get('name', '')))
            i_name.setToolTip(i_name.text())
            i_var = QTableWidgetItem(str(item.get('variant_info') or item.get('variant', '')))
            i_var.setToolTip(i_var.text())
            i_qty = QTableWidgetItem(str(qty))
            i_qty.setToolTip(i_qty.text())
            i_total = QTableWidgetItem(f"{total_line:,}")
            i_total.setToolTip(i_total.text())
            
            table.setItem(i, 0, i_name)
            table.setItem(i, 1, i_var)
            table.setItem(i, 2, i_qty)
            table.setItem(i, 3, i_total)
            
        lbl_total = QLabel(f"Tổng cộng: {total_verify:,} VNĐ")
        lbl_total.setStyleSheet("font-size: 16px; font-weight: bold; color: #ee4d2d; alignment: right;")
        layout.addWidget(lbl_total)


class DateEditDialog(QDialog):
    def __init__(self, order_id, initial_dt_str, parent=None):
        super().__init__(parent)
        self.order_id = order_id
        self.setWindowTitle("Chỉnh sửa ngày giờ")
        self.resize(300,120)
        l = QVBoxLayout(self)
        self.dt = QDateTimeEdit()
        self.dt.setDisplayFormat("yyyy-MM-dd HH:mm")
        # Improve readability: larger text and white background for better contrast
        try:
            self.dt.setStyleSheet("background: #ffffff; color: #000000; font-size: 16px; padding: 6px;")
            self.dt.setFixedHeight(34)
        except Exception:
            pass
        try:
            from datetime import datetime
            self.dt.setDateTime(datetime.strptime(initial_dt_str, "%Y-%m-%d %H:%M"))
        except:
            pass
        l.addWidget(self.dt)
        b = QHBoxLayout()
        btn_cancel = QPushButton("Hủy")
        btn_cancel.setObjectName("SecondaryBtn")
        btn_cancel.clicked.connect(self.reject)
        btn_ok = QPushButton("Lưu")
        btn_ok.setObjectName("PrimaryBtn")
        btn_ok.clicked.connect(self.save)
        b.addStretch(); b.addWidget(btn_cancel); b.addWidget(btn_ok)
        l.addLayout(b)
        # Enter = save, Esc = cancel
        try:
            from PyQt6.QtGui import QKeySequence
            from PyQt6.QtWidgets import QShortcut
            btn_ok.setAutoDefault(True)
            btn_ok.setDefault(True)
            sc1 = QShortcut(QKeySequence('Return'), self)
            sc1.activated.connect(lambda: btn_ok.click())
            sc2 = QShortcut(QKeySequence('Enter'), self)
            sc2.activated.connect(lambda: btn_ok.click())
            sc_esc = QShortcut(QKeySequence('Esc'), self)
            sc_esc.activated.connect(lambda: btn_cancel.click())
        except:
            pass

    def save(self):
        dt_str = self.dt.dateTime().toString("yyyy-MM-dd HH:mm")
        try:
            resp = requests.put(f"{API_URL}/orders/{self.order_id}/date", json={"created_at": dt_str})
            if resp.status_code in (200, 201):
                self.accept()
            else:
                QMessageBox.warning(self, "Lỗi", str(resp.text))
        except Exception as e:
            QMessageBox.critical(self, "Lỗi kết nối", str(e))


class EditLogDialog(QDialog):
    def __init__(self, cust_id, data=None, parent=None):
        super().__init__(parent)
        self.cust_id = cust_id
        self.data = data
        self.setWindowTitle("Điều chỉnh công nợ")
        self.resize(420,200)
        l = QVBoxLayout(self)

        l.addWidget(QLabel("Nội dung:"))
        self.desc_inp = QLineEdit()
        l.addWidget(self.desc_inp)

        l.addWidget(QLabel("Số tiền (ví dụ: -100000 hoặc 100000):"))
        # Sử dụng PriceInput để tự động format dấu chấm khi gõ
        self.amt_inp = PriceInput()
        self.amt_inp.setPlaceholderText("0")
        l.addWidget(self.amt_inp)

        l.addWidget(QLabel("Ngày giờ (YYYY-MM-DD HH:MM) - để trống = hiện tại:"))
        self.dt_inp = QLineEdit()
        self.dt_inp.setPlaceholderText("YYYY-MM-DD HH:MM")
        # Nếu là tạo mới (không có dữ liệu), tự động điền thời gian hiện tại để người dùng dễ hiểu
        try:
            if not self.data:
                from datetime import datetime
                self.dt_inp.setText(datetime.now().strftime("%Y-%m-%d %H:%M"))
        except:
            pass
        l.addWidget(self.dt_inp)

        hb = QHBoxLayout()
        hb.addStretch()
        btn_cancel = QPushButton("Hủy")
        btn_cancel.setObjectName("SecondaryBtn")
        btn_cancel.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_cancel.clicked.connect(self.reject)
        btn_save = QPushButton("Lưu")
        btn_save.setObjectName("PrimaryBtn")
        btn_save.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_save.clicked.connect(self.save)
        # make save more prominent: white text and pointer already set via PrimaryBtn style
        # ensure hover sensitivity and stronger appearance
        btn_save.setStyleSheet("color: #000; font-weight: bold; padding: 10px 18px;")
        hb.addWidget(btn_cancel); hb.addWidget(btn_save)
        l.addLayout(hb)

        # Allow Enter to accept and Esc to reject in dialogs (shortcuts set up below)
        btn_save.setAutoDefault(True)
        btn_save.setDefault(True)

        if self.data:
            # prefill
            self.desc_inp.setText(self.data.get('desc') or '')
            amt = self.data.get('amount')
            if amt is not None:
                # Hiển thị đã format để dễ đọc
                try:
                    self.amt_inp.setText(format_currency(int(amt)))
                except:
                    self.amt_inp.setText(str(int(amt)))
            self.dt_inp.setText(self.data.get('date') or '')
        # shortcuts for dialogs: Enter = accept, Esc = cancel
        btn_save.setAutoDefault(True)
        btn_save.setDefault(True)
        try:
            # Use globally-imported QShortcut/QKeySequence to avoid accidental
            # local binding via an inner import which can cause UnboundLocalError
            self._sc_enter = QShortcut(QKeySequence('Return'), self)
            self._sc_enter.activated.connect(lambda: btn_save.click())
            self._sc_enter2 = QShortcut(QKeySequence('Enter'), self)
            self._sc_enter2.activated.connect(lambda: btn_save.click())
            self._sc_esc = QShortcut(QKeySequence('Esc'), self)
            self._sc_esc.activated.connect(lambda: btn_cancel.click())
        except Exception:
            # ignore if shortcuts are unavailable in the environment
            pass

    def save(self):
        desc = self.desc_inp.text().strip()
        # Use PriceInput.get_value() to reliably parse formatted amounts (supports negatives)
        amt = self.amt_inp.get_value()
        if amt == 0 and (not self.amt_inp.text().strip() or self.amt_inp.text().strip() in ['0', '0.0']):
            QMessageBox.warning(self, "Lỗi", "Vui lòng nhập số tiền")
            return

        payload = {"change_amount": amt, "note": desc}
        dt = self.dt_inp.text().strip()
        if dt:
            payload['created_at'] = dt

        try:
            if self.data and self.data.get('log_id'):
                lid = self.data.get('log_id')
                resp = requests.put(f"{API_URL}/customers/{self.cust_id}/history/{lid}", json=payload)
            else:
                resp = requests.post(f"{API_URL}/customers/{self.cust_id}/history", json=payload)
            if resp.status_code in (200,201):
                self.accept()
            else:
                QMessageBox.warning(self, "Lỗi", str(resp.text))
        except Exception as e:
            QMessageBox.critical(self, "Lỗi kết nối", str(e))

class CustomerHistoryDialog(QDialog):
    def __init__(self, cust_id, cust_name, parent=None):
        super().__init__(parent)
        self.setWindowTitle(f"Lịch sử giao dịch - {cust_name}")
        self.resize(950, 600)
        self.setStyleSheet("background: white;")
        self.cust_id = cust_id 
        self.cust_name = cust_name

        l = QVBoxLayout(self)
        # Thêm nút "Thêm điều chỉnh" để tạo log mới
        h_top = QHBoxLayout()
        btn_add_log = QPushButton("+ Thêm điều chỉnh")
        btn_add_log.setObjectName("SecondaryBtn")
        btn_add_log.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_add_log.clicked.connect(self.add_log)
        h_top.addWidget(btn_add_log)
        h_top.addStretch()
        l.addLayout(h_top)

        self.tb = QTableWidget(0, 7)
        self.tb.setHorizontalHeaderLabels(["Ngày giờ", "Loại", "Nội dung", "Số tiền", "Xem", "Sửa", "Xóa"])
        
        self.tb.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Stretch)
        self.tb.horizontalHeader().setSectionResizeMode(4, QHeaderView.ResizeMode.Fixed)
        self.tb.horizontalHeader().setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed)
        self.tb.horizontalHeader().setSectionResizeMode(6, QHeaderView.ResizeMode.Fixed)
        self.tb.setColumnWidth(4, 60)
        self.tb.setColumnWidth(5, 60)
        self.tb.setColumnWidth(6, 60)
        
        # Cho phép edit thông qua nút Sửa; không cho phép chỉnh trực tiếp để kiểm soát validate
        self.tb.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.tb.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.tb.cellClicked.connect(self.clk)
        self.tb.cellDoubleClicked.connect(self.tb_dblclick)
        
        l.addWidget(self.tb)
        l.addWidget(QLabel("<i>* Nút Xóa chỉ xóa dữ liệu, không hoàn tiền.</i>"))
        self.load(cust_id)

    def load(self, cid):
        self.tb.setRowCount(0) 
        try:
            rs = requests.get(f"{API_URL}/customers/{cid}/history").json()
            for r in rs:
                ri = self.tb.rowCount()
                self.tb.insertRow(ri)
                
                i_date = QTableWidgetItem(r['date'])
                i_date.setToolTip(r['date'])
                # Lưu metadata vào UserRole để dễ thao tác (order data or log id)
                self.tb.setItem(ri, 0, i_date)
                
                is_order = (r['type'] == "ORDER")
                display_type = "Xuất đơn hàng" if is_order else "Điều chỉnh"
                typ = QTableWidgetItem(display_type)
                typ.setForeground(QColor("blue") if is_order else QColor("green"))
                self.tb.setItem(ri, 1, typ)
                
                i_desc = QTableWidgetItem(r['desc'])
                i_desc.setToolTip(r['desc'])
                self.tb.setItem(ri, 2, i_desc)
                
                amt = QTableWidgetItem(f"{r['amount']:+,}")
                amt.setForeground(QColor("red") if r['amount']>0 else QColor("green"))
                self.tb.setItem(ri, 3, amt)
                
                # Phân biệt ORDER và LOG: tạo widget tương ứng
                if is_order:
                    # store full order data for quick access
                    self.tb.item(ri, 0).setData(Qt.ItemDataRole.UserRole, r['data'])

                    btn_view = QPushButton("Xem")
                    btn_view.setObjectName("SecondaryBtn")
                    btn_view.setCursor(Qt.CursorShape.PointingHandCursor)
                    btn_view.setStyleSheet("color: blue; text-decoration: underline; border: none; font-weight: bold;")
                    btn_view.clicked.connect(lambda _, d=r['data']: OrderDetailDialog(d, self).exec())
                    w_view = QWidget(); l_view = QHBoxLayout(w_view); l_view.setContentsMargins(0,0,0,0); l_view.setAlignment(Qt.AlignmentFlag.AlignCenter); l_view.addWidget(btn_view); self.tb.setCellWidget(ri, 4, w_view)

                    btn_edit = QPushButton("Sửa")
                    btn_edit.setCursor(Qt.CursorShape.PointingHandCursor)
                    # Use SecondaryBtn style so button looks clickable and has hover effect
                    btn_edit.setObjectName("SecondaryBtn")
                    btn_edit.clicked.connect(lambda _, d=r['data']: (self.accept(), self.parent().load_order_to_edit(d)))
                    w_edit = QWidget(); l_edit = QHBoxLayout(w_edit); l_edit.setContentsMargins(0,0,0,0); l_edit.setAlignment(Qt.AlignmentFlag.AlignCenter); l_edit.addWidget(btn_edit); self.tb.setCellWidget(ri, 5, w_edit)

                    btn_del = QPushButton("X")
                    btn_del.setObjectName("DelCustBtn")
                    btn_del.setFixedSize(30, 25)
                    btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
                    order_id = r['data'].get('id')
                    btn_del.clicked.connect(lambda _, oid=order_id: self.delete_invoice(oid))
                    w_del = QWidget(); l_del = QHBoxLayout(w_del); l_del.setContentsMargins(0,0,0,0); l_del.setAlignment(Qt.AlignmentFlag.AlignCenter); l_del.addWidget(btn_del); self.tb.setCellWidget(ri, 6, w_del)
                else:
                    # LOG: lưu log id vào UserRole
                    log_id = r.get('log_id')
                    self.tb.item(ri, 0).setData(Qt.ItemDataRole.UserRole, { 'log_id': log_id })

                    btn_view = QPushButton("")
                    btn_view.setEnabled(False)
                    btn_view.setCursor(Qt.CursorShape.ArrowCursor)
                    self.tb.setCellWidget(ri, 4, btn_view)

                    btn_edit = QPushButton("Sửa")
                    btn_edit.setObjectName("SecondaryBtn")
                    btn_edit.setCursor(Qt.CursorShape.PointingHandCursor)
                    # ensure hover shows pointer and stronger visual
                    btn_edit.clicked.connect(lambda _, row=ri, rec=r: self.edit_log(rec))
                    w_edit = QWidget(); l_edit = QHBoxLayout(w_edit); l_edit.setContentsMargins(0,0,0,0); l_edit.setAlignment(Qt.AlignmentFlag.AlignCenter); l_edit.addWidget(btn_edit); self.tb.setCellWidget(ri, 5, w_edit)

                    btn_del = QPushButton("X")
                    btn_del.setObjectName("DelCustBtn")
                    btn_del.setFixedSize(30, 25)
                    btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
                    btn_del.clicked.connect(lambda _, lid=log_id: self.delete_log(lid))
                    w_del = QWidget(); l_del = QHBoxLayout(w_del); l_del.setContentsMargins(0,0,0,0); l_del.setAlignment(Qt.AlignmentFlag.AlignCenter); l_del.addWidget(btn_del); self.tb.setCellWidget(ri, 6, w_del)
                    
        except Exception as e:
            print("Lỗi load lịch sử:", e)

    def clk(self, r, c): 
        if c in [4, 5, 6]: return
        d = self.tb.item(r, 0).data(Qt.ItemDataRole.UserRole)
        # chỉ mở detail nếu là order và meta chứa 'id'
        if isinstance(d, dict) and d.get('id'):
            OrderDetailDialog(d, self).exec()

    def tb_dblclick(self, r, c):
        # Double click trên cột ngày của ORDER cho phép chỉnh ngày
        if c != 0: return
        meta = self.tb.item(r, 0).data(Qt.ItemDataRole.UserRole)
        if not meta: return
        # Nếu là order (meta is dict with id)
        if isinstance(meta, dict) and meta.get('id'):
            oid = meta.get('id')
            # open dialog to edit date
            dlg = DateEditDialog(oid, meta.get('created_at') or self.tb.item(r,0).text(), parent=self)
            if dlg.exec():
                self.load(self.cust_id)

    def add_log(self):
        dlg = EditLogDialog(self.cust_id, parent=self)
        if dlg.exec():
            self.load(self.cust_id)
            # refresh main window debt table if available
            try:
                if hasattr(self.parent(), 'refresh_debt_table'):
                    self.parent().refresh_debt_table()
            except: pass

    def edit_log(self, rec):
        # rec is history record dict for the log
        dlg = EditLogDialog(self.cust_id, data=rec, parent=self)
        if dlg.exec():
            self.load(self.cust_id)
            try:
                if hasattr(self.parent(), 'refresh_debt_table'):
                    self.parent().refresh_debt_table()
            except: pass

    def delete_log(self, log_id):
        if not log_id: return
        msg = QMessageBox(self)
        msg.setWindowTitle("Xác nhận xóa")
        msg.setText("Bạn có chắc chắn muốn xóa bản ghi điều chỉnh này? (Không hoàn tiền)")
        msg.setIcon(QMessageBox.Icon.Warning)
        btn_co = msg.addButton("Có", QMessageBox.ButtonRole.YesRole)
        btn_khong = msg.addButton("Không", QMessageBox.ButtonRole.NoRole)
        msg.exec()
        if msg.clickedButton() == btn_co:
            try:
                requests.delete(f"{API_URL}/customers/{self.cust_id}/history/{log_id}")
                self.load(self.cust_id)
                try:
                    if hasattr(self.parent(), 'refresh_debt_table'):
                        self.parent().refresh_debt_table()
                except: pass
            except Exception as e:
                print(e)

    def delete_invoice(self, order_id):
        msg = QMessageBox(self)
        msg.setWindowTitle("Xác nhận xóa")
        msg.setText("Bạn có chắc chắn muốn xóa Hóa đơn này?")
        msg.setIcon(QMessageBox.Icon.Warning)
        
        btn_co = msg.addButton("Có", QMessageBox.ButtonRole.YesRole)
        btn_co.setCursor(Qt.CursorShape.PointingHandCursor)
        
        btn_khong = msg.addButton("Không", QMessageBox.ButtonRole.NoRole)
        btn_khong.setCursor(Qt.CursorShape.PointingHandCursor)
        
        msg.exec()
        if msg.clickedButton() == btn_co:
            try:
                requests.delete(f"{API_URL}/orders/{order_id}")
                self.load(self.cust_id)
            except: pass

class ProductBuyDialog(QDialog): 
    def __init__(self, product_data, parent=None):
        super().__init__(parent)
        self.setWindowTitle("Chọn phân loại")
        self.resize(600, 650)
        self.setStyleSheet("QDialog { background-color: #ffffff; }")
        self.product = product_data
        self.selected_items = []
        
        l = QVBoxLayout(self)
        
        h = QHBoxLayout()
        img = QLabel()
        img.setPixmap(get_centered_image(self.product['image'], QSize(90, 90)))
        i = QVBoxLayout()
        i.addWidget(QLabel(f"<h2>{self.product['name']}</h2>"))
        i.addWidget(QLabel(f"Giá: <span style='color:#ee4d2d; font-weight:bold'>{self.product['price_range']} đ</span>"))
        h.addWidget(img)
        h.addLayout(i)
        l.addLayout(h)
        
        s = QScrollArea()
        s.setWidgetResizable(True)
        c = QWidget()
        c.setStyleSheet("background-color: #fff;")
        f = QVBoxLayout(c)
        f.setAlignment(Qt.AlignmentFlag.AlignTop)
        f.setSpacing(10)
        
        v_by_c = {}
        self.spins = {}
        for v in self.product['variants']:
            v_by_c.setdefault(v['color'], []).append(v)
        
        for idx, (col, vars) in enumerate(v_by_c.items()):
            gf = QFrame()
            gf.setStyleSheet(f".QFrame {{ background-color: {'#ffffff' if idx%2==0 else '#f8f9fa'}; border: 1px solid #e9ecef; border-radius: 6px; }}")
            gl = QVBoxLayout(gf)
            gl.addWidget(QLabel(col.upper()))
            g = QGridLayout()
            for j, v in enumerate(vars):
                sp = QSpinBox()
                sp.setRange(0, v['stock'])
                sp.setFixedWidth(100)
                self.spins[v['id']] = sp
                
                lbl_style = "padding: 2px; border-radius: 3px;"
                status_txt = ""
                bg = "#fff59d" if v['stock'] < 20 else ""
                
                if v['stock'] <= 0:
                    sp.setEnabled(False)
                    status_txt=" (HẾT)"
                    bg="#ef9a9a; font-weight: bold;"
                
                lb_sz = QLabel(f"Size {v['size']}")
                lb_sz.setStyleSheet(f"background-color: {bg}" if bg else "")
                
                lb_pr = QLabel(f"{v['price']:,}đ (Kho: {v['stock']}){status_txt}")
                lb_pr.setStyleSheet(f"background-color: {bg}" if bg else "")
                
                g.addWidget(lb_sz, j, 0)
                g.addWidget(lb_pr, j, 1)
                g.addWidget(sp, j, 2)
            gl.addLayout(g)
            f.addWidget(gf)
        
        c.setLayout(f)
        s.setWidget(c)
        l.addWidget(s)
        
        b = QHBoxLayout()
        b.addStretch()
        bc = QPushButton("Hủy bỏ")
        bc.setObjectName("SecondaryBtn")
        bc.setCursor(Qt.CursorShape.PointingHandCursor)
        bc.clicked.connect(self.reject)
        ba = QPushButton("Thêm vào đơn")
        ba.setObjectName("PrimaryBtn")
        ba.setCursor(Qt.CursorShape.PointingHandCursor)
        ba.clicked.connect(self.add)
        b.addWidget(bc)
        b.addWidget(ba)
        l.addLayout(b)
        # Enter = add, Esc = cancel
        try:
            from PyQt6.QtGui import QKeySequence
            from PyQt6.QtWidgets import QShortcut
            ba.setAutoDefault(True)
            ba.setDefault(True)
            sc1 = QShortcut(QKeySequence('Return'), self)
            sc1.activated.connect(lambda: ba.click())
            sc2 = QShortcut(QKeySequence('Enter'), self)
            sc2.activated.connect(lambda: ba.click())
            sc_esc = QShortcut(QKeySequence('Esc'), self)
            sc_esc.activated.connect(lambda: bc.click())
        except:
            pass

    def add(self):
        for vid, sp in self.spins.items():
            if sp.value() > 0:
                v = next(x for x in self.product['variants'] if x['id'] == vid)
                self.selected_items.append({"variant_id": v['id'], "product_name": self.product['name'], "color": v['color'], "size": v['size'], "price": v['price'], "quantity": sp.value()})
        self.accept()

class EditProductDialog(QDialog):
    def __init__(self, product_data, parent_window):
        super().__init__(parent_window)
        self.setWindowTitle(f"Chỉnh sửa: {product_data['name']}")
        self.resize(500, 600)
        self.product = product_data
        self.main_window = parent_window
        self.img_path = product_data['image']
        
        l = QVBoxLayout(self)
        self.name_inp = QLineEdit(self.product['name'])
        l.addWidget(self.name_inp)
        
        ib = QHBoxLayout()
        self.img_lbl = QLabel()
        self.img_lbl.setPixmap(get_centered_image(self.img_path, QSize(60, 60)))
        bi = QPushButton("Đổi ảnh")
        bi.setObjectName("SecondaryBtn")
        bi.setCursor(Qt.CursorShape.PointingHandCursor)
        bi.clicked.connect(self.choose_image)
        ib.addWidget(self.img_lbl)
        ib.addWidget(bi)
        l.addLayout(ib)
        
        s = QScrollArea()
        s.setWidgetResizable(True)
        self.vc = QWidget()
        self.vc.setStyleSheet("background-color: #f5f5f5;")
        self.vl = QVBoxLayout(self.vc)
        self.vl.setAlignment(Qt.AlignmentFlag.AlignTop)
        s.setWidget(self.vc)
        l.addWidget(s)
        
        ba = QPushButton("+ Thêm Nhóm Màu")
        ba.setObjectName("SecondaryBtn")
        ba.setCursor(Qt.CursorShape.PointingHandCursor)
        ba.clicked.connect(self.add_color_group)
        l.addWidget(ba)
        
        bs = QPushButton("Lưu Thay Đổi")
        bs.setObjectName("PrimaryBtn")
        bs.setCursor(Qt.CursorShape.PointingHandCursor)
        bs.clicked.connect(self.save)
        l.addWidget(bs)
        
        bd = QPushButton("XÓA SẢN PHẨM")
        bd.setObjectName("DeleteBtn")
        bd.setCursor(Qt.CursorShape.PointingHandCursor)
        bd.clicked.connect(self.delete_prod)
        l.addWidget(bd)
        
        self.load()
        # Enter = save, Esc = close
        try:
            from PyQt6.QtGui import QKeySequence
            from PyQt6.QtWidgets import QShortcut
            bs.setAutoDefault(True)
            bs.setDefault(True)
            sc1 = QShortcut(QKeySequence('Return'), self)
            sc1.activated.connect(lambda: bs.click())
            sc2 = QShortcut(QKeySequence('Enter'), self)
            sc2.activated.connect(lambda: bs.click())
            sc_esc = QShortcut(QKeySequence('Esc'), self)
            sc_esc.activated.connect(lambda: self.reject())
        except:
            pass
    
    def load(self):
        vbc = {}
        for v in self.product['variants']:
            vbc.setdefault(v['color'], []).append(v)

        for i, (c, vars) in enumerate(vbc.items()):
            g = ColorGroupWidget(c, is_even=(i%2==0))
            self.vl.addWidget(g)
            for v in vars:
                g.add_size_row(v)
    
    def add_color_group(self):
        g = ColorGroupWidget("", is_even=(self.vl.count()%2==0))
        self.vl.addWidget(g)
        g.color_inp.setFocus()
    
    def choose_image(self):
        file_path = open_file_dialog_safe()
        if file_path:
            target_folder = "assets/images"
            if not os.path.exists(target_folder):
                os.makedirs(target_folder)
            abs_file = os.path.abspath(file_path)
            abs_target = os.path.abspath(target_folder)
            
            if abs_file.startswith(abs_target):
                self.img_path = os.path.relpath(abs_file, os.getcwd()).replace("\\", "/")
            else:
                nm, ext = os.path.splitext(os.path.basename(file_path))
                uniq = f"{nm}_{int(time.time())}{ext}"
                dest = os.path.join(target_folder, uniq)
                try:
                    shutil.copy(file_path, dest)
                    self.img_path = dest.replace("\\", "/")
                except Exception as e:
                    print(e)
            self.img_lbl.setPixmap(get_centered_image(self.img_path, QSize(60, 60)))
            
    def save(self):
        vars = []
        for i in range(self.vl.count()):
            w = self.vl.itemAt(i).widget()
            if w:
                vars.extend(w.get_data())
        try:
            requests.put(f"{API_URL}/products/{self.product['id']}", json={"name": self.name_inp.text(), "image_path": self.img_path, "variants": vars})
            self.accept()
            self.main_window.load_products_for_grid()
        except Exception as e:
            QMessageBox.critical(self, "Lỗi", str(e))
    
    def delete_prod(self):
        msg = QMessageBox(self)
        msg.setWindowTitle("Xác nhận xóa")
        msg.setText("Bạn có chắc chắn muốn xóa sản phẩm này vĩnh viễn?")
        msg.setIcon(QMessageBox.Icon.Warning)
        btn_co = msg.addButton("Có", QMessageBox.ButtonRole.YesRole)
        btn_co.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_khong = msg.addButton("Không", QMessageBox.ButtonRole.NoRole)
        btn_khong.setCursor(Qt.CursorShape.PointingHandCursor)
        msg.exec()
        if msg.clickedButton() == btn_co: 
            requests.delete(f"{API_URL}/products/{self.product['id']}")
            self.accept()
            self.main_window.load_products_for_grid()

class AddProductPanel(QWidget):
    def __init__(self, main_window):
        super().__init__()
        self.main_window = main_window
        l = QVBoxLayout(self)
        l.setContentsMargins(10, 10, 10, 10)
        
        l.addWidget(QLabel("Thêm Sản Phẩm Mới", objectName="HeaderTitle"))
        self.name_inp = QLineEdit()
        self.name_inp.setPlaceholderText("Tên giày...")
        l.addWidget(self.name_inp)
        
        ib = QHBoxLayout()
        self.img_path = ""
        self.img_lbl = QLabel("No Img")
        self.img_lbl.setFixedSize(60, 60)
        bi = QPushButton("Chọn ảnh")
        bi.setObjectName("SecondaryBtn")
        bi.setCursor(Qt.CursorShape.PointingHandCursor)
        bi.clicked.connect(self.choose_image)
        ib.addWidget(self.img_lbl)
        ib.addWidget(bi)
        l.addLayout(ib)
        
        s = QScrollArea()
        s.setWidgetResizable(True)
        self.vc = QWidget()
        self.vl = QVBoxLayout(self.vc)
        self.vl.setAlignment(Qt.AlignmentFlag.AlignTop)
        s.setWidget(self.vc)
        l.addWidget(s)
        
        ba = QPushButton("+ Nhóm Màu")
        ba.setObjectName("SecondaryBtn")
        ba.setCursor(Qt.CursorShape.PointingHandCursor)
        ba.clicked.connect(self.add_color_group)
        l.addWidget(ba)
        
        bs = QPushButton("Lưu")
        bs.setObjectName("PrimaryBtn")
        bs.setMinimumHeight(45)
        bs.setCursor(Qt.CursorShape.PointingHandCursor)
        bs.clicked.connect(self.save)
        # emphasize save button visually
        bs.setStyleSheet("font-weight: bold; padding: 10px 18px;")
        l.addWidget(bs)
        
        self.add_color_group()
    
    def add_color_group(self):
        g = ColorGroupWidget("", is_even=(self.vl.count()%2==0))
        self.vl.addWidget(g)
        g.color_inp.setFocus()
    
    def choose_image(self):
        file_path = open_file_dialog_safe()
        if file_path:
            target_folder = "assets/images"
            if not os.path.exists(target_folder):
                os.makedirs(target_folder)
            abs_file = os.path.abspath(file_path)
            abs_target = os.path.abspath(target_folder)
            if abs_file.startswith(abs_target):
                self.img_path = os.path.relpath(abs_file, os.getcwd()).replace("\\", "/")
            else:
                nm, ext = os.path.splitext(os.path.basename(file_path))
                uniq = f"{nm}_{int(time.time())}{ext}"
                dest = os.path.join(target_folder, uniq)
                try:
                    shutil.copy(file_path, dest)
                    self.img_path = dest.replace("\\", "/")
                except Exception as e:
                    print(e)
            self.img_lbl.setPixmap(get_centered_image(self.img_path, QSize(60, 60)))
            
    def reset_form(self):
        self.name_inp.clear()
        self.img_path = ""
        self.img_lbl.clear()
        for i in reversed(range(self.vl.count())):
            w = self.vl.itemAt(i).widget()
            if w: w.setParent(None)
        self.add_color_group()
    
    def save(self):
        vars = []
        for i in range(self.vl.count()):
            w = self.vl.itemAt(i).widget()
            if w: vars.extend(w.get_data())
        if not vars: return
        requests.post(f"{API_URL}/products", json={"name":self.name_inp.text(), "image_path":self.img_path, "variants":vars, "description":""})
        self.main_window.load_products_for_grid()
        self.reset_form()

class MainWindow(QMainWindow):
    def __init__(self):
        super().__init__()
        self.setWindowTitle("Quản lý kho & Công nợ")
        self.resize(1280, 800)
        self.setStyleSheet(SHOPEE_THEME)
        self.cart = []
        self.editing_order_id = None
        self.all_products_cache = []
        self.rendered_count = 0
        self.BATCH_SIZE = 30
        
        self.search_timer = QTimer()
        self.search_timer.setSingleShot(True)
        self.search_timer.setInterval(400)
        self.search_timer.timeout.connect(self.exec_search)
        self.current_query = ""
        
        self.resize_timer = QTimer()
        self.resize_timer.setSingleShot(True)
        self.resize_timer.setInterval(150)
        self.resize_timer.timeout.connect(self.recalc_grid)
        self.active_threads = [] 

        c = QWidget()
        self.setCentralWidget(c)
        main = QHBoxLayout(c)
        main.setContentsMargins(0,0,0,0)
        main.setSpacing(0)
        
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
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.clicked.connect(lambda: self.switch_page(i))
            self.ng.addButton(b)
            sl.addWidget(b)
            return b
            
        self.b_pos = mk_nav("📦 Xuất hàng", 0)
        self.b_pos.setChecked(True)
        mk_nav("✏️ Kho hàng", 1)
        mk_nav("👥 Công nợ", 2)
        mk_nav("🧾 Hóa đơn", 3)
        sl.addStretch()
        main.addWidget(sb)

        self.stack = QStackedWidget()
        self.page_grid = QWidget()
        self.setup_grid_layout(self.page_grid)
        self.stack.addWidget(self.page_grid)
        
        self.page_debt = self.setup_debt_page()
        self.stack.addWidget(self.page_debt)
        
        self.page_his = self.setup_history_page()
        self.stack.addWidget(self.page_his)
        main.addWidget(self.stack)
        
        QTimer.singleShot(100, lambda: (self.switch_page(0), self.load_products_for_grid(), self.load_customer_suggestions()))

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
        elif i == 2:
            self.stack.setCurrentIndex(1)
            self.refresh_debt_table()
        else:
            self.stack.setCurrentIndex(2)
            self.refresh_history()

    def setup_grid_layout(self, p):
        l = QHBoxLayout(p)
        l.setContentsMargins(10,10,10,10)
        lp = QWidget()
        ll = QVBoxLayout(lp)
        ll.setContentsMargins(0,0,0,0)
        
        h = QHBoxLayout()
        self.ht = QLabel("Xuất Hàng")
        self.ht.setObjectName("HeaderTitle")
        s = QLineEdit()
        s.setPlaceholderText("🔍 Tìm kiếm (Tên SP)...")
        s.textChanged.connect(self.on_search_text_changed)
        h.addWidget(self.ht)
        h.addStretch()
        h.addWidget(s)
        ll.addLayout(h)
        
        self.gs = QScrollArea()
        self.gs.setWidgetResizable(True)
        self.gs.setStyleSheet("border:none; background: #f5f5f5;")
        self.gc = QWidget()
        self.pg = QGridLayout(self.gc)
        self.pg.setAlignment(Qt.AlignmentFlag.AlignTop|Qt.AlignmentFlag.AlignLeft)
        self.pg.setSpacing(10)
        self.gs.setWidget(self.gc)
        ll.addWidget(self.gs)
        # Connect scroll bar to enable lazy loading when user scrolls near bottom
        self.gs.verticalScrollBar().valueChanged.connect(self.on_scroll)
        l.addWidget(lp, 1) 

        self.rp = QWidget()
        self.rp.setFixedWidth(400)
        self.rp.setStyleSheet("background: white; border: 1px solid #ddd;")
        rl = QVBoxLayout(self.rp)
        rl.setContentsMargins(0,0,0,0)
        
        self.rs = QStackedWidget()
        cw = QWidget()
        cl = QVBoxLayout(cw)
        cl.addWidget(QLabel("<b>Thông tin khách hàng:</b>"))
        
        self.cust_completer = QCompleter([])
        self.cust_completer.setCaseSensitivity(Qt.CaseSensitivity.CaseInsensitive)
        self.cust_name_inp = QLineEdit()
        self.cust_name_inp.setPlaceholderText("Nhập tên khách")
        self.cust_name_inp.setCompleter(self.cust_completer)
        self.cust_name_inp.setStyleSheet("padding: 8px; border: 1px solid #ee4d2d;")
        cl.addWidget(self.cust_name_inp)
        self.cust_phone_inp = QLineEdit()
        self.cust_phone_inp.setPlaceholderText("Số điện thoại")
        cl.addWidget(self.cust_phone_inp)
        
        cl.addWidget(QLabel("<b>Giỏ hàng:</b>"))
        self.ct = QTableWidget(0, 4)
        self.ct.setHorizontalHeaderLabels(["SP", "SL", "Đ.Giá", "X"])
        self.ct.verticalHeader().setVisible(False)
        self.ct.setEditTriggers(QAbstractItemView.EditTrigger.DoubleClicked | QAbstractItemView.EditTrigger.AnyKeyPressed)
        self.ct.itemChanged.connect(self.on_cart_qty_changed)
        self.ct.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.ct.horizontalHeader().setSectionResizeMode(0, QHeaderView.ResizeMode.Stretch)
        self.ct.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Fixed)
        self.ct.setColumnWidth(1, 35)
        self.ct.horizontalHeader().setSectionResizeMode(2, QHeaderView.ResizeMode.Fixed)
        self.ct.setColumnWidth(2, 80)
        self.ct.horizontalHeader().setSectionResizeMode(3, QHeaderView.ResizeMode.Fixed)
        self.ct.setColumnWidth(3, 25)
        self.ct.setHorizontalScrollBarPolicy(Qt.ScrollBarPolicy.ScrollBarAlwaysOff)
        cl.addWidget(self.ct)
        
        self.lbl_total = QLabel("0 món - 0 đ")
        self.lbl_total.setStyleSheet("font-size: 18px; color: #ee4d2d; font-weight: bold; margin: 10px 0;")
        cl.addWidget(self.lbl_total)
        
        self.btn_checkout = QPushButton("Xuất hàng")
        self.btn_checkout.setObjectName("PrimaryBtn")
        self.btn_checkout.setMinimumHeight(50)
        self.btn_checkout.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_checkout.clicked.connect(self.checkout)
        # Slightly enhance visual affordance programmatically for checkout primary action
        self.btn_checkout.setStyleSheet("font-weight: bold; padding: 12px 20px;")
        cl.addWidget(self.btn_checkout)
        
        self.rs.addWidget(cw)
        self.rs.addWidget(AddProductPanel(self))
        rl.addWidget(self.rs)
        l.addWidget(self.rp, 0)

    def on_search_text_changed(self, text):
        self.current_query = text
        self.search_timer.start()
    
    def exec_search(self):
        self.load_products_for_grid(self.current_query)
    
    def load_products_for_grid(self, q=""):
        qt = q if isinstance(q, str) else ""
        worker = APIGetWorker(f"/products?search={qt}")
        worker.data_ready.connect(self.on_loaded)
        self.active_threads.append(worker)
        worker.finished.connect(lambda: self.cleanup_thread(worker))
        worker.start()

    def cleanup_thread(self, worker):
        if worker in self.active_threads: self.active_threads.remove(worker)
        worker.deleteLater()

    def on_loaded(self, data):
        self.all_products_cache = data if isinstance(data, list) else []
        self.rendered_count = 0
        for i in reversed(range(self.pg.count())): 
            w = self.pg.itemAt(i).widget()
            if w: w.setParent(None)
        self.render_next_batch()

    def render_next_batch(self):
        if self.rendered_count >= len(self.all_products_cache): return
        end_idx = min(self.rendered_count + self.BATCH_SIZE, len(self.all_products_cache))
        batch = self.all_products_cache[self.rendered_count : end_idx]
        w = self.gs.viewport().width() - 20
        cols = max(1, w // 155)
        for p in batch:
            r, c = divmod(self.rendered_count, cols)
            self.pg.addWidget(self.create_card(p), r, c)
            self.rendered_count += 1

    def on_scroll(self, value):
        bar = self.gs.verticalScrollBar()
        if value > bar.maximum() * 0.9: self.render_next_batch()

    def resizeEvent(self, e):
        self.resize_timer.start()
        super().resizeEvent(e)

    def recalc_grid(self):
        if self.stack.currentIndex() not in [0, 1] or not self.pg.count(): return
        w = self.gs.viewport().width() - 20
        cols = max(1, w // 155)
        self.gc.setUpdatesEnabled(False)
        widgets = []
        for i in reversed(range(self.pg.count())): 
            item = self.pg.itemAt(i)
            if item.widget(): widgets.insert(0, item.widget())
            self.pg.removeItem(item)
        for idx, widget in enumerate(widgets):
            r, c = divmod(idx, cols)
            self.pg.addWidget(widget, r, c)
        self.gc.setUpdatesEnabled(True)
    
    def create_card(self, p):
        card = QFrame()
        card.setObjectName("ProductCard")
        card.setFixedSize(145, 220)
        card.setCursor(Qt.CursorShape.PointingHandCursor)
        card.mousePressEvent = lambda e, data=p: self.on_card_click(data)
        
        total = sum([v['stock'] for v in p['variants']])
        has_low = any(v['stock'] < 20 for v in p['variants'])
        bg = "#fff"
        if total <= 0: bg = "#ef9a9a"
        elif has_low: bg = "#fff59d"
        
        card.setStyleSheet(f"QFrame#ProductCard {{ background-color: {bg}; border: 1px solid #eaeaea; border-radius: 4px; }} QFrame#ProductCard:hover {{ border: 1px solid #ee4d2d; }}")
        l = QVBoxLayout(card)
        l.setContentsMargins(5,5,5,5)
        l.setSpacing(2)
        
        img = QLabel()
        img.setAlignment(Qt.AlignmentFlag.AlignCenter)
        img.setPixmap(get_centered_image(p['image'], QSize(135, 135)))
        n = QLabel(p['name'])
        n.setWordWrap(True)
        n.setFixedHeight(35)
        n.setAlignment(Qt.AlignmentFlag.AlignTop)
        
        l.addWidget(img)
        l.addWidget(n)
        l.addWidget(QLabel(f"{p['price_range']} đ"))
        return card
    
    def on_card_click(self, p):
        if self.mode == "POS":
            d = ProductBuyDialog(p, self)
            if d.exec():
                self.cart.extend(d.selected_items)
                self.update_cart_ui()
        else:
            EditProductDialog(p, self).exec()
            self.load_products_for_grid(self.current_query)
    
    def on_cart_qty_changed(self, item):
        row = item.row()
        col = item.column()
        if col != 1: return
        try:
            new_qty = int(item.text())
            if new_qty <= 0: raise ValueError("SL phải > 0")
            self.cart[row]['quantity'] = new_qty
            self.recalculate_total()
        except:
            old_qty = self.cart[row]['quantity']
            self.ct.blockSignals(True)
            item.setText(str(old_qty))
            self.ct.blockSignals(False)
            QMessageBox.warning(self, "Lỗi", "Số lượng phải là số nguyên dương!")

    def recalculate_total(self):
        total = 0
        qty = 0
        for it in self.cart:
            total += it['price'] * it['quantity']
            qty += it['quantity']
        self.lbl_total.setText(f"Tổng: {qty} món - {total:,} đ")

    def update_cart_ui(self):
        self.ct.blockSignals(True)
        self.ct.setRowCount(0)
        total = 0
        qty = 0
        for i, it in enumerate(self.cart):
            self.ct.insertRow(i)
            
            disp_text = f"{it['product_name']} - {it['size']}/{it['color']}"
            item_name = QTableWidgetItem(disp_text)
            item_name.setToolTip(disp_text)
            item_name.setFlags(Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled)
            self.ct.setItem(i, 0, item_name)
            
            s = it['price'] * it['quantity']
            total += s
            qty += it['quantity']
            
            item_qty = QTableWidgetItem(str(it['quantity']))
            item_qty.setTextAlignment(Qt.AlignmentFlag.AlignCenter)
            item_qty.setFlags(Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled | Qt.ItemFlag.ItemIsEditable)
            self.ct.setItem(i, 1, item_qty)
            
            item_price = QTableWidgetItem(f"{it['price']:,}")
            item_price.setToolTip(f"Thành tiền: {s:,}")
            item_price.setFlags(Qt.ItemFlag.ItemIsSelectable | Qt.ItemFlag.ItemIsEnabled)
            self.ct.setItem(i, 2, item_price)
            
            b = QPushButton("x")
            b.setObjectName("RemoveRowBtn")
            b.setCursor(Qt.CursorShape.PointingHandCursor)
            b.clicked.connect(lambda _, x=i: self.remove_cart(x))
            self.ct.setCellWidget(i, 3, b)
            
        self.ct.resizeRowsToContents()
        self.lbl_total.setText(f"Tổng: {qty} món - {total:,} đ")
        self.ct.blockSignals(False)
        
    def remove_cart(self, i):
        del self.cart[i]
        self.update_cart_ui()

    def checkout(self):
        if not self.cart: return
        endpoint = "/checkout"
        method = requests.post
        payload = {"customer_name": self.cust_name_inp.text(), "customer_phone": self.cust_phone_inp.text(), "cart": self.cart}
        if self.editing_order_id:
            endpoint = f"/orders/{self.editing_order_id}"
            method = requests.put
        try:
            response = method(f"{API_URL}{endpoint}", json=payload)
            if response.status_code == 200:
                msg = "Đã cập nhật đơn hàng!" if self.editing_order_id else "Đã xuất kho và tạo hóa đơn!"
                QMessageBox.information(self, "Thành công", msg)
                self.cart = []
                self.cust_name_inp.clear()
                self.cust_phone_inp.clear()
                self.editing_order_id = None
                self.btn_checkout.setText("Xuất hàng")
                self.update_cart_ui()
                self.load_products_for_grid(self.current_query)
                self.load_customer_suggestions()
                self.refresh_debt_table()
                self.refresh_history()
            else:
                QMessageBox.warning(self, "Lỗi", f"Thất bại:\n{response.json().get('detail', 'Lỗi')}")
        except Exception as e:
            QMessageBox.warning(self, "Lỗi kết nối", str(e))
    
    def filter_debt_table(self, text):
        search_text = text.lower().strip()
        for i in range(self.debt_table.rowCount()):
            item_name = self.debt_table.item(i, 1)
            item_phone = self.debt_table.item(i, 2)
            name = item_name.text().lower() if item_name else ""
            phone = item_phone.text().lower() if item_phone else ""
            self.debt_table.setRowHidden(i, not (search_text in name or search_text in phone))
    
    def setup_debt_page(self):
        w = QWidget()
        main_layout = QHBoxLayout(w)
        main_layout.setContentsMargins(10, 10, 10, 10)
        left_panel = QWidget()
        l = QVBoxLayout(left_panel)
        l.setContentsMargins(0, 0, 0, 0)
        
        h = QHBoxLayout()
        h.addWidget(QLabel("Quản lý Công Nợ", objectName="HeaderTitle"))
        self.debt_search = QLineEdit()
        self.debt_search.setPlaceholderText("🔍 Tìm tên hoặc SĐT...")
        self.debt_search.setFixedWidth(250)
        self.debt_search.textChanged.connect(self.filter_debt_table)
        h.addWidget(self.debt_search)
        
        b = QPushButton("Làm mới")
        b.setObjectName("SecondaryBtn")
        b.setCursor(Qt.CursorShape.PointingHandCursor)
        b.clicked.connect(self.refresh_debt_table)
        h.addWidget(b)
        h.addStretch()
        l.addLayout(h)
        
        self.debt_table = QTableWidget(0, 6)
        self.debt_table.setHorizontalHeaderLabels(["ID", "Tên Khách", "SĐT", "Dư Nợ (VNĐ)", "Lịch sử", "Xóa"])
        self.debt_table.setColumnHidden(0, True)
        self.debt_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.debt_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed)
        self.debt_table.setColumnWidth(5, 50)
        self.debt_table.verticalHeader().setDefaultSectionSize(40)
        # Bỏ các trigger edit mặc định để Delegate hoạt động tốt hơn
        self.debt_table.setEditTriggers(QAbstractItemView.EditTrigger.DoubleClicked | QAbstractItemView.EditTrigger.SelectedClicked | QAbstractItemView.EditTrigger.AnyKeyPressed | QAbstractItemView.EditTrigger.CurrentChanged)
        
        # --- CÀI ĐẶT DELEGATE CHO CỘT NỢ (CỘT 3) ---
        self.debt_table.setItemDelegateForColumn(3, MathDelegate(self.debt_table))
        # Kết nối sự kiện thay đổi dữ liệu (để gọi API)
        self.debt_table.itemChanged.connect(self.on_debt_cell_changed)
        
        l.addWidget(self.debt_table)
        
        right_panel = QWidget()
        right_panel.setFixedWidth(400)
        right_panel.setStyleSheet("background: white; border: 1px solid #ddd; border-radius: 4px;")
        rp_layout = QVBoxLayout(right_panel)
        rp_layout.setContentsMargins(0,0,0,0)
        rp_layout.addWidget(AddCustomerPanel(self))
        main_layout.addWidget(left_panel, 1)
        main_layout.addWidget(right_panel, 0)
        return w
    
    def refresh_debt_table(self):
        self.debt_table.setUpdatesEnabled(False)
        self.debt_table.setSortingEnabled(False)
        self.debt_table.blockSignals(True)
        self.debt_table.setRowCount(0)
        try:
            custs = requests.get(f"{API_URL}/customers").json()
            for i, c in enumerate(custs):
                self.debt_table.insertRow(i)
                item_id = QTableWidgetItem(str(c['id']))
                item_id.setFlags(item_id.flags() ^ Qt.ItemFlag.ItemIsEditable)
                self.debt_table.setItem(i, 0, item_id)
                self.debt_table.setItem(i, 1, QTableWidgetItem(c['name']))
                self.debt_table.setItem(i, 2, QTableWidgetItem(c['phone']))
                
                # CHỈ CẦN LƯU GIÁ TRỊ VÀO EditRole/DisplayRole
                item_debt = QTableWidgetItem()
                item_debt.setData(Qt.ItemDataRole.EditRole, str(c['debt'])) # Giá trị thực cho Delegate
                item_debt.setData(Qt.ItemDataRole.DisplayRole, f"{c['debt']:,}") # Hiển thị có dấu phẩy
                item_debt.setData(Qt.ItemDataRole.UserRole, c['debt']) # Lưu giá trị gốc để tính toán
                
                if c['debt'] > 0: item_debt.setForeground(QColor("red"))
                else: item_debt.setForeground(QColor("black"))
                self.debt_table.setItem(i, 3, item_debt)
                
                btn_view = QPushButton("Xem")
                btn_view.setObjectName("SecondaryBtn")
                btn_view.setCursor(Qt.CursorShape.PointingHandCursor)
                btn_view.clicked.connect(lambda _, cid=c['id'], name=c['name']: CustomerHistoryDialog(cid, name, self).exec())
                self.debt_table.setCellWidget(i, 4, btn_view)
                
                btn_del = QPushButton("X")
                btn_del.setObjectName("DelCustBtn")
                btn_del.setFixedSize(30, 25)
                btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
                btn_del.clicked.connect(lambda _, cid=c['id']: self.delete_customer(cid))
                container = QWidget()
                layout_cen = QHBoxLayout(container)
                layout_cen.setContentsMargins(0,0,0,0)
                layout_cen.setAlignment(Qt.AlignmentFlag.AlignCenter)
                layout_cen.addWidget(btn_del)
                self.debt_table.setCellWidget(i, 5, container)
        except: pass
        self.debt_table.blockSignals(False)
        self.debt_table.setUpdatesEnabled(True)
        self.debt_table.setSortingEnabled(True)

    def delete_customer(self, cid):
        msg = QMessageBox(self)
        msg.setWindowTitle("Cảnh báo")
        msg.setText("Bạn có chắc chắn muốn xóa khách hàng này?\n(Toàn bộ lịch sử và công nợ sẽ mất)")
        msg.setIcon(QMessageBox.Icon.Warning)
        btn_co = msg.addButton("Có", QMessageBox.ButtonRole.YesRole)
        btn_co.setCursor(Qt.CursorShape.PointingHandCursor)
        btn_khong = msg.addButton("Không", QMessageBox.ButtonRole.NoRole)
        btn_khong.setCursor(Qt.CursorShape.PointingHandCursor)
        msg.exec()
        if msg.clickedButton() == btn_co: 
            requests.delete(f"{API_URL}/customers/{cid}")
            self.refresh_debt_table()
            self.load_customer_suggestions()
    
    def on_debt_cell_changed(self, item):
        row = item.row()
        col = item.column()
        if col != 3: return # Chỉ xử lý cột Nợ
        try:
            cid_item = self.debt_table.item(row, 0)
            if not cid_item: return
            cid = int(cid_item.text())
        except: return
        
        name = self.debt_table.item(row, 1).text().strip()
        phone = self.debt_table.item(row, 2).text().strip()
        
        debt = 0
        if col == 3:
            # Dữ liệu đã được MathDelegate xử lý và lưu vào UserRole
            debt = int(item.data(Qt.ItemDataRole.UserRole) or 0)
            
            self.debt_table.blockSignals(True)
            if debt > 0: item.setForeground(QColor("red"))
            else: item.setForeground(QColor("black"))
            self.debt_table.blockSignals(False)
        else:
            debt = int(self.debt_table.item(row, 3).data(Qt.ItemDataRole.UserRole) or 0)
            
        try:
            requests.put(f"{API_URL}/customers/{cid}", json={"name": name, "phone": phone, "debt": debt})
        except:
            self.refresh_debt_table()
    
    def load_customer_suggestions(self):
        try:
            custs = requests.get(f"{API_URL}/customers").json()
            self.cust_completer.setModel(QStringListModel([c['name'] for c in custs]))
        except: pass
    
    def setup_history_page(self):
        w = QWidget()
        l = QVBoxLayout(w)
        h = QHBoxLayout()
        h.addWidget(QLabel("Lịch Sử Hóa Đơn"))
        b = QPushButton("Làm mới")
        b.setObjectName("SecondaryBtn")
        b.setCursor(Qt.CursorShape.PointingHandCursor)
        b.clicked.connect(lambda: self.load_history_page(1))
        h.addWidget(b)
        h.addStretch()
        l.addLayout(h)
        
        self.ht_table = QTableWidget(0, 7)
        self.ht_table.setHorizontalHeaderLabels(["Ngày giờ", "Khách hàng", "Tổng tiền", "SL", "Chi tiết", "Sửa", "Xóa"])
        self.ht_table.horizontalHeader().setSectionResizeMode(1, QHeaderView.ResizeMode.Stretch)
        self.ht_table.horizontalHeader().setSectionResizeMode(5, QHeaderView.ResizeMode.Fixed)
        self.ht_table.horizontalHeader().setSectionResizeMode(6, QHeaderView.ResizeMode.Fixed)
        self.ht_table.setColumnWidth(5, 60)
        self.ht_table.setColumnWidth(6, 60)
        self.ht_table.setEditTriggers(QAbstractItemView.EditTrigger.NoEditTriggers)
        self.ht_table.setSelectionBehavior(QAbstractItemView.SelectionBehavior.SelectRows)
        self.ht_table.cellDoubleClicked.connect(self.ht_cell_dblclick)
        l.addWidget(self.ht_table)
        
        pagination_layout = QHBoxLayout()
        pagination_layout.addStretch()
        self.btn_prev = QPushButton("< Trước")
        self.btn_prev.setObjectName("SecondaryBtn")
        self.btn_prev.setFixedWidth(80)
        self.btn_prev.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_prev.clicked.connect(self.prev_page)
        self.lbl_page = QLabel("Trang 1")
        self.lbl_page.setStyleSheet("font-weight: bold; margin: 0 10px;")
        self.btn_next = QPushButton("Sau >")
        self.btn_next.setObjectName("SecondaryBtn")
        self.btn_next.setFixedWidth(80)
        self.btn_next.setCursor(Qt.CursorShape.PointingHandCursor)
        self.btn_next.clicked.connect(self.next_page)
        pagination_layout.addWidget(self.btn_prev)
        pagination_layout.addWidget(self.lbl_page)
        pagination_layout.addWidget(self.btn_next)
        pagination_layout.addStretch()
        l.addLayout(pagination_layout)
        return w
    
    def load_history_page(self, page):
        self.current_page_his = page
        self.btn_prev.setEnabled(False)
        self.btn_next.setEnabled(False)
        self.lbl_page.setText(f"Đang tải trang {page}...")
        self.hw_his = APIGetWorker(f"/orders?page={page}&limit=20")
        self.hw_his.data_ready.connect(self.on_his_loaded)
        self.hw_his.start()

    def ht_cell_dblclick(self, r, c):
        """Handle double-clicks on the history table to allow editing order date.

        Opens DateEditDialog when double-clicking the date column of an order row.
        After successful edit reload the current history page.
        """
        try:
            if c != 0: return
            item = self.ht_table.item(r, 0)
            if not item: return
            meta = item.data(Qt.ItemDataRole.UserRole)
            if not meta or not isinstance(meta, dict): return
            oid = meta.get('id')
            if not oid: return
            initial = meta.get('created_at') or item.text()
            dlg = DateEditDialog(oid, initial, parent=self)
            if dlg.exec():
                # reload current page to reflect updated date
                try:
                    self.load_history_page(self.current_page_his)
                except:
                    pass
        except Exception:
            pass

    def refresh_history(self):
        self.load_history_page(1)

    def prev_page(self):
        if self.current_page_his > 1: self.load_history_page(self.current_page_his - 1)

    def next_page(self):
        if self.current_page_his < self.total_pages_his: self.load_history_page(self.current_page_his + 1)
    
    def on_his_loaded(self, incoming_data):
        safe_orders_list = []
        data = incoming_data if isinstance(incoming_data, dict) else (incoming_data[0] if isinstance(incoming_data, tuple) else {})
        if isinstance(incoming_data, dict):
            safe_orders_list = incoming_data.get("data", [])
            total = incoming_data.get("total", 0)
            page = incoming_data.get("page", 1)
            import math
            limit = 20
            self.total_pages_his = math.ceil(total / limit) if limit > 0 else 1
            self.current_page_his = page
            self.lbl_page.setText(f"Trang {self.current_page_his} / {self.total_pages_his}")
            self.btn_prev.setEnabled(self.current_page_his > 1)
            self.btn_next.setEnabled(self.current_page_his < self.total_pages_his)
        elif isinstance(incoming_data, list):
            safe_orders_list = incoming_data
        
        self.ht_table.setUpdatesEnabled(False)
        self.ht_table.setSortingEnabled(False)
        self.ht_table.setRowCount(0)
        
        for i, o in enumerate(safe_orders_list):
            try:
                if not isinstance(o, dict): continue
                self.ht_table.insertRow(i)
                item_date = QTableWidgetItem(str(o.get('created_at') or o.get('date', '')))
                item_date.setToolTip(item_date.text())
                # store order object for quick access (edit date)
                item_date.setData(Qt.ItemDataRole.UserRole, o)
                self.ht_table.setItem(i, 0, item_date)
                
                item_cust = QTableWidgetItem(str(o.get('customer_name') or o.get('customer') or "Khách lẻ"))
                item_cust.setToolTip(item_cust.text())
                self.ht_table.setItem(i, 1, item_cust)
                
                val_amt = o.get('total_amount') if o.get('total_amount') is not None else o.get('total_money', 0)
                item_amt = QTableWidgetItem(f"{val_amt:,}")
                item_amt.setToolTip(item_amt.text())
                self.ht_table.setItem(i, 2, item_amt)
                
                item_qty = QTableWidgetItem(str(o.get('total_qty', 0)))
                item_qty.setToolTip(item_qty.text())
                self.ht_table.setItem(i, 3, item_qty)
                
                btn = QPushButton("Xem")
                btn.setObjectName("SecondaryBtn")
                btn.setCursor(Qt.CursorShape.PointingHandCursor)
                btn.setStyleSheet("color:blue; text-decoration: underline; border:none;")
                btn.clicked.connect(lambda _, x=o: OrderDetailDialog(x, self).exec())
                self.ht_table.setCellWidget(i, 4, btn)
                
                btn_edit = QPushButton("Sửa")
                btn_edit.setObjectName("SecondaryBtn")
                btn_edit.setCursor(Qt.CursorShape.PointingHandCursor)
                btn_edit.setStyleSheet("color: #e65100; font-weight: bold; border: none;")
                btn_edit.clicked.connect(lambda _, x=o: self.load_order_to_edit(x))
                w_edit = QWidget()
                l_edit = QHBoxLayout(w_edit)
                l_edit.setContentsMargins(0,0,0,0)
                l_edit.setAlignment(Qt.AlignmentFlag.AlignCenter)
                l_edit.addWidget(btn_edit)
                self.ht_table.setCellWidget(i, 5, w_edit)
                
                btn_del = QPushButton("X")
                btn_del.setObjectName("DelCustBtn")
                btn_del.setFixedSize(30, 25)
                btn_del.setCursor(Qt.CursorShape.PointingHandCursor)
                btn_del.clicked.connect(lambda _, x=o: self.delete_order(x.get('id')))
                container = QWidget()
                ly = QHBoxLayout(container)
                ly.setContentsMargins(0,0,0,0)
                ly.setAlignment(Qt.AlignmentFlag.AlignCenter)
                ly.addWidget(btn_del)
                self.ht_table.setCellWidget(i, 6, container)
            except: continue
        self.ht_table.setUpdatesEnabled(True)
        self.ht_table.setSortingEnabled(True)

    def load_order_to_edit(self, order_data):
        self.editing_order_id = order_data['id']
        self.cart = []
        
        items = order_data.get('items', [])
        for item in items:
            v_info = item.get('variant_info', "")
            if '-' in v_info:
                color, size = v_info.split('-', 1)
            else:
                color, size = "", v_info
            
            vid = item.get('variant_id') 
            if not vid: 
                QMessageBox.warning(self, "Lỗi", "Đơn hàng cũ không hỗ trợ sửa (Thiếu ID).")
                self.editing_order_id = None
                return
            
            raw_qty = item.get('quantity')
            if raw_qty is None:
                raw_qty = item.get('qty') 
            
            raw_price = item.get('price')

            try:
                qty = int(raw_qty) if raw_qty is not None else 0
                price = int(raw_price) if raw_price is not None else 0
            except:
                qty = 0
                price = 0

            self.cart.append({
                "variant_id": vid,
                "product_name": item.get('product_name') or item.get('name', ''), 
                "color": color,
                "size": size,
                "quantity": qty,
                "price": price
            })
            
        c_name = order_data.get('customer_name') or order_data.get('customer') or ""
        self.cust_name_inp.setText(str(c_name))
        
        self.update_cart_ui()
        self.btn_checkout.setText(f"Cập nhật Đơn #{self.editing_order_id}")
        self.switch_page(0)

    def delete_order(self, order_id):
        if not order_id: return
        msg = QMessageBox(self)
        msg.setWindowTitle("Xác nhận xóa")
        msg.setText(f"Bạn có chắc chắn muốn xóa Hóa đơn?")
        msg.setIcon(QMessageBox.Icon.Warning)
        
        btn_co = msg.addButton("Có", QMessageBox.ButtonRole.YesRole)
        btn_co.setCursor(Qt.CursorShape.PointingHandCursor)
        
        btn_khong = msg.addButton("Không", QMessageBox.ButtonRole.NoRole)
        btn_khong.setCursor(Qt.CursorShape.PointingHandCursor)
        
        msg.exec()
        if msg.clickedButton() == btn_co:
            try:
                resp = requests.delete(f"{API_URL}/orders/{order_id}")
                if resp.status_code == 200: 
                    self.load_history_page(self.current_page_his)
                else: 
                    QMessageBox.warning(self, "Lỗi", f"Không xóa được: {resp.text}")
            except Exception as e: 
                QMessageBox.critical(self, "Lỗi kết nối", str(e))

def run_gui(): app = QApplication(sys.argv); window = MainWindow(); window.showMaximized(); sys.exit(app.exec())