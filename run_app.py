import sys
import threading
import uvicorn
import time
import os
import traceback
import importlib.util
from multiprocessing import freeze_support
try:
    from PyQt6.QtWidgets import QApplication, QMessageBox
except Exception:
    # PyQt6 removed from repo; keep script runnable for backend-only usage
    QApplication = None
    QMessageBox = None

if sys.stdout is None:
    sys.stdout = open(os.devnull, "w")
if sys.stderr is None:
    sys.stderr = open(os.devnull, "w")

class ServerThread(threading.Thread):
    def __init__(self, app_instance):
        super().__init__()
        self.server = None
        self.app_instance = app_instance

    def run(self):
        try:
            config = uvicorn.Config(self.app_instance, host="127.0.0.1", port=8000, log_level="critical", use_colors=False)
            self.server = uvicorn.Server(config)
            self.server.run()
        except Exception:
            with open("crash_server.txt", "w", encoding="utf-8") as f:
                f.write(traceback.format_exc())

    def stop(self):
        if self.server:
            self.server.should_exit = True

if __name__ == "__main__":
    freeze_support()
    try:
        api_path = os.path.join(os.path.dirname(__file__), "server-repo", "api.py")
        spec = importlib.util.spec_from_file_location("server_repo_api", api_path)
        if spec is None or spec.loader is None:
            raise RuntimeError(f"Không nạp được API từ {api_path}")
        module = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(module)
        fastapi_app = module.app

        # Start backend server thread only. Desktop UI is deprecated.
        server_thread = ServerThread(fastapi_app)
        server_thread.daemon = True
        server_thread.start()

        print("Server backend (server-repo) started in background.")
        try:
            while True:
                time.sleep(1)
        except KeyboardInterrupt:
            server_thread.stop()
            sys.exit(0)

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