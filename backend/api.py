from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import List, Optional
from sqlalchemy import desc
from sqlalchemy.orm import Session
from backend.database import SessionLocal, Product, Variant, Order, OrderItem, Customer, DebtLog

app = FastAPI()

# --- DEPENDENCY: KẾT NỐI DB (Đã sửa lỗi Syntax) ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- MODELS ---
class CustomerCreate(BaseModel):
    name: str
    phone: str = ""
    debt: int = 0

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

# --- API SẢN PHẨM (TRẢ VỀ LIST - KHÔNG PHÂN TRANG) ---
@app.get("/products")
def get_products(search: str = "", db: Session = Depends(get_db)):
    query = db.query(Product)
    if search:
        query = query.filter(Product.name.contains(search))
    
    # Lấy toàn bộ, sắp xếp mới nhất lên đầu
    products = query.order_by(desc(Product.id)).all()
    results = []
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
    return results

@app.post("/products")
def create_product(p: ProductCreate, db: Session = Depends(get_db)):
    new_prod = Product(name=p.name, description=p.description, image_path=p.image_path)
    db.add(new_prod)
    db.commit()
    db.refresh(new_prod)
    
    for v in p.variants:
        db.add(Variant(product_id=new_prod.id, color=v.color, size=v.size, price=v.price, stock=v.stock))
    db.commit()
    return {"status": "ok"}

@app.put("/products/{product_id}")
def update_product(product_id: int, p_data: ProductUpdate, db: Session = Depends(get_db)):
    product = db.query(Product).filter(Product.id == product_id).first()
    if not product:
        raise HTTPException(status_code=404)
    product.name = p_data.name
    product.image_path = p_data.image_path
    current_variants_map = {v.id: v for v in product.variants}
    current_ids = set(current_variants_map.keys())
    incoming_ids = {v.id for v in p_data.variants if v.id is not None}
    to_delete_ids = current_ids - incoming_ids
    for vid in to_delete_ids:
        variant_to_delete = current_variants_map.get(vid)
        if variant_to_delete:
            db.delete(variant_to_delete)
    for v_data in p_data.variants:
        if v_data.id and v_data.id in current_ids:
            var = current_variants_map[v_data.id] 
            var.color = v_data.color
            var.size = v_data.size
            var.price = v_data.price
            var.stock = v_data.stock
        else:
            new_var = Variant(
                product_id=product.id, 
                color=v_data.color, 
                size=v_data.size, 
                price=v_data.price, 
                stock=v_data.stock
            )
            db.add(new_var)
    db.commit()
    return {"status": "updated"}

@app.delete("/products/{product_id}")
def delete_product(product_id: int, db: Session = Depends(get_db)):
    p = db.query(Product).filter(Product.id == product_id).first()
    if p:
        db.query(Variant).filter(Variant.product_id == product_id).delete()
        db.delete(p)
        db.commit()
    return {"status": "deleted"}

# --- API KHÁCH HÀNG ---
@app.post("/customers")
def create_customer_manual(data: CustomerCreate, db: Session = Depends(get_db)):
    try:
        if db.query(Customer).filter(Customer.name == data.name).first():
            raise HTTPException(status_code=400, detail="Tên đã tồn tại!")
        
        new_cust = Customer(name=data.name, phone=data.phone, debt=data.debt)
        db.add(new_cust)
        db.flush()
        
        if data.debt != 0:
            db.add(DebtLog(customer_id=new_cust.id, change_amount=data.debt, new_balance=data.debt, note="Khởi tạo thủ công"))
        
        db.commit()
        db.refresh(new_cust)
        return {"status": "created", "id": new_cust.id}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/customers")
def get_customers(db: Session = Depends(get_db)):
    custs = db.query(Customer).order_by(desc(Customer.id)).all()
    return [{"id": c.id, "name": c.name, "phone": c.phone, "debt": c.debt} for c in custs]

@app.put("/customers/{cid}")
def update_customer_excel(cid: int, data: CustomerUpdate, db: Session = Depends(get_db)):
    cust = db.query(Customer).filter(Customer.id == cid).first()
    if not cust:
        raise HTTPException(status_code=404)
    
    diff = data.debt - cust.debt
    cust.name = data.name
    cust.phone = data.phone
    cust.debt = data.debt
    
    if diff != 0:
        db.add(DebtLog(customer_id=cust.id, change_amount=diff, new_balance=cust.debt, note="Điều chỉnh thủ công"))
        
    db.commit()
    return {"status": "ok"}

@app.delete("/customers/{customer_id}")
def delete_customer(customer_id: int, db: Session = Depends(get_db)):
    customer = db.query(Customer).filter(Customer.id == customer_id).first()
    if not customer:
        raise HTTPException(status_code=404, detail="Khách hàng không tồn tại")
    db.query(Order).filter(Order.customer_id == customer_id).delete(synchronize_session=False)
    db.delete(customer)
    db.commit()
    return {"detail": "Đã xóa khách hàng và toàn bộ lịch sử đơn hàng liên quan"}

@app.get("/customers/{cid}/history")
def get_customer_history(cid: int, db: Session = Depends(get_db)):
    orders = db.query(Order).filter(Order.customer_id == cid).all()
    history = []
    for o in orders:
        items_list = o.items if o.items else []
        total_items = sum([i.quantity for i in items_list])
        details = [{"name": i.product_name, "variant": i.variant_info, "qty": i.quantity, "price": i.price} for i in items_list]
        
        amt = getattr(o, "total_amount", getattr(o, "total_money", 0))
        qty = getattr(o, "total_qty", total_items)
        
        history.append({
            "type": "ORDER",
            "date": o.created_at.strftime("%Y-%m-%d %H:%M"),
            "desc": f"Mua đơn hàng #{o.id}",
            "amount": amt,
            "data": {
                "id": o.id, 
                "customer": o.customer_name, 
                "date": o.created_at.strftime("%d/%m %H:%M"),
                "total_money": amt, 
                "total_qty": qty, 
                "items": details
            }
        })
    
    # 2. Lịch sử nợ
    logs = db.query(DebtLog).filter(DebtLog.customer_id == cid).all()
    for l in logs:
        history.append({
            "type": "LOG",
            "date": l.created_at.strftime("%Y-%m-%d %H:%M"),
            "desc": l.note,
            "amount": l.change_amount,
            "data": None
        })
        
    return sorted(history, key=lambda x: x['date'], reverse=True)

# --- API CHECKOUT & ORDERS ---
@app.post("/checkout")
def checkout(data: CheckoutRequest, db: Session = Depends(get_db)):
    try:
        total = sum([item.quantity * item.price for item in data.cart])
        
        # Trừ kho
        for item in data.cart:
            variant = db.query(Variant).filter(Variant.id == item.variant_id).first()
            if not variant or variant.stock < item.quantity:
                raise HTTPException(status_code=400, detail=f"SP {item.product_name} thiếu hàng")
            variant.stock -= item.quantity
        
        # Khách hàng & Công nợ
        c_name = data.customer_name.strip()
        customer = None
        if c_name:
            customer = db.query(Customer).filter(Customer.name == c_name).first()
            if not customer:
                customer = Customer(name=c_name, phone=data.customer_phone, debt=0)
                db.add(customer)
                db.flush()
            customer.debt += total
        
        # Tạo đơn
        new_order = Order(
            total_amount=total,
            customer_name=c_name if c_name else "Khách lẻ",
            customer_id=customer.id if customer else None
        )
        db.add(new_order)
        db.flush()
        
        # Chi tiết đơn
        for item in data.cart:
            db.add(OrderItem(
                order_id=new_order.id, 
                product_name=item.product_name, 
                variant_info=f"{item.color}-{item.size}", 
                quantity=item.quantity, 
                price=item.price
            ))
            
        db.commit()
        return {"status": "success"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/orders")
def get_orders(page: int = 1, limit: int = 20, db: Session = Depends(get_db)):
    skip = (page - 1) * limit
    total = db.query(Order).count()
    orders = db.query(Order).order_by(desc(Order.created_at)).offset(skip).limit(limit).all()
    
    result = []
    for o in orders:
        items_list = []
        calc_qty = 0
        if o.items:
            for i in o.items:
                calc_qty += i.quantity
                items_list.append({
                    "product_name": i.product_name,
                    "variant_info": i.variant_info,
                    "quantity": i.quantity,
                    "price": i.price
                })
        
        amt = getattr(o, "total_amount", getattr(o, "total_money", 0))
        result.append({
            "id": o.id,
            "created_at": o.created_at.strftime("%Y-%m-%d %H:%M"),
            "customer_name": o.customer_name or "Khách lẻ",
            "total_amount": amt,
            "total_qty": calc_qty,
            "items": items_list
        })
        
    return {"data": result, "total": total, "page": page, "limit": limit}


@app.delete("/orders/{order_id}")
def delete_order_only(order_id: int, db: Session = Depends(get_db)):
    order = db.query(Order).filter(Order.id == order_id).first()
    if not order:
        raise HTTPException(status_code=404, detail="Hóa đơn không tồn tại")
    try:
        db.query(OrderItem).filter(OrderItem.order_id == order_id).delete()
        db.delete(order)
        db.commit()
        return {"detail": "Đã xóa hóa đơn (Không hoàn tiền/kho)"}
    except Exception as e:
        db.rollback()
        raise HTTPException(status_code=500, detail=str(e))