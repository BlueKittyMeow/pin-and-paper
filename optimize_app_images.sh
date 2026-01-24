#!/bin/bash
set -e

# App Quiz/Onboarding Image Optimization
# These images are displayed larger, so we use a higher target resolution

QUIZ_DIR="pin_and_paper/assets/images/quiz"
ONBOARDING_DIR="pin_and_paper/assets/images/onboarding"
BACKUP_DIR="pin_and_paper/assets/images_backup_$(date +%Y%m%d_%H%M%S)"

# Target width (these are displayed larger than badges)
TARGET_WIDTH=1200

echo "=========================================="
echo "Quiz & Onboarding Image Optimization"
echo "=========================================="
echo ""

if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick not found"
    exit 1
fi

# Backup
mkdir -p "$BACKUP_DIR"
[ -d "$QUIZ_DIR" ] && cp -r "$QUIZ_DIR" "$BACKUP_DIR/quiz"
[ -d "$ONBOARDING_DIR" ] && cp -r "$ONBOARDING_DIR" "$BACKUP_DIR/onboarding"
echo "✓ Backup created at: $BACKUP_DIR"
echo ""

# Process function
process_dir() {
    local dir=$1
    local name=$2

    if [ ! -d "$dir" ]; then
        echo "Skipping $name (not found)"
        return
    fi

    echo "Processing $name images..."
    local count=0
    local saved_bytes=0

    for img in "$dir"/*.png; do
        [ -f "$img" ] || continue

        local original_size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
        local current_width=$(identify -format "%w" "$img")

        if [ "$current_width" -gt "$TARGET_WIDTH" ]; then
            convert "$img" -resize "${TARGET_WIDTH}x" -strip -quality 90 "$img.tmp"
            mv "$img.tmp" "$img"

            local new_size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
            local saved=$((original_size - new_size))
            saved_bytes=$((saved_bytes + saved))
            count=$((count + 1))
        fi
    done

    local saved_mb=$(echo "scale=2; $saved_bytes / 1024 / 1024" | bc)
    echo "  ✓ $name: $count images optimized, saved ${saved_mb}MB"
}

process_dir "$QUIZ_DIR" "Quiz"
process_dir "$ONBOARDING_DIR" "Onboarding"

echo ""
echo "✓ Optimization complete!"
echo "Backup: $BACKUP_DIR"
echo "=========================================="
