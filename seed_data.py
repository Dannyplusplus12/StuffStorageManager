import random
from datetime import datetime, timedelta
from backend.database import SessionLocal, Product, Variant, Order, OrderItem, engine, Base

# --- CẤU HÌNH DỮ LIỆU GIẢ ---

PRODUCT_NAMES = [
    "Giày Sneaker Basic White", "Giày Chạy Bộ Sport Pro", "Giày Tây Oxford Classic", 
    "Giày Lười Da Bò", "Boot Cổ Cao Fashion", "Sandal Mùa Hè Cool", 
    "Giày Bóng Rổ Jordan Fake", "Dép Slide Simple", "Giày Vải Canvas Vintage", 
    "Giày Cao Gót Office", "Giày Slip-on Caro", "Giày Chunky Big Sole",
    "Giày Đá Bóng Sân Cỏ", "Giày Đi Bộ Êm Chân", "Boots Da Lộn",
    "Giày Búp Bê Cute", "Giày Mọi Nam Công Sở", "Dép Lào Beach Vibe",
    "Giày Training Phòng Gym", "Sneaker High-Top Streetwear"
]

COLORS = ["Trắng", "Đen", "Xám", "Xanh Navy", "Đỏ Đô", "Nâu Da Bò", "Kem", "Hồng Pastel"]

SIZES = ["38", "39", "40", "41", "42", "43"]

# Danh sách ảnh có sẵn trong thư mục assets/images của bạn
AVAILABLE_IMAGES = ["1.jpg", "2.jpg", "3.jpg"]

# --- HÀM TẠO DỮ LIỆU ---

def seed_database():
    print("🔄 Đang xóa dữ liệu cũ và khởi tạo database mới...")
    
    # Xóa và tạo lại bảng để dữ liệu sạch sẽ
    Base.metadata.drop_all(bind=engine)
    Base.metadata.create_all(bind=engine)
    
    db = SessionLocal()
    
    products_list = []
    variants_list = []
    
    print("📦 Đang tạo sản phẩm và gán ảnh ngẫu nhiên...")
    
    # 1. TẠO SẢN PHẨM & BIẾN THỂ
    for i, name in enumerate(PRODUCT_NAMES):
        # Chọn ngẫu nhiên 1 ảnh từ danh sách 3 ảnh bạn có
        random_img = random.choice(AVAILABLE_IMAGES)
        
        # Tạo sản phẩm
        product = Product(
            name=name,
            description=f"Mô tả chi tiết cho {name}. Chất liệu cao cấp, thoáng khí, phù hợp đi chơi và đi làm.",
            image_path=f"assets/images/{random_img}" # Đường dẫn trỏ tới file ảnh
        )
        db.add(product)
        db.flush() # Để lấy product.id ngay lập tức
        products_list.append(product)

        # Tạo biến thể (Mỗi giày chọn ngẫu nhiên 2-3 màu)
        selected_colors = random.sample(COLORS, k=random.randint(2, 3))
        base_price = random.randint(150, 800) * 1000 # Giá gốc từ 150k đến 800k
        
        for color in selected_colors:
            for size in SIZES:
                # Logic giá: Size càng to càng đắt thêm 1 chút
                # Ví dụ: Size 38 giá gốc, Size 39 + 10k, Size 40 + 20k
                size_diff = int(size) - 38
                price_variation = base_price + (size_diff * 10000)
                
                variant = Variant(
                    product_id=product.id,
                    color=color,
                    size=size,
                    price=price_variation,
                    stock=random.randint(5, 50) # Tồn kho ngẫu nhiên
                )
                db.add(variant)
                variants_list.append(variant)
    
    db.commit() # Lưu kho hàng

    print("📜 Đang tạo lịch sử đơn hàng giả lập (30 ngày qua)...")
    
    # 2. TẠO LỊCH SỬ ĐƠN HÀNG (HISTORY)
    # Reload lại danh sách variant đã có ID
    all_variants = db.query(Variant).all()
    
    for _ in range(50): # Tạo 50 đơn hàng giả
        # Random ngày giờ trong 30 ngày qua
        days_ago = random.randint(0, 30)
        hours_ago = random.randint(0, 23)
        fake_date = datetime.now() - timedelta(days=days_ago, hours=hours_ago)
        
        # Random số món mua trong 1 đơn (1-5 món)
        num_items = random.randint(1, 5)
        cart_items = random.sample(all_variants, k=min(num_items, len(all_variants)))
        
        total_amount = 0
        order_items_data = []
        
        for var in cart_items:
            qty = random.randint(1, 3)
            # Lấy tên sản phẩm từ quan hệ
            prod_name = db.query(Product).get(var.product_id).name
            
            item_total = var.price * qty
            total_amount += item_total
            
            # Tạo chi tiết đơn hàng
            order_items_data.append({
                "product_name": prod_name,
                "variant_info": f"{var.color} - Size {var.size}",
                "quantity": qty,
                "price": var.price
            })
            
            # Trừ kho giả lập (để dữ liệu logic)
            var.stock = max(0, var.stock - qty)

        # Tạo đơn hàng
        order = Order(created_at=fake_date, total_amount=total_amount)
        db.add(order)
        db.flush()
        
        # Lưu các item vào đơn
        for item_data in order_items_data:
            order_item = OrderItem(
                order_id=order.id,
                product_name=item_data["product_name"],
                variant_info=item_data["variant_info"],
                quantity=item_data["quantity"],
                price=item_data["price"]
            )
            db.add(order_item)

    db.commit()
    db.close()
    print("✅ Đã tạo dữ liệu giả thành công với hình ảnh!")
    print(f"Ảnh đang sử dụng: {AVAILABLE_IMAGES}")

if __name__ == "__main__":
    seed_database()