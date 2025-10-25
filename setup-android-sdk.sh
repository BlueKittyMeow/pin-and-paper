#!/bin/bash
# Pin and Paper - Android SDK Setup
# Run with: sudo ./setup-android-sdk.sh

set -e

echo "📱 Installing Android SDK cmdline-tools..."

# Install additional Android SDK components
apt-get install -y \
    google-android-cmdline-tools-12.0-installer

# Accept licenses
yes | /usr/lib/android-sdk/cmdline-tools/12.0/bin/sdkmanager --licenses || true

echo ""
echo "✅ Android SDK setup complete!"
echo ""
echo "Next: Try running the app again with: flutter run"
