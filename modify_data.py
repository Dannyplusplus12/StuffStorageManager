import pandas as pd
import os
import warnings
from datetime import datetime

warnings.filterwarnings("ignore")

# --- CẤU HÌNH TÊN FILE ---
SALES_FILE = "BÁN HÀNG.xlsx"
DEBT_FILE = "CÔNG NỢ CHỢ HÀN.xlsx"
OUTPUT_FILE = "result.xlsx"

def clean_str(val):
    if pd.isna(val): return ""
    return str(val).strip()

def clean_money(val):
    if pd.isna(val) or str(val).strip() == '': return 0
    try:
        clean = str(val).replace(',', '').replace(' ', '')
        if '(' in clean and ')' in clean:
            clean = '-' + clean.replace('(', '').replace(')', '')
        return float(clean)
    except:
        return 0

def clean_quantity(val):
    """Đọc số lượng chuẩn, tránh lỗi 7 thành 70"""
    if pd.isna(val) or str(val).strip() == '': return 0
    try:
        # Xóa dấu phẩy nghìn nếu có, chuyển về float trước để an toàn
        val_str = str(val).replace(',', '').replace(' ', '')
        return float(val_str) 
    except:
        return 0

def parse_date(val):
    if pd.isna(val) or str(val).strip() == '': return None
    text = str(val).strip()
    for fmt in ('%Y-%m-%d', '%d/%m/%Y', '%d-%m-%Y', '%Y/%m/%d'):
        try:
            return datetime.strptime(text, fmt)
        except ValueError:
            continue
    return None

def main():
    print("🚀 Đang xử lý file Excel...")

    # 1. TẠO TỪ ĐIỂN MÃ HÀNG (TỪ FILE BÁN HÀNG)
    if not os.path.exists(SALES_FILE):
        print(f"❌ Thiếu file {SALES_FILE}"); return

    name_to_code = {}
    try:
        df_ref = pd.read_excel(SALES_FILE, sheet_name="MÃ HÀNG")
        df_ref.columns = [str(c).strip().upper() for c in df_ref.columns]
        for _, row in df_ref.iterrows():
            mh = clean_str(row.get('MH'))
            ten = clean_str(row.get('TÊN HÀNG'))
            if mh and ten:
                name_to_code[ten.upper()] = mh
    except Exception as e:
        print(f"❌ Lỗi đọc file bán hàng: {e}"); return

    # 2. QUÉT FILE CÔNG NỢ
    if not os.path.exists(DEBT_FILE):
        print(f"❌ Thiếu file {DEBT_FILE}"); return

    xls = pd.ExcelFile(DEBT_FILE)
    ignore_sheets = ["MẪU", "Sheet", "TỔNG", "TONG"]
    all_rows = []

    for sheet_name in xls.sheet_names:
        if any(x in sheet_name.upper() for x in ignore_sheets): continue
        
        try:
            # A. Lấy Công Nợ Cũ (Quét 15 dòng đầu)
            df_raw = pd.read_excel(DEBT_FILE, sheet_name=sheet_name, header=None, nrows=15)
            old_debt = 0
            for r in range(len(df_raw)):
                row_vals = df_raw.iloc[r].values
                for c_idx, val in enumerate(row_vals):
                    if isinstance(val, str) and "Công nợ cũ" in str(val):
                        for offset in range(1, 5):
                            if c_idx + offset < len(row_vals):
                                amt = clean_money(row_vals[c_idx+offset])
                                if amt != 0: 
                                    old_debt = amt
                                    break
            
            # B. Tìm dòng tiêu đề bảng
            header_row = 0
            df_temp = pd.read_excel(DEBT_FILE, sheet_name=sheet_name, header=None, nrows=25)
            for i, row in df_temp.iterrows():
                s = " ".join([str(x) for x in row]).upper()
                if "NGÀY" in s and "TÊN HÀNG" in s:
                    header_row = i; break
            
            # C. Đọc dữ liệu chi tiết
            df = pd.read_excel(DEBT_FILE, sheet_name=sheet_name, header=header_row)
            df.columns = [str(c).strip().upper() for c in df.columns]

            # Tìm ngày đầu tiên (string) trong sheet
            current_date = None
            for val in df.get('NGÀY', []):
                val_str = clean_str(val)
                if val_str:
                    current_date = val_str
                    break
            
            # -> GHI DÒNG CÔNG NỢ CŨ
            if old_debt != 0:
                all_rows.append({
                    "Khách hàng": sheet_name,
                    "Ngày": current_date,
                    "Mã hàng": "CÔNG NỢ",
                    "Số lượng": old_debt,
                    "Ghi chú": "Nợ đầu kỳ"
                })

            # -> GHI CHI TIẾT
            def get_nearest_date_above(df, idx):
                for i in range(idx-1, -1, -1):
                    d = parse_date(df.iloc[i].get('NGÀY'))
                    if d:
                        return d
                return None

            def get_nearest_date_below(df, idx):
                for i in range(idx+1, len(df)):
                    d = parse_date(df.iloc[i].get('NGÀY'))
                    if d:
                        return d
                return None

            for idx, row in df.iterrows():
                day_val = clean_str(row.get('NGÀY'))
                if day_val:
                    current_date = day_val
                row_date = current_date

                raw_name = clean_str(row.get('TÊN HÀNG'))
                raw_code = clean_str(row.get('MÃ HÀNG'))
                qty = clean_quantity(row.get('SL', 0))

                # Tính tổng tiền để phân loại
                total = 0
                if 'TỔNG' in df.columns:
                    total = clean_money(row.get('TỔNG'))
                elif 'THÀNH TIỀN' in df.columns:
                    total = clean_money(row.get('THÀNH TIỀN'))

                # Case 1: TRẢ TIỀN (Số âm)
                if total < 0:
                    all_rows.append({
                        "Khách hàng": sheet_name,
                        "Ngày": row_date,
                        "Mã hàng": "TRẢ TIỀN",
                        "Số lượng": total,
                        "Ghi chú": ""
                    })
                    continue

                # Case 2: MUA HÀNG (Số dương)
                if total > 0:
                    final_code = ""
                    note = ""
                    so_luong = qty if qty != 0 else 1

                    # Nếu mã hàng hoặc tên hàng là SANG SỔ
                    if (raw_code.upper() == "SANG SỔ" or raw_name.upper() == "SANG SỔ"):
                        final_code = "SANG SỔ"
                        note = "Ghi SANG SỔ theo yêu cầu"
                        so_luong = total
                    # Nếu mã hàng là CÔNG NỢ
                    elif (raw_code.upper() == "CÔNG NỢ" or raw_name.upper() == "CÔNG NỢ"):
                        final_code = "CÔNG NỢ"
                        note = "Ghi CÔNG NỢ theo yêu cầu"
                        so_luong = total
                    elif raw_code and raw_code.lower() != 'nan':
                        # Nếu mã hàng không tra được, vẫn ghi mã hàng đó và note
                        final_code = raw_code
                        if raw_code.upper() not in name_to_code.values():
                            note = f"Mã hàng không tra được: {raw_code}"
                        else:
                            note = "Có sẵn mã"
                    elif raw_name and raw_name.lower() != 'nan':
                        # Nếu chỉ có tên hàng, ghi tên hàng vào mã hàng và note
                        final_code = raw_name
                        note = "Chỉ có tên hàng, cần tự tra mã"
                    else:
                        # Trường hợp không biết xử lý, vẫn ghi lại và note
                        final_code = ""
                        note = "Không xác định được mã/tên hàng"

                    all_rows.append({
                        "Khách hàng": sheet_name,
                        "Ngày": row_date,
                        "Mã hàng": final_code,
                        "Số lượng": so_luong,
                        "Ghi chú": note
                    })

        except Exception as e:
            print(f"⚠️ Lỗi sheet {sheet_name}: {e}")

    # 3. XUẤT FILE KẾT QUẢ
    if all_rows:
        df_res = pd.DataFrame(all_rows)
        df_res = df_res.sort_values(by=['Khách hàng', 'Ngày'])
        df_res['Ngày'] = df_res['Ngày'].apply(lambda x: x if pd.notnull(x) else "")
        df_res.to_excel(OUTPUT_FILE, index=False)
        print(f"✅ Xong! File kết quả: {OUTPUT_FILE}")
    else:
        print("⚠️ Không có dữ liệu nào được xuất.")

if __name__ == "__main__":
    main()