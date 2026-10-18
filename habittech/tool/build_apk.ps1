# Builds HabitTech as an installable Android APK on Windows (PowerShell).
#
# Requirements: Flutter (stable) with the Android SDK set up. Check with
#   flutter doctor
#
# Usage (from the project root):   powershell -ExecutionPolicy Bypass -File tool\build_apk.ps1
# Output:                          dist\HabitTech.apk
$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if (-not (Get-Command flutter -ErrorAction SilentlyContinue)) {
  Write-Error "Flutter was not found on your PATH. Install it from https://docs.flutter.dev/get-started/install"
}

if (-not (Test-Path "android")) {
  Write-Host "==> Generating the Android project"
  flutter create --platforms=android --org com.habittech --project-name habittech --description "HabitTech" .
  if ($LASTEXITCODE -ne 0) { throw "flutter create failed" }
  Remove-Item -Force -ErrorAction SilentlyContinue "test\widget_test.dart"
}

$manifest = "android\app\src\main\AndroidManifest.xml"
if (Test-Path $manifest) {
  (Get-Content $manifest) -replace 'android:label="[^"]*"', 'android:label="HabitTech"' | Set-Content $manifest
}

Write-Host "==> Fetching packages"
flutter pub get
if ($LASTEXITCODE -ne 0) { throw "flutter pub get failed" }

Write-Host "==> Running tests"
flutter test
if ($LASTEXITCODE -ne 0) { throw "tests failed" }

Write-Host "==> Building the release APK"
flutter build apk --release
if ($LASTEXITCODE -ne 0) { throw "flutter build apk failed" }

New-Item -ItemType Directory -Force -Path dist | Out-Null
Copy-Item "build\app\outputs\flutter-apk\app-release.apk" "dist\HabitTech.apk" -Force
Write-Host ""
Write-Host "Done: dist\HabitTech.apk"
Write-Host "Copy it to your phone and open it. Android will ask you to allow installs from this source."
