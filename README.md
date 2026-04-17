# Photo Booth — Complete Setup Guide

## What's Included

- Flutter app (Android + iOS + Web) — Snapchat-level
- FastAPI backend with PostgreSQL
- 120+ filters (GPU-optimized ColorFilter matrices)
- 100+ photo strip templates
- Real-time chat (WebSocket)
- Razorpay payment + UPI (parulsinhaa5@okaxis)
- Print & order system
- Free / Pro (₹99) / Premium (₹299) tiers
- Crazy 3D splash screen with particle effects
- All countries, all currencies

---

## Quick Start — Flutter App

### 1. Prerequisites
- Flutter SDK 3.10+
- Android Studio / Xcode
- Node.js (optional, for web)

### 2. Install Dependencies
```bash
cd photobooth
flutter pub get
```

### 3. Set Environment Variables
Create `.env` in project root:
```
BASE_URL=https://api.photobooth.app
WS_URL=wss://api.photobooth.app/ws
RAZORPAY_KEY_ID=rzp_live_YOUR_KEY
```

Or pass at build time:
```bash
flutter run --dart-define=BASE_URL=https://your-api.com \
            --dart-define=RAZORPAY_KEY_ID=rzp_live_xxx
```

### 4. Firebase Setup
- Create Firebase project at console.firebase.google.com
- Download `google-services.json` → `android/app/`
- Download `GoogleService-Info.plist` → `ios/Runner/`
- Enable Phone Authentication in Firebase Console

### 5. Run
```bash
# Android
flutter run -d android

# iOS
flutter run -d ios

# Web
flutter run -d chrome
```

### 6. Build for Release
```bash
# Android APK
flutter build apk --release --dart-define=BASE_URL=https://api.photobooth.app

# Android Bundle (Play Store)
flutter build appbundle --release

# iOS
flutter build ios --release

# Web
flutter build web --release
```

---

## Quick Start — Backend

### 1. Prerequisites
- Python 3.11+
- PostgreSQL 15+
- Redis 7+
- Docker (optional)

### 2. Local Setup
```bash
cd photobooth/backend

# Create virtual environment
python -m venv venv
source venv/bin/activate  # Linux/Mac
# venv\Scripts\activate   # Windows

# Install dependencies
pip install -r requirements.txt

# Copy env file
cp .env.example .env
# Edit .env with your values
```

### 3. .env file
```env
DEBUG=true
SECRET_KEY=your-super-secret-key-minimum-32-chars
DATABASE_URL=postgresql+asyncpg://photobooth:password@localhost:5432/photobooth_db
REDIS_URL=redis://localhost:6379/0

# Razorpay — Get from dashboard.razorpay.com
RAZORPAY_KEY_ID=rzp_live_xxxxxxxxxxxx
RAZORPAY_KEY_SECRET=xxxxxxxxxxxxxxxxxxxx
RAZORPAY_WEBHOOK_SECRET=xxxxxxxxxxxxxxxxxxxx

# AWS S3
AWS_ACCESS_KEY_ID=xxxx
AWS_SECRET_ACCESS_KEY=xxxx
AWS_REGION=ap-south-1
S3_BUCKET_NAME=photobooth-media
CDN_BASE_URL=https://cdn.photobooth.app

# Firebase (for push notifications)
FIREBASE_PROJECT_ID=photobooth-app
FIREBASE_CREDENTIALS_PATH=./firebase-credentials.json
```

### 4. Database Setup
```bash
# Create PostgreSQL database
createdb photobooth_db

# Run migrations
alembic upgrade head
```

### 5. Start Backend
```bash
python -m uvicorn app.main:app --reload --port 8000
```

API docs: http://localhost:8000/docs

---

## Docker Deployment (Production)

```bash
# Create .env.production with all values set

# Build and start all services
docker-compose up -d

# Check logs
docker-compose logs -f api

# Run migrations
docker-compose exec api alembic upgrade head
```

Services started:
- API: port 8000
- PostgreSQL: port 5432
- Redis: port 6379
- Nginx: ports 80, 443

---

## Razorpay Setup

1. Create account at **dashboard.razorpay.com**
2. Go to Settings → API Keys → Generate Key
3. Copy `Key ID` and `Key Secret` to your `.env`
4. For UPI: The UPI ID `parulsinhaa5@okaxis` is pre-configured as the merchant UPI
5. Set up Webhooks in Razorpay dashboard:
   - URL: `https://api.photobooth.app/api/v1/payments/razorpay-callback`
   - Events: `payment.captured`, `payment.failed`

---

## Subscription Tiers

| Feature | Free | Pro (₹99/mo) | Premium (₹299/mo) |
|---------|------|-------------|-------------------|
| Filters | 20 | 60 | 120+ |
| Templates | 5 | 50 | 100+ |
| Watermark | Yes | No | No |
| Print orders | No | 10% off | Free shipping |
| Video quality | HD | HD | 4K |

---

## Architecture

```
Flutter App
├── Camera (100+ GPU filters)
├── Photo Booth (strip generation)
├── Editor (Canva + Lightroom)
├── Discover
├── Chat (WebSocket, disappearing)
├── Orders + Print
└── Profile + Subscription

FastAPI Backend
├── Auth (OTP via SMS)
├── Media (S3 upload/CDN)
├── Filters + Templates
├── Photo Booth API
├── Chat (WebSocket)
├── Orders (Shiprocket)
└── Payments (Razorpay + UPI)

Infrastructure
├── PostgreSQL (primary DB)
├── Redis (cache + ws sessions)
├── AWS S3 (media storage)
├── CloudFront CDN
└── Docker + Nginx
```

---

## Adding More Filters

Edit `lib/features/camera/filters/filter_definitions.dart`:
```dart
FilterPreset(
  id: 'my_filter',
  name: 'My Filter',
  category: 'beauty',
  isPremium: false,
  previewColor: Color(0xFFFF6B9D),
  matrix: [
    // 4x5 color matrix (R, G, B, A, offset)
    1.0, 0,   0,   0, 0,
    0,   1.0, 0,   0, 0,
    0,   0,   1.0, 0, 0,
    0,   0,   0,   1, 0,
  ],
),
```

---

## Support

UPI Payments: parulsinhaa5@okaxis
API Base: https://api.photobooth.app
