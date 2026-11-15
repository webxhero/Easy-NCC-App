
#!/usr/bin/env bash

set -euo pipefail

echo "Starting Easy NCC Flutter Web Build..."

# Check Supabase configuration
if [ -z "${SUPABASE_URL:-}" ]; then
  echo "ERROR: SUPABASE_URL is missing!"
  exit 1
fi

if [ -z "${SUPABASE_PUBLISHABLE_KEY:-}" ]; then
  echo "ERROR: SUPABASE_PUBLISHABLE_KEY is missing!"
  exit 1
fi

# Install Flutter SDK
FLUTTER_DIR="$HOME/flutter"

if [ ! -x "$FLUTTER_DIR/bin/flutter" ]; then
  echo "Installing Flutter SDK..."

  git clone --depth 1 --branch stable \
    https://github.com/flutter/flutter.git \
    "$FLUTTER_DIR"
fi

# Configure Flutter
export PATH="$FLUTTER_DIR/bin:$PATH"

flutter --version

flutter config --enable-web

flutter precache --web

# Install project dependencies
echo "Installing Flutter dependencies..."

flutter pub get

# Build production website
echo "Building Easy NCC Website..."

flutter build web --release \
  --dart-define="SUPABASE_URL=$SUPABASE_URL" \
  --dart-define="SUPABASE_PUBLISHABLE_KEY=$SUPABASE_PUBLISHABLE_KEY"

echo "Easy NCC Web Build Completed Successfully!"
