from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional, Union
from backend.database import SessionLocal, Product, Variant, Order, OrderItem, Customer, DebtLog
from sqlalchemy import desc

app = FastAPI()

# --- MODELS ---
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

class CartItem(BaseModel):
    variant_id: int
    quantity: int
    price: int
    product_name: str
    color: str
    size: str

class CheckoutRequest(BaseModel):
    customer_name: str
    customer_phone: str = ""
    cart: List[CartItem]

class CustomerUpdate(BaseModel):
    name: str
    phone: str
    debt: int 

# --- API SẢN PHẨM ---
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
            "id": p.id, "name": p.name, "image": p.image_path, "price_range": price_range,
            "variants": [{"id": v.id, "color": v.color, "size": v.size, "price": v.price, "stock": v.stock} for v in p.variants]
        })
    db.close()
    return results

@app.post("/products")
def create_product(p: ProductCreate):
    db = SessionLocal()
    new_prod = Product(name=p.name, description=p.description, image_path=p.image_path)
    db.add(new_prod); db.commit(); db.refresh(new_prod)
    for v in p.variants:
        db.add(Variant(product_id=new_prod.id, color=v.color, size=v.size, price=v.price, stock=v.stock))
    db.commit(); db.close()
    return {"status": "ok"}

@app.put("/products/{product_id}")
def update_product(product_id: int, p_data: ProductUpdate):
    db = SessionLocal()
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product: db.close(); raise HTTPException(status_code=404)
    product.name = p_data.name; product.image_path = p_data.image_path
    
    current_ids = {v.id for v in product.variants}
    incoming_ids = {v.id for v in p_data.variants if v.id is not None}
    to_delete = current_ids - incoming_ids
    if to_delete: db.query(Variant).filter(Variant.id.in_(to_delete)).delete(synchronize_session=False)
    
    for v_data in p_data.variants:
        if v_data.id and v_data.id in current_ids:
            var = db.query(Variant).filter(Variant.id == v_data.id).first()
            var.color = v_data.color; var.size = v_data.size
            var.price = v_data.price; var.stock = v_data.stock
        else:
            db.add(Variant(product_id=product.id, color=v_data.color, size=v_data.size, price=v_data.price, stock=v_data.stock))
    db.commit(); db.close()
    return {"status": "updated"}

@app.delete("/products/{product_id}")
def delete_product(product_id: int):
    db = SessionLocal()
    p = db.query(Product).filter(Product.id == product_id).first()
    if p: db.delete(p); db.commit()
    db.close()
    return {"status": "deleted"}

# --- API KHÁCH HÀNG & CÔNG NỢ ---

@app.get("/customers")
def get_customers():
    db = SessionLocal()
    custs = db.query(Customer).order_by(desc(Customer.id)).all()
    res = [{"id": c.id, "name": c.name, "phone": c.phone, "debt": c.debt} for c in custs]
    db.close()
    return res

@app.put("/customers/{cid}")
def update_customer_excel(cid: int, data: CustomerUpdate):
    db = SessionLocal()
    cust = db.query(Customer).filter(Customer.id == cid).first()
    if not cust: db.close(); raise HTTPException(status_code=404)
    
    diff = data.debt - cust.debt
    cust.name = data.name; cust.phone = data.phone; cust.debt = data.debt
    
    if diff != 0:
        log = DebtLog(customer_id=cust.id, change_amount=diff, new_balance=cust.debt, note="Điều chỉnh thủ công")
        db.add(log)
        
    db.commit(); db.close()
    return {"status": "ok"}

@app.get("/customers/{cid}/history")
def get_customer_history(cid: int):
    db = SessionLocal()
    # 1. Lấy đơn hàng (Tự động coi là nợ tăng)
    orders = db.query(Order).filter(Order.customer_id == cid).all()
    history = []
    for o in orders:
        total_items = sum([i.quantity for i in o.items])
        
        # Tạo dữ liệu chi tiết để Frontend popup
        details = [{"name": i.product_name, "variant": i.variant_info, "qty": i.quantity, "price": i.price} for i in o.items]
        order_data_full = {
            "id": o.id, "customer": o.customer_name, 
            "date": o.created_at.strftime("%d/%m %H:%M"),
            "total_money": o.total_amount, "total_qty": total_items, "items": details
        }

        history.append({
            "type": "ORDER",
            "date": o.created_at.strftime("%Y-%m-%d %H:%M"),
            "desc": f"Mua đơn hàng #{o.id} ({total_items} món)",
            "amount": o.total_amount, 
            "data": order_data_full # Dữ liệu để popup
        })
    
    # 2. Lấy log nợ (Điều chỉnh tay)
    logs = db.query(DebtLog).filter(DebtLog.customer_id == cid).all()
    for l in logs:
        history.append({
            "type": "LOG",
            "date": l.created_at.strftime("%Y-%m-%d %H:%M"),
            "desc": l.note,
            "amount": l.change_amount, 
            "data": None
        })
    
    history.sort(key=lambda x: x['date'], reverse=True)
    db.close()
    return history

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
        variant.stock = variant.stock - item.quantity 
    
    # 2. Xử lý khách hàng
    c_name = data.customer_name.strip()
    customer = None
    if c_name:
        customer = db.query(Customer).filter(Customer.name == c_name).first()
        if not customer:
            customer = Customer(name=c_name, phone=data.customer_phone, debt=0)
            db.add(customer); db.commit(); db.refresh(customer)
        
        # 3. Cộng nợ (FIX LỖI DOUBLE LOG: CHỈ CỘNG NỢ, KHÔNG GHI LOG NỮA)
        # Vì đơn hàng sinh ra (Order) đã được tính là một record trong lịch sử rồi.
        customer.debt += total 

    # 4. Tạo đơn hàng
    new_order = Order(
        total_amount=total, 
        customer_name=c_name if c_name else "Khách lẻ",
        customer_id=customer.id if customer else None
    )
    db.add(new_order); db.commit(); db.refresh(new_order)
    
    for item in data.cart:
        db.add(OrderItem(
            order_id=new_order.id, product_name=item.product_name,
            variant_info=f"{item.color} - Size {item.size}",
            quantity=item.quantity, price=item.price
        ))
    
    db.commit(); db.close()
    return {"status": "success"}

@app.get("/orders")
def get_orders():
    db = SessionLocal()
    orders = db.query(Order).order_by(desc(Order.created_at)).all()
    res = []
    for o in orders:
        total_items = sum([i.quantity for i in o.items])
        details = [{"name": i.product_name, "variant": i.variant_info, "qty": i.quantity, "price": i.price} for i in o.items]
        res.append({
            "id": o.id, "customer": o.customer_name, 
            "date": o.created_at.strftime("%d/%m %H:%M"),
            "total_money": o.total_amount, "total_qty": total_items, "items": details
        })
    db.close()
    return res