import argparse
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

def split_semicolon(s):
    if pd.isna(s) or s is None: return []
    return [x.strip() for x in str(s).split(";") if x.strip()]

def none_if_nan(v):
    return None if pd.isna(v) else v

def to_bool(v):
    if isinstance(v, bool): return v
    if pd.isna(v): return False
    return str(v).strip().lower() in ("true", "1", "yes", "y")

def _is_header_or_empty(row, id_key, id_value=None):
    """若該列為標題列或 ID 為空，則視為需跳過（不依賴固定跳過第一行）。"""
    v = row.get(id_key)
    if pd.isna(v) or str(v).strip() == "":
        return True
    s = str(v).strip().lower()
    if s == id_key.lower():  # 例如 segmentId 列寫 "segmentId"
        return True
    if id_value is not None and s == str(id_value).strip().lower():
        return True
    return False

def _safe_order(v, default=0):
    """安全解析 order。回傳 (value, ok)；若為中文說明等無法轉數字則 ok=False，呼叫端應跳過該列。"""
    if pd.isna(v):
        return (default, True)
    s = str(v).strip()
    try:
        n = int(float(s))
        return (n, True)
    except (ValueError, TypeError):
        return (default, False)

def _parse_difficulty(v):
    """解析難度值：支援數字（1-5）或文字（easy=1, medium=2, hard=3）"""
    if pd.isna(v):
        return 1
    if isinstance(v, (int, float)):
        return int(v)
    v_str = str(v).strip().lower()
    # 文字映射
    difficulty_map = {
        "easy": 1,
        "medium": 2,
        "hard": 3,
        "very hard": 4,
        "expert": 5,
    }
    if v_str in difficulty_map:
        return difficulty_map[v_str]
    # 嘗試轉換為數字
    try:
        return int(float(v_str))
    except (ValueError, TypeError):
        return 1  # 預設值

def main():
    ap = argparse.ArgumentParser(
        epilog='Example: python3 upload_v3_excel.py --key tools/keys/service-account.json --excel Onepop2.xlsx',
    )
    ap.add_argument("--key", required=True, help="service account json path")
    ap.add_argument("--excel", required=True, help="xlsx path")
    args = ap.parse_args()

    cred = credentials.Certificate(args.key)
    firebase_admin.initialize_app(cred)
    db = firestore.client()

    xlsx = args.excel
    xl = pd.ExcelFile(xlsx)
    sheet_names = set(xl.sheet_names)

    # 1) UI_SEGMENTS -> ui/segments_v1
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    if "UI_SEGMENTS" not in sheet_names:
        print("⏭️  UI_SEGMENTS: 工作表中不存在，跳過")
    else:
        seg_df = pd.read_excel(xlsx, sheet_name="UI_SEGMENTS")
        segments = []
        for idx, r in seg_df.iterrows():
            # 跳過標題列或無效列（不固定跳過第一行，避免只有一筆資料時被略過）
            if _is_header_or_empty(r, "segmentId") or pd.isna(r.get("title")):
                continue
            order_val, order_ok = _safe_order(r.get("order"))
            if not order_ok:
                continue  # 跳過說明列（order 為中文等）
            try:
                segments.append({
                    "id": str(r["segmentId"]).strip(),
                    "title": str(r["title"]).strip(),
                    "order": order_val,
                    "mode": str(r["mode"]).strip() if not pd.isna(r.get("mode")) else "tag",
                    "tag": none_if_nan(r.get("tag")),
                    "published": to_bool(r["published"]),
                })
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        segments = [s for s in segments if s["published"]]
        segments.sort(key=lambda x: x["order"])
        # 只有在有資料時才更新，避免空值覆蓋現有資料
        if segments:
            db.collection("ui").document("segments_v1").set({"segments": segments}, merge=True)
            print(f"✅ UI_SEGMENTS: 已更新 {len(segments)} 筆區段")
        else:
            print("⏭️  UI_SEGMENTS: 工作表為空，跳過更新（保留現有資料）")

    # 1b) UI_SEARCH_SUGGESTIONS -> ui/search_suggestions_v1
    # 結構：第一行=英文列名 suggested / trending，第二行=中文說明，第三行起=數據（每格一筆或分號分隔）
    if "UI_SEARCH_SUGGESTIONS" not in sheet_names:
        print("⏭️  UI_SEARCH_SUGGESTIONS: 工作表中不存在，跳過")
    else:
        ss_df = pd.read_excel(xlsx, sheet_name="UI_SEARCH_SUGGESTIONS")
        # 每列一筆或單格內分號分隔，跳過第 1 列（說明列）
        def flatten_cells(df, col_key):
            out = []
            for idx, r in df.iterrows():
                v = r.get(col_key)
                if pd.isna(v) or str(v).strip().lower() == col_key.lower():
                    continue
                s = str(v).strip()
                if not s:
                    continue
                parts = split_semicolon(v) if ";" in s else [s]
                for p in parts:
                    if p:
                        out.append(p)
            return out
        suggested = flatten_cells(ss_df, "suggested")
        trending = flatten_cells(ss_df, "trending")
        if suggested or trending:
            db.collection("ui").document("search_suggestions_v1").set(
                {"suggested": suggested, "trending": trending}, merge=True
            )
            print(f"✅ UI_SEARCH_SUGGESTIONS: suggested={len(suggested)} 筆, trending={len(trending)} 筆")
        else:
            print("⏭️  UI_SEARCH_SUGGESTIONS: 工作表為空，跳過更新（保留現有資料）")

    # helper: batched writes (<=500 per batch)
    def commit_in_batches(writes, batch_size=450):
        for i in range(0, len(writes), batch_size):
            b = db.batch()
            for fn in writes[i:i+batch_size]:
                fn(b)
            b.commit()

    # 2) TOPICS -> topics/{topicId}
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    if "TOPICS" not in sheet_names:
        print("⏭️  TOPICS: 工作表中不存在，跳過")
    else:
        topics_df = pd.read_excel(xlsx, sheet_name="TOPICS")
        topic_writes = []
        for idx, r in topics_df.iterrows():
            if _is_header_or_empty(r, "topicId") or pd.isna(r.get("title")):
                continue
            order_val, order_ok = _safe_order(r.get("order"))
            if not order_ok:
                continue  # 跳過說明列
            try:
                tid = str(r["topicId"]).strip()
                data = {
                    "topicId": tid,
                    "title": str(r["title"]).strip(),
                    "published": to_bool(r["published"]),
                    "order": order_val,
                    "tags": split_semicolon(r.get("tags")),
                    "bubbleImageUrl": none_if_nan(r.get("bubbleImageUrl")),
                    "bubbleStorageFile": none_if_nan(r.get("bubbleStorageFile")),
                    "bubbleGradStart": none_if_nan(r.get("bubbleGradStart")),
                    "bubbleGradEnd": none_if_nan(r.get("bubbleGradEnd")),
                }
                topic_writes.append(lambda b, tid=tid, data=data: b.set(db.collection("topics").document(tid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        commit_in_batches(topic_writes)
        print(f"✅ TOPICS: 已更新 {len(topic_writes)} 筆主題")

    # 3) PRODUCTS -> products/{productId}
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    if "PRODUCTS" not in sheet_names:
        print("⏭️  PRODUCTS: 工作表中不存在，跳過")
    else:
        prod_df = pd.read_excel(xlsx, sheet_name="PRODUCTS")
        prod_writes = []
        for idx, r in prod_df.iterrows():
            if _is_header_or_empty(r, "productId") or pd.isna(r.get("topicId")):
                continue
            try:
                pid = str(r["productId"]).strip()
                # 生成 title（優先使用 Excel 中的 title，否則使用 topicId + level）
                title = none_if_nan(r.get("title")) or f'{str(r["topicId"]).strip()} {str(r["level"]).strip()}'
                # 生成 titleLower：一律由 title 產生，確保與 title 一致、搜尋可用
                title_lower = (title or "").lower().strip()
                # 處理 order 欄位（若為中文說明列則跳過該列）
                order_value, order_ok = _safe_order(r.get("order"))
                if not order_ok:
                    continue

                data = {
                    "type": none_if_nan(r.get("type")),
                    "topicId": str(r["topicId"]).strip(),
                    "level": str(r["level"]).strip(),
                    "title": title,
                    "titleLower": title_lower,
                    "order": order_value,
                    "levelGoal": none_if_nan(r.get("levelGoal")),
                    "levelBenefit": none_if_nan(r.get("levelBenefit")),
                    "anchorGroup": none_if_nan(r.get("anchorGroup")),
                    "version": none_if_nan(r.get("version")),
                    "published": to_bool(r.get("published")),
                    "coverImageUrl": none_if_nan(r.get("coverImageUrl")),
                    "coverStorageFile": none_if_nan(r.get("coverStorageFile")),
                    "itemCount": int(r.get("itemCount")) if not pd.isna(r.get("itemCount")) else None,
                    "wordCountAvg": int(r.get("wordCountAvg")) if not pd.isna(r.get("wordCountAvg")) else None,
                    "pushStrategy": none_if_nan(r.get("pushStrategy")),
                    "sourceType": none_if_nan(r.get("sourceType")),
                    "source": none_if_nan(r.get("source")),
                    "sourceUrl": none_if_nan(r.get("sourceUrl")),
                    "spec1Label": none_if_nan(r.get("spec1Label")),
                    "spec2Label": none_if_nan(r.get("spec2Label")),
                    "spec3Label": none_if_nan(r.get("spec3Label")),
                    "spec4Label": none_if_nan(r.get("spec4Label")),
                    "spec1Icon": none_if_nan(r.get("spec1Icon")),
                    "spec2Icon": none_if_nan(r.get("spec2Icon")),
                    "spec3Icon": none_if_nan(r.get("spec3Icon")),
                    "spec4Icon": none_if_nan(r.get("spec4Icon")),
                    "trialMode": none_if_nan(r.get("trialMode")),
                    "trialLimit": int(r.get("trialLimit")) if not pd.isna(r.get("trialLimit")) else 3,
                    "releaseAtMs": int(r.get("releaseAtMs")) if not pd.isna(r.get("releaseAtMs")) else None,
                    "createdAtMs": int(r.get("createdAtMs")) if not pd.isna(r.get("createdAtMs")) else None,
                    "contentArchitecture": none_if_nan(r.get("contentarchitecture")),
                    "creditsRequired": min(999, max(0, int(r.get("creditsRequired")))) if not pd.isna(r.get("creditsRequired")) else 1,
                }
                prod_writes.append(lambda b, pid=pid, data=data: b.set(db.collection("products").document(pid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        commit_in_batches(prod_writes)
        print(f"✅ PRODUCTS: 已更新 {len(prod_writes)} 筆產品")

    # 4) FEATURED_LISTS -> featured_lists/{listId}
    # ✅ Excel 結構：第一行=英文列名，第二行=中文說明，第三行開始=數據
    if "FEATURED_LISTS" not in sheet_names:
        print("⏭️  FEATURED_LISTS: 工作表中不存在，跳過")
    else:
        fl_df = pd.read_excel(xlsx, sheet_name="FEATURED_LISTS")
        fl_writes = []
        for idx, r in fl_df.iterrows():
            if _is_header_or_empty(r, "listId") or pd.isna(r.get("title")):
                continue
            try:
                lid = str(r["listId"]).strip()
                ids = split_semicolon(r.get("ids"))
                ftype = str(r.get("type")).strip() if not pd.isna(r.get("type")) else "productIds"
                data = {
                    "title": str(r["title"]).strip(),
                    "published": True,
                    "order": 0,
                    "coverImageUrl": none_if_nan(r.get("coverImageUrl")),
                    "coverStorageFile": none_if_nan(r.get("coverStorageFile")),
                }
                # 依 type 決定放哪個欄位
                if ftype == "productIds":
                    data["productIds"] = ids
                elif ftype == "topicIds":
                    data["topicIds"] = ids
                else:
                    data["ids"] = ids  # 不確定就保留原始
                fl_writes.append(lambda b, lid=lid, data=data: b.set(db.collection("featured_lists").document(lid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        commit_in_batches(fl_writes)
        print(f"✅ FEATURED_LISTS: 已更新 {len(fl_writes)} 筆精選清單")

    # 5) CONTENT_ITEMS -> content_items/{itemId}
    # ✅ 第一列=英文欄位名，第二列=中文說明（跳過），第三列起=數據
    if "CONTENT_ITEMS" not in sheet_names:
        print("⏭️  CONTENT_ITEMS: 工作表中不存在，跳過")
    else:
        ci_df = pd.read_excel(xlsx, sheet_name="CONTENT_ITEMS")
        ci_writes = []
        for idx, r in ci_df.iterrows():
            if _is_header_or_empty(r, "itemId") or pd.isna(r.get("productId")):
                continue
            try:
                iid = str(r["itemId"]).strip()
                data = {
                    "productId": str(r["productId"]).strip(),
                    "type": none_if_nan(r.get("type")),
                    "topicId": none_if_nan(r.get("topicId")),
                    "level": none_if_nan(r.get("level")),
                    "levelGoal": none_if_nan(r.get("levelGoal")),
                    "levelBenefit": none_if_nan(r.get("levelBenefit")),
                    "anchorGroup": none_if_nan(r.get("anchorGroup")),
                    "anchor": str(r.get("anchor")).strip() if not pd.isna(r.get("anchor")) else "",
                    "intent": str(r.get("intent")).strip() if not pd.isna(r.get("intent")) else "",
                    "difficulty": _parse_difficulty(r.get("difficulty")),
                    "content": str(r.get("content")).strip() if not pd.isna(r.get("content")) else "",
                    "wordCount": int(r.get("wordCount")) if not pd.isna(r.get("wordCount")) else None,
                    "reusable": to_bool(r.get("reusable")),
                    "sourceType": none_if_nan(r.get("sourceType")),
                    "source": none_if_nan(r.get("source")),
                    "sourceUrl": none_if_nan(r.get("sourceUrl")),
                    "version": none_if_nan(r.get("version")),
                    "pushOrder": int(r.get("pushOrder")) if not pd.isna(r.get("pushOrder")) else None,
                    "storageFile": none_if_nan(r.get("storageFile")),
                    "seq": int(r.get("seq")) if not pd.isna(r.get("seq")) else 0,
                    "isPreview": to_bool(r.get("isPreview")),
                    "deepAnalysis": none_if_nan(r.get("deepAnalysis")),
                }
                ci_writes.append(lambda b, iid=iid, data=data: b.set(db.collection("content_items").document(iid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        commit_in_batches(ci_writes)
        print(f"✅ CONTENT_ITEMS: 已更新 {len(ci_writes)} 筆內容項目")

    print("\n✅ Upload done: UI_SEGMENTS / UI_SEARCH_SUGGESTIONS / TOPICS / PRODUCTS / FEATURED_LISTS / CONTENT_ITEMS")

if __name__ == "__main__":
    main()