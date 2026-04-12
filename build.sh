#!/bin/bash

set -euo pipefail

PROJECT_PATH="QieQie.xcodeproj"
SCHEME_NAME="QieQie"
APP_NAME="QieQie.app"
BUILD_CONFIG="${1:-Debug}"
BUILD_DIR="$(pwd)/build"
DERIVED_DATA_DIR="$BUILD_DIR/DerivedData"
PRODUCT_PATH="$DERIVED_DATA_DIR/Build/Products/$BUILD_CONFIG/$APP_NAME"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [[ "$BUILD_CONFIG" != "Debug" && "$BUILD_CONFIG" != "Release" ]]; then
    echo -e "${RED}错误：配置必须是 Debug 或 Release${NC}"
    echo "用法: ./build.sh [Debug|Release]"
    exit 1
fi

echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}  QieQie 构建脚本${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo -e "${YELLOW}配置: $BUILD_CONFIG${NC}"
echo ""

echo -e "${YELLOW}[1/4] 清理旧构建...${NC}"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo -e "${YELLOW}[2/4] 编译 QieQie...${NC}"
xcodebuild \
    -project "$PROJECT_PATH" \
    -scheme "$SCHEME_NAME" \
    -configuration "$BUILD_CONFIG" \
    -derivedDataPath "$DERIVED_DATA_DIR" \
    build

if [ ! -d "$PRODUCT_PATH" ]; then
    echo -e "${RED}错误：未找到构建产物 $PRODUCT_PATH${NC}"
    exit 1
fi

echo -e "${YELLOW}[3/4] 复制应用到 build 目录...${NC}"
cp -R "$PRODUCT_PATH" "$BUILD_DIR/"

echo -e "${YELLOW}[4/4] 生成启动脚本...${NC}"
cat > "$BUILD_DIR/run.sh" << 'EOF'
#!/bin/bash

set -euo pipefail

APP_PATH="$(dirname "$0")/QieQie.app"

if [ ! -d "$APP_PATH" ]; then
    echo "错误：找不到 QieQie.app"
    exit 1
fi

echo "正在启动 QieQie..."
open "$APP_PATH"
EOF

chmod +x "$BUILD_DIR/run.sh"

APP_SIZE=$(du -sh "$BUILD_DIR/$APP_NAME" | cut -f1)

echo ""
echo -e "${GREEN}==============================${NC}"
echo -e "${GREEN}✓ 构建完成${NC}"
echo -e "${GREEN}==============================${NC}"
echo ""
echo "产物: $(pwd)/build/$APP_NAME"
echo "大小: $APP_SIZE"
echo ""
echo "运行方式："
echo "  1. open build/$APP_NAME"
echo "  2. ./build/run.sh"
