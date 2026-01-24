#!/bin/bash
set -e

# Badge Image Optimization Script
# Resizes oversized badge images to proper Flutter densities and optimizes them
# Original images are 2816x1536 across all densities (wrong!)
# Target: Properly sized images for each density

BADGE_DIR="pin_and_paper/assets/images/badges"
BACKUP_DIR="pin_and_paper/assets/images/badges_backup_$(date +%Y%m%d_%H%M%S)"

# Badge target dimensions (maintaining aspect ratio ~1.83:1)
# Based on typical display size of ~120x65 logical pixels
TARGET_1X_WIDTH=400
TARGET_2X_WIDTH=800
TARGET_3X_WIDTH=1200

echo "=========================================="
echo "Badge Image Optimization Script"
echo "=========================================="
echo ""

# Check if ImageMagick is installed
if ! command -v convert &> /dev/null; then
    echo "Error: ImageMagick not found. Install with:"
    echo "  sudo apt install imagemagick"
    exit 1
fi

# Check for optional pngquant (for better compression)
HAS_PNGQUANT=false
if command -v pngquant &> /dev/null; then
    HAS_PNGQUANT=true
    echo "✓ pngquant found - will use for additional optimization"
else
    echo "Note: pngquant not found - using ImageMagick only (still effective)"
fi
echo ""

# Create backup
echo "Creating backup at: $BACKUP_DIR"
cp -r "$BADGE_DIR" "$BACKUP_DIR"
echo "✓ Backup created"
echo ""

# Function to optimize a single density directory
optimize_density() {
    local density=$1
    local target_width=$2
    local dir="$BADGE_DIR/${density}"

    if [ ! -d "$dir" ]; then
        echo "Warning: Directory $dir not found, skipping"
        return
    fi

    echo "Processing ${density} badges (target width: ${target_width}px)..."

    local count=0
    local saved_bytes=0

    for img in "$dir"/*.png; do
        if [ ! -f "$img" ]; then
            continue
        fi

        local filename=$(basename "$img")
        local original_size=$(stat -f%z "$img" 2>/dev/null || stat -c%s "$img")

        # Get current dimensions
        local current_dims=$(identify -format "%wx%h" "$img")

        # Resize and optimize (maintaining aspect ratio)
        # ImageMagick quality settings: strip metadata, optimize PNG
        convert "$img" -resize "${target_width}x" -strip -quality 95 "$img.tmp"

        # Additional optimization with pngquant if available
        if [ "$HAS_PNGQUANT" = true ]; then
            pngquant --ext .png --force --quality=85-95 "$img.tmp" 2>/dev/null || true
        fi

        # Replace original
        mv "$img.tmp" "$img"

        local new_size=$(stat -f%z "$img" 2>/dev/null || stat -c%s "$img")
        local new_dims=$(identify -format "%wx%h" "$img")
        local saved=$((original_size - new_size))
        saved_bytes=$((saved_bytes + saved))

        count=$((count + 1))

        # Show progress every 5 images
        if [ $((count % 5)) -eq 0 ]; then
            echo "  Processed $count badges... (${current_dims} → ${new_dims})"
        fi
    done

    local saved_mb=$(echo "scale=2; $saved_bytes / 1024 / 1024" | bc)
    echo "  ✓ ${density}: $count badges optimized, saved ${saved_mb}MB"
    echo ""
}

# Optimize each density
optimize_density "1x" "$TARGET_1X_WIDTH"
optimize_density "2x" "$TARGET_2X_WIDTH"
optimize_density "3x" "$TARGET_3X_WIDTH"

# Calculate total savings
echo "=========================================="
echo "Calculating total size reduction..."
original_size=$(du -sm "$BACKUP_DIR" | cut -f1)
new_size=$(du -sm "$BADGE_DIR" | cut -f1)
saved=$((original_size - new_size))
percent=$((saved * 100 / original_size))

echo ""
echo "RESULTS:"
echo "  Original size: ${original_size}MB"
echo "  New size: ${new_size}MB"
echo "  Saved: ${saved}MB (${percent}% reduction)"
echo ""
echo "Backup location: $BACKUP_DIR"
echo "To restore: mv $BACKUP_DIR/* $BADGE_DIR/"
echo ""
echo "✓ Optimization complete!"
echo "=========================================="
