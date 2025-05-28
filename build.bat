@echo off
echo Building Flutter web app for production...

REM Clean previous builds
flutter clean

REM Get dependencies
flutter pub get

REM Build for web
flutter build web --release --base-href /

echo Build completed! Files are in build/web/
echo To test locally, you can serve the build/web directory with a local server
