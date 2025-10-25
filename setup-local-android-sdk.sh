#!/bin/bash
# Pin and Paper - Setup Local Android SDK
# This creates a local Android SDK to avoid permission issues
# Run WITHOUT sudo: ./setup-local-android-sdk.sh

set -e

echo "📱 Setting up local Android SDK in ~/Android/Sdk..."

# Create Android SDK directory
mkdir -p ~/Android/Sdk/cmdline-tools

# Download Android command line tools
cd ~/Android/Sdk/cmdline-tools
wget -q https://dl.google.com/android/repository/commandlinetools-linux-11076708_latest.zip
unzip -q commandlinetools-linux-11076708_latest.zip
mv cmdline-tools latest
rm commandlinetools-linux-11076708_latest.zip

# Set up Flutter to use local SDK
$HOME/flutter/bin/flutter config --android-sdk ~/Android/Sdk

# Accept licenses and install required components
yes | ~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager --licenses
~/Android/Sdk/cmdline-tools/latest/bin/sdkmanager "platform-tools" "platforms;android-35" "build-tools;35.0.0" "ndk;27.0.12077973"

echo ""
echo "✅ Local Android SDK setup complete!"
echo ""
echo "SDK location: ~/Android/Sdk"
echo ""
echo "Next: Run flutter run to deploy to your phone!"
