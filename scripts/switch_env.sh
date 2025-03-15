#!/bin/bash

# Script to switch between development and production environments
# Usage: ./scripts/switch_env.sh [dev|prod]

# Define colors for better output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if an environment is provided
if [ $# -ne 1 ]; then
  echo -e "${RED}Error: Please specify an environment (dev or prod)${NC}"
  echo "Usage: ./scripts/switch_env.sh [dev|prod]"
  exit 1
fi

ENV=$1

# Validate the environment
if [ "$ENV" != "dev" ] && [ "$ENV" != "prod" ]; then
  echo -e "${RED}Error: Invalid environment. Please use 'dev' or 'prod'${NC}"
  echo "Usage: ./scripts/switch_env.sh [dev|prod]"
  exit 1
fi

echo -e "${GREEN}🔄 Switching to ${ENV} environment...${NC}"

# Ensure environment directories exist
if [ ! -d "environments/$ENV" ]; then
  echo -e "${RED}Error: Environment directory 'environments/$ENV' does not exist${NC}"
  exit 1
fi

# Copy Google Services JSON for Android
if [ -f "environments/$ENV/google-services.json" ]; then
  echo -e "${GREEN}📄 Copying Google Services JSON for Android...${NC}"
  cp "environments/$ENV/google-services.json" "android/app/google-services.json"
else
  echo -e "${YELLOW}⚠️ Warning: google-services.json not found in environments/$ENV${NC}"
fi

# Copy GoogleService-Info.plist for iOS
if [ -f "environments/$ENV/GoogleService-Info.plist" ]; then
  echo -e "${GREEN}📄 Copying GoogleService-Info.plist for iOS...${NC}"
  cp "environments/$ENV/GoogleService-Info.plist" "ios/Runner/GoogleService-Info.plist"
else
  echo -e "${YELLOW}⚠️ Warning: GoogleService-Info.plist not found in environments/$ENV${NC}"
fi

# Update firebase_options.dart from the environment-specific file
if [ -f "lib/firebase_options_${ENV}.dart" ]; then
  echo -e "${GREEN}📄 Updating Firebase options...${NC}"
  # Create a backup of the original file (optional)
  cp "lib/firebase_options.dart" "lib/firebase_options.dart.bak"
  # Copy the environment-specific file to the main options file
  cp "lib/firebase_options_${ENV}.dart" "lib/firebase_options.dart"
  
  # Replace the class name based on environment
  if [ "$ENV" = "dev" ]; then
    sed -i '' 's/DefaultFirebaseOptionsDev/DefaultFirebaseOptions/g' "lib/firebase_options.dart"
  elif [ "$ENV" = "prod" ]; then
    sed -i '' 's/DefaultFirebaseOptionsProd/DefaultFirebaseOptions/g' "lib/firebase_options.dart"
  fi
else
  echo -e "${RED}Error: lib/firebase_options_${ENV}.dart not found${NC}"
  exit 1
fi

# Update firebase.json configuration
if [ -f "environments/$ENV/firebase.json" ]; then
  echo -e "${GREEN}📄 Updating firebase.json configuration...${NC}"
  cp "environments/$ENV/firebase.json" "firebase.json"
else
  echo -e "${YELLOW}⚠️ Warning: firebase.json not found in environments/$ENV${NC}"
fi

echo -e "${GREEN}✅ Successfully switched to $ENV environment${NC}"
echo ""
echo -e "To run the app with this configuration:"
echo -e "${GREEN}flutter run --flavor $ENV -t lib/main_${ENV}.dart${NC}"
echo ""