import argparse
from sqlalchemy import text

try:
    from backend.database import engine, is_sqlite
except ImportError:
    from database import engine, is_sqlite


def ensure_is_draft_column(conn):
    if is_sqlite:
        info = conn.execute(text("PRAGMA table_info('orders')")).fetchall()
        cols = [r[1] for r in info]
        if 'is_draft' not in cols:
            conn.execute(text("ALTER TABLE orders ADD COLUMN is_draft INTEGER DEFAULT 0"))
    else:
        try:
            conn.execute(text("ALTER TABLE orders ADD COLUMN is_draft INTEGER DEFAULT 0"))
        except Exception:
            conn.rollback()
            pass

    conn.execute(text("UPDATE orders SET is_draft = 0 WHERE is_draft IS NULL"))
    conn.commit()


def main():
    parser = argparse.ArgumentParser(description="Mark pending orders as approved (is_draft=0).")
    parser.add_argument("--allow-sqlite", action="store_true", help="Allow running on local SQLite database")
    args = parser.parse_args()

    db_target = str(engine.url)
    print(f"Target DB: {db_target}")
    if is_sqlite and not args.allow_sqlite:
        print("Abort: current target is SQLite local DB. Set DATABASE_URL to Railway PostgreSQL or pass --allow-sqlite.")
        return

    with engine.connect() as conn:
        ensure_is_draft_column(conn)

        pending = conn.execute(text("SELECT COUNT(*) FROM orders WHERE COALESCE(is_draft, 0) = 1")).scalar() or 0
        print(f"Pending before update: {pending}")

        conn.execute(text("UPDATE orders SET is_draft = 0 WHERE COALESCE(is_draft, 0) = 1"))
        conn.commit()

        pending_after = conn.execute(text("SELECT COUNT(*) FROM orders WHERE COALESCE(is_draft, 0) = 1")).scalar() or 0
        print(f"Pending after update: {pending_after}")
        print("Done: all existing orders are marked as approved.")


if __name__ == "__main__":
    main()
