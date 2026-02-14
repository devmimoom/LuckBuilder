# App 隱私權政策與使用條款（給 Notion 使用）

將以下內容複製到 Notion 建立「隱私權政策」與「使用條款」頁面，發佈後取得連結，再貼到 App Store Connect 的 **App 隱私**／隱私政策 URL，以及 App 內「Privacy policy」「Terms of use」連結。

---

## 一、隱私權政策（Privacy Policy）— 可直接複製貼上

### Copy-paste version (English) — paste into Notion as-is

```
OnePop – Privacy Policy

Last updated: 2026

We care about your privacy. This policy describes what data we collect and how we use it.

1. Data we collect

• Account: When you sign up or sign in (email, or Apple/Google sign-in), we store your account identifier and, if you provide it, your email address.
• Usage: We may collect information about how you use the app (e.g. which products you open, progress, and preferences) to improve the service and your experience.
• Device: We may collect device-related information (e.g. platform, language) for compatibility and support.

2. How we use your data

• To provide and improve the app (learning content, library, notifications).
• To communicate with you (e.g. support, password reset).
• To comply with law and protect our rights.

3. Sharing

We do not sell your personal data. We do not share your personal information for cross-context behavioral advertising. We may share data only as required by law or with service providers that help us run the app (e.g. hosting, analytics), under strict agreements.

4. Security

We use industry-standard measures to protect your data. You are responsible for keeping your password safe.

5. Your choices

You can request access, correction, or deletion of your data by contacting us at dev.mimoom@gmail.com. You may also delete your account or reset data directly within the app. If you are a California resident, you have additional rights under the California Consumer Privacy Act (CCPA), including the right to know, delete, and opt out of the sale of personal information (we do not sell your data).

6. Data retention

We retain your data only as long as your account is active or as needed to provide the service. You may delete your account at any time from the app settings, which will remove your data from our systems.

7. Children

This app is not directed at children under 13. We do not knowingly collect personal information from children under 13. If we learn that we have collected data from a child under 13, we will delete it promptly. If you believe a child has provided us with personal data, please contact us at dev.mimoom@gmail.com.

8. Changes

We may update this policy from time to time. We will notify you of material changes via the app or email where appropriate.

Contact: dev.mimoom@gmail.com
© 2026 mimoom
```

---

## 二、使用條款（Terms of Use）— 可直接複製貼上

### Copy-paste version (English) — paste into Notion as-is

```
OnePop – Terms of Use

Last updated: 2026

By using the OnePop app, you agree to these terms.

1. Use of the app

You may use the app for personal, non-commercial learning. You must not misuse the app (e.g. reverse engineering, circumventing payment or access controls, or violating laws).

2. Account

You are responsible for keeping your account credentials secure. You must provide accurate information when signing up. We may suspend or terminate accounts that violate these terms.

3. Content and intellectual property

Content in the app (text, audio, images, etc.) is owned by us or our licensors. You may not copy, redistribute, or use it outside the app without permission.

4. Purchases and credits

If you purchase credits or subscriptions, refunds are subject to the platform’s (e.g. App Store) policies. We do not guarantee refunds for digital content except as required by law.

5. Disclaimers

The app and content are provided “as is.” We do not guarantee uninterrupted or error-free service. Learning outcomes depend on your use and effort.

6. Limitation of liability

To the extent permitted by law, we are not liable for indirect, incidental, or consequential damages arising from your use of the app.

7. Changes

We may change these terms. Continued use of the app after changes means you accept the new terms. We will notify you of material changes where appropriate.

8. Contact

Questions? Contact us at dev.mimoom@gmail.com.

© 2026 mimoom
```

---

## 三、在 App Store Connect 與 App 內填寫方式

### 1. Notion 發佈

1. 在 Notion 新增兩個頁面：「OnePop – Privacy Policy」「OnePop – Terms of Use」。
2. 分別貼上上面「一」「二」的內文（或你的版本）。
3. 各頁右上角 **Share** → **Publish to web** → 開啟 **Publish**。
4. 複製兩個網址（例如 `https://xxx.notion.site/Privacy-Policy-...`、`https://xxx.notion.site/Terms-of-Use-...`）。

### 2. App Store Connect

- 到該 App → **App 隱私**（App Privacy）或版本頁的 **隱私政策 URL**（Privacy Policy URL）。
- **隱私政策 URL** 貼上 Notion 隱私權政策頁的連結。
- 若欄位有「使用條款 URL」，貼上 Notion 使用條款頁的連結；若沒有，通常只要求隱私政策 URL。

### 3. App 內連結（lib/pages/me_page.dart）

- 將 **Privacy policy** 的 `https://example.com/privacy` 改為你的 **Notion 隱私權政策** 連結。
- 將 **Terms of use** 的 `https://example.com/terms` 改為你的 **Notion 使用條款** 連結。

這樣 App 隱私、App Store 申請與 App 內「隱私權政策／使用條款」就都對齊了。
