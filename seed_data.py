from backend.database import SessionLocal, Product, Variant
import random

# Kết nối DB
db = SessionLocal()

# 1. Xóa sạch dữ liệu cũ
print("Dang xoa du lieu cu...")
try:
    # Xóa variant trước vì có khóa ngoại
    db.query(Variant).delete()
    db.query(Product).delete()
    db.commit()
    print("Da xoa sach DB.")
except Exception as e:
    db.rollback()
    print("Loi xoa DB:", e)
