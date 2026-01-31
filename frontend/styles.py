SHOPEE_THEME = """
/* ================= GLOBAL ================= */
* { font-family: 'Segoe UI', sans-serif; color: #333; }

QMainWindow, QDialog { background-color: #ffffff; }

QToolTip { 
    color: #000; background-color: #fff; border: 1px solid #ee4d2d; padding: 5px; 
}

QScrollArea { background-color: transparent; border: none; }
QScrollArea > QWidget > QWidget { background-color: #ffffff; }

/* ================= BUTTONS ================= */
/* LƯU Ý: ĐÃ XÓA 'cursor: pointer' ĐỂ TRÁNH LỖI TERMINAL */

QPushButton#PrimaryBtn { 
    background-color: #ee4d2d; color: #333; border: none; 
    padding: 10px 16px; border-radius: 4px; font-weight: bold; font-size: 15px;
}
QPushButton#PrimaryBtn:hover { background-color: #d73211; border: 2px solid #bf2b0e; }

QPushButton#SecondaryBtn { 
    background-color: black; color: #555; border: 1px solid #ddd; 
    padding: 8px 16px; border-radius: 2px; 
}
QPushButton#SecondaryBtn:hover { background-color: #f5f5f5; border-color: #bbb; color: #000; }

QPushButton#NavButton { text-align: left; padding: 15px 20px; border: none; font-size: 14px; color: #555; background: transparent; }
QPushButton#NavButton:hover { background-color: #fff5f2; color: #ee4d2d; border-right: 4px solid #ffccbc; }
QPushButton#NavButton:checked { background-color: #fff5f2; color: #ee4d2d; border-right: 4px solid #ee4d2d; font-weight: bold; }

QPushButton#IconBtn { font-size: 16px; font-weight: 900; color: #d32f2f; background: #fff; border: 1px solid #ddd; }
QPushButton#IconBtn:hover { background-color: #ffebee; border-radius: 4px; }

QPushButton#RemoveRowBtn { background: transparent; color: red; font-weight: bold; border: none; font-size: 14px; }
QPushButton#RemoveRowBtn:hover { background-color: #ffebee; border-radius: 12px; }

QPushButton#DelCustBtn { font-weight: bold; color: red; border: 1px solid #ffcdd2; background: #ffebee; border-radius: 4px; }
QPushButton#DelCustBtn:hover { background: #ef9a9a; color: white; border: 1px solid #ef5350; }

QPushButton#DeleteBtn { background-color: #ffffff; color: #d32f2f; border: 1px solid #d32f2f; font-weight: bold; }
QPushButton#DeleteBtn:hover { background-color: #ffebee; border-color: #b71c1c; }

/* ================= INPUTS & TABLES ================= */
QLineEdit { border: 1px solid #ddd; padding: 8px; border-radius: 2px; background: white; color: #333; }
QLineEdit:focus { border: 1px solid #ee4d2d; background: #fffdfb; }

QTableWidget QLineEdit { padding: 0px 4px; border: none; background: #fffdfb; font-weight: bold; }

QSpinBox { border: 1px solid #ddd; padding: 5px; border-radius: 2px; background: white; font-size: 14px; color: #333; }
QSpinBox::up-button, QSpinBox::down-button { width: 30px; background: #f0f0f0; border: none; border-left: 1px solid #ddd; }
QSpinBox::up-button:hover, QSpinBox::down-button:hover { background: #e0e0e0; }

/* TABLE STYLES */
QTableWidget { 
    border: 1px solid #000; 
    background: white; 
    gridline-color: #000; 
    color: #333; 
    selection-background-color: #fff5f2; 
    selection-color: #ee4d2d; 
    font-size: 13px; 
    outline: 0; 
}

QTableWidget::item:focus {
    border: none;
    outline: none;
    background-color: #fff5f2;
}

QHeaderView::section { background-color: #eee; padding: 4px; border: 1px solid #000; font-weight: bold; color: #000; }

QScrollBar:vertical { border: none; background: #f1f1f1; width: 10px; margin: 0px; }
QScrollBar::handle:vertical { background: #c1c1c1; min-height: 20px; border-radius: 4px; }
"""