#!/usr/bin/env python3
"""將 onepop 橫幅 Excel 各資料 sheet 轉為 assets 用 JSON（不依賴 openpyxl）。"""
from __future__ import annotations

import argparse
import json
import re
import sys
import zipfile
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from pathlib import Path

SKIP_SHEETS = frozenset({"架構說明", "批次總索引"})
# 只讀資料的 sheet 名稱（學期縮寫）
DATA_SHEETS = frozenset({"七上", "七下", "八上", "八下", "九上", "九下"})
# 含子科目對照的 sheet 名稱
SUB_SEGMENT_SHEETS = frozenset({"總覽", "學期章節對照"})

NS = {
    "a": "http://schemas.openxmlformats.org/spreadsheetml/2006/main",
    "r": "http://schemas.openxmlformats.org/officeDocument/2006/relationships",
}


def _cell_value(cell, shared: list[str]) -> str | float | int | None:
    t = cell.attrib.get("t")
    v_el = cell.find("a:v", NS)
    if v_el is None or v_el.text is None:
        is_el = cell.find("a:is", NS)
        if is_el is not None:
            return "".join(t.text or "" for t in is_el.findall(".//a:t", NS))
        return None
    raw = v_el.text
    if t == "s":
        i = int(raw)
        return shared[i] if i < len(shared) else raw
    if t == "n" or t is None:
        try:
            f = float(raw)
            if f.is_integer():
                return int(f)
            return f
        except ValueError:
            return raw
    return raw


def _load_workbook(path: Path):
    with zipfile.ZipFile(path) as z:
        shared: list[str] = []
        if "xl/sharedStrings.xml" in z.namelist():
            sroot = ET.fromstring(z.read("xl/sharedStrings.xml"))
            for si in sroot.findall("a:si", NS):
                text = "".join(t.text or "" for t in si.findall(".//a:t", NS))
                shared.append(text)

        wb = ET.fromstring(z.read("xl/workbook.xml"))
        rels = ET.fromstring(z.read("xl/_rels/workbook.xml.rels"))
        rid_to_target = {rel.attrib["Id"]: rel.attrib["Target"] for rel in rels}
        sheets_meta = []
        for s in wb.findall("a:sheets/a:sheet", NS):
            name = s.attrib.get("name", "")
            rid = s.attrib.get(
                "{http://schemas.openxmlformats.org/officeDocument/2006/relationships}id"
            )
            rel_target = rid_to_target[rid]
            if rel_target.startswith("/"):
                target = rel_target.lstrip("/")
            elif rel_target.startswith("xl/"):
                target = rel_target
            else:
                target = "xl/" + rel_target
            sheets_meta.append((name, target))

        sheets_data: dict[str, list[list]] = {}
        for name, target in sheets_meta:
            root = ET.fromstring(z.read(target))
            rows_out: list[list] = []
            for row in root.findall("a:sheetData/a:row", NS):
                row_vals: list = []
                for c in row.findall("a:c", NS):
                    row_vals.append(_cell_value(c, shared))
                rows_out.append(row_vals)
            sheets_data[name] = rows_out

    return sheets_data


def _build_sub_segment_map(sheets: dict[str, list[list]]) -> dict[tuple[str, str], str]:
    """
    從「總覽」或「學期章節對照」sheet 讀取 (productId, 學期縮寫) -> 子科目名稱 的對照表。
    例：("細胞", "七上") -> "生物"
    """
    mapping: dict[tuple[str, str], str] = {}
    for sheet_name in SUB_SEGMENT_SHEETS:
        rows = sheets.get(sheet_name)
        if not rows:
            continue
        header = [str(x).strip() if x is not None else "" for x in rows[0]]
        # 社會的 sheet 欄位名為「對應productId」，自然為「productId」
        prod_col = "對應productId" if "對應productId" in header else "productId"
        if prod_col not in header or "來源批次" not in header or "學期" not in header:
            continue
        idx_prod = header.index(prod_col)
        idx_batch = header.index("來源批次")
        idx_sem = header.index("學期")
        for r in rows[1:]:
            if not r or len(r) <= max(idx_prod, idx_batch, idx_sem):
                continue
            product = str(r[idx_prod] or "").strip()
            batch = str(r[idx_batch] or "").strip()
            sem_raw = str(r[idx_sem] or "").strip()
            # 學期可能為 "七上" 或 "7上" 兩種格式，統一取前兩字
            sem = sem_raw[:2] if len(sem_raw) >= 2 else sem_raw
            if product and batch and sem:
                mapping[(product, sem)] = batch
    return mapping


def _norm_topic_id(v) -> int | None:
    if v is None:
        return None
    if isinstance(v, int):
        return v
    if isinstance(v, float):
        return int(v) if v == int(v) else int(v)
    s = str(v).strip()
    if not s:
        return None
    m = re.match(r"^(\d+)", s)
    if m:
        return int(m.group(1))
    try:
        f = float(s)
        return int(f)
    except ValueError:
        return None


def _rows_to_items(
    sheet_name: str,
    rows: list[list],
    sub_segment_map: dict[tuple[str, str], str],
) -> list[dict]:
    if not rows:
        return []
    header = [str(x).strip() if x is not None else "" for x in rows[0]]
    if not header or "itemId" not in header:
        return []
    idx = {h: i for i, h in enumerate(header)}
    required = ["itemId", "productId", "content", "pushTitle", "topicId", "segment"]
    for k in required:
        if k not in idx:
            print(f"[warn] sheet {sheet_name!r} 缺少欄位 {k}，略過", file=sys.stderr)
            return []

    items: list[dict] = []
    for r in rows[1:]:
        if not r or all(x is None or str(x).strip() == "" for x in r):
            continue

        def get(k):
            i = idx[k]
            return r[i] if i < len(r) else None

        item_id = get("itemId")
        if item_id is None or str(item_id).strip() == "":
            continue
        topic = _norm_topic_id(get("topicId"))
        if topic is None:
            print(f"[warn] {sheet_name} row itemId={item_id!r} topicId 無效，略過", file=sys.stderr)
            continue

        def opt_num(key):
            v = get(key)
            if v is None or str(v).strip() == "":
                return None
            if isinstance(v, (int, float)):
                return float(v) if isinstance(v, float) and not v == int(v) else int(v) if isinstance(v, float) and v == int(v) else v
            try:
                return float(v)
            except ValueError:
                return None

        product_id = str(get("productId") or "").strip()
        # semester 直接取 sheet 名稱（七上/七下/八上/八下/九上/九下）
        semester = sheet_name if sheet_name in DATA_SHEETS else ""
        sub_segment = sub_segment_map.get((product_id, semester), "")

        items.append(
            {
                "itemId": str(item_id).strip(),
                "segment": str(get("segment") or "").strip(),
                "topicId": topic,
                "semester": semester,
                "subSegment": sub_segment,
                "productId": product_id,
                "anchor": str(get("anchor") or "").strip(),
                "content": str(get("content") or ""),
                "pushTitle": str(get("pushTitle") or "").strip(),
                "seq": opt_num("seq"),
                "pushOrder": opt_num("pushOrder"),
                "sourceSheet": sheet_name,
            }
        )
    return items


def main():
    root = Path(__file__).resolve().parents[1]
    parser = argparse.ArgumentParser(description="將 onepop 橫幅 Excel 轉為 JSON")
    parser.add_argument(
        "xlsx",
        nargs="*",
        default=["onepop 國文橫幅 全冊 學期版.xlsx"],
        help="相對於專案根目錄的 Excel 檔名（可傳多個）",
    )
    parser.add_argument(
        "--out",
        default="assets/data/banner_catalog.json",
        help="相對於專案根目錄的輸出 JSON 路徑",
    )
    args = parser.parse_args()

    out = root / args.out
    input_files = [root / p for p in args.xlsx]
    missing = [p for p in input_files if not p.exists()]
    if missing:
        for p in missing:
            print(f"找不到 {p}", file=sys.stderr)
        sys.exit(1)

    all_items: list[dict] = []
    used_sheets: list[str] = []
    source_files: list[str] = []
    for xlsx in input_files:
        source_files.append(xlsx.name)
        sheets = _load_workbook(xlsx)
        sub_map = _build_sub_segment_map(sheets)
        if sub_map:
            print(f"[info] {xlsx.name}: 讀取到 {len(sub_map)} 筆子科目對照")
        for name, rows in sheets.items():
            if name in SKIP_SHEETS or name in SUB_SEGMENT_SHEETS:
                continue
            items = _rows_to_items(name, rows, sub_map)
            if items:
                used_sheets.append(f"{xlsx.stem}::{name}")
                all_items.extend(items)

    payload = {
        "generatedAt": datetime.now(timezone.utc).isoformat(),
        "sourceFile": ", ".join(source_files),
        "sourceFiles": source_files,
        "sourceSheets": used_sheets,
        "items": all_items,
    }
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(json.dumps(payload, ensure_ascii=False, indent=2), encoding="utf-8")
    print(
        f"Wrote {len(all_items)} items from {len(used_sheets)} sheet(s)"
        f" across {len(source_files)} file(s) -> {out}"
    )


if __name__ == "__main__":
    main()
