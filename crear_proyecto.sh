#!/usr/bin/env bash
# Crea el proyecto Flutter "rovant" con este código y compila el APK.
# Uso: bash crear_proyecto.sh   (ejecutar dentro de esta carpeta)
set -e
AQUI="$(cd "$(dirname "$0")" && pwd)"
DEST="$AQUI/../rovant_app"

flutter create --org com.rovant --project-name rovant --platforms android,ios "$DEST"
rm -rf "$DEST/lib" "$DEST/test"
cp -r "$AQUI/lib" "$AQUI/assets" "$AQUI/pubspec.yaml" "$DEST/"
cp "$AQUI/android_config/AndroidManifest.xml" "$DEST/android/app/src/main/AndroidManifest.xml"

# minSdk 23 (lo piden la grabadora y la ubicación)
GRADLE="$DEST/android/app/build.gradle.kts"; [ -f "$GRADLE" ] || GRADLE="$DEST/android/app/build.gradle"
sed -i.bak -E 's/minSdk( =|) *flutter\.minSdkVersion/minSdk\1 23/; s/minSdkVersion flutter\.minSdkVersion/minSdkVersion 23/' "$GRADLE"

cd "$DEST"
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
echo ""
echo "Listo: $DEST/build/app/outputs/flutter-apk/app-release.apk"
