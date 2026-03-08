# Firebase Setup Guide

## Step 1 — Create a Firebase project

1. Go to https://console.firebase.google.com
2. Click **Add project**
3. Name it `stockbook` (or anything you like)
4. Disable Google Analytics (not needed)
5. Click **Create project**

## Step 2 — Enable Firestore

1. In the left sidebar click **Firestore Database**
2. Click **Create database**
3. Choose **Start in test mode** (allows all reads/writes for 30 days — fine for now)
4. Pick a region close to Ethiopia, e.g. `europe-west1`
5. Click **Done**

## Step 3 — Connect your Flutter app

Install the FlutterFire CLI if you haven't already:
```
dart pub global activate flutterfire_cli
```

Then inside your project folder run:
```
flutterfire configure
```

This command will:
- Ask you to pick your Firebase project
- Ask which platforms (Android, iOS, etc.)
- Automatically generate `lib/firebase_options.dart`

## Step 4 — Update main.dart

After running `flutterfire configure`, change your `main.dart` import to:
```dart
import 'firebase_options.dart';

await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

## Step 5 — Run the app
```
flutter pub get
flutter run
```

## Firestore Security Rules (important before going live)

Right now the database is open to everyone. Before sharing the app,
go to Firestore → Rules and replace the content with:

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /{document=**} {
      allow read, write: if request.time < timestamp.date(2026, 12, 31);
    }
  }
}
```

For production, add proper authentication rules.

## Firestore data structure

```
/products/{autoId}
  name: "Sugar"
  buyPrice: 45.0
  sellPrice: 60.0
  openingStock: 12
  active: true

/dayEntries/{dateStr}            e.g. "2026-03-04"
  date: "2026-03-04"
  complete: false
  totalRevenue: 0
  totalProfit: 0
  totalExpenses: 0
  netProfit: 0
  openingStock: { "productId1": 12, "productId2": 8 }

  /purchases/{productId}
    productId: "abc123"
    qty: 10
    price: 45.0

  /sales/{productId}
    productId: "abc123"
    qtySold: 7

  /expenses/{autoId}
    description: "Electricity"
    amount: 85.5
```
