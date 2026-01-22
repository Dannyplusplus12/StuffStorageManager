import os
import sys
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import sessionmaker, relationship, declarative_base
from datetime import datetime

# --- HÀM TÌM ĐƯỜNG DẪN DATABASE CHUẨN (Quan trọng cho file EXE) ---
def get_db_path():
    """
    Trả về đường dẫn tuyệt đối đến file shop.db
    - Nếu chạy bằng file .exe: Lấy đường dẫn của file .exe
    - Nếu chạy bằng code python: Lấy đường dẫn thư mục gốc dự án
    """
    if getattr(sys, 'frozen', False):
        # Đang chạy trong môi trường đã đóng gói (PyInstaller)
        application_path = os.path.dirname(sys.executable)
    else:
        # Đang chạy bằng lệnh python thường
        # File này nằm ở backend/database.py -> cần nhảy lên 1 cấp để về root
        current_dir = os.path.dirname(os.path.abspath(__file__))
        application_path = os.path.dirname(current_dir) 
    
    return os.path.join(application_path, "shop.db")

# Lấy đường dẫn động
db_path = get_db_path()
DATABASE_URL = f"sqlite:///{db_path}"

# In ra để debug xem database đang nằm ở đâu
print(f"📂 Database path: {db_path}")

Base = declarative_base()

# check_same_thread=False là BẮT BUỘC khi dùng SQLite với nhiều luồng (GUI + API)
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# 1. Bảng Sản Phẩm (Thông tin chung)
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String, default="")
    image_path = Column(String, default="") # Đường dẫn ảnh file
    
    variants = relationship("Variant", back_populates="product", cascade="all, delete-orphan")

# 2. Bảng Biến Thể (Màu - Size - Giá - Tồn kho)
class Variant(Base):
    __tablename__ = "variants"
    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"))
    color = Column(String)
    size = Column(String)
    price = Column(Integer)
    stock = Column(Integer)

    product = relationship("Product", back_populates="variants")

# 3. Bảng Đơn Hàng
class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    created_at = Column(DateTime, default=datetime.now)
    total_amount = Column(Integer)
    items = relationship("OrderItem", back_populates="order")

# 4. Chi tiết đơn hàng
class OrderItem(Base):
    __tablename__ = "order_items"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    product_name = Column(String) # Lưu cứng tên lúc mua
    variant_info = Column(String) # Lưu cứng màu/size lúc mua
    quantity = Column(Integer)
    price = Column(Integer)
    
    order = relationship("Order", back_populates="items")

# Tạo bảng nếu chưa có
Base.metadata.create_all(bind=engine)