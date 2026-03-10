import argparse
import pandas as pd
import firebase_admin
from firebase_admin import credentials, firestore

def split_semicolon(s):
    if pd.isna(s) or s is None: return []
    return [x.strip() for x in str(s).split(";") if x.strip()]

def none_if_nan(v):
    return None if pd.isna(v) else v

def _str_opt(v):
    """回傳 None（不寫入 Firestore）若為空；否則回傳去空白字串。用於雙語欄位，僅有值時才寫入。"""
    if v is None or pd.isna(v):
        return None
    s = str(v).strip()
    return s if s else None

def to_bool(v):
    """Excel 的 TRUE/1 常被 pandas 讀成 float 1.0，需一併視為 True。"""
    if isinstance(v, bool): return v
    if pd.isna(v): return False
    if isinstance(v, (int, float)): return v != 0
    s = str(v).strip().lower()
    if s in ("true", "1", "yes", "y", "是", "✓", "√"): return True
    if s in ("false", "0", "no", "n", "", "否", "✗"): return False
    try: return float(s) != 0  # "1.0" -> True
    except (ValueError, TypeError): return False


def _product_published(row):
    """讀取 PRODUCTS 的 published，支援 'published' / 'Published' 欄位；缺欄或空值時視為 True，避免誤設為未上架。"""
    v = row.get("published") if not pd.isna(row.get("published")) else row.get("Published")
    if pd.isna(v) or v is None or str(v).strip() == "":
        return True
    return to_bool(v)

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
                seg = {
                    "id": str(r["segmentId"]).strip(),
                    "title": str(r["title"]).strip(),
                    "order": order_val,
                    "mode": str(r["mode"]).strip() if not pd.isna(r.get("mode")) else "tag",
                    "tag": none_if_nan(r.get("tag")),
                    "published": to_bool(r["published"]),
                }
                title_zh = _str_opt(r.get("title_zh"))
                if title_zh is not None:
                    seg["title_zh"] = title_zh
                segments.append(seg)
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
    # 結構：第一行=英文列名 suggested / trending / suggested_zh / trending_zh，
    #     第二行=中文說明，第三行起=數據（每格一筆或分號分隔）
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
        # 新增：繁體中文欄位 suggested_zh / trending_zh（若不存在則為空陣列）
        suggested_zh = flatten_cells(ss_df, "suggested_zh") if "suggested_zh" in ss_df.columns else []
        trending_zh = flatten_cells(ss_df, "trending_zh") if "trending_zh" in ss_df.columns else []
        if suggested or trending or suggested_zh or trending_zh:
            payload = {
                "suggested": suggested,
                "trending": trending,
            }
            if suggested_zh:
                payload["suggestedZh"] = suggested_zh
            if trending_zh:
                payload["trendingZh"] = trending_zh
            db.collection("ui").document("search_suggestions_v1").set(payload, merge=True)
            print(
                "✅ UI_SEARCH_SUGGESTIONS: "
                f"suggested={len(suggested)} 筆, trending={len(trending)} 筆, "
                f"suggested_zh={len(suggested_zh)} 筆, trending_zh={len(trending_zh)} 筆"
            )
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
                title_zh = _str_opt(r.get("title_zh"))
                if title_zh is not None:
                    data["title_zh"] = title_zh
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
                    "published": _product_published(r),
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
                # 雙語欄位：以 snake_case 寫入 Firestore，與 App (lib/data/models.dart) 一致
                # 註：spec1Label～spec4Label 未使用雙語欄位，不讀寫 spec*_zh
                for col, fname in [
                    ("title_zh", "title_zh"), ("title_en", "title_en"),
                    ("levelGoal_zh", "levelGoal_zh"), ("levelGoal_en", "levelGoal_en"),
                    ("levelBenefit_zh", "levelBenefit_zh"), ("levelBenefit_en", "levelBenefit_en"),
                    ("contentArchitecture_zh", "contentArchitecture_zh"), ("contentArchitecture_en", "contentArchitecture_en"),
                ]:
                    val = _str_opt(r.get(col))
                    if val is not None:
                        data[fname] = val
                prod_writes.append(lambda b, pid=pid, data=data: b.set(db.collection("products").document(pid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        commit_in_batches(prod_writes)
        print(f"✅ PRODUCTS: 已更新 {len(prod_writes)} 筆產品")

    # 4) FEATURED_LISTS -> featured_lists/{listId}
    # ✅ 依 listId 彙總：同一 listId 多列會合併成一份文件，並寫入 items[]（含 itemImageUrl、itemOrder）
    if "FEATURED_LISTS" not in sheet_names:
        print("⏭️  FEATURED_LISTS: 工作表中不存在，跳過")
    else:
        fl_df = pd.read_excel(xlsx, sheet_name="FEATURED_LISTS")
        # 依 listId 分組
        by_list = {}
        for idx, r in fl_df.iterrows():
            if _is_header_or_empty(r, "listId") or pd.isna(r.get("title")):
                continue
            try:
                lid = str(r["listId"]).strip()
                if lid not in by_list:
                    by_list[lid] = []
                by_list[lid].append(r)
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        fl_writes = []
        for lid, rows in by_list.items():
            try:
                first = rows[0]
                order_val, _ = _safe_order(first.get("order"), 0)
                data = {
                    "title": str(first["title"]).strip(),
                    "published": True,
                    "order": order_val,
                    "coverImageUrl": none_if_nan(first.get("coverImageUrl")),
                    "coverStorageFile": none_if_nan(first.get("coverStorageFile")),
                }
                all_product_ids = []
                all_topic_ids = []
                items = []
                for r in rows:
                    ids = split_semicolon(r.get("ids"))
                    topic_ids = split_semicolon(r.get("topicIds"))
                    ftype = str(r.get("type")).strip() if not pd.isna(r.get("type")) else "productIds"
                    item_order = int(r.get("itemOrder")) if not pd.isna(r.get("itemOrder")) and str(r.get("itemOrder")).strip() != "" else len(items)
                    try:
                        item_order = int(float(str(item_order)))
                    except (ValueError, TypeError):
                        item_order = len(items)
                    item = {
                        "itemId": str(r.get("itemId", "")).strip() or f"item_{len(items)}",
                        "itemTitle": _str_opt(r.get("itemTitle")),
                        "itemTitleZh": _str_opt(r.get("itemTitleZh")),
                        "itemImageUrl": _str_opt(r.get("itemImageUrl")),
                        "itemOrder": item_order,
                        "type": ftype,
                    }
                    if ftype == "productIds":
                        item["productIds"] = ids
                        all_product_ids.extend(ids)
                    elif ftype == "topicIds":
                        item["topicIds"] = topic_ids
                        all_topic_ids.extend(topic_ids)
                    else:
                        item["productIds"] = ids
                        all_product_ids.extend(ids)
                    items.append(item)
                data["items"] = items
                if all_product_ids:
                    data["productIds"] = all_product_ids
                if all_topic_ids:
                    data["topicIds"] = all_topic_ids
                fl_writes.append(lambda b, lid=lid, data=data: b.set(db.collection("featured_lists").document(lid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  FEATURED_LISTS listId={lid}: {e}")
                continue
        commit_in_batches(fl_writes)
        print(f"✅ FEATURED_LISTS: 已更新 {len(fl_writes)} 筆精選清單（含 items 與 itemImageUrl）")

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
                # 雙語欄位：以 snake_case 寫入 Firestore，與 App (lib/data/models.dart) 一致
                for col, fname in [
                    ("anchorGroup_zh", "anchorGroup_zh"),
                    ("anchor_zh", "anchor_zh"), ("anchor_en", "anchor_en"),
                    ("content_zh", "content_zh"), ("content_en", "content_en"),
                    ("intent_zh", "intent_zh"), ("intent_en", "intent_en"),
                    ("deepAnalysis_zh", "deepAnalysis_zh"), ("deepAnalysis_en", "deepAnalysis_en"),
                    ("pushTitle", "pushTitle"), ("pushTeaser", "pushTeaser"),
                    ("pushTitle_zh", "pushTitle_zh"), ("pushTeaser_zh", "pushTeaser_zh"),
                ]:
                    val = _str_opt(r.get(col))
                    if val is not None:
                        data[fname] = val
                ci_writes.append(lambda b, iid=iid, data=data: b.set(db.collection("content_items").document(iid), data, merge=True))
            except (ValueError, KeyError) as e:
                print(f"⚠️  跳過無效行: {e}")
                continue
        commit_in_batches(ci_writes)
        print(f"✅ CONTENT_ITEMS: 已更新 {len(ci_writes)} 筆內容項目")

    print("\n✅ Upload done: UI_SEGMENTS / UI_SEARCH_SUGGESTIONS / TOPICS / PRODUCTS / FEATURED_LISTS / CONTENT_ITEMS")

if __name__ == "__main__":
    main()