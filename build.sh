#!/bin/bash

echo "Building Flutter web app for production..."

# Clean previous builds
flutter clean

# Get dependencies
flutter pub get

# Build for web
flutter build web --release --base-href /

echo "Build completed! Files are in build/web/"
echo "To test locally, you can serve the build/web directory with a local server"
