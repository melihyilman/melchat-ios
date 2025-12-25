# 🚀 TestFlight Deployment Guide - MelChat iOS

## 📋 İçindekiler
1. [Apple Developer Account Setup](#apple-developer-account-setup)
2. [App ID & Capabilities](#app-id--capabilities)
3. [Certificates & Provisioning](#certificates--provisioning)
4. [Xcode Configuration](#xcode-configuration)
5. [TestFlight Submission](#testflight-submission)
6. [Troubleshooting](#troubleshooting)

---

## 1️⃣ Apple Developer Account Setup

### Gereksinimler:
- ✅ Apple Developer Program ($99/year)
- ✅ macOS with Xcode 15+
- ✅ Valid Apple ID

### Account Types:
- **Individual**: Tek geliştirici (önerilen başlangıç için)
- **Organization**: Şirket hesabı

---

## 2️⃣ App ID & Capabilities

### A. App ID Oluşturma

1. **developer.apple.com** → Certificates, IDs & Profiles
2. **Identifiers** → **+** (Add button)
3. **App IDs** seç → Continue
4. **App** seç → Continue

### B. Temel Bilgiler

```
Description: MelChat
Bundle ID: com.yourcompany.melchat  // Eğer bundle ID'n varsa onu kullan
```

**Bundle ID Seçimi:**
- ✅ Explicit App ID kullan (Wildcard değil)
- ✅ Reverse domain notation: `com.company.appname`
- ⚠️ Bundle ID sonradan değiştirilemez!

### C. Capabilities Seçimi

MelChat için **gerekli** capability'ler:

#### ✅ ZORUNLU:

**1. Push Notifications**
- ✅ Seç: "Push Notifications"
- 📌 Amaç: Remote notifications için
- 📌 Kullanım: Yeni mesaj bildirimleri

**2. Background Modes**
- ✅ Seç: "Background Modes"
- 📌 Alt seçenekler:
  - ✅ Remote notifications
  - ✅ Background fetch
  - ✅ Audio (voice messages için)
- 📌 Amaç: Arka planda mesaj alma

**3. Keychain Sharing** (İsteğe Bağlı)
- ✅ Seç: "Keychain Sharing"
- 📌 Amaç: Cihazlar arası token senkronizasyonu
- 📌 Keychain Group: `$(AppIdentifierPrefix)com.yourcompany.melchat`

#### ⚠️ GEREK YOK (Şimdilik):

❌ **iCloud** - Bulut senkronizasyonu yok
❌ **HealthKit** - Sağlık verisi kullanmıyoruz
❌ **HomeKit** - Akıllı ev değil
❌ **Apple Pay** - Ödeme yok (şimdilik)
❌ **Siri** - Şimdilik entegrasyon yok
❌ **Game Center** - Oyun değil
❌ **In-App Purchase** - İçinde ödeme yok (şimdilik)
❌ **Wallet** - Wallet pass yok
❌ **Associated Domains** - Universal links yok (şimdilik)

#### 🔮 GELECEK (Phase 2):

🔵 **Sign in with Apple** - OAuth login için
🔵 **In-App Purchase** - Premium features için
🔵 **App Groups** - Widget/extension paylaşımı için

---

## 3️⃣ Certificates & Provisioning Profiles

### A. Development Certificate

1. **Certificates** → **+**
2. **iOS App Development** seç
3. **CSR (Certificate Signing Request)** oluştur:

```bash
# Mac'te Keychain Access aç:
# Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority

Common Name: Your Name
Email: your@email.com
Request is: Saved to disk
```

4. CSR'ı upload et → Download certificate
5. Certificate'ı çift tıkla (Keychain'e ekler)

### B. Distribution Certificate

1. **Certificates** → **+**
2. **iOS Distribution (App Store and Ad Hoc)** seç
3. Aynı CSR işlemini tekrarla
4. Download → Install

### C. Provisioning Profiles

#### Development Profile:
1. **Profiles** → **+**
2. **iOS App Development** seç
3. App ID'ni seç (com.yourcompany.melchat)
4. Certificate'ı seç
5. Test device'ları seç
6. İsim ver: "MelChat Development"
7. Download

#### App Store Profile:
1. **Profiles** → **+**
2. **App Store** seç
3. App ID'ni seç
4. Distribution certificate'ı seç
5. İsim ver: "MelChat AppStore"
6. Download

---

## 4️⃣ Xcode Configuration

### A. Project Settings

1. Xcode'da projeyi aç
2. Project Navigator → **MelChat** (blue icon)
3. **TARGETS** → MelChat seç
4. **Signing & Capabilities** tab

### B. Signing Setup

#### Automatic Signing (Kolay - Önerilen):
```
☑️ Automatically manage signing

Team: Your Team Name
Bundle Identifier: com.yourcompany.melchat
```

#### Manual Signing (Advanced):
```
☐ Automatically manage signing

Signing Certificate: iOS Distribution
Provisioning Profile: MelChat AppStore
```

### C. Capabilities Ekleme

**Signing & Capabilities** tab'de **+ Capability**:

**1. Push Notifications**
```
+ Capability → Push Notifications
```

**2. Background Modes**
```
+ Capability → Background Modes

✅ Remote notifications
✅ Background fetch
✅ Audio, AirPlay, and Picture in Picture
```

**3. Keychain Sharing** (Optional)
```
+ Capability → Keychain Sharing

Keychain Groups:
  - $(AppIdentifierPrefix)com.yourcompany.melchat
```

### D. Info.plist Permissions

`Info.plist` dosyasına ekle:

```xml
<!-- Microphone Permission (Voice Messages) -->
<key>NSMicrophoneUsageDescription</key>
<string>MelChat needs microphone access to record and send voice messages</string>

<!-- Camera Permission (Photos) -->
<key>NSCameraUsageDescription</key>
<string>MelChat needs camera access to take and send photos</string>

<!-- Photo Library Permission -->
<key>NSPhotoLibraryUsageDescription</key>
<string>MelChat needs photo library access to send images</string>

<!-- Background Modes -->
<key>UIBackgroundModes</key>
<array>
    <string>remote-notification</string>
    <string>fetch</string>
    <string>audio</string>
</array>
```

---

## 5️⃣ Build Configuration

### A. Build Settings

**Target** → **Build Settings** → Filter: "versioning"

```
Product Name: MelChat
Product Bundle Identifier: com.yourcompany.melchat

Version: 1.0.0
Build: 1

// Versioning:
// Version = User-facing (1.0.0)
// Build = Internal (1, 2, 3...)
```

### B. Release Configuration

**Build Settings** → Filter: "optimization"

```
Optimization Level: -Os (Optimize for Size)
Swift Optimization Level: -O (Optimize for Speed)

Enable Bitcode: No (artık deprecated)
Strip Debug Symbols: Yes
```

### C. Archive Settings

**Product** → **Scheme** → **Edit Scheme** → **Archive**

```
Build Configuration: Release
```

---

## 6️⃣ TestFlight Submission

### A. App Store Connect Setup

1. **appstoreconnect.apple.com** → My Apps → **+**
2. **New App**

```
Platform: iOS
Name: MelChat
Primary Language: Turkish (or English)
Bundle ID: com.yourcompany.melchat
SKU: melchat-ios-001
User Access: Full Access
```

### B. App Information

**App Information** tab:

```
Name: MelChat
Subtitle: Güvenli Mesajlaşma
Category: Social Networking
```

**Privacy Policy URL:**
```
https://yourwebsite.com/privacy
```

**Description:**
```
MelChat - End-to-end encrypted messaging app

✨ Features:
• 🔐 End-to-end encryption with Signal Protocol
• 💬 Text, photos, and voice messages
• 🎨 Modern, beautiful interface
• 🌙 Dark mode support
• ⚡ Fast and secure

Your privacy is our priority. All messages are encrypted and only you and your recipient can read them.
```

### C. Build Upload

**Xcode'da:**

1. **Product** → **Archive**
2. Wait for build to complete
3. **Organizer** window açılır
4. **Distribute App**
5. **App Store Connect** seç
6. **Upload** seç
7. ✅ Sign options:
   - ✅ Automatically manage signing
   - ✅ Upload your app's symbols
8. **Upload**

### D. TestFlight Configuration

**App Store Connect** → **TestFlight** tab:

**Internal Testing:**
```
1. "+" → Add Internal Testers
2. Email addresses ekle
3. Otomatik invite gönderir
```

**External Testing:**
```
1. "+" → Create New Group
2. Group Name: Beta Testers
3. Add Build (uploaded build'i seç)
4. Submit for Beta Review (Apple review)
5. Approval sonrası testerlar test edebilir
```

### E. Beta App Information

**TestFlight** → **Test Information**:

```
Beta App Description:
  "MelChat beta - help us test encrypted messaging!"

Feedback Email: support@yourcompany.com

Marketing URL: https://yourwebsite.com

Privacy Policy URL: https://yourwebsite.com/privacy
```

**What to Test:**
```
1. Login flow
2. Sending/receiving messages
3. Voice messages
4. Photo sharing
5. Encryption functionality
6. Dark mode
7. Notifications
```

---

## 7️⃣ App Review Preparation

### A. Screenshots (Required Sizes)

**iPhone 6.7" (iPhone 15 Pro Max):**
- 1290 x 2796 pixels
- Minimum 3 screenshots

**iPhone 6.5" (iPhone 14 Plus):**
- 1242 x 2688 pixels

**iPad Pro 12.9" (3rd gen):**
- 2048 x 2732 pixels

### B. App Preview Video (Optional)

```
Duration: 15-30 seconds
Resolution: Same as screenshots
Format: .mov, .m4v, .mp4
```

### C. Test Account (IMPORTANT!)

App Store Connect → **App Review Information**:

```
Sign-in required: Yes

Demo Account:
  Username: test@melchat.com
  Password: TestPassword123!
  
Notes:
  "This is a test account for reviewers. 
   You can create multiple accounts to test messaging between users."
```

---

## 8️⃣ Common Issues & Solutions

### ❌ Issue: "No signing certificate found"

**Solution:**
```bash
1. Xcode → Preferences → Accounts
2. Apple ID ekle
3. Download Manual Profiles
4. Retry
```

### ❌ Issue: "Entitlements file is missing"

**Solution:**
```
1. Target → Signing & Capabilities
2. + Capability → Push Notifications
3. Clean Build Folder (⌘+Shift+K)
4. Build again
```

### ❌ Issue: "Invalid Bundle ID"

**Solution:**
```
1. Bundle ID'nin App Store Connect ile eşleştiğinden emin ol
2. Büyük/küçük harf önemli!
3. Wildcard (*) kullanma
```

### ❌ Issue: "Build processing fails"

**Solution:**
```
1. Archive → Export IPA
2. Validate App (errors gösterir)
3. Fix errors
4. Re-upload
```

---

## 9️⃣ Version Management

### Semantic Versioning:

```
MAJOR.MINOR.PATCH
  1  . 0  . 0

MAJOR: Breaking changes
MINOR: New features
PATCH: Bug fixes

Examples:
  1.0.0 → Initial release
  1.0.1 → Bug fix
  1.1.0 → New feature (voice messages)
  2.0.0 → Major redesign
```

### Build Number:

```
1.0.0 (1)   → First submission
1.0.0 (2)   → Fix & resubmit
1.0.1 (3)   → Bug fix update
```

**Auto-increment build number:**
```bash
# Build Phases → + → New Run Script Phase
/usr/libexec/PlistBuddy -c "Set :CFBundleVersion $(/usr/libexec/PlistBuddy -c "Print CFBundleVersion" "${INFOPLIST_FILE}" | awk '{print $0 + 1}')" "${INFOPLIST_FILE}"
```

---

## 🔟 Checklist

### Pre-Submission:
- [ ] Bundle ID configured
- [ ] Capabilities added
- [ ] Certificates installed
- [ ] Provisioning profiles downloaded
- [ ] Info.plist permissions added
- [ ] App icon added (all sizes)
- [ ] Launch screen configured
- [ ] Version & build number set

### App Store Connect:
- [ ] App created
- [ ] Screenshots uploaded (all sizes)
- [ ] Description written
- [ ] Keywords set
- [ ] Privacy policy URL added
- [ ] Support URL added
- [ ] Test account provided

### Testing:
- [ ] Build uploaded
- [ ] Internal testing done
- [ ] External testing submitted
- [ ] Feedback collected
- [ ] Bugs fixed

### Final:
- [ ] App Store submission
- [ ] Review notes complete
- [ ] Contact info updated
- [ ] 🎉 Launch!

---

## 📞 Support

### Apple Developer Support:
- **Phone**: Check developer.apple.com
- **Email**: developer.apple.com/contact
- **Forums**: forums.developer.apple.com

### Common Documentation:
- App Store Review Guidelines: developer.apple.com/app-store/review/guidelines
- TestFlight: developer.apple.com/testflight
- Human Interface Guidelines: developer.apple.com/design/human-interface-guidelines

---

## 🎉 Launch Strategy

### Phase 1: TestFlight (Week 1-2)
```
- 10-50 internal testers
- Fix critical bugs
- Gather feedback
- Iterate quickly
```

### Phase 2: External Beta (Week 3-4)
```
- 100-1000 external testers
- Public link sharing
- Analytics monitoring
- Performance optimization
```

### Phase 3: App Store (Week 5)
```
- Submit for review
- Wait 24-48 hours
- Address any issues
- Release!
```

### Phase 4: Post-Launch (Week 6+)
```
- Monitor crash reports
- Collect user feedback
- Plan updates
- Marketing push
```

---

## 💡 Pro Tips

### 1. Build Numbering:
```bash
# Use CI/CD to auto-increment
# GitHub Actions, Bitrise, etc.
```

### 2. Fastlane:
```ruby
# Automate TestFlight deployment
lane :beta do
  increment_build_number
  build_app(scheme: "MelChat")
  upload_to_testflight
end
```

### 3. Crash Reporting:
```swift
// Add Firebase Crashlytics or Sentry
// Monitor production issues
```

### 4. Analytics:
```swift
// Add Firebase Analytics or Mixpanel
// Track user behavior
```

---

**Good luck with your TestFlight launch!** 🚀

**Questions? Check Apple Developer Forums or contact support.**

---

**Document Version:** 1.0
**Last Updated:** December 25, 2024
**Author:** MelChat Team
