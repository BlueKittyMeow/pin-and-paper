#!/bin/bash
# Install Java JDK for Android development
# Run with: sudo ./install-jdk.sh

set -e

echo "☕ Installing Java JDK..."

# Install JDK (not just JRE)
apt-get install -y openjdk-17-jdk

# Set JAVA_HOME
echo "export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64" >> ~/.bashrc

echo ""
echo "✅ Java JDK installed!"
echo "JAVA_HOME set to: /usr/lib/jvm/java-17-openjdk-amd64"
echo ""
echo "Next: Run flutter run to deploy to your phone!"
