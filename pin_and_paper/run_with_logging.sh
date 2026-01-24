#!/bin/bash

# Phase 3.7 Test Script
# Runs the app with date parsing logging enabled

cd "$(dirname "$0")"

echo "=== Phase 3.7: Natural Language Date Parsing Test ==="
echo ""
echo "Looking for initialization message..."
echo ""

# Run the release build with output
exec ./build/linux/x64/release/bundle/pin_and_paper 2>&1 | grep --line-buffered -E "DateParsing|chrono|initialized|Phase 3.7|ERROR" || ./build/linux/x64/release/bundle/pin_and_paper
