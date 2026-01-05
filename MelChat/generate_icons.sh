#!/bin/bash

# 🎨 App Icon Generator for iOS
# Generates all required icon sizes from a single 1024x1024 image

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
BOLD='\033[1m'
NC='\033[0m'

echo -e "${BOLD}${BLUE}============================================${NC}"
echo -e "${BOLD}${BLUE}  MelChat App Icon Generator${NC}"
echo -e "${BOLD}${BLUE}============================================${NC}\n"

# Check input
if [ $# -eq 0 ]; then
    echo -e "${YELLOW}Usage: $0 <input_1024x1024.png>${NC}"
    echo -e "${YELLOW}Example: $0 melchat_icon_1024.png${NC}"
    exit 1
fi

INPUT="$1"

# Check if input exists
if [ ! -f "$INPUT" ]; then
    echo -e "${YELLOW}❌ Error: File '$INPUT' not found!${NC}"
    exit 1
fi

# Check if sips is available (macOS built-in)
if ! command -v sips &> /dev/null; then
    echo -e "${YELLOW}❌ Error: 'sips' command not found!${NC}"
    echo -e "${YELLOW}This script requires macOS.${NC}"
    exit 1
fi

OUTPUT_DIR="AppIcon.appiconset"
mkdir -p "$OUTPUT_DIR"

echo -e "${GREEN}📁 Creating output directory: $OUTPUT_DIR${NC}\n"

# Generate all sizes
echo -e "${BOLD}🎨 Generating icon sizes...${NC}\n"

# iPhone Notification (20pt)
echo "  📱 20x20 @2x (40x40)"
sips -z 40 40 "$INPUT" --out "$OUTPUT_DIR/icon_20@2x.png" &> /dev/null

echo "  📱 20x20 @3x (60x60)"
sips -z 60 60 "$INPUT" --out "$OUTPUT_DIR/icon_20@3x.png" &> /dev/null

# iPhone Settings (29pt)
echo "  ⚙️  29x29 @2x (58x58)"
sips -z 58 58 "$INPUT" --out "$OUTPUT_DIR/icon_29@2x.png" &> /dev/null

echo "  ⚙️  29x29 @3x (87x87)"
sips -z 87 87 "$INPUT" --out "$OUTPUT_DIR/icon_29@3x.png" &> /dev/null

# iPhone Spotlight (40pt)
echo "  🔍 40x40 @2x (80x80)"
sips -z 80 80 "$INPUT" --out "$OUTPUT_DIR/icon_40@2x.png" &> /dev/null

echo "  🔍 40x40 @3x (120x120)"
sips -z 120 120 "$INPUT" --out "$OUTPUT_DIR/icon_40@3x.png" &> /dev/null

# iPhone App (60pt)
echo "  📱 60x60 @2x (120x120)"
sips -z 120 120 "$INPUT" --out "$OUTPUT_DIR/icon_60@2x.png" &> /dev/null

echo "  📱 60x60 @3x (180x180)"
sips -z 180 180 "$INPUT" --out "$OUTPUT_DIR/icon_60@3x.png" &> /dev/null

# App Store
echo "  🏪 App Store (1024x1024)"
cp "$INPUT" "$OUTPUT_DIR/icon_1024.png"

# Create Contents.json
echo -e "\n${BOLD}📝 Creating Contents.json...${NC}\n"

cat > "$OUTPUT_DIR/Contents.json" << 'EOF'
{
  "images" : [
    {
      "filename" : "icon_20@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "20x20"
    },
    {
      "filename" : "icon_20@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "20x20"
    },
    {
      "filename" : "icon_29@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "29x29"
    },
    {
      "filename" : "icon_29@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "29x29"
    },
    {
      "filename" : "icon_40@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "40x40"
    },
    {
      "filename" : "icon_40@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "40x40"
    },
    {
      "filename" : "icon_60@2x.png",
      "idiom" : "iphone",
      "scale" : "2x",
      "size" : "60x60"
    },
    {
      "filename" : "icon_60@3x.png",
      "idiom" : "iphone",
      "scale" : "3x",
      "size" : "60x60"
    },
    {
      "filename" : "icon_1024.png",
      "idiom" : "ios-marketing",
      "scale" : "1x",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
EOF

echo -e "${BOLD}${GREEN}============================================${NC}"
echo -e "${BOLD}${GREEN}✅ ALL ICON SIZES GENERATED!${NC}"
echo -e "${BOLD}${GREEN}============================================${NC}\n"

echo -e "${BOLD}📋 Generated files in ${BLUE}$OUTPUT_DIR/${NC}:"
ls -lh "$OUTPUT_DIR"/*.png | awk '{print "  " $9 " (" $5 ")"}'

echo -e "\n${BOLD}🚀 Next steps:${NC}"
echo -e "  1. Open Xcode"
echo -e "  2. Navigate to: Project → Assets.xcassets → AppIcon"
echo -e "  3. Delete existing icons (if any)"
echo -e "  4. Drag all files from ${BLUE}$OUTPUT_DIR/${NC} into AppIcon"
echo -e "  5. Or replace: Assets.xcassets/AppIcon.appiconset/ with this folder"
echo -e "\n${GREEN}Done! 🎉${NC}\n"
