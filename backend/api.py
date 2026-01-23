from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
from backend.database import SessionLocal, Product, Variant, Order, OrderItem

app = FastAPI()

# --- Pydantic Models ---
class VariantUpdate(BaseModel):
    id: Optional[int] = None
    color: str
    size: str
    price: int
    stock: int

class ProductUpdate(BaseModel):
    name: str
    image_path: str
    variants: List[VariantUpdate]

class ProductCreate(BaseModel):
    name: str
    description: str
    image_path: str
    variants: List[VariantUpdate]

# Model cho 1 món hàng trong giỏ
class CartItem(BaseModel):
    variant_id: int
    quantity: int
    price: int
    product_name: str
    color: str
    size: str

# Model cho Yêu cầu thanh toán (Gồm tên khách + Danh sách hàng)
class CheckoutRequest(BaseModel):
    customer_name: str
    cart: List[CartItem]

# --- API ---

@app.get("/products")
def get_products(search: str = ""):
    db = SessionLocal()
    query = db.query(Product)
    if search:
        query = query.filter(Product.name.contains(search))
    
    results = []
    products = query.all()
    for p in products:
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

@app.put("/products/{product_id}")
def update_product(product_id: int, p_data: ProductUpdate):
    db = SessionLocal()
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        db.close()
        raise HTTPException(status_code=404, detail="Not found")
    
    product.name = p_data.name
    product.image_path = p_data.image_path
    
    current_ids = {v.id for v in product.variants}
    incoming_ids = {v.id for v in p_data.variants if v.id is not None}
    to_delete = current_ids - incoming_ids
    if to_delete:
        db.query(Variant).filter(Variant.id.in_(to_delete)).delete(synchronize_session=False)
    
    for v_data in p_data.variants:
        if v_data.id and v_data.id in current_ids:
            var = db.query(Variant).filter(Variant.id == v_data.id).first()
            var.color = v_data.color
            var.size = v_data.size
            var.price = v_data.price
            var.stock = v_data.stock
        else:
            new_var = Variant(product_id=product.id, color=v_data.color, size=v_data.size, price=v_data.price, stock=v_data.stock)
            db.add(new_var)
            
    db.commit()
    db.close()
    return {"status": "updated"}

# --- API CHECKOUT MỚI (NHẬN TÊN KHÁCH) ---
@app.post("/checkout")
def checkout(data: CheckoutRequest):
    db = SessionLocal()
    total = sum([item.quantity * item.price for item in data.cart])
    
    # 1. Trừ kho
    for item in data.cart:
        variant = db.query(Variant).filter(Variant.id == item.variant_id).first()
        if not variant or variant.stock < item.quantity:
            db.close()
            raise HTTPException(status_code=400, detail=f"Sản phẩm {item.product_name} không đủ hàng!")
        variant.stock -= item.quantity
    
    # 2. Tạo đơn hàng (Lưu tên khách)
    new_order = Order(
        total_amount=total, 
        customer_name=data.customer_name if data.customer_name.strip() else "Khách lẻ"
    )
    db.add(new_order)
    db.commit()
    db.refresh(new_order)
    
    # 3. Tạo chi tiết
    for item in data.cart:
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
        # Tính tổng số lượng hàng trong đơn
        total_items = sum([item.quantity for item in o.items])
        
        # Lấy chi tiết items
        details = []
        for i in o.items:
            details.append({
                "name": i.product_name,
                "variant": i.variant_info,
                "qty": i.quantity,
                "price": i.price
            })

        res.append({
            "id": o.id,
            "customer": o.customer_name, # Trả về tên khách
            "date": o.created_at.strftime("%d/%m %H:%M"),
            "total_money": o.total_amount,
            "total_qty": total_items, # Trả về tổng số lượng
            "items": details # Trả về full chi tiết để hiển thị popup
        })
    db.close()
    return res