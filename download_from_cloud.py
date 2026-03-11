"""
Download toàn bộ dữ liệu từ Railway PostgreSQL về SQLite local.
Chạy: python download_from_cloud.py
"""
import os
import sqlite3
from datetime import datetime

# --- CẤU HÌNH ---
# URL công khai của PostgreSQL trên Railway (dùng proxy port)
CLOUD_URL = "postgresql://postgres:gDRpchOHRXoEXKIDuqrYfilrKhjLNmHa@centerbeam.proxy.rlwy.net:21122/railway"
LOCAL_DB = "shop_backup.db"


def download():
    try:
        import psycopg2
    except ImportError:
        print("Cần cài psycopg2-binary: pip install psycopg2-binary")
        return

    print(f"Kết nối tới cloud database...")
    cloud = psycopg2.connect(CLOUD_URL)
    cc = cloud.cursor()

    # Xóa file backup cũ nếu có
    if os.path.exists(LOCAL_DB):
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        backup_name = f"shop_backup_{ts}.db"
        os.rename(LOCAL_DB, backup_name)
        print(f"  File cũ đổi tên thành: {backup_name}")

    local = sqlite3.connect(LOCAL_DB)
    lc = local.cursor()

    # Tạo tables trong SQLite
    lc.executescript("""
        CREATE TABLE IF NOT EXISTS products (
            id INTEGER PRIMARY KEY, name TEXT, description TEXT DEFAULT '', image_path TEXT DEFAULT ''
        );
        CREATE TABLE IF NOT EXISTS variants (
            id INTEGER PRIMARY KEY, product_id INTEGER, color TEXT, size TEXT, price INTEGER, stock INTEGER,
            FOREIGN KEY (product_id) REFERENCES products(id)
        );
        CREATE TABLE IF NOT EXISTS customers (
            id INTEGER PRIMARY KEY, name TEXT UNIQUE, phone TEXT DEFAULT '', debt INTEGER DEFAULT 0
        );
        CREATE TABLE IF NOT EXISTS debt_logs (
            id INTEGER PRIMARY KEY, customer_id INTEGER, change_amount INTEGER, new_balance INTEGER,
            note TEXT, created_at TIMESTAMP, created_ts INTEGER,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
        );
        CREATE TABLE IF NOT EXISTS orders (
            id INTEGER PRIMARY KEY, customer_name TEXT, customer_id INTEGER,
            created_at TIMESTAMP, created_ts INTEGER, total_amount INTEGER,
            FOREIGN KEY (customer_id) REFERENCES customers(id)
        );
        CREATE TABLE IF NOT EXISTS order_items (
            id INTEGER PRIMARY KEY, order_id INTEGER, product_name TEXT,
            variant_id INTEGER, variant_info TEXT, quantity INTEGER, price INTEGER,
            FOREIGN KEY (order_id) REFERENCES orders(id)
        );
    """)

    # Download từng bảng
    tables = [
        ("products",    "id, name, description, image_path"),
        ("variants",    "id, product_id, color, size, price, stock"),
        ("customers",   "id, name, phone, debt"),
        ("debt_logs",   "id, customer_id, change_amount, new_balance, note, created_at, created_ts"),
        ("orders",      "id, customer_name, customer_id, created_at, created_ts, total_amount"),
        ("order_items", "id, order_id, product_name, variant_id, variant_info, quantity, price"),
    ]

    for table, cols in tables:
        print(f"  Đang tải: {table}...", end=" ")
        cc.execute(f"SELECT {cols} FROM {table}")
        rows = cc.fetchall()
        col_count = len(cols.split(","))
        placeholders = ",".join(["?"] * col_count)
        lc.executemany(f"INSERT OR REPLACE INTO {table} ({cols}) VALUES ({placeholders})", rows)
        print(f"{len(rows)} bản ghi")

    local.commit()
    local.close()
    cloud.close()

    size_mb = os.path.getsize(LOCAL_DB) / (1024 * 1024)
    print(f"\n✅ Hoàn tất! File backup: {LOCAL_DB} ({size_mb:.2f} MB)")
    print(f"   Bạn có thể mở file này bằng DB Browser for SQLite hoặc copy thành shop.db")


if __name__ == "__main__":
    download()
