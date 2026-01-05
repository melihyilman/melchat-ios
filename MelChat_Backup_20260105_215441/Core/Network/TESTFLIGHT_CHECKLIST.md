# ✅ TestFlight Hazırlık Checklist

## 🎯 Hızlı Başlangıç (15 dakika)

### 1. Apple Developer Portal
**developer.apple.com** → Certificates, Identifiers & Profiles

#### App ID Oluştur:
```
☐ Identifiers → + (Add)
☐ App IDs → Continue
☐ Description: MelChat
☐ Bundle ID: com.yourname.melchat
```

#### Capabilities Seç (Sadece Bunlar):
```
✅ Push Notifications
✅ Background Modes
☐ Keychain Sharing (opsiyonel)
```

### 2. Xcode'da
**Signing & Capabilities** tab:

```
☐ Team seç
☐ Bundle ID doğru mu kontrol et
☐ + Capability → Push Notifications
☐ + Capability → Background Modes
    ☐ Remote notifications
    ☐ Background fetch  
    ☐ Audio (voice messages için)
```

### 3. Info.plist
Aşağıdaki permissions'ları ekle:

```xml
☐ NSMicrophoneUsageDescription
☐ NSCameraUsageDescription  
☐ NSPhotoLibraryUsageDescription
```

### 4. App Store Connect
**appstoreconnect.apple.com**:

```
☐ My Apps → + → New App
☐ İsim: MelChat
☐ Bundle ID seç
☐ Privacy Policy URL ekle
☐ Description yaz
```

### 5. Build & Upload
```
☐ Product → Archive
☐ Distribute App → App Store Connect
☐ Upload
☐ TestFlight → Add Internal Testers
☐ ✅ DONE!
```

---

## 📋 Detaylı Checklist

### Pre-Development
- [ ] Apple Developer Program ($99/year) aktif mi?
- [ ] Xcode 15+ installed mi?
- [ ] macOS güncel mi?

### Apple Developer Portal

#### Certificates:
- [ ] iOS Distribution certificate oluşturuldu
- [ ] Development certificate oluşturuldu

#### App ID:
- [ ] Bundle ID: `com.yourname.melchat`
- [ ] Push Notifications enabled
- [ ] Background Modes enabled

#### Provisioning Profiles:
- [ ] Development profile downloaded
- [ ] Distribution profile downloaded

### Xcode Configuration

#### General:
- [ ] Display Name: MelChat
- [ ] Bundle Identifier doğru
- [ ] Version: 1.0.0
- [ ] Build: 1

#### Signing & Capabilities:
- [ ] Team selected
- [ ] Signing certificate valid
- [ ] Push Notifications added
- [ ] Background Modes added
  - [ ] Remote notifications
  - [ ] Background fetch
  - [ ] Audio

#### Info.plist:
- [ ] NSMicrophoneUsageDescription
- [ ] NSCameraUsageDescription
- [ ] NSPhotoLibraryUsageDescription
- [ ] UIBackgroundModes array

#### Build Settings:
- [ ] Optimization: Release
- [ ] Strip Debug Symbols: Yes
- [ ] Bitcode: No

### App Assets

#### App Icon:
- [ ] 1024x1024 PNG (App Store)
- [ ] All required sizes in Assets.xcassets
- [ ] No transparency
- [ ] No rounded corners

#### Launch Screen:
- [ ] LaunchScreen.storyboard configured
- [ ] Loads quickly (<1s)

### App Store Connect

#### App Information:
- [ ] App name: MelChat
- [ ] Subtitle (optional)
- [ ] Category: Social Networking
- [ ] Privacy Policy URL
- [ ] Support URL

#### Version Information:
- [ ] Description (engaging!)
- [ ] Keywords
- [ ] Screenshots (3-10)
  - [ ] iPhone 6.7" (Pro Max)
  - [ ] iPhone 6.5" (Plus)
  - [ ] iPad Pro 12.9"
- [ ] App Preview video (optional)

#### App Review Information:
- [ ] Contact info
- [ ] Demo account credentials
- [ ] Review notes

#### Pricing:
- [ ] Price: Free (or set price)
- [ ] Availability: All countries

### TestFlight

#### Internal Testing:
- [ ] Internal testers added (email)
- [ ] Build distributed
- [ ] Feedback received

#### External Testing:
- [ ] Beta App Description written
- [ ] Test information complete
- [ ] Beta review submitted
- [ ] External testers added

### Testing Checklist

#### Functionality:
- [ ] Login/Register works
- [ ] Send text messages
- [ ] Send photos
- [ ] Send voice messages
- [ ] Receive messages
- [ ] Push notifications
- [ ] Dark mode
- [ ] Encryption working

#### UI/UX:
- [ ] All screens responsive
- [ ] Animations smooth
- [ ] No layout issues
- [ ] Proper loading states
- [ ] Error handling

#### Performance:
- [ ] App launches quickly (<2s)
- [ ] Smooth scrolling (60 FPS)
- [ ] No memory leaks
- [ ] Battery usage reasonable
- [ ] Network efficient

#### Devices:
- [ ] iPhone SE (2nd gen) - smallest
- [ ] iPhone 15 Pro Max - largest
- [ ] iPad - tablet
- [ ] iOS 17.0 - minimum version

### Privacy & Security

#### Privacy Manifest:
- [ ] PrivacyInfo.xcprivacy added (iOS 17+)
- [ ] Required Reason API declarations

#### App Tracking Transparency:
- [ ] ATT prompt if needed
- [ ] Privacy labels accurate

#### Data Collection:
- [ ] Minimal data collection
- [ ] Encrypted storage
- [ ] Clear privacy policy

### Pre-Submission Final Checks

#### Code:
- [ ] No hardcoded secrets
- [ ] API endpoints production-ready
- [ ] Logging disabled/minimized
- [ ] Crashlytics integrated (optional)
- [ ] Analytics integrated (optional)

#### Legal:
- [ ] Terms of Service
- [ ] Privacy Policy
- [ ] EULA (if needed)
- [ ] Age rating appropriate (4+, 9+, 12+, 17+)

#### Localization (Future):
- [ ] English (default)
- [ ] Turkish (if targeting Turkey)
- [ ] Other languages

---

## 🚨 Common Mistakes to Avoid

### ❌ DON'T:
- Use wildcard Bundle ID (com.company.*)
- Skip test account in review
- Forget microphone permission description
- Use test/debug API endpoints
- Include placeholder content
- Submit without testing
- Ignore App Store guidelines

### ✅ DO:
- Test on real devices
- Provide detailed review notes
- Include demo account
- Test all permissions
- Check all screenshots
- Read rejection reasons carefully
- Respond to Apple quickly

---

## 📞 Emergency Contacts

### Build Issues:
- Clean Build Folder (⌘+Shift+K)
- Delete Derived Data
- Restart Xcode
- Restart Mac

### Upload Issues:
- Check internet connection
- Try Application Loader (legacy)
- Wait 15 minutes, retry
- Check Apple system status

### Review Issues:
- Read rejection email carefully
- Fix issues
- Resubmit with notes
- Usually 24-48 hours

---

## 🎯 Quick Reference

### Bundle ID Format:
```
com.company.appname
com.yourname.melchat
```

### Version Format:
```
1.0.0 (Build 1)
Major.Minor.Patch (Build Number)
```

### Required Permissions:
```
NSMicrophoneUsageDescription → Voice messages
NSCameraUsageDescription → Take photos
NSPhotoLibraryUsageDescription → Send photos
```

### Required Capabilities:
```
✅ Push Notifications
✅ Background Modes (remote-notification, fetch, audio)
```

---

## 📊 Timeline

### Realistic Timeline:
```
Day 1-2: Setup developer account & certificates
Day 3-4: Configure Xcode & capabilities
Day 5-7: Prepare assets & screenshots
Day 8-10: Internal testing & fixes
Day 11-14: External beta testing
Day 15: Submit to App Store
Day 16-17: Apple review (24-48 hours)
Day 18: 🎉 LIVE!
```

### Fast Track (Emergency):
```
Hour 1: Configure everything
Hour 2: Upload build
Hour 3: TestFlight testing
Hour 4+: Submit (if urgent)
```

---

## 💡 Pro Tips

1. **Use Automatic Signing** (easier for beginners)
2. **Test on multiple devices** before submission
3. **Take screenshots in Simulator** (⌘+S)
4. **Use TestFlight extensively** before public
5. **Respond to reviews** quickly
6. **Update regularly** (every 2-4 weeks)

---

## 🎉 You're Ready!

Print this checklist and check off items as you go.

**Questions?**
- TESTFLIGHT_SETUP.md (detailed guide)
- developer.apple.com/support
- forums.developer.apple.com

**Good luck!** 🚀
