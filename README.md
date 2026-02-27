# One Minute Digital Diary

<div align="center">

<img src="readmephotos/logo.png" width="200" alt="OneMinute Logo"/>

Capture your life, one minute at a time.

*A beautiful mobile app that lets you record a one-minute video diary entry every day. Look back at your memories, share moments with the community, and build your personal video journal.*

</div>


## Features

### Daily Video Recording
Record a one-minute video every day to capture your thoughts, experiences, and memories. The app automatically saves entries with timestamps so you can easily revisit any day.

### Personal Video Gallery
Browse through your video diary entries organized by date. Use the calendar view to jump to any specific day and relive your past moments.

### Public Feed
Share your moments with the OneMinute community! Make your entries public and discover what others are sharing around the world.

### User Profiles
Create your personal profile, customize your account, and manage your video collection all in one place.

### Premium Features
Unlock premium features for an enhanced experience with monthly or yearly subscription options.

---

## Screenshots

<div align="center">

### Authentication
| Login | Register |
|:---:|:---:|
| <img src="readmephotos/loginpage.jpg" width="250"/> | <img src="readmephotos/registerpage.jpg" width="250"/> |

### Recording
| Camera View | Recording in Progress |
|:---:|:---:|
| <img src="readmephotos/recordingpage.jpg" width="250"/> | <img src="readmephotos/recordingpage2.jpg" width="250"/> |

### Video Gallery
| Gallery View | Calendar Selection |
|:---:|:---:|
| <img src="readmephotos/gallerypage.jpg" width="250"/> | <img src="readmephotos/gallerydate.jpg" width="250"/> |

### Community & Social
| Public Feed | Search |
|:---:|:---:|
| <img src="readmephotos/publicfeed.jpg" width="250"/> | <img src="readmephotos/searchpage.jpg" width="250"/> |

### Profile & Settings
| Profile | Settings |
|:---:|:---:|
| <img src="readmephotos/profilepage.jpg" width="250"/> | <img src="readmephotos/settingspage.jpg" width="250"/> |

### Premium
| Premium Plans | Subscription Details |
|:---:|:---:|
| <img src="readmephotos/premiumpage.jpg" width="250"/> | <img src="readmephotos/premiumpage2.jpg" width="250"/> |

### Upload & Edit
| Uploading | Edit |
|:---:|:---:|
| <img src="readmephotos/uploadingpage2.jpg" width="250"/> | <img src="readmephotos/downloadingpage.jpg" width="250"/> |

</div>

---

## Tech Stack

| Technology | Purpose |
|------------|---------|
| **Flutter** | Cross-platform mobile development |
| **Dart** | Programming language |
| **Firebase Auth** | User authentication |
| **Cloud Firestore** | Database for user data and metadata |
| **Firebase Storage** | Video file storage |
| **Firebase Messaging** | Push notifications |
| **In-App Purchase** | Premium subscription handling |

---

## Getting Started

### Prerequisites

- Flutter SDK (^3.9.2)
- Dart SDK
- Firebase project setup
- Android Studio / Xcode (for mobile development)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/dincerefe/1mdd.git
   cd 1mdd
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Configure Firebase**
   - Create a Firebase project
   - Add your `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Update `firebase_options.dart` with your configuration

4. **Set up environment variables**
   - Create a `.env` file in the root directory
   - Add required environment variables

5. **Run the app**
   ```bash
   flutter run
   ```

---

