#!/usr/bin/env bash
set -euo pipefail
echo "Regenerando carpeta android (embedding v2) y fijando NDK 27..."
flutter --version
rm -rf android
flutter create --platforms=android .
# build.gradle(.kts)
sed -i '0,/android \{/s//android {\n    ndkVersion = "27.0.12077973"/' android/app/build.gradle.kts 2>/dev/null || true
sed -i "0,/android \{/s//android {\n    ndkVersion '27.0.12077973'/" android/app/build.gradle 2>/dev/null || true
# gradle.properties
echo "android.ndkVersion=27.0.12077973" >> android/gradle.properties
# local.properties
echo "ndk.dir=$ANDROID_SDK_ROOT/ndk/27.0.12077973" >> android/local.properties
echo "Listo."
