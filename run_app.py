import sys
import threading
import uvicorn
import time
import os

from PyQt6.QtWidgets import QApplication
from backend.api import app as fastapi_app
from frontend.ui import MainWindow

# Class để chạy Server trong luồng riêng
class ServerThread(threading.Thread):
    def __init__(self):
        super().__init__()
        self.server = None

    def run(self):
        # Chạy server ở localhost port 8000
        # log_level="critical" để giấu bớt log rác
        config = uvicorn.Config(fastapi_app, host="127.0.0.1", port=8000, log_level="critical")
        self.server = uvicorn.Server(config)
        self.server.run()

    def stop(self):
        if self.server:
            self.server.should_exit = True

if __name__ == "__main__":
    # 1. Khởi động Server ngầm
    server_thread = ServerThread()
    server_thread.start()
    
    # Đợi xíu cho server lên (tránh App gọi API bị lỗi Connection Refused)
    time.sleep(1.5)

    # 2. Khởi động Giao diện
    app = QApplication(sys.argv)
    window = MainWindow()
    window.show()

    # 3. Khi đóng cửa sổ App -> Tắt luôn Server
    exit_code = app.exec()
    server_thread.stop()
    server_thread.join()
    
    sys.exit(exit_code)