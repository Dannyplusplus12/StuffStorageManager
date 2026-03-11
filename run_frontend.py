"""Chạy frontend kết nối đến server Railway (không khởi động server local)."""
import sys
import os
import traceback
from multiprocessing import freeze_support

if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

if __name__ == "__main__":
    freeze_support()
    try:
        from PyQt6.QtWidgets import QApplication, QMessageBox
        from frontend.ui import MainWindow

        qt_app = QApplication(sys.argv)
        window = MainWindow()
        window.show()
        sys.exit(qt_app.exec())

    except Exception as e:
        error_msg = traceback.format_exc()
        with open("crash_log.txt", "w", encoding="utf-8") as f:
            f.write(error_msg)
        try:
            app = QApplication.instance()
            if not app:
                from PyQt6.QtWidgets import QApplication, QMessageBox
                app = QApplication(sys.argv)
            QMessageBox.critical(None, "Lỗi Nghiêm Trọng", f"App bị lỗi khởi động!\nXem file crash_log.txt.\n\n{str(e)}")
        except:
            pass
