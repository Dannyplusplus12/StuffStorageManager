import random
import os
from datetime import datetime, timedelta
from backend.database import SessionLocal, Product, Variant, Order, OrderItem, Customer, DebtLog, engine, Base

# --- DANH SÁCH DỮ LIỆU MẪU ---

PRODUCT_NAMES = [
    "Sandal Chiến Binh", "Giày Lười Vải Bố", "Boot Da Lộn Cổ Thấp", 
    "Giày Bata Thượng Đình Style", "Dép Tổ Ong Cao Cấp", "Giày Sneaker Chunky", 
    "Giày Cao Gót 7cm", "Giày Tây Da Bóng", "Dép Slide Unisex", 
    "Giày Chạy Bộ Siêu Nhẹ", "Sục Cross Văn Phòng", "Giày Vải Canvas Trắng",
    "Giày Bóng Rổ Jordan Fake", "Dép Lào Beach Vibe", "Giày Mọi Nam Công Sở",
    "Boots Cổ Cao Fashion", "Giày Slip-on Caro", "Giày Đá Bóng Sân Cỏ"
]

CUSTOMER_DATA = [
    {"name": "Đại lý Minh Hằng", "phone": "0901234567"},
    {"name": "Kho Sỉ Giày 365", "phone": "0918765432"},
    {"name": "Shop Mẹ và Bé", "phone": "0988888888"},
    {"name": "Anh Tuấn (Ninh Hiệp)", "phone": "0977777777"},
    {"name": "Chị Lan (An Đông)", "phone": "0909090909"},
    {"name": "Khách Lẻ Vãng Lai", "phone": ""}
]

COLORS_POOL = ["Trắng", "Đen", "Be", "Nâu", "Xanh Rêu", "Xám Tiêu", "Đỏ Đô", "Vàng Chanh"]
SIZES = ["36", "37", "38", "39", "40", "41", "42", "43"]
AVAILABLE_IMAGES = ["1.jpg", "2.jpg", "3.jpg"] 

def seed_database():
    print("🔄 Đang xóa và khởi tạo dữ liệu MỚI...")
    
    # Reset Database
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    db = SessionLocal()
    
    # 1. Tạo Khách Hàng
    print("👥 Đang tạo hồ sơ khách hàng...")
    customers_objs = []
    for c in CUSTOMER_DATA:
        cust = Customer(name=c["name"], phone=c["phone"], debt=0)
        db.add(cust)
        customers_objs.append(cust)
    db.commit() 

    # 2. Tạo Sản Phẩm & Biến Thể
    all_variants = []
    print("📦 Đang nhập kho (Test logic Màu sắc UI & Giá theo Size)...")
    
    for i, name in enumerate(PRODUCT_NAMES):
        img_name = random.choice(AVAILABLE_IMAGES)
        prod = Product(name=name, description="Hàng mới về, giá tốt.", image_path=f"assets/images/{img_name}")
        db.add(prod)
        db.flush()

        # Random kịch bản tồn kho
        stock_scenario = random.choices([0, 1, 2], weights=[20, 20, 60])[0]
        selected_colors = random.sample(COLORS_POOL, k=random.randint(2, 3))
        base_price = random.randint(100, 500) * 1000 
        
        for color in selected_colors:
            for size_idx, size in enumerate(SIZES):
                price = base_price + (size_idx * 5000)
                stock = 0
                if stock_scenario == 0: stock = random.randint(0, 3)
                elif stock_scenario == 1: 
                    if random.random() < 0.2: stock = random.randint(0, 5)
                    else: stock = random.randint(50, 100)
                else: stock = random.randint(30, 200)

                var = Variant(product_id=prod.id, color=color, size=size, price=price, stock=stock)
                db.add(var)
                all_variants.append(var)
    
    db.commit()

    # 3. Tạo Lịch sử giao dịch
    print("📜 Đang tạo đơn hàng giả lập...")
    sellable_variants = [v for v in all_variants if v.stock > 0]
    
    for _ in range(40): 
        days_ago = random.randint(0, 30)
        fake_date = datetime.now() - timedelta(days=days_ago, hours=random.randint(8, 20))
        cust = random.choice(customers_objs)
        
        num_items = random.randint(3, 6) 
        chosen_vars = random.sample(sellable_variants, k=min(num_items, len(sellable_variants)))
        
        total_money = 0
        order_items_buffer = []

        for var in chosen_vars:
            qty = random.randint(5, 20)
            
            # --- SỬA LỖI LEGACY Ở ĐÂY: Dùng db.get() thay vì db.query().get() ---
            current_var = db.get(Variant, var.id) 
            # --------------------------------------------------------------------
            
            if current_var.stock < qty: qty = max(1, current_var.stock)
            if qty <= 0: continue

            price = var.price
            if qty >= 10: price -= 2000 
            
            total_money += price * qty
            
            # --- SỬA LỖI LEGACY Ở ĐÂY ---
            prod = db.get(Product, var.product_id)
            p_name = prod.name
            # ----------------------------
            
            order_items_buffer.append({
                "name": p_name, "info": f"{var.color} - Size {var.size}",
                "qty": qty, "price": price
            })
            var.stock = max(0, var.stock - qty)

        if total_money > 0:
            order = Order(created_at=fake_date, total_amount=total_money, customer_name=cust.name, customer_id=cust.id)
            db.add(order)
            db.flush()
            for item in order_items_buffer:
                db.add(OrderItem(order_id=order.id, product_name=item["name"], variant_info=item["info"], quantity=item["qty"], price=item["price"]))
            
            cust.debt += total_money
            
            if random.random() < 0.3:
                pay_amount = int(total_money * random.uniform(0.5, 1.0) / 1000) * 1000
                cust.debt -= pay_amount
                pay_date = fake_date + timedelta(days=random.randint(1, 5))
                if pay_date > datetime.now(): pay_date = datetime.now()
                
                log = DebtLog(
                    customer_id=cust.id, 
                    change_amount=-pay_amount, 
                    new_balance=cust.debt, 
                    note="Điều chỉnh thủ công", 
                    created_at=pay_date
                )
                db.add(log)

    db.commit()
    db.close()
    print("✅ HOÀN TẤT! Đã fix lỗi Legacy Warning và cập nhật nội dung log.")

if __name__ == "__main__":
    seed_database()