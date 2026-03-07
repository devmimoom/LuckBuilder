# US Market: ASO & App Store Connect Checklist

## App Store Connect Settings (manual steps)

### 1. Primary Language
- Set to **English (U.S.)** in App Store Connect > App Information

### 2. App Name
- `OnePop`

### 3. Subtitle (max 30 chars)
Suggested options (pick one):
- `Learn something new every day`
- `Daily bite-sized learning`
- `Your daily learning companion`

### 4. Keywords (max 100 chars, comma-separated)
```
learning,education,daily,personal growth,micro learning,self improvement,knowledge,study,habits
```

### 5. Description
```
OnePop delivers bite-sized learning content straight to your day — one pop at a time.

Build smarter habits with daily notifications that bring curated knowledge to your fingertips. Whether you want to grow personally, learn new skills, or stay sharp, OnePop makes it effortless.

KEY FEATURES

• Daily Learning Pops — Receive handpicked content on topics you care about, delivered at your preferred times.
• Personalized Library — Browse topics, add products to your library, and track your progress.
• Flexible Notifications — Set your own schedule, quiet hours, and daily caps. Learn on your terms.
• Beautiful Design — A clean, modern interface with dark and light themes.
• Multiple Sign-In Options — Use email, Google, or Apple to keep your progress synced.
• Credits System — Unlock premium content with credits purchased in-app.

HOW IT WORKS

1. Browse topics and add products to your library.
2. Set up your notification preferences.
3. Receive daily learning pops and mark them as done.
4. Track your progress and build a learning streak.

Start learning smarter today — one pop at a time.
```

### 6. Promotional Text (max 170 chars, can be changed without new build)
```
Build smarter habits with daily learning pops. Browse topics, set your schedule, and grow — one pop at a time.
```

### 7. What's New (for version 1.0.0)
```
Welcome to OnePop! Your daily learning companion.

• Browse curated learning topics
• Personalized notification schedule
• Track your learning progress
• Dark and light themes
• Sign in with Email, Google, or Apple
```

---

## Age Rating Questionnaire

Answer these in App Store Connect > App Information > Age Rating:

| Question | Answer |
|----------|--------|
| Made for Kids? | No |
| Cartoon or Fantasy Violence | None |
| Realistic Violence | None |
| Sexual Content or Nudity | None |
| Profanity or Crude Humor | None |
| Alcohol, Tobacco, or Drug Use or References | None |
| Simulated Gambling | None |
| Horror/Fear Themes | None |
| Mature/Suggestive Themes | None |
| Medical/Treatment Information | None |
| Unrestricted Web Access | No |

Expected rating: **4+**

---

## App Privacy (App Store Connect)

### Data types collected:

| Data Type | Category | Purpose | Linked to Identity | Used for Tracking |
|-----------|----------|---------|-------------------|-------------------|
| Email Address | Contact Info | App Functionality | Yes | No |
| User ID | Identifiers | App Functionality | Yes | No |
| Product Interaction | Usage Data | App Functionality, Analytics | Yes | No |
| Other Usage Data | Usage Data | App Functionality | Yes | No |
| Crash Data | Diagnostics | App Functionality | No | No |
| Performance Data | Diagnostics | App Functionality | No | No |

### Data NOT collected:
- Location, Health, Fitness, Financial Info, Sensitive Info, Contacts, Photos, Audio, Browsing History, Search History, Purchases (handled by Apple)

---

## Tax & Banking

### For non-US developers (Taiwan):
1. Go to App Store Connect > Agreements, Tax, and Banking
2. Complete **Paid Apps** agreement
3. Fill in **W-8BEN** form:
   - Country of residence: Taiwan
   - Tax ID: your local tax ID (or passport number)
   - Claim treaty benefits if applicable (US-Taiwan tax treaty)
4. Add banking information for USD payments

---

## IAP Products Setup

Create these in App Store Connect > In-App Purchases:

| Product ID | Type | Display Name | Price (USD) |
|-----------|------|-------------|-------------|
| credits_1 | Consumable | 1 Credit | $0.99 |
| credits_3 | Consumable | 3 Credits | $2.99 |
| credits_10 | Consumable | 10 Credits | $7.99 |

For each product:
1. Set Reference Name, Product ID, Price
2. Add localization (English US): Display Name, Description
3. Add screenshot (of the purchase UI)
4. Submit for review (bundled with app)

---

## Screenshots

### Required sizes:
- **iPhone 6.7"** (iPhone 14 Pro Max): 1290 x 2796 px — REQUIRED
- **iPhone 6.5"** (iPhone 11 Pro Max): 1242 x 2688 px — recommended
- **iPad Pro 12.9"**: 2048 x 2732 px — if supporting iPad

### Content suggestions for 5-7 screenshots:
1. Home page — topic bubbles and daily content
2. Product detail — learning content card
3. Notification — daily pop notification on lock screen
4. Library — personal progress tracking
5. Notification settings — schedule customization
6. Themes — dark and light mode
7. Wallet / credits — premium content unlock

All screenshots must show **English** text.

---

## Copyright

In App Store Connect, set Copyright to: `© 2026 mimoom`

---

## URLs Required

| Field | URL |
|-------|-----|
| Privacy Policy URL | Your Notion privacy policy page URL |
| Support URL | Your Notion support page URL |
| Marketing URL | (optional) |

---

## Pre-submission Checklist

- [ ] Primary language: English (U.S.)
- [ ] App name, subtitle, keywords, description filled in English
- [ ] Screenshots uploaded (English text, correct sizes)
- [ ] Age rating questionnaire completed
- [ ] App privacy data collection declared
- [ ] Privacy Policy URL added
- [ ] Support URL added
- [ ] Copyright set to © 2026 mimoom
- [ ] Tax/banking info completed (W-8BEN for non-US)
- [ ] IAP products created with USD pricing
- [ ] Build uploaded and processed
- [ ] Version 1.0.0 ready for submission
