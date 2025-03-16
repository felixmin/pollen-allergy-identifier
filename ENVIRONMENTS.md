# Environment Switching for Allergy Identifier

This project supports multiple environments (development and production) to allow easy switching between different Firebase projects.

## Available Environments

- **Development (`dev`)**: Points to the `allergy-ident-dev` Firebase project
- **Production (`prod`)**: Points to the `allergy-ident-prod` Firebase project

## How to Switch Environments

### Using npm scripts

The easiest way to switch environments is using the provided npm scripts:

```bash
# Switch to development environment
npm run switch:dev

# Switch to production environment
npm run switch:prod
```

### Manual switching

You can also manually switch environments by running the script directly:

```bash
./scripts/switch_env.sh dev
# or
./scripts/switch_env.sh prod
```

## Running the App

After switching environments, you can run the app with the appropriate flavor:

```bash
# Run development environment
npm run dev
# or
flutter run --flavor dev -t lib/main_dev.dart

# Run production environment
npm run prod
# or
flutter run --flavor prod -t lib/main_prod.dart
```

### Running in Chrome (Web)

For web development, use the chrome scripts which will handle environment switching automatically:

```bash
# Run in Chrome with development environment
npm run chrome:dev

# Run in Chrome with production environment
npm run chrome:prod
```

## Building the App

To build the app for a specific environment:

### Android

```bash
# Build for development
npm run build:apk:dev
# or
flutter build apk --release --flavor dev -t lib/main_dev.dart

# Build for production
npm run build:apk:prod
# or
flutter build apk --release --flavor prod -t lib/main_prod.dart
```

### iOS

```bash
# Build for development
npm run build:ios:dev
# or
flutter build ios --release --flavor dev -t lib/main_dev.dart

# Build for production
npm run build:ios:prod
# or
flutter build ios --release --flavor prod -t lib/main_prod.dart
```

### Web

```bash
# Build for development
npm run build:web:dev
# or
flutter build web --release -t lib/main_dev.dart

# Build for production
npm run build:web:prod
# or
flutter build web --release -t lib/main_prod.dart
```

## CI/CD Integration

For CI/CD pipelines, you can use the environment switching script before building:

```yaml
# Example GitHub Actions workflow
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      # Set up Flutter
      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.7.0'
      
      # Switch to production environment
      - name: Switch to production environment
        run: ./scripts/switch_env.sh prod
      
      # Build the app
      - name: Build Android app
        run: flutter build apk --flavor prod -t lib/main_prod.dart
```

## How It Works

The environment switching system works by:

1. Maintaining separate Firebase configuration files for each environment in the `environments/` directory
2. Using Flutter flavors to configure the app for different environments
3. Using separate entry points (`main_dev.dart` and `main_prod.dart`) to set the environment before app initialization
4. Copying the appropriate configuration files when switching environments
5. Updating the `lib/firebase_options.dart` file with environment-specific options from either `lib/firebase_options_dev.dart` or `lib/firebase_options_prod.dart`
6. Updating the `firebase.json` configuration file to point to the correct Firebase project

### What the Environment Switching Script Does

When you switch environments using `./scripts/switch_env.sh [dev|prod]`, the script:

1. Copies the environment-specific Google Services JSON file to `android/app/google-services.json`
2. Copies the environment-specific GoogleService-Info.plist file to `ios/Runner/GoogleService-Info.plist` 
3. Copies the content of `lib/firebase_options_[dev|prod].dart` to `lib/firebase_options.dart` (ensuring the class name remains `DefaultFirebaseOptions`)
4. Copies the environment-specific `firebase.json` file to the root directory

This ensures that all platforms (Android, iOS, and web) use the correct Firebase configuration for the selected environment.

## File Structure

- `lib/config/environment.dart`: Central configuration class for environment management
- `lib/firebase_options.dart`: Current active Firebase options (copied from the environment-specific file)
- `lib/firebase_options_dev.dart`: Firebase options for development
- `lib/firebase_options_prod.dart`: Firebase options for production
- `lib/main_dev.dart`: Entry point for development
- `lib/main_prod.dart`: Entry point for production
- `environments/dev/`: Development environment configuration files
  - `google-services.json`: Android Firebase configuration for development
  - `GoogleService-Info.plist`: iOS Firebase configuration for development
  - `firebase.json`: Firebase project configuration for development
- `environments/prod/`: Production environment configuration files
  - `google-services.json`: Android Firebase configuration for production
  - `GoogleService-Info.plist`: iOS Firebase configuration for production
  - `firebase.json`: Firebase project configuration for production
- `scripts/switch_env.sh`: Script to switch between environments 