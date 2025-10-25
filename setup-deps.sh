#!/bin/bash
# Pin and Paper - Development Dependencies Setup
# Run with: sudo ./setup-deps.sh

set -e

echo "📦 Installing Flutter Linux desktop dependencies..."
apt-get update
apt-get install -y \
    clang \
    cmake \
    ninja-build \
    pkg-config \
    libgtk-3-dev

echo "📱 Installing Android development tools..."
apt-get install -y \
    openjdk-17-jdk \
    android-tools-adb \
    android-tools-fastboot

echo ""
echo "✅ All dependencies installed!"
echo ""
echo "Next steps:"
echo "1. Check if phone is connected: flutter devices"
echo "2. Run on phone: flutter run"
echo "3. Run on Linux desktop: flutter run -d linux"
