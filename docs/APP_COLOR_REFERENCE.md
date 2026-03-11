# OnePop App 色系參考

專案採用**雙主題**：**Amber Night（深色）** + **Warm Amber（淺色）**，主色為琥珀/金黃色系。

---

## 一、全域主題（`lib/theme/app_themes.dart`）

### 1. 深色主題 `darkNeon`（Amber Night）

| 用途 | 色名 / Token | Hex / 說明 |
|------|--------------|------------|
| **背景** | `bg` | `#0C0F1A` |
| **背景漸層** | `bgGradient` | `#0C0F1A` → `#1A1F35` → `#0C0F1A` |
| **主色** | `primary` | `#E8A838`（琥珀） |
| **主色亮** | `primaryLight` / `primaryBright` | `#F5C04A` |
| **主色淡底** | `primaryPale` | `rgba(232,168,56,0.15)` |
| **主色上文字** | `textOnPrimary` | `#0C0F1A` |
| **區塊標題** | `sectionTitleColor` | `#E8A838`（同 primary） |
| **主要文字** | `textPrimary` | `#EDE8DD` |
| **次要文字** | `textSecondary` | `#9A9484` |
| **弱化文字** | `textMuted` | `#6B6558` |
| **卡片背景** | `cardBg` | `#151929` |
| **卡片邊框** | `cardBorder` | `rgba(232,168,56,0.12)` |
| **卡片陰影** | `cardShadow` | 琥珀 6% + 黑 35% |
| **卡片漸層** | `cardGradient` | 白 12% → 琥珀 8% → 白 8% |
| **Chip 背景** | `chipBg` | `#1C2139` |
| **Chip 漸層** | `chipGradient` | 琥珀 15% → 白 8% |
| **導覽列背景** | `navBg` | `rgba(20,24,44,0.72)` |
| **導覽列漸層** | `navGradient` | `rgba(20,24,44,0.85)` → `rgba(11,14,26,0.95)` |
| **按鈕漸層** | `buttonGradient` | `#E8A838` → `#F5C04A` |
| **搜尋列漸層** | `searchBarGradient` | 白 12% → 白 8% |
| **下拉選單背景** | `surfaceContainerHighest` | `#14182E` |
| **輸入框填滿** | InputDecoration fill | `rgba(255,255,255,0.10)` |
| **輸入框提示** | hintStyle | `rgba(255,255,255,0.60)` |
| **輸入框邊框** | border | `rgba(255,255,255,0.14)` |

---

### 2. 淺色主題 `whiteMint`（Warm Amber）

| 用途 | 色名 / Token | Hex / 說明 |
|------|--------------|------------|
| **背景** | `bg` | `#FAF8F4` |
| **背景漸層** | `bgGradient` | `#FAF8F4` → `#F5F2EC` → `#FAF8F4` |
| **主色** | `primary` | `#C8850A`（深琥珀） |
| **主色亮** | `primaryBright` | `#E8A838` |
| **主色淡底** | `primaryPale` | `#FFF3DC` |
| **主色上文字** | `textOnPrimary` | `#FFFFFF` |
| **區塊標題** | `sectionTitleColor` | `#1A1710`（近黑，非琥珀） |
| **主要文字** | `textPrimary` | `#1A1710` |
| **次要文字** | `textSecondary` | `#6B6152` |
| **弱化文字** | `textMuted` | `#9A9080` |
| **卡片背景** | `cardBg` | `#FFFFFF` |
| **卡片邊框** | `cardBorder` | `rgba(26,23,16,0.08)` |
| **卡片陰影** | `cardShadow` | `rgba(26,23,16,0.06)` |
| **卡片漸層** | `cardGradient` | `#FFFFFF` → `#FAF8F4` |
| **Chip 背景** | `chipBg` | `#F0EDE6` |
| **Chip 漸層** | `chipGradient` | `#F0EDE6` → `#FFF8EC` |
| **導覽列** | `navBg` / `navGradient` | `#FFFFFF` |
| **按鈕漸層** | `buttonGradient` | `#E8A838`（單色） |
| **搜尋列漸層** | `searchBarGradient` | `#F5F2EC` → `#F0EDE6` |
| **輸入框填滿** | InputDecoration fill | `#F6F7FB` |
| **輸入框提示** | hintStyle | `#9CA3AF` |
| **輸入框邊框** | border | `#EEF1F6` |

---

## 二、Plus 引導頁專用色（`plus_guide_page.dart` — `_GuideColors`）

### 深色模式

| 用途 | Hex |
|------|-----|
| 卡片起/終 | `#1E2236` / `#14182C` |
| 卡片陰影 | `#44000000` |
| 表面 / 選中表面 | `#1AFFFFFF` / `#2E3350` |
| 強調 / 深強調 | `#E8A838` / `#D49520` |
| 標題 / 內文 / 弱化文字 | `#EDE8DD` / `#9A9484` / `#6B6558` |
| 正向文字/背景 | `#6CC070` / `#1A6CC070` |
| 警告背景/文字 | `#26E8A838` / `#E8A838` |
| Chip 背景/邊框 | `#14FFFFFF` / `#E8A838` |

### 淺色模式

| 用途 | Hex |
|------|-----|
| 卡片起/終 | `#FFF3D0` / `#FFE8A0` |
| 卡片陰影 | `#33D4A017` |
| 表面 / 選中表面 | `#99FFFFFF` / `#FFD966` |
| 強調 / 深強調 | `#D4A017` / `#B8860B` |
| 標題 / 內文 / 弱化文字 | `#3A2C00` / `#7A6000` / `#9A7800` |
| 正向文字/背景 | `#4A9A4A` / `#E8F5E8` |
| 警告背景/文字 | `#FFF0E0` / `#B05000` |
| Chip 背景/邊框 | `#8CFFFFFF` / `#D4A017` |

---

## 三、其他頁面／元件用色（非主題 Token）

| 位置 | 用途 | 色值 |
|------|------|------|
| **Welcome / 啟動** | 背景漸層 | `#0A0E27` → `#1A1A3A` → `#0F1629` |
| **Onboarding** | 深色底 | `#0A0E27`、`#1A1F3A`、`#1A2642` |
| **Onboarding** | 按鈕漸層 | `#667EEA` → `#764BA2` |
| **Onboarding** | 灰階文字 | `#666666`、`#333333`、`#999999`、`#DDDDDD` |
| **Category 頁** | 分類漸層（多組） | 例如 `#FF6B35`→`#E63946`、`#2D00F7`→`#8900F2` 等 |
| **書架 (bookshelf)** | 背景/書架/邊框 | `#14120E`、`#2A2318`、`#3A3020`、`rgba(160,140,100,0.12)` |
| **書架** | 文字 / 金色 | `#E0D8C8`、`#9A9080`、`#605848`、`#C8A050` |
| **書架** | 書脊色盤 | 綠/棕/藍/紫/皮革/青等（如 `#2D5A3D`、`#8B4513`…） |
| **書架** | 狀態色 | 綠 `#4ADE80`、橙 `#F97316`、藍 `#60A5FA`、紫 `#A855F7`、粉 `#FB7185`、黃 `#FACC15` |
| **iOS 通知引導** | 橘/藍/綠圖示 | `#FF9800`、`#5B8DEF`、`#66BB6A`；背景 `#FFF3E0` |
| **Me 頁** | 刪除/危險 | `Colors.red` |
| **Push 相關** | 裝飾 | `Colors.amber` 及其 shade |

---

## 四、核心色一覽（方便複製）

- **主琥珀（按鈕/強調）**：`#E8A838`
- **主琥珀亮**：`#F5C04A`
- **深色主色（淺色主題用）**：`#C8850A`
- **深色背景**：`#0C0F1A`
- **深色卡片**：`#151929`
- **淺色背景**：`#FAF8F4`
- **淺色主色淡底**：`#FFF3DC`
- **深色主要文字**：`#EDE8DD`
- **淺色主要文字**：`#1A1710`

取得主題色請使用 `Theme.of(context).extension<AppTokens>()!` 或 `context.tokens`（見 `app_tokens.dart`）。
