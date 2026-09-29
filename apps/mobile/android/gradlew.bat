@echo off
setlocal EnableExtensions

set "GRADLE_VERSION=9.3.1"
set "GRADLE_SHA256=b266d5ff6b90eada6dc3b20cb090e3731302e553a27c5d3e4df1f0d76beaff06"
if defined GRADLE_USER_HOME (
  set "GRADLE_CACHE=%GRADLE_USER_HOME%\savestream-wrapper"
) else (
  set "GRADLE_CACHE=%USERPROFILE%\.gradle\savestream-wrapper"
)
set "GRADLE_HOME=%GRADLE_CACHE%\gradle-%GRADLE_VERSION%"
set "ARCHIVE=%GRADLE_CACHE%\gradle-%GRADLE_VERSION%-bin.zip"
set "URL=https://services.gradle.org/distributions/gradle-%GRADLE_VERSION%-bin.zip"

if not exist "%GRADLE_HOME%\bin\gradle.bat" (
  if not exist "%GRADLE_CACHE%" mkdir "%GRADLE_CACHE%"

  if not exist "%ARCHIVE%" (
    powershell -NoProfile -ExecutionPolicy Bypass -Command ^
      "$ProgressPreference='SilentlyContinue'; Invoke-WebRequest -UseBasicParsing -Uri '%URL%' -OutFile '%ARCHIVE%'"
    if errorlevel 1 exit /b 1
  )

  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "$actual=(Get-FileHash -Algorithm SHA256 '%ARCHIVE%').Hash.ToLower(); if ($actual -ne '%GRADLE_SHA256%') { Write-Error 'SaveStream: Gradle distribution checksum mismatch.'; exit 1 }"
  if errorlevel 1 (
    del /q "%ARCHIVE%" >nul 2>nul
    exit /b 1
  )

  set "TMP_DIR=%GRADLE_CACHE%\.extract-%GRADLE_VERSION%-%RANDOM%"
  powershell -NoProfile -ExecutionPolicy Bypass -Command ^
    "New-Item -ItemType Directory -Force -Path '%TMP_DIR%' | Out-Null; Expand-Archive -Force -Path '%ARCHIVE%' -DestinationPath '%TMP_DIR%'; if (Test-Path '%GRADLE_HOME%') { Remove-Item -Recurse -Force '%GRADLE_HOME%' }; Move-Item '%TMP_DIR%\gradle-%GRADLE_VERSION%' '%GRADLE_HOME%'; Remove-Item -Recurse -Force '%TMP_DIR%'"
  if errorlevel 1 exit /b 1
)

call "%GRADLE_HOME%\bin\gradle.bat" -p "%~dp0" %*
exit /b %ERRORLEVEL%
