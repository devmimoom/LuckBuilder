#!/bin/bash

# 從 OnePop.png 生成所有 App icon 尺寸的腳本

SOURCE_IMAGE="assets/images/OnePop.png"
ICON_DIR="ios/Runner/Assets.xcassets/AppIcon.appiconset"

# 檢查源圖片是否存在
if [ ! -f "$SOURCE_IMAGE" ]; then
    echo "錯誤：找不到源圖片 $SOURCE_IMAGE"
    exit 1
fi

echo "開始從 $SOURCE_IMAGE 生成 App icons..."

# 創建臨時目錄
TEMP_DIR=$(mktemp -d)
echo "使用臨時目錄: $TEMP_DIR"

# 生成所有需要的尺寸
# iPhone 20pt
sips -z 40 40 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@2x.png"
sips -z 60 60 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@3x.png"

# iPhone 29pt
sips -z 29 29 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@1x.png"
sips -z 58 58 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@2x.png"
sips -z 87 87 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-29x29@3x.png"

# iPhone 40pt
sips -z 80 80 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@2x.png"
sips -z 120 120 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@3x.png"

# iPhone 60pt
sips -z 120 120 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-60x60@2x.png"
sips -z 180 180 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-60x60@3x.png"

# iPad 20pt
sips -z 20 20 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-20x20@1x.png"

# iPad 29pt (已生成，重複使用)
# Icon-App-29x29@1x.png 和 Icon-App-29x29@2x.png 已生成

# iPad 40pt
sips -z 40 40 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-40x40@1x.png"

# iPad 76pt
sips -z 76 76 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-76x76@1x.png"
sips -z 152 152 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-76x76@2x.png"

# iPad Pro 83.5pt
sips -z 167 167 "$SOURCE_IMAGE" --out "$TEMP_DIR/Icon-App-83.5x83.5@2x.png"

# App Store 1024x1024
cp "$SOURCE_IMAGE" "$TEMP_DIR/Icon-App-1024x1024@1x.png"

echo "所有圖標已生成，正在複製到 $ICON_DIR..."

# 備份現有圖標（可選）
if [ -d "$ICON_DIR" ]; then
    BACKUP_DIR="${ICON_DIR}_backup_$(date +%Y%m%d_%H%M%S)"
    echo "備份現有圖標到: $BACKUP_DIR"
    cp -r "$ICON_DIR" "$BACKUP_DIR"
fi

# 複製所有生成的圖標
cp "$TEMP_DIR"/*.png "$ICON_DIR/"

# 清理臨時目錄
rm -rf "$TEMP_DIR"

echo "✅ 完成！所有 App icons 已更新。"
echo ""
echo "生成的圖標："
ls -lh "$ICON_DIR"/*.png | awk '{print $9, "(" $5 ")"}'
