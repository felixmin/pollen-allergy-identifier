# Allergy Identifier

A Flutter mobile application that helps users identify which pollen types are most likely causing their allergy symptoms by correlating daily feedback with local pollen data.

## Overview

Allergy Identifier collects data through daily user feedback about how they're feeling, cross-references this with real-time pollen data from the Google Pollen API based on the user's location, and performs correlation analysis to determine which specific pollen types most strongly affect the user.

### Key Features

- **Daily Check-ins**: Receive push notifications prompting for symptom feedback
- **Automatic Pollen Data Collection**: GPS-based retrieval of local pollen exposure levels
- **Personalized Analysis**: Statistical correlation of symptoms with specific pollen types
- **Secure Cloud Backend**: Firebase-powered data storage and processing

## Technical Architecture

### Frontend (Flutter App)

- **Framework**: Flutter with Provider for state management
- **Authentication**: Firebase Authentication (Google, Apple, Email/Password)
- **Notifications**: Firebase Cloud Messaging (FCM)
- **Environment Management**: Flutter flavors with separate configurations for development and production

### Backend (Firebase)

- **Cloud Functions**: TypeScript-based API endpoints for data processing and analysis
- **Database**: Firestore collections for users, feedback, and analysis results
- **Security**: JWT-based authentication with Firebase ID tokens

## Getting Started

### Prerequisites

- Flutter SDK (latest stable version)
- Firebase CLI
- Node.js and npm (for Firebase Functions development)
- Google Cloud Platform account with billing enabled

### Development Setup

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/flutter_allergy_identifier.git
   cd flutter_allergy_identifier
   ```

2. Install Flutter dependencies:
   ```
   flutter pub get
   ```

3. Configure Firebase:
   ```
   firebase login
   flutterfire configure
   ```

4. Create Flutter flavors for development and production environments:
   - Add appropriate entries in `android/app/build.gradle` and `ios/Runner.xcodeproj`
   - Create `lib/main_dev.dart` and `lib/main_prod.dart`

5. Deploy Firebase Functions:
   ```
   cd functions
   npm install
   npm run deploy
   ```

### Running the App

For development:
```
flutter run --flavor dev -t lib/main_dev.dart
```

For production:
```
flutter run --flavor prod -t lib/main_prod.dart
```

## Database Schema

### Users Collection
- uid: String
- email: String
- notificationTime: String (e.g., "15:00")
- timezone: String
- createdAt: Timestamp

### Feedback Collection
- userId: String
- timestamp: Timestamp
- feedback: Number/String
- location: {lat: Number, lng: Number}
- pollenData: Array of {pollenType: String, exposureLevel: Number}

### Results Collection
- userId: String
- analyzedAt: Timestamp
- correlations: Object mapping pollen types to correlation data
- likelyAllergy: String

## API Endpoints

- **POST /api/feedback**: Submit user feedback with location and pollen data
- **GET /api/analysis**: Retrieve pollen correlation analysis for the user

## Deployment

The application uses Fastlane for automated deployment:

- iOS: TestFlight for testing, App Store for production
- Android: Google Play internal testing and production

## Project Structure

This repository contains both the Flutter mobile application and the Firebase backend in a single, integrated codebase:

- The root directory contains the Flutter application code with UI components, state management, and service integrations
- The `functions` directory houses the Firebase Cloud Functions code written in TypeScript, which powers the backend API endpoints and data processing
- Both parts of the application are configured to work seamlessly together, sharing type definitions and API contracts

## License

[Specify your license here]

## Acknowledgments

- Google Pollen API for providing real-time pollen data
- Firebase platform for backend services
