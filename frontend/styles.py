SHOPEE_THEME = """
/* GLOBAL */
* { font-family: 'Segoe UI', sans-serif; color: #333; }

/* ÉP NỀN TRẮNG TUYỆT ĐỐI CHO DIALOG VÀ MAINWINDOW */
QMainWindow, QDialog { background-color: #ffffff; }

/* FIX LỖI SCROLL AREA TRONG DIALOG BỊ XÁM/ĐEN */
QScrollArea { background-color: transparent; border: none; }
QScrollArea > QWidget > QWidget { background-color: #ffffff; }

/* SIDEBAR */
QWidget#Sidebar { background-color: #fcfcfc; border-right: 1px solid #e0e0e0; }
QPushButton#NavButton {
    text-align: left; padding: 15px 20px; border: none; font-size: 14px; color: #555; background-color: transparent;
}
QPushButton#NavButton:hover { background-color: #fff5f2; color: #ee4d2d; }
QPushButton#NavButton:checked { 
    background-color: #fff5f2; color: #ee4d2d; border-right: 4px solid #ee4d2d; font-weight: bold;
}

/* PRODUCT CARD */
QFrame#ProductCard { background-color: #ffffff; border: 1px solid #eaeaea; border-radius: 4px; }
QFrame#ProductCard:hover { border: 1px solid #ee4d2d; background-color: #fff; box-shadow: 0 4px 8px rgba(0,0,0,0.1); }

/* TEXT STYLES */
QLabel { color: #333; }
QLabel#PriceLabel { color: #ee4d2d; font-weight: bold; font-size: 13px; }
QLabel#NameLabel { font-size: 12px; color: #333; font-weight: 500; }
QLabel#HeaderTitle { font-size: 20px; font-weight: bold; color: #333; }
QLabel#DialogTitle { font-size: 18px; font-weight: bold; color: #ee4d2d; margin-bottom: 10px; }

/* INPUTS */
QLineEdit { border: 1px solid #ddd; padding: 8px; border-radius: 2px; background: white; color: #333; }
QLineEdit:focus { border: 1px solid #ee4d2d; background: #fffdfb; }

/* SPINBOX CUSTOM (TO & DỄ BẤM) */
QSpinBox {
    border: 1px solid #ddd; padding: 5px; border-radius: 2px; background: white; font-size: 14px; color: #333;
}
QSpinBox::up-button, QSpinBox::down-button {
    width: 30px; /* Nút to hơn nữa */
    background: #f0f0f0;
    border: none;
    border-left: 1px solid #ddd;
}
QSpinBox::up-button:hover, QSpinBox::down-button:hover { background: #e0e0e0; }

/* BUTTONS */
QPushButton.PrimaryBtn { background-color: #ee4d2d; color: #333; border: none; padding: 10px 16px; border-radius: 2px; font-weight: bold; }
QPushButton.PrimaryBtn:hover { background-color: #d73211; }

QPushButton.SecondaryBtn { background-color: white; color: #555; border: 1px solid #ddd; padding: 8px 16px; border-radius: 2px; }
QPushButton.SecondaryBtn:hover { background-color: #f8f8f8; }

/* TABLES */
QTableWidget { border: 1px solid #eee; background: white; gridline-color: #f0f0f0; color: #333; selection-background-color: #fff5f2; selection-color: #ee4d2d; }
QHeaderView::section { background-color: #fafafa; padding: 8px; border: none; font-weight: bold; color: #555; border-bottom: 2px solid #ee4d2d; }

/* SCROLLBAR */
QScrollBar:vertical { border: none; background: #f1f1f1; width: 10px; margin: 0px; }
QScrollBar::handle:vertical { background: #c1c1c1; min-height: 20px; border-radius: 4px; }
"""