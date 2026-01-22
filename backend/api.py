from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from backend.database import SessionLocal, Product, Variant, Order, OrderItem

app = FastAPI()

def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Pydantic Models (Dữ liệu đầu vào/ra) ---
class VariantBase(BaseModel):
    color: str
    size: str
    price: int
    stock: int

class ProductCreate(BaseModel):
    name: str
    description: str
    image_path: str
    variants: List[VariantBase]

class CartItem(BaseModel):
    variant_id: int
    quantity: int
    price: int # Giá tại thời điểm bán
    product_name: str
    color: str
    size: str

class VariantUpdate(BaseModel):
    id: Optional[int] = None # Nếu có ID là sửa, không có là thêm mới
    color: str
    size: str
    price: int
    stock: int

class ProductUpdate(BaseModel):
    name: str
    image_path: str
    variants: List[VariantUpdate]

# --- API Endpoints ---

@app.get("/products")
def get_products(search: str = ""):
    db = SessionLocal()
    query = db.query(Product)
    if search:
        query = query.filter(Product.name.contains(search))
    
    results = []
    products = query.all()
    # Format dữ liệu để frontend dễ hiển thị
    for p in products:
        # Tính khoảng giá
        prices = [v.price for v in p.variants]
        price_range = "Hết hàng"
        if prices:
            min_p, max_p = min(prices), max(prices)
            price_range = f"{min_p:,} - {max_p:,}" if min_p != max_p else f"{min_p:,}"
        
        results.append({
            "id": p.id,
            "name": p.name,
            "image": p.image_path,
            "price_range": price_range,
            "variants": [{"id": v.id, "color": v.color, "size": v.size, "price": v.price, "stock": v.stock} for v in p.variants]
        })
    db.close()
    return results

@app.post("/products")
def create_product(product: ProductCreate):
    db = SessionLocal()
    new_prod = Product(name=product.name, description=product.description, image_path=product.image_path)
    db.add(new_prod)
    db.commit()
    db.refresh(new_prod)
    
    for v in product.variants:
        new_var = Variant(product_id=new_prod.id, color=v.color, size=v.size, price=v.price, stock=v.stock)
        db.add(new_var)
    db.commit()
    db.close()
    return {"status": "ok"}

@app.post("/checkout")
def checkout(cart: List[CartItem]):
    db = SessionLocal()
    total = sum([item.quantity * item.price for item in cart])
    
    # 1. Trừ kho
    for item in cart:
        variant = db.query(Variant).filter(Variant.id == item.variant_id).first()
        if not variant or variant.stock < item.quantity:
            db.close()
            raise HTTPException(status_code=400, detail=f"Sản phẩm {item.product_name} ({item.color}/{item.size}) không đủ hàng!")
        variant.stock -= item.quantity
    
    # 2. Tạo đơn hàng
    new_order = Order(total_amount=total)
    db.add(new_order)
    db.commit()
    db.refresh(new_order)
    
    # 3. Tạo chi tiết
    for item in cart:
        order_item = OrderItem(
            order_id=new_order.id,
            product_name=item.product_name,
            variant_info=f"{item.color} - Size {item.size}",
            quantity=item.quantity,
            price=item.price
        )
        db.add(order_item)
    
    db.commit()
    db.close()
    return {"status": "success"}

@app.get("/orders")
def get_orders():
    db = SessionLocal()
    orders = db.query(Order).order_by(Order.created_at.desc()).all()
    res = []
    for o in orders:
        items_str = ", ".join([f"{i.product_name} ({i.quantity})" for i in o.items])
        res.append({
            "id": o.id,
            "date": o.created_at.strftime("%Y-%m-%d %H:%M"),
            "total": o.total_amount,
            "details": items_str
        })
    db.close()
    return res

@app.put("/products/{product_id}")
def update_product(product_id: int, p_data: ProductUpdate):
    db = SessionLocal()
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        db.close()
        raise HTTPException(status_code=404, detail="Không tìm thấy sản phẩm")
    
    # 1. Update thông tin chung
    product.name = p_data.name
    product.image_path = p_data.image_path
    
    # 2. Xử lý Variants
    # Lấy danh sách ID variants hiện tại trong DB
    current_var_ids = {v.id for v in product.variants}
    incoming_var_ids = {v.id for v in p_data.variants if v.id is not None}
    
    # Xóa các variant không còn trong danh sách gửi lên
    to_delete_ids = current_var_ids - incoming_var_ids
    if to_delete_ids:
        db.query(Variant).filter(Variant.id.in_(to_delete_ids)).delete(synchronize_session=False)
    
    # Thêm mới hoặc Cập nhật
    for v_data in p_data.variants:
        if v_data.id and v_data.id in current_var_ids:
            # Update
            var = db.query(Variant).filter(Variant.id == v_data.id).first()
            var.color = v_data.color
            var.size = v_data.size
            var.price = v_data.price
            var.stock = v_data.stock
        else:
            # Create new
            new_var = Variant(
                product_id=product.id, 
                color=v_data.color, 
                size=v_data.size, 
                price=v_data.price, 
                stock=v_data.stock
            )
            db.add(new_var)
            
    db.commit()
    db.close()
    return {"status": "updated"}