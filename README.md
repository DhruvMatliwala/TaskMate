# 🚀 TaskMate — Hyper-Local Gig Economy Marketplace

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.x-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Firestore%20%7C%20Auth%20%7C%20Storage-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![Google Maps](https://img.shields.io/badge/Google%20Maps-Platform-4285F4?logo=googlemaps&logoColor=white)](https://developers.google.com/maps)
[![Architecture](https://img.shields.io/badge/Architecture-MVVM%20%2F%20Provider-6C63FF)](https://pub.dev/packages/provider)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-43E97B)](https://flutter.dev)

> **TaskMate** is a real-time, hyper-local gig economy mobile platform that connects busy community members who need urgent, real-world errands fulfilled (such as parcel delivery, grocery pickup, line standing, or technical assistance) with nearby verified peers and student freelancers looking to monetize their spare time.

Developed as a capstone project for **Mobile Application Development (3170726)** in the **Computer Engineering Department** at **C. K. Pithawala College of Engineering & Technology (CKPCET)**.

---

## 📱 App Showcase & Key Interfaces

<p align="center">
  <img src="Cipat/mockups/mockup_map.png" width="22%" alt="Live Map Radar" />
  <img src="Cipat/mockups/mockup_bidding.png" width="22%" alt="Task Bidding" />
  <img src="Cipat/mockups/mockup_nav.png" width="22%" alt="GPS Navigation" />
  <img src="Cipat/mockups/mockup_chat.png" width="22%" alt="Real-time Chat" />
</p>

---

## ✨ Core Features

* 📍 **Interactive Google Maps Radar:** Real-time visual discovery of open tasks within a 25 km radius, featuring category-coded custom map pins.
* 🤖 **Automated Dynamic Pricing Engine:** An intelligent algorithmic pricing model that factors in category base fares, GPS spherical distance, travel duration estimates, and dynamic urgency surge factors.
* 🤝 **Real-Time Counter-Bidding:** Open marketplace where workers submit counter-bids and creators review applicant ratings, bid histories, and profiles before acceptance.
* 🧭 **Turn-by-Turn GPS Polyline Navigation:** Live device geolocator tracking with encoded route polylines, travel distance in kilometers, and accurate ETA calculations.
* 💬 **Sub-100ms In-App Messaging:** Instant bilateral chat powered by Firebase Cloud Firestore WebSocket snapshots (`snapshots()`) without polling or page reloads.
* ⭐ **Peer Review & Rating Reputation System:** 5-star rating matrix with written feedback dynamically updating cumulative worker profile averages.
* 🔒 **Secure Authentication & Cloud Storage:** Passwords hashed with salted PBKDF2/SHA-256 via Firebase Auth; full support for multimedia attachments via Firebase Cloud Storage.

---

## 🏗️ Technical Architecture & Stack

TaskMate is built following the **Serverless Backend-as-a-Service (BaaS)** paradigm combined with a decoupled **MVVM (Model - View - ViewModel / Provider)** design pattern:

```
┌────────────────────────────────────────────────────────┐
│  1. THE VIEW (Presentation & UI Layer)                 │
│     Files: lib/screens/ & lib/widgets/                 │
│     • Custom Material widgets, Google Fonts, Shimmer   │
│     • Google Maps canvas with CustomMarkerPainter      │
└──────────────────────────┬─────────────────────────────┘
                           │ Dispatches user interactions
                           ▼
┌────────────────────────────────────────────────────────┐
│  2. THE BRAIN (State Management Layer)                 │
│     Files: lib/providers/                             │
│     • Provider & ChangeNotifier Architecture           │
│     • Reactive stream subscriptions & notifyListeners()│
└──────────────────────────┬─────────────────────────────┘
                           │ Calls backend APIs & Database
                           ▼
┌────────────────────────────────────────────────────────┐
│  3. THE SERVICES (Cloud Backend & Location Layer)      │
│     Files: lib/services/                               │
│     • Google Cloud Firestore (NoSQL document database) │
│     • Firebase Authentication & Cloud Storage          │
│     • Google Places Autocomplete & Directions APIs     │
│     • Native GPS Geolocator & Haversine math           │
└────────────────────────────────────────────────────────┘
```

### Technology Matrix

| Layer | Technology | Details |
| :--- | :--- | :--- |
| **Framework** | **Flutter 3.x** | Multi-platform compiled to native ARM machine code |
| **Language** | **Dart 3.x** | Sound null safety, asynchronous streams, async/await |
| **State Management** | **Provider 6.x** | Scoped reactive state management via `ChangeNotifier` |
| **Cloud Database** | **Google Cloud Firestore** | NoSQL document database with live WebSocket synchronization |
| **Authentication** | **Firebase Auth** | Industry-standard salted cryptographic credential vault |
| **Object Storage** | **Firebase Cloud Storage** | Scalable blob store for task photos and profile avatars |
| **Mapping & GPS** | **Google Maps SDK & Geolocator** | High-precision satellite GPS, Places Autocomplete, Polylines |
| **Typography & UI** | **Google Fonts (Poppins)** | Modern glassmorphism UI with Flutter Animate and Lottie |

---

## 📂 Repository Code Structure (`lib/`)

All application source code and business logic reside inside the **`lib/`** directory:

```
lib/
├── main.dart                        # Application entry point & Firebase initialization
├── firebase_options.dart            # Multi-platform Firebase configuration
├── app/
│   └── app.dart                     # MaterialApp configuration, dark theme & custom transitions
├── models/                          # Data blueprints & JSON serialization
│   ├── task_model.dart              # Task schema, statuses, and category enums
│   ├── user_model.dart              # User profile schema and rating metrics
│   ├── chat_room_model.dart         # Chat thread channel blueprint
│   ├── message_model.dart           # Single message timestamp payload
│   └── rating_model.dart            # Review score and feedback data
├── providers/                       # State controllers (The Brain)
│   ├── auth_provider.dart           # Session state, login, registration, logout
│   ├── task_provider.dart           # Task creation, bidding, acceptance, and active streams
│   ├── location_provider.dart       # Live device GPS tracking and coordinate streams
│   ├── chat_provider.dart           # Real-time message streaming and unread thread counts
│   └── notification_provider.dart   # Push alerts and system notification dispatch
├── screens/                         # User interface screens
│   ├── splash_screen.dart           # Animated splash & authentication routing
│   ├── auth/                        # Login & registration forms with validation
│   ├── home/                        # Map radar, search bar, active task details
│   ├── tasks/                       # Task creation flow & "My Tasks" management
│   ├── chat/                        # Direct messaging screen & chat inbox
│   └── profile/                     # User statistics, ratings, and account settings
├── services/                        # Backend and external API communication
│   ├── firestore_service.dart       # All Cloud Firestore CRUD operations and live streams
│   ├── auth_service.dart            # Firebase Authentication communication
│   ├── storage_service.dart         # Image compression and upload to Firebase Storage
│   ├── pricing_service.dart         # Dynamic pricing algorithm and budget range formula
│   ├── directions_service.dart      # Haversine distance, travel ETA, and route polylines
│   └── places_service.dart          # Google Places Autocomplete API integration
└── widgets/                         # Reusable UI components
    ├── common/                      # GlassCard, GradientButton, ShimmerLoader
    ├── map/                         # CustomMarkerPainter for colored category pins
    └── task/                        # TaskCard and RatingDialog
```

---

## 🧮 The Dynamic Pricing Formula

Located in [`lib/services/pricing_service.dart`](lib/services/pricing_service.dart):

$$\text{Suggested Reward} = \Big(\text{Base Fare} + (\text{Distance In Km} \times \text{Rate Per Km}) + (\text{Estimated Minutes} \times \text{Duration Rate})\Big) \times \text{Complexity Multiplier}$$

* **Category Base Rates:**
  * **Delivery:** Base ₹30 + ₹12/km
  * **Grocery Pickup:** Base ₹70 + ₹12/km
  * **Line Standing:** Base ₹30 + ₹2.5/min
  * **Physical Labor:** Base ₹100 + ₹10/km ($\times 1.4\text{x}$ complexity multiplier)
  * **Tech Help:** Base ₹150 + ₹5/km
* **Urgency Surge:** $+25\%$ surge factor ($\times 1.25$) applied when marked urgent.
* **Negotiable Range:** Sets **$-10\%$ (Min)** to **$+30\%$ (Max)** budget range for counter-bidding flexibility.

---

## 🚀 Getting Started & Local Setup

### Prerequisites
* [Flutter SDK](https://flutter.dev/docs/get-started/install) (version `>= 3.0.0`)
* [Android Studio](https://developer.android.com/studio) or [VS Code](https://code.visualstudio.com/) with Flutter extension
* Android Device / Emulator running API Level 26+

### 1. Clone the Repository
```bash
git clone https://github.com/DhruvMatliwala/TaskMate.git
cd TaskMate
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Setup Firebase & Google Maps Keys
* Add your `google-services.json` to `android/app/`
* Insert your Google Maps API Key in `android/app/src/main/AndroidManifest.xml`:
  ```xml
  <meta-data
      android:name="com.google.android.geo.API_KEY"
      android:value="YOUR_MAPS_API_KEY_HERE" />
  ```

### 4. Run the Application
```bash
flutter run
```

### 5. Build Standalone Release APK
```bash
flutter build apk --release
```
*The optimized release APK will be generated at:* `build/app/outputs/flutter-apk/app-release.apk`

---

## 👥 Contributors (Group 08)

This project was developed by the following students of the **Computer Engineering Department**, **C. K. Pithawala College of Engineering & Technology (CKPCET)**:

| No. | Student Name | Enrollment Number |
| :---: | :--- | :---: |\n| **1.** | **Matliwala Dhruvkumar Yogeshkumar** | `220090107076` |
| **2.** | **Afinwala Hitesh Piyushbhai** | `230090107002` |
| **3.** | **Kukadiya Divyesh Hareshbhai** | `230090107070` |
| **4.** | **Parekh Khantkumar Nirbhaykumar** | `230090107112` |

* **Faculty Guide & Subject Coordinator:** Prof. Hemil Patel
* **Head of Department:** Dr. Saurabh Tandel
* **Course:** Mobile Application Development (3170726) | B.E. IV, Semester VII

---

## 📄 License
This project is developed for academic evaluation purposes under the Gujarat Technological University (GTU) curriculum.
