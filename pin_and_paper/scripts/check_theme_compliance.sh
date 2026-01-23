#!/bin/bash
# Checks for hardcoded color usage violations
# Run from pin_and_paper/ directory: bash scripts/check_theme_compliance.sh

set -e

echo "🎨 Checking theme compliance..."
echo ""

# Colors that should be avoided (common Material colors)
VIOLATIONS=0

# Check for Colors.* usage in screens (excluding theme.dart itself)
# Note: Widgets still have violations - Phase 3.9.0 cleaned screens only
echo "Checking for Colors.* usage in screens..."
if grep -rn "Colors\." lib/screens/ 2>/dev/null | \
   grep -v "Colors.white" | \
   grep -v "Colors.transparent" | \
   grep -v "Colors.black" | \
   grep -v "TagColors"; then
  echo "❌ Found hardcoded Colors.* usage in screens above"
  echo "   Use AppTheme.success, AppTheme.danger, etc. instead"
  VIOLATIONS=$((VIOLATIONS + 1))
else
  echo "✅ No Colors.* violations in screens"
fi

echo ""

# Check for Color(0x...) literals in screens
echo "Checking for Color(0x...) literals in screens..."
if grep -rn "Color(0x" lib/screens/ 2>/dev/null; then
  echo "❌ Found hardcoded Color(0x...) literals in screens above"
  echo "   Use AppTheme palette colors instead"
  VIOLATIONS=$((VIOLATIONS + 1))
else
  echo "✅ No Color(0x...) violations in screens"
fi

echo ""

if [ $VIOLATIONS -eq 0 ]; then
  echo "✅ Theme compliance check passed!"
  exit 0
else
  echo "❌ Theme compliance check failed with $VIOLATIONS violation(s)"
  echo ""
  echo "See lib/utils/theme.dart for color usage policy"
  exit 1
fi
