import random
import os
from datetime import datetime, timedelta
from backend.database import SessionLocal, Product, Variant, Order, OrderItem, engine, Base

# --- CẤU HÌNH DỮ LIỆU SỈ (WHOLESALE) ---

PRODUCT_NAMES = [
    "Sandal Chiến Binh", "Giày Lười Vải Bố", "Boot Da Lộn Cổ Thấp", 
    "Giày Bata Thượng Đình Style", "Dép Tổ Ong Cao Cấp", "Giày Sneaker Chunky", 
    "Giày Cao Gót 7cm", "Giày Tây Da Bóng", "Dép Slide Unisex", 
    "Giày Chạy Bộ Siêu Nhẹ", "Sục Cross Văn Phòng", "Giày Vải Canvas Trắng"
]

CUSTOMER_NAMES = [
    "Đại lý Minh Hằng (Hà Nội)", "Kho Sỉ Giày 365", "Shop Mẹ và Bé (Q.5)", 
    "Anh Tuấn (Chợ Ninh Hiệp)", "Chị Lan (Chợ An Đông)", "Shop Giày Xinh (Đà Nẵng)", 
    "Kho Tổng Miền Nam", "Khách Buôn (Zalo)", "Chị Thảo (Sỉ SLL)"
]

COLORS = ["Trắng", "Đen", "Be", "Nâu", "Xanh Rêu", "Xám Tiêu"]
SIZES = ["36", "37", "38", "39", "40", "41", "42", "43"]
AVAILABLE_IMAGES = ["1.jpg", "2.jpg", "3.jpg"] 

def seed_database():
    print("🔄 Đang xóa và khởi tạo dữ liệu MÔ HÌNH SỈ...")
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    all_variants = []
    
    print("📦 Đang nhập kho số lượng LỚN...")
    for name in PRODUCT_NAMES:
        # Tạo sản phẩm
        prod = Product(name=name, description="Hàng lô mới về", image_path=f"assets/images/{random.choice(AVAILABLE_IMAGES)}")
        db.add(prod)
        db.flush()

        # Tạo hàng loạt biến thể (Kho sỉ nên tồn vài trăm đến vài ngàn đôi)
        base_price = random.randint(50, 200) * 1000 # Giá sỉ rẻ hơn (50k - 200k)
        
        for color in random.sample(COLORS, 3):
            for size in SIZES:
                # Tồn kho cực lớn để đủ bán sỉ
                stock = random.choice([200, 500, 1000, 2000])
                
                var = Variant(
                    product_id=prod.id,
                    color=color, size=size,
                    price=base_price, # Giá sỉ thường đồng giá theo mẫu
                    stock=stock
                )
                db.add(var)
                all_variants.append(var)
    
    db.commit()

    print("📜 Đang tạo đơn hàng SỈ (Số lượng 50-200 đôi/đơn)...")
    for _ in range(20): # 20 đơn sỉ
        days_ago = random.randint(0, 10)
        fake_date = datetime.now() - timedelta(days=days_ago, hours=random.randint(8, 18))
        cust = random.choice(CUSTOMER_NAMES)
        
        # Một đơn sỉ thường lấy nhiều mã
        num_items = random.randint(3, 8) 
        chosen_vars = random.sample(all_variants, k=num_items)
        
        total_money = 0
        order_items_buffer = []

        for var in chosen_vars:
            # Sỉ mua theo ri hoặc số lượng lớn (10, 20, 50, 100 đôi)
            qty = random.choice([10, 20, 50, 100, 200])
            price = var.price
            
            # Logic giảm giá nếu mua nhiều
            if qty >= 100: price = price - 5000 
            
            total_money += price * qty
            order_items_buffer.append({
                "name": db.query(Product).get(var.product_id).name,
                "info": f"{var.color} / {var.size}",
                "qty": qty,
                "price": price
            })
            # Trừ kho
            var.stock -= qty

        order = Order(created_at=fake_date, total_amount=total_money, customer_name=cust)
        db.add(order)
        db.flush()
        
        for item in order_items_buffer:
            oi = OrderItem(
                order_id=order.id, product_name=item["name"],
                variant_info=item["info"], quantity=item["qty"], price=item["price"]
            )
            db.add(oi)

    db.commit()
    db.close()
    print("✅ Xong! Đã có dữ liệu chuyên Sỉ.")

if __name__ == "__main__":
    seed_database()