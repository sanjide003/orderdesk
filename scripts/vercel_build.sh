#!/usr/bin/env bash
set -euo pipefail

FLUTTER_DIR="/tmp/flutter-sdk"
if [ ! -d "$FLUTTER_DIR" ]; then
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 "$FLUTTER_DIR"
fi
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter config --enable-web --no-analytics
flutter pub get

VER_LINE=$(grep '^version:' pubspec.yaml | awk '{print $2}')
VER_NAME=$(echo "$VER_LINE" | cut -d'+' -f1)
WEB_BUILD_NUM=$(date -u +"%y%m%d%H%M")
NOW_UTC=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

REPO_SLUG="${GITHUB_REPO:-}"
if [ -z "$REPO_SLUG" ] && [ -n "${VERCEL_GIT_REPO_OWNER:-}" ] && [ -n "${VERCEL_GIT_REPO_SLUG:-}" ]; then
  REPO_SLUG="${VERCEL_GIT_REPO_OWNER}/${VERCEL_GIT_REPO_SLUG}"
fi

APK_URL=""
if [ -n "$REPO_SLUG" ]; then
  APK_URL="https://github.com/${REPO_SLUG}/releases/latest/download/orderdesk-latest.apk"
fi

flutter build web --release \
  --dart-define=WEB_BUILD_NUMBER="$WEB_BUILD_NUM" \
  --dart-define=GITHUB_REPO="$REPO_SLUG"

cat << AJSON > build/web/app_version.json
{
  "version": "$VER_NAME",
  "buildNumber": $WEB_BUILD_NUM,
  "apkUrl": "$APK_URL",
  "updatedAt": "$NOW_UTC"
}
AJSON

if [ -n "$APK_URL" ]; then
  cat << VJSON > build/web/version.json
{
  "version": "$VER_NAME",
  "buildNumber": $WEB_BUILD_NUM,
  "apkUrl": "$APK_URL",
  "updatedAt": "$NOW_UTC"
}
VJSON
fi
