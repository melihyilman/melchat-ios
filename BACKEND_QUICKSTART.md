# Backend Quick Start Guide

Bu dosyayı iOS geliştirmeden önce oku! Backend'i başlatmadan iOS app çalışmaz.

---

## 🚀 Method 1: Docker Compose (Önerilen)

**En kolay yol!** PostgreSQL, Redis ve Backend'i tek komutla başlatır.

### Adımlar:

```bash
# 1. Ana dizine git
cd /Users/melih/dev/melchat

# 2. Docker Compose ile başlat
docker-compose up -d

# 3. Logları takip et (opsiyonel)
docker-compose logs -f backend

# 4. Servisi durdur (işin bitince)
docker-compose down
```

### Servisler:
- **Backend API:** http://localhost:3000
- **Swagger Docs:** http://localhost:3000/docs
- **PostgreSQL:** localhost:5433
- **Redis:** localhost:6379

### Sorun giderme:
```bash
# Servis durumunu kontrol et
docker-compose ps

# Tüm logları gör
docker-compose logs

# Baştan başlat
docker-compose down
docker-compose up -d
```

---

## 🛠️ Method 2: Manuel (Development)

Docker kullanmak istemiyorsan, manuel olarak başlat.

### Ön Gereksinimler:
- **PostgreSQL** çalışıyor olmalı (port 5433)
- **Redis** çalışıyor olmalı (port 6379)
- **Node.js 18+** yüklü olmalı

### Adımlar:

```bash
# 1. Backend dizinine git
cd /Users/melih/dev/melchat/backend

# 2. Dependencies kur (ilk seferinde)
npm install

# 3. Database migration çalıştır (ilk seferinde)
npx prisma migrate dev

# 4. Serveri başlat
npx tsx test-server.ts

# VEYA watch mode ile (kodları değiştiğinde otomatik restart)
npm run dev
```

### Test et:
```bash
# Backend çalışıyor mu kontrol et
curl http://localhost:3000/health

# Response:
# {"status":"ok","timestamp":"2024-12-25T..."}
```

---

## 📱 iOS App'i Bağla

### 1. Backend URL'ini Ayarla

`MelChat/Core/Network/APIClient.swift` dosyasını aç:

```swift
// Simulator için
#if targetEnvironment(simulator)
private let baseURL = "http://localhost:3000/api"

// Real device için (Mac'in IP adresini kullan)
#else
private let baseURL = "http://192.168.1.116:3000/api"
#endif
```

### 2. Mac'in IP Adresini Bul

**Real device'ta test ediyorsan:**

```bash
# Terminal'de çalıştır
ifconfig | grep "inet " | grep -v 127.0.0.1

# Çıktı: inet 192.168.1.116 netmask ...
# Bu IP'yi yukarıdaki baseURL'de kullan
```

---

## ✅ Backend Hazır mı Kontrol Et

### Test Checklist:

1. **Health Check**
   ```bash
   curl http://localhost:3000/health
   ```
   ✅ Response: `{"status":"ok",...}`

2. **Swagger Docs**

   Tarayıcıda aç: http://localhost:3000/docs

   ✅ API dokümantasyonu görünüyor

3. **Database Bağlantısı**
   ```bash
   cd backend
   npx prisma studio
   ```
   ✅ Prisma Studio açılıyor (http://localhost:5555)

---

## 🔥 Sık Karşılaşılan Hatalar

### 1. Port zaten kullanımda
```
Error: listen EADDRINUSE: address already in use 0.0.0.0:3000
```

**Çözüm:**
```bash
# Port 3000'i kullanan process'i bul ve öldür
lsof -ti:3000 | xargs kill -9

# Yeniden başlat
npx tsx test-server.ts
```

### 2. Database bağlanamıyor
```
Error: Can't reach database server at localhost:5433
```

**Çözüm:**
```bash
# PostgreSQL çalışıyor mu kontrol et
docker ps | grep postgres

# Docker Compose ile başlat
docker-compose up -d postgres

# VEYA manuel PostgreSQL başlat
brew services start postgresql@16
```

### 3. Redis bağlanamıyor
```
Error: Redis connection failed
```

**Çözüm:**
```bash
# Redis çalışıyor mu kontrol et
docker ps | grep redis

# Docker Compose ile başlat
docker-compose up -d redis

# VEYA manuel Redis başlat
brew services start redis
```

### 4. Migration hataları
```
Error: Prisma schema is not in sync with database
```

**Çözüm:**
```bash
cd backend
npx prisma migrate dev
npx prisma generate
```

---

## 📚 Faydalı Komutlar

```bash
# Backend logları canlı takip et
docker-compose logs -f backend

# Database'i sıfırla (DEV ONLY!)
docker-compose down -v
docker-compose up -d
cd backend && npx prisma migrate dev

# Tüm Docker container'ları durdur
docker-compose down

# Backend'i yeniden build et
docker-compose build backend
docker-compose up -d backend

# Node modules güncelle
cd backend
npm install
```

---

## 🎯 Hızlı Başlangıç (TL;DR)

**En hızlı yol:**

```bash
# Terminal'de çalıştır:
cd /Users/melih/dev/melchat
docker-compose up -d

# Backend hazır! Şimdi Xcode'da iOS app'i çalıştır.
```

**Backend URL:** http://localhost:3000
**Swagger Docs:** http://localhost:3000/docs

---

**Hazır mısın?** Xcode'u aç ve ⌘+R ile iOS app'i başlat! 🚀
