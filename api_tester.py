"""
api_tester.py

Small test runner for the project's FastAPI backend. Place this file next to
`seed_data.py`. It can optionally run the seeder, then exercise endpoints and
perform consistency checks (customer debt vs history, basic checkout and debt
log CRUD). It prints a short report highlighting any failures or inconsistencies
detected.

Usage:
    python api_tester.py [--seed]

--seed : run `seed_data.py` before tests (will recreate `shop.db`).

Note: The backend server must be running at API_URL (default http://127.0.0.1:8000).
"""

import subprocess
import sys
import time
import requests
import argparse
from pprint import pprint

API_URL = "http://127.0.0.1:8000"


def run_seed():
    print("[+] Running seed_data.py to populate database...")
    try:
        res = subprocess.run([sys.executable, "seed_data.py"], capture_output=True, text=True)
        print(res.stdout)
        if res.returncode != 0:
            print("seed_data.py returned non-zero exit code:")
            print(res.stderr)
            return False
        return True
    except Exception as e:
        print(f"Failed to run seed script: {e}")
        return False

def test_delete_order_restore(report):
    print("[+] Testing delete order restores stock and customer debt...")
    # find a variant with stock >=2 to be safe
    r = safe_get("/products")
    if isinstance(r, Exception) or r.status_code != 200:
        report.append(("delete_order_restore", False, "/products unreachable"))
        return False
    prods = r.json()
    variant = None
    product_name = None
    for p in prods:
        for v in p.get('variants', []):
            if v.get('stock', 0) >= 1:
                variant = v
                product_name = p.get('name')
                break
        if variant:
            break

    if not variant:
        report.append(("delete_order_restore", False, "no variant with stock >=1 found"))
        return False

    vid = variant['id']
    before_stock = variant['stock']
    qty = 1
    test_customer = f"DEL_TEST_{int(time.time())}"
    cart = [{
        "variant_id": vid,
        "quantity": qty,
        "price": variant['price'],
        "product_name": product_name,
        "color": variant['color'],
        "size": variant['size']
    }]

    # ensure no pre-existing customer with same name
    rcusts = safe_get("/customers")
    if not isinstance(rcusts, Exception) and rcusts.status_code == 200:
        for c in rcusts.json():
            if c['name'] == test_customer:
                # delete to start clean
                safe_delete(f"/customers/{c['id']}")

    # perform checkout
    payload = {"customer_name": test_customer, "customer_phone": "", "cart": cart}
    r2 = safe_post("/checkout", json=payload)
    if isinstance(r2, Exception) or r2.status_code != 200:
        report.append(("delete_order_restore", False, ("checkout_failed", r2)))
        return False

    time.sleep(0.2)

    # find created order and customer
    rorders = safe_get("/orders?page=1&limit=50")
    if isinstance(rorders, Exception) or rorders.status_code != 200:
        report.append(("delete_order_restore", False, ("orders_fetch_failed", rorders)))
        return False

    orders = rorders.json().get('data', [])
    order_id = None
    total_amount = sum([c['quantity'] * c['price'] for c in cart])
    for o in orders:
        if o.get('customer_name') == test_customer and int(o.get('total_amount') or 0) == int(total_amount):
            order_id = o.get('id')
            break

    if not order_id:
        report.append(("delete_order_restore", False, "created order not found"))
        return False

    # find customer id and debt after checkout
    rcusts = safe_get("/customers")
    if isinstance(rcusts, Exception) or rcusts.status_code != 200:
        report.append(("delete_order_restore", False, "customers fetch failed"))
        return False
    cust = None
    for c in rcusts.json():
        if c['name'] == test_customer:
            cust = c
            break
    if not cust:
        report.append(("delete_order_restore", False, "created customer not found after checkout"))
        return False

    cust_id = cust['id']
    debt_after = int(cust.get('debt') or 0)

    # check stock decreased
    rprod2 = safe_get("/products")
    if isinstance(rprod2, Exception) or rprod2.status_code != 200:
        report.append(("delete_order_restore", False, "products fetch failed after checkout"))
        return False
    after_stock = None
    for p in rprod2.json():
        for v in p.get('variants', []):
            if v['id'] == vid:
                after_stock = v['stock']
                break
        if after_stock is not None: break

    if after_stock is None:
        report.append(("delete_order_restore", False, "variant not found after checkout"))
        return False
    if after_stock != before_stock - qty:
        report.append(("delete_order_restore", False, {"stock_mismatch_after_checkout": {"before": before_stock, "after": after_stock, "expected": before_stock-qty}}))
        return False

    # now delete order
    rd = safe_delete(f"/orders/{order_id}")
    if isinstance(rd, Exception) or rd.status_code not in (200, 204):
        report.append(("delete_order_restore", False, ("delete_failed", rd)))
        return False

    time.sleep(0.1)

    # verify stock restored
    rprod3 = safe_get("/products")
    if isinstance(rprod3, Exception) or rprod3.status_code != 200:
        report.append(("delete_order_restore", False, "products fetch failed after delete"))
        return False
    restored_stock = None
    for p in rprod3.json():
        for v in p.get('variants', []):
            if v['id'] == vid:
                restored_stock = v['stock']
                break
        if restored_stock is not None: break

    if restored_stock != before_stock:
        report.append(("delete_order_restore", False, {"stock_not_restored": {"before": before_stock, "restored": restored_stock}}))
        return False

    # verify customer debt restored
    rcust_after = safe_get("/customers")
    if isinstance(rcust_after, Exception) or rcust_after.status_code != 200:
        report.append(("delete_order_restore", False, "customers fetch failed after delete"))
        return False
    cust_after = None
    for c in rcust_after.json():
        if c['id'] == cust_id:
            cust_after = c
            break
    if not cust_after:
        report.append(("delete_order_restore", False, "customer disappeared after delete"))
        return False

    if int(cust_after.get('debt') or 0) != int(cust.get('debt') or 0) - int(total_amount):
        # expected debt after deletion = debt_after - total_amount (but since we just deleted order, should revert to previous)
        # better: compute expected = debt_after - total_amount
        expected = int(cust.get('debt') or 0) - int(total_amount)
        report.append(("delete_order_restore", False, {"debt_expected": expected, "debt_actual": int(cust_after.get('debt') or 0)}))
        return False

    report.append(("delete_order_restore", True, {"order_id": order_id, "stock_restored": restored_stock, "debt_restored": int(cust_after.get('debt') or 0)}))
    return True


def safe_get(path, params=None):
    url = API_URL.rstrip("/") + path
    try:
        r = requests.get(url, params=params, timeout=5)
        return r
    except Exception as e:
        return e


def safe_post(path, json=None):
    url = API_URL.rstrip("/") + path
    try:
        r = requests.post(url, json=json, timeout=5)
        return r
    except Exception as e:
        return e


def safe_put(path, json=None):
    url = API_URL.rstrip("/") + path
    try:
        r = requests.put(url, json=json, timeout=5)
        return r
    except Exception as e:
        return e


def safe_delete(path):
    url = API_URL.rstrip("/") + path
    try:
        r = requests.delete(url, timeout=5)
        return r
    except Exception as e:
        return e


def test_basic_endpoints(report):
    print("[+] Testing basic endpoints (/products, /customers, /orders)...")
    ok = True
    r = safe_get("/products")
    if isinstance(r, Exception) or r.status_code != 200:
        report.append(("/products", False, r))
        ok = False
    else:
        report.append(("/products", True, f"{len(r.json())} products"))

    r = safe_get("/customers")
    if isinstance(r, Exception) or r.status_code != 200:
        report.append(("/customers", False, r))
        ok = False
    else:
        report.append(("/customers", True, f"{len(r.json())} customers"))

    r = safe_get("/orders?page=1&limit=5")
    if isinstance(r, Exception) or r.status_code != 200:
        report.append(("/orders", False, r))
        ok = False
    else:
        try:
            data = r.json()
            report.append(("/orders", True, f"{len(data.get('data', []))} orders on page"))
        except Exception as e:
            report.append(("/orders", False, e))
            ok = False

    return ok


def recompute_debt_from_history(hist):
    # history items include ORDER (amount positive) and LOG (amount can be + or -)
    total = 0
    for entry in hist:
        try:
            total += int(entry.get('amount') or 0)
        except Exception:
            pass
    return total


def test_customer_debt_consistency(report):
    print("[+] Checking customer debt consistency vs history...")
    r = safe_get("/customers")
    if isinstance(r, Exception) or r.status_code != 200:
        report.append(("debt_consistency", False, "/customers unreachable"))
        return False

    custs = r.json()
    bad = []
    for c in custs:
        cid = c['id']
        r2 = safe_get(f"/customers/{cid}/history")
        if isinstance(r2, Exception) or r2.status_code != 200:
            report.append((f"history_{cid}", False, r2))
            bad.append((c, "history fetch failed"))
            continue
        hist = r2.json()
        recomputed = recompute_debt_from_history(hist)
        reported = int(c.get('debt') or 0)
        if recomputed != reported:
            bad.append((c, {'reported': reported, 'computed': recomputed}))

    if bad:
        report.append(("debt_consistency", False, bad))
        return False
    else:
        report.append(("debt_consistency", True, "All customers consistent"))
        return True


def test_checkout_flow(report):
    print("[+] Testing checkout flow (create order, stock update, customer debt)...")
    r = safe_get("/products")
    if isinstance(r, Exception) or r.status_code != 200:
        report.append(("checkout", False, "/products unreachable"))
        return False
    prods = r.json()
    if not prods:
        report.append(("checkout", False, "no products to test"))
        return False

    # find a variant with stock >=1
    variant = None
    for p in prods:
        for v in p.get('variants', []):
            if v.get('stock', 0) > 0:
                variant = v
                product_name = p.get('name')
                break
        if variant:
            break

    if not variant:
        report.append(("checkout", False, "no variant with stock > 0 found"))
        return False

    # get current stock
    vid = variant['id']
    before_stock = variant['stock']
    qty = 1

    test_customer = f"Test Customer {int(time.time())}"
    cart = [{
        "variant_id": vid,
        "quantity": qty,
        "price": variant['price'],
        "product_name": product_name,
        "color": variant['color'],
        "size": variant['size']
    }]

    payload = {"customer_name": test_customer, "customer_phone": "", "cart": cart}
    r2 = safe_post("/checkout", json=payload)
    if isinstance(r2, Exception) or r2.status_code != 200:
        report.append(("checkout", False, r2))
        return False

    # allow a moment for db to update
    time.sleep(0.2)
    # reload products and find variant
    r3 = safe_get("/products")
    if isinstance(r3, Exception) or r3.status_code != 200:
        report.append(("checkout_post", False, "/products unreachable after checkout"))
        return False
    found = False
    for p in r3.json():
        for v in p.get('variants', []):
            if v['id'] == vid:
                found = True
                after_stock = v['stock']
                break
        if found: break

    if not found:
        report.append(("checkout_stock", False, f"variant {vid} not found after checkout"))
        return False

    if after_stock != before_stock - qty:
        report.append(("checkout_stock", False, {"before": before_stock, "after": after_stock, "expected": before_stock-qty}))
        return False

    report.append(("checkout", True, {"variant": vid, "before": before_stock, "after": after_stock}))
    return True


def test_debt_log_crud(report):
    print("[+] Testing debt log CRUD (create / update / delete)")
    # create a new customer to avoid colliding with existing
    name = f"tmp_{int(time.time())}"
    r = safe_post("/customers", json={"name": name, "phone": "000", "debt": 0})
    if isinstance(r, Exception) or r.status_code not in (200, 201):
        report.append(("debt_log_crud", False, ("create_customer_failed", r)))
        return False
    cid = r.json().get('id')
    if not cid:
        report.append(("debt_log_crud", False, ("no_customer_id", r.json())))
        return False

    # create debt log +5000
    r2 = safe_post(f"/customers/{cid}/history", json={"change_amount": 5000, "note": "test add", "created_at": "2023-01-01 10:00"})
    if isinstance(r2, Exception) or r2.status_code not in (200,201):
        report.append(("debt_log_create", False, r2))
        return False

    # fetch customer and expect debt == 5000
    r3 = safe_get("/customers")
    cust = None
    if not isinstance(r3, Exception) and r3.status_code == 200:
        for c in r3.json():
            if c['id'] == cid:
                cust = c
                break
    if not cust:
        report.append(("debt_log_crud", False, "created customer not found"))
        return False
    if int(cust.get('debt') or 0) != 5000:
        report.append(("debt_log_crud", False, ("debt_after_create_mismatch", cust)))
        return False

    # get history to find log id
    r4 = safe_get(f"/customers/{cid}/history")
    if isinstance(r4, Exception) or r4.status_code != 200:
        report.append(("debt_log_crud", False, ("history_fetch", r4)))
        return False
    logs = [h for h in r4.json() if h['type'] == 'LOG']
    if not logs:
        report.append(("debt_log_crud", False, ("no_log_found", r4.json())))
        return False
    log = logs[0]
    lid = log.get('log_id')

    # update log to +3000 (change_amount -> 3000) so diff = -2000, debt should become 3000
    r5 = safe_put(f"/customers/{cid}/history/{lid}", json={"change_amount": 3000, "note": "updated", "created_at": "2023-01-01 11:00"})
    if isinstance(r5, Exception) or r5.status_code not in (200,201):
        report.append(("debt_log_update", False, r5))
        return False

    r6 = safe_get("/customers")
    for c in r6.json():
        if c['id'] == cid:
            if int(c['debt'] or 0) != 3000:
                report.append(("debt_log_crud", False, ("debt_after_update_mismatch", c)))
                return False
            break

    # delete log -> debt should become 0
    r7 = safe_delete(f"/customers/{cid}/history/{lid}")
    if isinstance(r7, Exception) or r7.status_code not in (200,204):
        # some implementations return 200 with body
        if isinstance(r7, Exception) or getattr(r7, 'status_code', None) != 200:
            report.append(("debt_log_delete", False, r7))
            return False

    r8 = safe_get("/customers")
    for c in r8.json():
        if c['id'] == cid:
            if int(c['debt'] or 0) != 0:
                report.append(("debt_log_crud", False, ("debt_after_delete_mismatch", c)))
                return False
            break

    # cleanup: delete customer
    safe_delete(f"/customers/{cid}")
    report.append(("debt_log_crud", True, "CRUD flow ok"))
    return True


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--seed', action='store_true', help='Run seed_data.py before tests')
    args = parser.parse_args()

    report = []

    if args.seed:
        ok = run_seed()
        if not ok:
            print("Seeding failed — aborting tests.")
            sys.exit(1)

    # allow user to start backend if not running
    print(f"[*] Target API: {API_URL}")

    # Basic connectivity
    basic_ok = test_basic_endpoints(report)
    if not basic_ok:
        print("Basic endpoint tests failed — ensure backend is running at the target URL.")

    # Consistency checks
    test_customer_debt_consistency(report)

    # Checkout flow
    test_checkout_flow(report)

    # Debt log CRUD
    test_debt_log_crud(report)

    # Delete order restore test
    test_delete_order_restore(report)

    print('\n=== TEST REPORT ===')
    for name, ok, info in report:
        status = 'OK' if ok else 'FAIL'
        print(f"[{status}] {name}: {info}")

    # Quick heuristics: detect common bug patterns from responses
    issues = []
    for name, ok, info in report:
        if not ok:
            issues.append((name, info))

    if issues:
        print('\nPotential issues detected:')
        for n, i in issues:
            pprint((n, i))
    else:
        print('\nNo obvious issues detected by automated checks.')


if __name__ == '__main__':
    main()
