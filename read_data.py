import pandas as pd
import os
import sys
import warnings
from datetime import datetime, timedelta
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import sessionmaker, relationship, declarative_base

# Tắt warning openpyxl
warnings.filterwarnings("ignore", category=UserWarning)

# --- 1. CẤU HÌNH DATABASE ---
BASE_DIR = os.path.dirname(os.path.abspath(__file__))
DB_PATH = os.path.join(BASE_DIR, "shop.db")
DATABASE_URL = f"sqlite:///{DB_PATH}"

Base = declarative_base()
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

# --- 2. ĐỊNH NGHĨA MODELS ---
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    image_path = Column(String, default="assets/images/default.jpg")
    description = Column(String, default="")
    variants = relationship("Variant", back_populates="product", cascade="all, delete-orphan")

class Variant(Base):
    __tablename__ = "variants"
    id = Column(Integer, primary_key=True, index=True)
    product_id = Column(Integer, ForeignKey("products.id"))
    color = Column(String)
    size = Column(String)
    price = Column(Integer)
    stock = Column(Integer)
    product = relationship("Product", back_populates="variants")

class Customer(Base):
    __tablename__ = "customers"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True, unique=True)
    phone = Column(String, default="")
    debt = Column(Integer, default=0)
    orders = relationship("Order", back_populates="customer_rel")
    logs = relationship("DebtLog", back_populates="customer")

class DebtLog(Base):
    __tablename__ = "debt_logs"
    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"))
    change_amount = Column(Integer)
    new_balance = Column(Integer)
    note = Column(String)
    created_at = Column(DateTime, default=datetime.now)
    # high-resolution epoch milliseconds for stable sorting and to avoid tie issues
    created_ts = Column(Integer, default=lambda: int(datetime.utcnow().timestamp() * 1000))
    customer = relationship("Customer", back_populates="logs")

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    customer_name = Column(String)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.now)
    # high-resolution epoch milliseconds for stable sorting
    created_ts = Column(Integer, default=lambda: int(datetime.utcnow().timestamp() * 1000))
    total_amount = Column(Integer)
    items = relationship("OrderItem", back_populates="order", cascade="all, delete-orphan")
    customer_rel = relationship("Customer", back_populates="orders")

class OrderItem(Base):
    __tablename__ = "order_items"
    id = Column(Integer, primary_key=True, index=True)
    order_id = Column(Integer, ForeignKey("orders.id"))
    product_name = Column(String)
    variant_id = Column(Integer, ForeignKey("variants.id"), nullable=True)
    variant_info = Column(String)
    quantity = Column(Integer)
    price = Column(Integer)
    order = relationship("Order", back_populates="items")

# --- 3. HÀM HỖ TRỢ ---
def clean_money(val):
    """
    Giữ nguyên giá trị số từ Excel (VD: 400 -> 400).
    Không nhân 1000.
    """
    if pd.isna(val) or str(val).strip() == '':
        return 0
    try:
        if isinstance(val, (int, float)):
            return int(val)
        
        clean = str(val).strip().replace(',', '').replace(' ', '')
        if '(' in clean and ')' in clean:
            clean = '-' + clean.replace('(', '').replace(')', '')
            
        return int(float(clean))
    except:
        return 0

def parse_date(val):
    if pd.isna(val) or str(val).strip() == '':
        return None
    text = str(val).strip()
    for fmt in ('%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%Y/%m/%d %H:%M:%S', '%Y-%m-%d %H:%M:%S'):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    return None

# --- 4. LOGIC NHẬP KHO (TỪ FILE BÁN HÀNG) ---
def import_inventory(db):
    print("\n📦 ĐANG NHẬP KHO TỪ 'BÁN HÀNG.xlsx' (SHEET: MÃ HÀNG)...")
    file_path = "BÁN HÀNG.xlsx"
    if not os.path.exists(file_path):
        print(f"❌ Không tìm thấy {file_path}")
        return

    try:
        df = pd.read_excel(file_path, sheet_name="MÃ HÀNG")
        count = 0
        for _, row in df.iterrows():
            # Cột MH là Tên/Mã, ĐG là Giá
            p_name = str(row.get('MH', '')).strip()
            price = clean_money(row.get('ĐG', 0))
            
            if not p_name or p_name.lower() == 'nan': continue
            
            # Tạo Product nếu chưa có
            if not db.query(Product).filter(Product.name == p_name).first():
                prod = Product(name=p_name)
                db.add(prod)
                db.commit()
                db.refresh(prod)
                
                # Tạo Variant mặc định: Đen, 40, Stock 20
                var = Variant(
                    product_id=prod.id,
                    color="Đen",
                    size="40",
                    stock=20,
                    price=price
                )
                db.add(var)
                db.commit()
                count += 1
        print(f"✅ Đã nhập {count} mẫu sản phẩm vào kho.")
    except Exception as e:
        print(f"❌ Lỗi nhập kho: {e}")

# --- 5. LOGIC NHẬP TỪ RESULT.XLSX ---
def import_from_result(db):
    print("\n📊 ĐANG NHẬP HÓA ĐƠN & CÔNG NỢ TỪ 'result.xlsx'...")
    file_path = "result.xlsx"
    if not os.path.exists(file_path):
        print(f"❌ Không tìm thấy {file_path}")
        return

    try:
        df = pd.read_excel(file_path)
        df.columns = [str(c).strip().upper() for c in df.columns]

        # Group by (KHÁCH HÀNG, NGÀY) để gom các đơn cùng ngày
        grouped = df.groupby(['KHÁCH HÀNG', 'NGÀY'])

        for (customer_name, date_str), group in grouped:
            customer_name = str(customer_name).strip()
            date_str = str(date_str).strip()

            print(f"   -> Xử lý: {customer_name} ({date_str})")

            # Tạo khách nếu chưa có
            cust = db.query(Customer).filter(Customer.name == customer_name).first()
            if not cust:
                cust = Customer(name=customer_name, phone="", debt=0)
                db.add(cust)
                db.commit()
                db.refresh(cust)

            # Parse ngày
            order_date = parse_date(date_str)
            if not order_date:
                order_date = datetime.now()

            # Duyệt từng dòng trong nhóm (KHÁCH HÀNG, NGÀY)
            pending_items = []
            operation_index = 0  # Đếm số thao tác để thêm phút

            for idx, row in group.iterrows():
                ma_hang = str(row.get('MÃ HÀNG', '')).strip()
                so_luong = clean_money(row.get('SỐ LƯỢNG', 0))

                # Tính thời gian với phút tương ứng
                operation_date = order_date + timedelta(minutes=operation_index)
                operation_ts = int(operation_date.timestamp() * 1000) if hasattr(operation_date, 'timestamp') else int(datetime.utcnow().timestamp() * 1000)

                # Các trường hợp đặc biệt: TRẢ TIỀN, CÔNG NỢ, SANG SỔ, NHẦM
                if ma_hang == "TRẢ TIỀN":
                    # Lưu các đơn mua trước đó
                    if pending_items:
                        save_order(db, cust, pending_items)
                        pending_items = []
                        operation_index += 1
                        operation_date = order_date + timedelta(minutes=operation_index)
                        operation_ts = int(operation_date.timestamp() * 1000) if hasattr(operation_date, 'timestamp') else int(datetime.utcnow().timestamp() * 1000)

                    # Tạo DebtLog trừ tiền
                    cust.debt += so_luong  # so_luong là số âm
                    log = DebtLog(
                        customer_id=cust.id,
                        change_amount=so_luong,
                        new_balance=cust.debt,
                        note="Trả tiền",
                        created_at=operation_date,
                        created_ts=operation_ts
                    )
                    db.add(log)
                    operation_index += 1

                elif ma_hang in ["CÔNG NỢ", "SANG SỔ", "NHẦM"]:
                    # Lưu các đơn mua trước đó
                    if pending_items:
                        save_order(db, cust, pending_items)
                        pending_items = []
                        operation_index += 1
                        operation_date = order_date + timedelta(minutes=operation_index)
                        operation_ts = int(operation_date.timestamp() * 1000) if hasattr(operation_date, 'timestamp') else int(datetime.utcnow().timestamp() * 1000)

                    # Tạo DebtLog cộng tiền
                    cust.debt += so_luong
                    log = DebtLog(
                        customer_id=cust.id,
                        change_amount=so_luong,
                        new_balance=cust.debt,
                        note=ma_hang,
                        created_at=operation_date,
                        created_ts=operation_ts
                    )
                    db.add(log)
                    operation_index += 1

                else:
                    # Mua hàng bình thường
                    if not ma_hang or ma_hang.lower() == 'nan':
                        continue

                    # Tìm mã hàng trong database
                    prod = db.query(Product).filter(Product.name == ma_hang).first()
                    if not prod:
                        print(f"   ⚠️ LỖI: Không tìm thấy mã hàng '{ma_hang}' trong kho (khách: {customer_name}, ngày: {date_str})")
                        continue

                    # Lấy variant đầu tiên (Đen, 40)
                    var = prod.variants[0] if prod.variants else None
                    if not var:
                        print(f"   ⚠️ LỖI: Sản phẩm '{ma_hang}' không có variant (khách: {customer_name})")
                        continue

                    # Thêm vào pending_items
                    pending_items.append({
                        "product_name": ma_hang,
                        "variant_id": var.id,
                        "variant_info": f"{var.size}/{var.color}",
                        "quantity": int(so_luong) if so_luong > 0 else 1,
                        "price": var.price,
                        "operation_date": operation_date,
                        "operation_ts": operation_ts
                    })
                    operation_index += 1

            # Lưu đơn cuối cùng
            if pending_items:
                save_order(db, cust, pending_items)

        print(f"✅ Đã nhập hóa đơn công nợ từ result.xlsx")
    except Exception as e:
        print(f"❌ Lỗi nhập result.xlsx: {e}")

def save_order(db, customer, items):
    if not items: return

    # Lấy thời gian từ item đầu tiên
    order_date = items[0].get("operation_date")
    order_ts = items[0].get("operation_ts")

    # Tính tổng tiền
    total = sum([i['quantity'] * i['price'] for i in items])

    order = Order(
        customer_id=customer.id,
        customer_name=customer.name,
        total_amount=total,
        created_at=order_date,
        created_ts=order_ts
    )
    db.add(order)
    db.flush()

    for i in items:
        item = OrderItem(
            order_id=order.id,
            product_name=i['product_name'],
            variant_id=i['variant_id'],
            variant_info=i['variant_info'],
            quantity=i['quantity'],
            price=i['price']
        )
        db.add(item)

    customer.debt += total
    db.commit()

if __name__ == "__main__":
    if os.path.exists(DB_PATH):
        os.remove(DB_PATH)

    Base.metadata.create_all(bind=engine)
    db = SessionLocal()

    import_inventory(db)
    import_from_result(db)

    db.close()
    print("\n✅ NHẬP LIỆU HOÀN TẤT!")