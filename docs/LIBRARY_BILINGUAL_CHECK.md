# Library 雙語實作 — 完整功能檢查報告

## 1. 資料層（Models + Firestore）

### Product（lib/bubble_library/models/product.dart）
| 項目 | 狀態 | 說明 |
|------|------|------|
| 欄位 titleZh, levelGoalZh, levelBenefitZh, contentArchitectureZh | OK | 已定義，可為 null |
| 欄位 levelBenefit, contentArchitecture（fallback） | OK | 已定義，fromMap 讀取 |
| fromMap 讀取 title_zh, levelGoal_zh, levelBenefit_zh, contentArchitecture_zh / contentarchitecture_zh | OK | 使用 _str() 處理空字串為 null |
| extension displayTitle(lang) | OK | zhTw 且 titleZh 有值用 titleZh，否則 title |
| extension displayLevelGoal / displayLevelBenefit / displayContentArchitecture(lang) | OK | 同上邏輯，fallback 為原欄位或 '' |

### ContentItem（lib/bubble_library/models/content_item.dart）
| 項目 | 狀態 | 說明 |
|------|------|------|
| 欄位 anchorGroupZh, anchorZh, contentZh, deepAnalysisZh | OK | 已定義 |
| fromMap 讀取 anchorGroup_zh, anchor_zh, content_zh, deepAnalysis_zh | OK | 使用 _str() |
| extension displayAnchorGroup / displayAnchor / displayContent / displayDeepAnalysis(lang) | OK | zhTw 且 _zh 有值用 _zh，否則原欄位 |

---

## 2. Library UI 顯示處（依設定語言）

### bubble_library_page.dart
| 位置 | 用途 | 狀態 |
|------|------|------|
| build() | lang = ref.watch(appLanguageProvider) | OK |
| _buildBody | 傳遞 lang 給各 tab | OK |
| _buildPurchasedTab | 篩選：title + titleZh 比對關鍵字；LibraryRichCard title: product.displayTitle(lang) | OK |
| _buildWishlistTab | title = p.displayTitle(lang) | OK |
| _buildFavoritesTab | title = productsMap[pid]!.displayTitle(lang) | OK |
| _buildHistoryView | 傳 lang 給 _buildHistoryContentGrouped | OK |
| 排序產品名稱 | titleA/B = productsMap[a/b]?.displayTitle(lang) ?? '' | OK |
| _buildProductGroup | productTitle = product?.displayTitle(lang) ?? 'Unknown product' | OK |
| _buildHistoryCard / _buildHistoryCardContent | productTitle = product?.displayTitle(lang)；anchorGroup = displayAnchorGroup(lang)；content 預覽 = displayContent(lang) | OK |
| 歷史篩選 Chip | label: Text(product?.displayTitle(lang) ?? productId) | OK（已補正） |
| 搜尋篩選（購買列表） | 比對 product.title 與 product.titleZh | OK（非顯示用） |
| latestTitleText(ScheduledPushEntry e) | e.title（推播項目標題，非 Product） | 刻意不改，屬通知標題 |
| _buildFavoriteSentencesTab | sentence.anchorGroup, sentence.anchor, sentence.content | 刻意不改，快照不跟隨語言 |

### detail_page.dart
| 位置 | 用途 | 狀態 |
|------|------|------|
| build() | lang = ref.watch(appLanguageProvider) | OK |
| AppBar title | item.displayAnchor(lang).isNotEmpty ? item.displayAnchor(lang) : 'Detail' | OK |
| headerTitle | product?.displayTitle(lang) ?? item.displayAnchorGroup(lang) | OK |
| headerSubtitle | [item.displayAnchor(lang), item.displayAnchorGroup(lang)].where(...) | OK |
| Quick Bite 內文 | item.displayContent(lang) | OK |
| Copy / Share 文案 | item.displayContent(lang) | OK |
| Deep dive | item.displayDeepAnalysis(lang) | OK |
| 收藏時寫入 FavoriteSentence | productName = product?.title；anchorGroup/anchor/content 用原欄位 | OK（快照儲存，不跟語言） |

### wishlist_page.dart
| 位置 | 狀態 |
|------|------|
| lang = ref.watch(appLanguageProvider) | OK |
| title = p.displayTitle(lang), subtitle = p.displayLevelGoal(lang) | OK |

### push_center_page.dart
| 位置 | 狀態 |
|------|------|
| lang = ref.watch(appLanguageProvider) | OK |
| 推播中產品名稱、已完成產品名稱 = products[...].displayTitle(lang) | OK |

### push_product_config_page.dart
| 位置 | 狀態 |
|------|------|
| lang = ref.watch(appLanguageProvider) | OK |
| title = products[productId]?.displayTitle(lang) ?? productId（含「重新開始」對話框用 productTitle） | OK |

### product_library_page.dart
| 位置 | 狀態 |
|------|------|
| build() | lang = ref.watch(appLanguageProvider) | OK |
| 產品標題 | product.displayTitle(lang) | OK |
| _contentCard(..., lang) | anchor/anchorGroup = displayAnchor(lang) / displayAnchorGroup(lang)；content 預覽 = displayContent(lang) | OK |

---

## 3. 刻意不跟隨語言的部分

| 項目 | 說明 |
|------|------|
| FavoriteSentence（Saved Bites） | 顯示 sentence.productName, sentence.anchorGroup, sentence.anchor, sentence.content；儲存時用 product?.title 與 item 原欄位。快照不隨語言切換。 |
| 推播標題/內文（push_orchestrator, scheduled_push_cache） | 目前使用 product?.title、t.item.content 組通知。若未來要通知跟隨語言，可改為傳入 lang 並使用 displayTitle(lang)、displayContent(lang)。 |
| push_timeline_section | e.title 為時間軸項目標題，非 Product；可選是否依 lang 改為從 ContentItem/Product 取 display*。 |

---

## 4. 依賴與 import

| 檔案 | 需 import 以使用 extension |
|------|----------------------------|
| bubble_library_page | app_language, app_language_provider（已有） |
| detail_page | models/product.dart, models/content_item.dart, app_language_provider |
| wishlist_page | models/product.dart, app_language_provider |
| push_center_page | models/product.dart, app_language_provider |
| push_product_config_page | models/product.dart, app_language_provider |
| product_library_page | models/product.dart, models/content_item.dart, app_language, app_language_provider |

Extension 定義在 model 檔案內，import 該 model 即可使用 display*。

---

## 5. 本次修正

- **bubble_library_page.dart 約 L1231**：歷史篩選 Chip 的 label 由 `product?.title` 改為 `product?.displayTitle(lang) ?? productId`，與其他顯示處一致。

---

## 6. 結論

- 所有 Library 內「產品／內容」的**顯示**皆已依 `appLanguageProvider` 使用 display*(lang)。
- 篩選／搜尋邏輯已同時比對 title 與 titleZh。
- FavoriteSentence 維持快照顯示、不跟隨語言；通知標題／內文為可選延伸。
- 資料層 fromMap 與 extension 邏輯一致，Firestore 無 _zh 時會 fallback 原欄位。
