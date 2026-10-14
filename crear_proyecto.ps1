# Crea el proyecto Flutter "rovant" con este código y compila el APK (Windows).
# Uso: clic derecho > Ejecutar con PowerShell, o:  powershell -ExecutionPolicy Bypass -File crear_proyecto.ps1
$ErrorActionPreference = "Stop"
$aqui = Split-Path -Parent $MyInvocation.MyCommand.Path
$dest = Join-Path (Split-Path -Parent $aqui) "rovant_app"

flutter create --org com.rovant --project-name rovant --platforms android,ios $dest
Remove-Item -Recurse -Force (Join-Path $dest "lib"), (Join-Path $dest "test")
Copy-Item -Recurse (Join-Path $aqui "lib"), (Join-Path $aqui "assets") $dest
Copy-Item (Join-Path $aqui "pubspec.yaml") $dest -Force
Copy-Item (Join-Path $aqui "android_config\AndroidManifest.xml") (Join-Path $dest "android\app\src\main\AndroidManifest.xml") -Force

$gradle = Join-Path $dest "android\app\build.gradle.kts"
if (-not (Test-Path $gradle)) { $gradle = Join-Path $dest "android\app\build.gradle" }
(Get-Content $gradle) -replace 'minSdk = flutter\.minSdkVersion','minSdk = 23' -replace 'minSdkVersion flutter\.minSdkVersion','minSdkVersion 23' | Set-Content $gradle

Set-Location $dest
flutter pub get
dart run flutter_launcher_icons
flutter build apk --release
Write-Host "`nListo: $dest\build\app\outputs\flutter-apk\app-release.apk"
