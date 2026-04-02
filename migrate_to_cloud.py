"""
Script chuyển dữ liệu từ shop.db (SQLite local) lên PostgreSQL (Railway).

Cách dùng:
    1. Lấy DATABASE_URL từ Railway Dashboard (PostgreSQL plugin → Connect → Connection String)
    2. Chạy:
       python migrate_to_cloud.py "postgresql://user:pass@host:port/dbname"
    
    Hoặc nếu chỉ muốn test xem có bao nhiêu dữ liệu:
       python migrate_to_cloud.py --preview
"""

import sqlite3
import sys
import os
from datetime import datetime


def get_local_db_path():
    """Tìm file shop.db ở thư mục gốc project."""
    candidates = [
        os.path.join(os.path.dirname(os.path.abspath(__file__)), "shop.db"),
        "shop.db",
    ]
    for p in candidates:
        if os.path.exists(p):
            return p
    return None


def read_local_data(db_path):
    """Đọc toàn bộ dữ liệu từ SQLite local."""
    conn = sqlite3.connect(db_path)
    conn.row_factory = sqlite3.Row
    cur = conn.cursor()

    data = {}

    # Products
    cur.execute("SELECT * FROM products")
    data["products"] = [dict(r) for r in cur.fetchall()]

    # Variants
    cur.execute("SELECT * FROM variants")
    data["variants"] = [dict(r) for r in cur.fetchall()]

    # Customers
    cur.execute("SELECT * FROM customers")
    data["customers"] = [dict(r) for r in cur.fetchall()]

    # Areas
    try:
        cur.execute("SELECT * FROM areas")
        data["areas"] = [dict(r) for r in cur.fetchall()]
    except Exception:
        data["areas"] = []

    # DebtLogs
    try:
        cur.execute("SELECT * FROM debt_logs")
        data["debt_logs"] = [dict(r) for r in cur.fetchall()]
    except Exception:
        data["debt_logs"] = []

    # Orders
    cur.execute("SELECT * FROM orders")
    data["orders"] = [dict(r) for r in cur.fetchall()]

    # OrderItems
    cur.execute("SELECT * FROM order_items")
    data["order_items"] = [dict(r) for r in cur.fetchall()]

    conn.close()
    return data


def preview_data(data):
    """In ra thống kê dữ liệu local."""
    print("\n=== DỮ LIỆU TRONG shop.db ===")
    print(f"  Sản phẩm  : {len(data['products'])}")
    print(f"  Phân loại  : {len(data['variants'])}")
    print(f"  Khách hàng : {len(data['customers'])}")
    print(f"  Khu vực    : {len(data['areas'])}")
    print(f"  Log công nợ: {len(data['debt_logs'])}")
    print(f"  Đơn hàng   : {len(data['orders'])}")
    print(f"  Chi tiết đơn: {len(data['order_items'])}")
    print()

    if data["products"]:
        print("  --- Một vài sản phẩm ---")
        for p in data["products"][:5]:
            print(f"    #{p['id']}: {p['name']}")
        if len(data["products"]) > 5:
            print(f"    ... và {len(data['products']) - 5} sản phẩm khác")

    if data["customers"]:
        print("\n  --- Một vài khách hàng ---")
        for c in data["customers"][:5]:
            print(f"    #{c['id']}: {c['name']} - Nợ: {c['debt']:,}")
        if len(data["customers"]) > 5:
            print(f"    ... và {len(data['customers']) - 5} khách hàng khác")
    print()


def migrate(pg_url, data):
    """Chuyển dữ liệu sang PostgreSQL, giữ nguyên ID."""
    try:
        import psycopg2
    except ImportError:
        print("ERROR: Cần cài psycopg2-binary để kết nối PostgreSQL:")
        print("  pip install psycopg2-binary")
        sys.exit(1)

    print(f"\nĐang kết nối PostgreSQL...")
    conn = psycopg2.connect(pg_url)
    cur = conn.cursor()

    try:
        # Kiểm tra xem tables đã tồn tại chưa, nếu chưa thì tự tạo
        cur.execute("SELECT EXISTS (SELECT FROM information_schema.tables WHERE table_name = 'products')")
        if not cur.fetchone()[0]:
            print("Tables chưa tồn tại → Đang tự tạo...")
            cur.execute("""
                CREATE TABLE IF NOT EXISTS products (
                    id SERIAL PRIMARY KEY,
                    code VARCHAR,
                    name VARCHAR,
                    description VARCHAR,
                    image_path VARCHAR
                );
                CREATE TABLE IF NOT EXISTS variants (
                    id SERIAL PRIMARY KEY,
                    product_id INTEGER REFERENCES products(id),
                    color VARCHAR,
                    size VARCHAR,
                    price INTEGER,
                    stock INTEGER
                );
                CREATE TABLE IF NOT EXISTS customers (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR UNIQUE,
                    phone VARCHAR DEFAULT '',
                    debt INTEGER DEFAULT 0,
                    area_id INTEGER
                );
                CREATE TABLE IF NOT EXISTS areas (
                    id SERIAL PRIMARY KEY,
                    name VARCHAR UNIQUE
                );
                CREATE TABLE IF NOT EXISTS debt_logs (
                    id SERIAL PRIMARY KEY,
                    customer_id INTEGER REFERENCES customers(id),
                    change_amount INTEGER,
                    new_balance INTEGER,
                    note VARCHAR,
                    created_at TIMESTAMP DEFAULT NOW(),
                    created_ts BIGINT
                );
                CREATE TABLE IF NOT EXISTS orders (
                    id SERIAL PRIMARY KEY,
                    customer_name VARCHAR,
                    customer_id INTEGER REFERENCES customers(id),
                    created_at TIMESTAMP DEFAULT NOW(),
                    created_ts BIGINT,
                    total_amount INTEGER,
                    is_draft INTEGER DEFAULT 0,
                    status VARCHAR DEFAULT 'completed',
                    picker_note VARCHAR DEFAULT ''
                );
                CREATE TABLE IF NOT EXISTS order_items (
                    id SERIAL PRIMARY KEY,
                    order_id INTEGER REFERENCES orders(id),
                    product_name VARCHAR,
                    variant_id INTEGER REFERENCES variants(id),
                    variant_info VARCHAR,
                    quantity INTEGER,
                    price INTEGER
                );
                CREATE INDEX IF NOT EXISTS ix_products_id ON products(id);
                CREATE INDEX IF NOT EXISTS ix_variants_id ON variants(id);
                CREATE INDEX IF NOT EXISTS ix_customers_id ON customers(id);
                CREATE INDEX IF NOT EXISTS ix_customers_name ON customers(name);
                CREATE INDEX IF NOT EXISTS ix_debt_logs_id ON debt_logs(id);
                CREATE INDEX IF NOT EXISTS ix_orders_id ON orders(id);
                CREATE INDEX IF NOT EXISTS ix_order_items_id ON order_items(id);
            """)
            conn.commit()
            print("  ✓ Tất cả tables đã được tạo!")

        # Đảm bảo schema products có cột code (cho DB đã tồn tại từ bản cũ)
        cur.execute("""
            SELECT EXISTS (
                SELECT 1
                FROM information_schema.columns
                WHERE table_name = 'products' AND column_name = 'code'
            )
        """)
        has_code = cur.fetchone()[0]
        if not has_code:
            print("Thiếu cột products.code → Đang tự thêm...")
            cur.execute("ALTER TABLE products ADD COLUMN code VARCHAR")
            cur.execute("UPDATE products SET code = name WHERE code IS NULL OR code = ''")
            conn.commit()
            print("  ✓ Đã thêm cột code")

        # Kiểm tra DB cloud có dữ liệu không
        cur.execute("SELECT COUNT(*) FROM products")
        existing = cur.fetchone()[0]
        if existing > 0:
            resp = input(f"\n⚠️  PostgreSQL đã có {existing} sản phẩm. Xóa sạch và import lại? (y/n): ")
            if resp.lower() != 'y':
                print("Hủy migration.")
                return
            # Xóa theo thứ tự FK
            cur.execute("DELETE FROM order_items")
            cur.execute("DELETE FROM debt_logs")
            cur.execute("DELETE FROM orders")
            cur.execute("DELETE FROM variants")
            cur.execute("DELETE FROM customers")
            cur.execute("DELETE FROM areas")
            cur.execute("DELETE FROM products")
            conn.commit()
            print("  Đã xóa sạch dữ liệu cũ trên cloud.")

        print("[0/7] Đang chuyển Areas...")
        for a in data["areas"]:
            cur.execute(
                "INSERT INTO areas (id, name) VALUES (%s, %s)",
                (a["id"], a["name"])
            )
        print(f"  ✓ {len(data['areas'])} khu vực")

        # --- INSERT DỮ LIỆU (giữ nguyên ID) ---
        print("\n[1/7] Đang chuyển Products...")
        for p in data["products"]:
            cur.execute(
                "INSERT INTO products (id, code, name, description, image_path) VALUES (%s, %s, %s, %s, %s)",
                (p["id"], p.get("code") or p["name"], p["name"], p.get("description", ""), p.get("image_path", ""))
            )
        print(f"  ✓ {len(data['products'])} sản phẩm")

        print("[2/7] Đang chuyển Variants...")
        for v in data["variants"]:
            cur.execute(
                "INSERT INTO variants (id, product_id, color, size, price, stock) VALUES (%s, %s, %s, %s, %s, %s)",
                (v["id"], v["product_id"], v["color"], v["size"], v["price"], v["stock"])
            )
        print(f"  ✓ {len(data['variants'])} phân loại")

        print("[3/7] Đang chuyển Customers...")
        for c in data["customers"]:
            cur.execute(
                "INSERT INTO customers (id, name, phone, debt, area_id) VALUES (%s, %s, %s, %s, %s)",
                (c["id"], c["name"], c.get("phone", ""), c.get("debt", 0), c.get("area_id"))
            )
        print(f"  ✓ {len(data['customers'])} khách hàng")

        print("[4/7] Đang chuyển Debt Logs...")
        for dl in data["debt_logs"]:
            created_at = dl.get("created_at")
            if isinstance(created_at, str) and created_at:
                # Try parsing various datetime formats from SQLite
                for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
                    try:
                        created_at = datetime.strptime(created_at, fmt)
                        break
                    except ValueError:
                        continue
            cur.execute(
                "INSERT INTO debt_logs (id, customer_id, change_amount, new_balance, note, created_at, created_ts) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (dl["id"], dl["customer_id"], dl["change_amount"], dl.get("new_balance", 0),
                 dl.get("note", ""), created_at, dl.get("created_ts"))
            )
        print(f"  ✓ {len(data['debt_logs'])} bản ghi công nợ")

        print("[5/7] Đang chuyển Orders...")
        for o in data["orders"]:
            created_at = o.get("created_at")
            if isinstance(created_at, str) and created_at:
                for fmt in ("%Y-%m-%d %H:%M:%S.%f", "%Y-%m-%d %H:%M:%S", "%Y-%m-%d %H:%M"):
                    try:
                        created_at = datetime.strptime(created_at, fmt)
                        break
                    except ValueError:
                        continue
            cur.execute(
                "INSERT INTO orders (id, customer_name, customer_id, created_at, created_ts, total_amount, is_draft, status, picker_note) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)",
                (o["id"], o.get("customer_name", ""), o.get("customer_id"),
                 created_at, o.get("created_ts"), o.get("total_amount", 0), o.get("is_draft", 0), o.get("status", "completed"), o.get("picker_note", ""))
            )
        print(f"  ✓ {len(data['orders'])} đơn hàng")

        print("[6/7] Đang chuyển Order Items...")
        for oi in data["order_items"]:
            cur.execute(
                "INSERT INTO order_items (id, order_id, product_name, variant_id, variant_info, quantity, price) "
                "VALUES (%s, %s, %s, %s, %s, %s, %s)",
                (oi["id"], oi["order_id"], oi.get("product_name", ""), oi.get("variant_id"),
                 oi.get("variant_info", ""), oi["quantity"], oi["price"])
            )
        print(f"  ✓ {len(data['order_items'])} chi tiết đơn")

        # Reset auto-increment sequences cho PostgreSQL
        print("\nĐang cập nhật sequences...")
        for table in ("products", "variants", "areas", "customers", "debt_logs", "orders", "order_items"):
            cur.execute(f"SELECT COALESCE(MAX(id), 0) FROM {table}")
            max_id = cur.fetchone()[0]
            cur.execute(f"SELECT setval(pg_get_serial_sequence('{table}', 'id'), %s, true)", (max(max_id, 1),))
        print("  ✓ Sequences đã cập nhật")

        conn.commit()
        print("\n✅ MIGRATION THÀNH CÔNG!")
        print(f"  Đã chuyển toàn bộ dữ liệu từ shop.db lên PostgreSQL.")
        print(f"  Bây giờ hãy mở app và kiểm tra dữ liệu.")

    except Exception as e:
        conn.rollback()
        print(f"\n❌ LỖI MIGRATION: {e}")
        import traceback
        traceback.print_exc()
    finally:
        cur.close()
        conn.close()


def main():
    db_path = get_local_db_path()
    if not db_path:
        print("ERROR: Không tìm thấy shop.db!")
        print("  Hãy chạy script này từ thư mục gốc project (chứa shop.db).")
        sys.exit(1)

    print(f"Tìm thấy database local: {db_path}")
    data = read_local_data(db_path)
    preview_data(data)

    if len(sys.argv) < 2:
        print("CÁCH DÙNG:")
        print("  python migrate_to_cloud.py <DATABASE_URL>")
        print()
        print("  DATABASE_URL lấy từ Railway Dashboard:")
        print("    → PostgreSQL plugin → Connect → Connection String")
        print('    VD: "postgresql://postgres:xxxx@host.railway.app:5432/railway"')
        print()
        print("  Hoặc xem trước dữ liệu:")
        print("    python migrate_to_cloud.py --preview")
        sys.exit(0)

    if sys.argv[1] == "--preview":
        print("(Chế độ preview - không migrate)")
        sys.exit(0)

    pg_url = sys.argv[1]
    if not pg_url.startswith("postgresql"):
        print("ERROR: DATABASE_URL phải bắt đầu bằng 'postgresql://'")
        sys.exit(1)

    print(f"Target: {pg_url[:50]}...")
    migrate(pg_url, data)


if __name__ == "__main__":
    main()
