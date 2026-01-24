#!/bin/bash
set -e

# Documentation Image Optimization Script
# Optimizes large PNG images in docs/ directory

DOCS_DIR="docs/images"
BACKUP_DIR="docs/images_backup_$(date +%Y%m%d_%H%M%S)"

# Target width for documentation images (reasonable for docs)
TARGET_WIDTH=800

echo "=========================================="
echo "Documentation Image Optimization"
echo "=========================================="
echo ""

# Check ImageMagick
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick not found"
    exit 1
fi

# Create backup
echo "Creating backup at: $BACKUP_DIR"
cp -r "$DOCS_DIR" "$BACKUP_DIR"
echo "✓ Backup created"
echo ""

# Find and optimize all PNGs
echo "Optimizing PNG images..."
count=0
saved_bytes=0

while IFS= read -r -d '' img; do
    original_size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
    current_width=$(identify -format "%w" "$img")

    # Only resize if image is larger than target
    if [ "$current_width" -gt "$TARGET_WIDTH" ]; then
        convert "$img" -resize "${TARGET_WIDTH}x" -strip -quality 90 "$img.tmp"
        mv "$img.tmp" "$img"

        new_size=$(stat -c%s "$img" 2>/dev/null || stat -f%z "$img")
        saved=$((original_size - new_size))
        saved_bytes=$((saved_bytes + saved))
        count=$((count + 1))

        if [ $((count % 10)) -eq 0 ]; then
            echo "  Processed $count images..."
        fi
    fi
done < <(find "$DOCS_DIR" -name "*.png" -type f -print0)

saved_mb=$(echo "scale=2; $saved_bytes / 1024 / 1024" | bc)
echo "  ✓ Optimized $count images, saved ${saved_mb}MB"
echo ""

# Calculate total
original_size=$(du -sm "$BACKUP_DIR" | cut -f1)
new_size=$(du -sm "$DOCS_DIR" | cut -f1)
saved=$((original_size - new_size))
percent=$((saved * 100 / original_size))

echo "RESULTS:"
echo "  Original size: ${original_size}MB"
echo "  New size: ${new_size}MB"
echo "  Saved: ${saved}MB (${percent}% reduction)"
echo ""
echo "Backup: $BACKUP_DIR"
echo "✓ Complete!"
echo "=========================================="
