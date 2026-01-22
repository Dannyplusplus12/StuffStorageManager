import sys
import threading
import uvicorn
import time
import os
import traceback
from PyQt6.QtWidgets import QApplication, QMessageBox

# --- [QUAN TRỌNG] FIX LỖI CHO PYINSTALLER --NOCONSOLE ---
# Đoạn này phải nằm trên cùng, trước khi chạy bất cứ logic nào
# Nó tạo ra một luồng ảo để Uvicorn không bị crash khi không tìm thấy màn hình đen
if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")
# --------------------------------------------------------

class ServerThread(threading.Thread):
    def __init__(self, app_instance):
        super().__init__()
        self.server = None
        self.app_instance = app_instance

    def run(self):
        try:
            # Cấu hình Server
            # use_colors=False: Tắt màu mè để tránh lỗi console
            config = uvicorn.Config(self.app_instance, host="127.0.0.1", port=8000, log_level="critical", use_colors=False)
            self.server = uvicorn.Server(config)
            self.server.run()
        except Exception as e:
            with open("crash_server.txt", "w", encoding="utf-8") as f:
                f.write(traceback.format_exc())

    def stop(self):
        if self.server:
            self.server.should_exit = True

# --- HÀM MAIN CHÍNH ---
if __name__ == "__main__":
    try:
        # Import module sau khi đã vá lỗi stdout
        from backend.api import app as fastapi_app
        from frontend.ui import MainWindow

        # Khởi động Server ngầm
        server_thread = ServerThread(fastapi_app)
        server_thread.start()
        
        time.sleep(1.5)

        # Khởi động Giao diện
        qt_app = QApplication(sys.argv)
        window = MainWindow()
        window.show()

        exit_code = qt_app.exec()
        
        server_thread.stop()
        server_thread.join()
        sys.exit(exit_code)

    except Exception as e:
        error_msg = traceback.format_exc()
        with open("crash_log.txt", "w", encoding="utf-8") as f:
            f.write(error_msg)
            
        try:
            app = QApplication.instance()
            if not app: app = QApplication(sys.argv)
            QMessageBox.critical(None, "Lỗi Nghiêm Trọng", f"App bị lỗi khởi động!\nXem file crash_log.txt.\n\n{str(e)}")
        except:
            pass