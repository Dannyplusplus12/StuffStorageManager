import os
import random
from datetime import datetime, timedelta
from sqlalchemy import create_engine, Column, Integer, String, ForeignKey, DateTime
from sqlalchemy.orm import sessionmaker, relationship, declarative_base

# --- CẤU HÌNH DATABASE ---
DB_NAME = "shop.db"

# 1. Xóa DB cũ
if os.path.exists(DB_NAME):
    os.remove(DB_NAME)
    # avoid non-ascii characters to keep console encoding safe in all environments
    print(f"Removed old DB file {DB_NAME}.")

DATABASE_URL = f"sqlite:///{DB_NAME}"
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()

# --- MODELS (GIỮ NGUYÊN) ---
class Product(Base):
    __tablename__ = "products"
    id = Column(Integer, primary_key=True, index=True)
    name = Column(String, index=True)
    description = Column(String, default="")
    image_path = Column(String, default="") 
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
    
    logs = relationship("DebtLog", back_populates="customer", cascade="all, delete-orphan")
    orders = relationship("Order", back_populates="customer_rel")

class DebtLog(Base):
    __tablename__ = "debt_logs"
    id = Column(Integer, primary_key=True, index=True)
    customer_id = Column(Integer, ForeignKey("customers.id"))
    change_amount = Column(Integer)
    new_balance = Column(Integer)
    note = Column(String)
    created_at = Column(DateTime, default=datetime.now)
    
    customer = relationship("Customer", back_populates="logs")

class Order(Base):
    __tablename__ = "orders"
    id = Column(Integer, primary_key=True, index=True)
    customer_name = Column(String)
    customer_id = Column(Integer, ForeignKey("customers.id"), nullable=True)
    created_at = Column(DateTime, default=datetime.now)
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

# --- HÀM SINH DỮ LIỆU ---
def create_sample_data():
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    # avoid emoji to prevent encoding errors on some consoles
    print("Starting to generate sample data...")

    # 1. SẢN PHẨM
    shoe_models = [
        ("Nike Air Force 1", "assets/images/nike_af1.jpg", 1200000),
        ("Adidas Ultraboost 22", "assets/images/das_ultra.jpg", 1800000),
        ("Jordan 1 High Panda", "assets/images/jordan.jpg", 2500000),
        ("Dép Hermes Oran", "assets/images/hermes.jpg", 850000),
        ("Sandal Gucci Nam", "assets/images/gucci_sandal.jpg", 3200000),
        ("Giày Lười Loafer", "assets/images/loafer.jpg", 650000),
        ("Converse Classic High", "assets/images/converse.jpg", 500000),
        ("Vans Old Skool", "assets/images/vans.jpg", 550000),
        ("MLB Chunky Liner", "assets/images/mlb.jpg", 950000),
        ("Crocs Classic Clog", "assets/images/crocs.jpg", 350000),
        ("New Balance 530", "assets/images/nb530.jpg", 1100000),
        ("Dr. Martens 1460", "assets/images/doc.jpg", 2200000),
    ]
    sizes = ["36", "37", "38", "39", "40", "41", "42", "43"]
    colors = ["Trắng", "Đen", "Xám", "Be", "Đỏ", "Xanh Dương"]
    all_variants = []

    for idx, (name, img, base_price) in enumerate(shoe_models):
        prod = Product(name=name, description=f"Mô tả {name}", image_path=img)
        db.add(prod)
        db.flush()
        
        scenario = idx % 4 
        num_variants = random.randint(3, 5)
        selected_colors = random.sample(colors, min(len(colors), num_variants))

        for color in selected_colors:
            size = random.choice(sizes)
            stock = 0
            if scenario == 0: stock = 0
            elif scenario == 1: stock = random.randint(1, 19)
            elif scenario == 2: stock = random.randint(20, 100)
            else: stock = random.choice([0, random.randint(1, 10), random.randint(30, 80)])

            var = Variant(product_id=prod.id, color=color, size=size, price=base_price, stock=stock)
            db.add(var)
            all_variants.append(var)
    
    db.commit()
    print("Created products.")

    # 2. KHÁCH HÀNG
    customer_names = [("Kho Sỉ Chị Hạnh", "0909123456"), ("Shop Giày Đà Nẵng", "0912345678"), ("Shop Online Thảo Vy", "0905111222")]
    customers = []
    for name, phone in customer_names:
        cust = Customer(name=name, phone=phone, debt=0)
        db.add(cust)
        customers.append(cust)
    db.commit()

    # 3. ĐƠN HÀNG (SỬA LỖI DUPLICATE TẠI ĐÂY)
    all_variants = db.query(Variant).all()
    customers = db.query(Customer).all()
    num_orders = 15
    print(f"Generating {num_orders} orders...")

    for _ in range(num_orders):
        cust = random.choice(customers)
        days_ago = random.randint(0, 60)
        order_date = datetime.now() - timedelta(days=days_ago)

        # Tạo đơn
        num_items = random.randint(1, 3)
        selected_vars = random.sample(all_variants, num_items)
        
        new_order = Order(customer_name=cust.name, customer_id=cust.id, created_at=order_date, total_amount=0)
        db.add(new_order)
        db.flush()

        total_money = 0
        for var in selected_vars:
            qty = random.randint(5, 10)
            price = var.price
            total_money += qty * price
            db.add(OrderItem(order_id=new_order.id, product_name=var.product.name, variant_id=var.id, variant_info=f"{var.color}-{var.size}", quantity=qty, price=price))

        new_order.total_amount = total_money
        
        # --- CẬP NHẬT CÔNG NỢ ---
        # Chỉ cộng nợ vào Customer, KHÔNG TẠO DebtLog (vì Order chính là log mua hàng rồi)
        cust.debt += total_money
        
        # --- THANH TOÁN (ĐIỀU CHỈNH) ---
        if random.random() < 0.6:
            pay_amount = int(total_money * 0.8 / 1000) * 1000
            pay_date = order_date + timedelta(hours=2)
            
            cust.debt -= pay_amount
            # Tạo DebtLog cho việc trả tiền/điều chỉnh
            db.add(DebtLog(
                customer_id=cust.id,
                change_amount=-pay_amount, 
                new_balance=cust.debt,
                note=f"Điều chỉnh thủ công (Đơn #{new_order.id})", # Đổi nội dung note
                created_at=pay_date
            ))

    db.commit()
    db.close()
    print("Done. Sample data created.")

if __name__ == "__main__":
    create_sample_data()