# Runs the app on the Android emulator (or a USB phone) from a terminal.
#
#   .\run_android.ps1                 first connected Android device
#   .\run_android.ps1 emulator-5554   a specific device
#
# adb reverse lets the device reach the backend on this PC at 127.0.0.1:8000.
# Start the backend first: php artisan serve --port=8000 (in backend/).

param([string]$Device)

$adb = "$env:LOCALAPPDATA\Android\Sdk\platform-tools\adb.exe"
if ($Device) {
    & $adb -s $Device reverse tcp:8000 tcp:8000
} else {
    & $adb reverse tcp:8000 tcp:8000
}
if ($LASTEXITCODE -ne 0) {
    Write-Host "No Android device found. Start the emulator first (Flutter: Launch Emulator)." -ForegroundColor Red
    exit 1
}

if ($Device) { flutter run -d $Device } else { flutter run }
