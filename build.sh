#!/bin/bash

# Countdown 应用构建脚本
# 用途：编译并生成可用的 .app 文件

set -e

# 颜色输出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Countdown 应用构建脚本${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# 检查参数
BUILD_CONFIG=${1:-Debug}  # 默认 Debug 配置

if [[ "$BUILD_CONFIG" != "Debug" && "$BUILD_CONFIG" != "Release" ]]; then
    echo -e "${RED}错误：配置必须是 Debug 或 Release${NC}"
    echo "用法: ./build.sh [Debug|Release]"
    exit 1
fi

echo -e "${YELLOW}配置: $BUILD_CONFIG${NC}"
echo ""

# 清理旧的构建产物
echo -e "${YELLOW}[1/4] 清理旧的构建产物...${NC}"
rm -rf build

# 编译项目
echo -e "${YELLOW}[2/4] 编译项目 ($BUILD_CONFIG)...${NC}"
xcodebuild -project timer/timer.xcodeproj \
    -scheme countdown \
    -configuration "$BUILD_CONFIG" \
    build

# 获取构建产物路径
BUILD_PRODUCTS_DIR="$HOME/Library/Developer/Xcode/DerivedData/timer-gurbbbfurgecyqfwjyhkrzgzcogx/Build/Products/$BUILD_CONFIG/countdown.app"

# 检查编译产物是否存在
if [ ! -d "$BUILD_PRODUCTS_DIR" ]; then
    echo -e "${RED}错误：编译产物不存在于 $BUILD_PRODUCTS_DIR${NC}"
    exit 1
fi

# 复制到项目根目录
echo -e "${YELLOW}[3/4] 复制 .app 文件到项目根目录...${NC}"
mkdir -p build
cp -R "$BUILD_PRODUCTS_DIR" build/

# 生成可执行文件（方便直接运行）
echo -e "${YELLOW}[4/4] 生成快捷启动脚本...${NC}"
cat > build/run.sh << 'EOF'
#!/bin/bash
# Countdown 应用启动脚本

APP_PATH="$(dirname "$0")/countdown.app"

if [ ! -d "$APP_PATH" ]; then
    echo "错误：找不到 countdown.app"
    exit 1
fi

echo "正在启动 Countdown 应用..."
open "$APP_PATH"
EOF

chmod +x build/run.sh

# 获取文件大小
APP_SIZE=$(du -sh build/countdown.app | cut -f1)

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}✓ 构建完成！${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${GREEN}产物信息：${NC}"
echo "  配置: $BUILD_CONFIG"
echo "  路径: $(pwd)/build/countdown.app"
echo "  大小: $APP_SIZE"
echo ""
echo -e "${GREEN}使用方法：${NC}"
echo "  方法1: 双击 build/countdown.app"
echo "  方法2: 运行 ./build/run.sh"
echo "  方法3: 命令行 open build/countdown.app"
echo ""
echo -e "${YELLOW}提示：${NC}"
echo "  - Debug 配置包含调试信息，体积较大"
echo "  - Release 配置经过优化，体积更小性能更好"
echo ""
