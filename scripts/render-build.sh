#!/usr/bin/env bash
# Render build script for the FinTrack Flutter web app.
#
# Render's static-site build image has no Flutter SDK, so we fetch the pinned
# version into the build workspace and build from it. Pinned (not "stable") so a
# new upstream Flutter release can never silently break a deploy.
set -euo pipefail

FLUTTER_VERSION="${FLUTTER_VERSION:-3.24.0}"
FLUTTER_DIR="${PWD}/.flutter-sdk"

echo "==> FinTrack web build (Flutter ${FLUTTER_VERSION})"

if [ ! -x "${FLUTTER_DIR}/bin/flutter" ]; then
  echo "==> Downloading Flutter ${FLUTTER_VERSION}"
  mkdir -p "${FLUTTER_DIR}"
  curl -fsSL --retry 3 \
    "https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz" \
    -o /tmp/flutter.tar.xz
  # Archive contains a top-level flutter/ dir; strip it into FLUTTER_DIR.
  tar -xJf /tmp/flutter.tar.xz -C "${FLUTTER_DIR}" --strip-components=1
  rm -f /tmp/flutter.tar.xz
else
  echo "==> Reusing cached Flutter SDK"
fi

export PATH="${FLUTTER_DIR}/bin:${PATH}"

# Render's build container runs as a different user than the SDK's git checkout
# owner, which makes git refuse to operate on it.
git config --global --add safe.directory "${FLUTTER_DIR}" || true

flutter --version
flutter pub get

# NOTE: intentionally no --dart-define for API keys. Any value passed here is
# embedded in the public JavaScript bundle and readable by every visitor. The
# app degrades gracefully: AI + stock prices are disabled unless the user
# supplies their own key at runtime. Mutual-fund NAVs still work (keyless).
flutter build web --release

echo "==> Built build/web"
ls -la build/web/index.html
