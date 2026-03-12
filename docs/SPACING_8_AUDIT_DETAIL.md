# 間距 8 倍數詳細檢查報告（Detail Check）

本文件為**詳細檢查**結果：約定僅使用 **8 的倍數**（8、16、24、32、40、48、56、64、72、80…）於  
**SizedBox、EdgeInsets、BorderRadius、spacing/runSpacing、按鈕/區塊的 height/width**。  
不納入：`999` 圓角（膠囊）、`fontSize`、`height`（行高）、`strokeWidth`、裝飾用 1px 線條。

---

## 一、本次詳細檢查修正項目（Check Again Detail）

| 檔案 | 項目 | 原值 | 修正後 |
|------|------|------|--------|
| **category_page.dart** | `_kGridPadding` 常數 | 20.0 | `AppSpacing.md`（24） |
| **bubble_library_page.dart** | loading 區塊 `height` | 60 | 64 |
| **onboarding_screen.dart** | 圓形圖示容器 `width` / `height` | 100 | 96 |

---

## 二、SizedBox — 現狀摘要

- **height**：程式內僅出現 8、16、24、32、40、48、64、80、232 等 8 的倍數（或已改為 `AppSpacing.*`）。
- **width**：僅出現 8、16 等 8 的倍數（或 `AppSpacing.*`）。

---

## 三、EdgeInsets — 現狀摘要

- 已全面改用 `AppSpacing.*` 或 8 的倍數常數（如 16、24、32、56）。
- **常數**：`_kGridGap = 8`、`_kCardOuterH = 16`、`_kCardInnerPadding = 24`、`chipH`/`chipV` 為 8/16，皆符合。

---

## 四、BorderRadius / Radius.circular — 現狀摘要

- 非膠囊：僅使用 8、16、24、48 等 8 的倍數（或 `AppSpacing.radiusXs/Sm/Md/Lg`）。
- `BorderRadius.circular(999)` 保留為膠囊形，不納入 8 格規範。

---

## 五、spacing / runSpacing — 現狀摘要

- 所有 `Wrap` / `GridView` 等之 `spacing`、`runSpacing` 均為 `8`（或 `AppSpacing.xs`）。

---

## 六、其他 height/width（布局用）

- **保留不改**：`height: 1`、`width: 1` 用於 Divider / 細線裝飾。
- **保留不改**：`fontSize` 搭配的 `height: 1.2`、`1.4`、`1.5`、`1.6` 為行高，非間距。
- **已改**：loading 區塊 `height: 60` → 64；onboarding 圓形 100×100 → 96×96。

---

## 七、檢查方式（供日後覆查）

可依下列指令快速掃出「可能」非 8 倍數的數值（再手動排除 fontSize、行高、999、1px 線）：

```bash
# SizedBox 數字
rg "SizedBox\(height: \d+\)" lib
rg "SizedBox\(width: \d+\)" lib

# EdgeInsets 中的數字（會含 8/16/24 等，需目視篩選）
rg "EdgeInsets\.(all|only|fromLTRB|symmetric)\([^)]+\)" lib

# 常數定義
rg "(_kGridPadding|_kCardInnerPadding|chipH|chipV)\s*[=:]" lib

# 布局用 height/width 數字
rg "(height|width):\s*\d+" lib --type dart
```

---

*最後更新：依「check detailly」結果更新，並完成上述三處修正。*
