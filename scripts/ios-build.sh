# iOS 打包脚本（需在 macOS 上运行）
#
# 用途：在 mac 上一条命令产出未签名 ipa。
#      未签名包在 Windows 上用 Sideloadly / AltStore 重签后即可装到自己 iPhone。
#
# 用法：
#   cd <repo>
#   bash scripts/ios-build.sh            # 产出未签名 ipa
#   bash scripts/ios-build.sh --archive  # 额外保留 .xcarchive 便于排查
#
# 前置：
#   - macOS 13+，Xcode 15+（xcode-select --install 已执行）
#   - Node 18（nvm use 18）
#   - CocoaPods（sudo gem install cocoapods 或 brew install cocoapods）
#
# 说明：此脚本只做「编译 + 打包」，不做签名。
#      Apple 的签名必须在有你的开发者证书/Apple ID 的机器上完成。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

KEEP_ARCHIVE=0
for arg in "$@"; do
  case "$arg" in
    --archive) KEEP_ARCHIVE=1 ;;
    *) echo "未知参数: $arg"; exit 1 ;;
  esac
done

echo "==> 环境检查"
command -v node >/dev/null || { echo "缺少 node"; exit 1; }
command -v pod  >/dev/null || { echo "缺少 CocoaPods"; exit 1; }
xcodebuild -version

NODE_MAJOR="$(node -p 'process.versions.node.split(".")[0]')"
if [ "$NODE_MAJOR" -lt 18 ]; then
  echo "Node 版本过低（$NODE_MAJOR），需要 >= 18"; exit 1
fi

echo "==> 安装 JS 依赖"
if [ -f package-lock.json ]; then
  npm ci
else
  npm install
fi

echo "==> pod install"
cd ios
pod install --repo-update
cd "$REPO_ROOT"

echo "==> 编译（Release, iphoneos, 未签名）"
BUILD_DIR="$REPO_ROOT/ios/build"
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

xcodebuild \
  -workspace ios/LxMusicMobile.xcworkspace \
  -scheme LxMusicMobile \
  -configuration Release \
  -sdk iphoneos \
  -archivePath "$BUILD_DIR/LxMusicMobile.xcarchive" \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  CODE_SIGN_ENTITLEMENTS="" \
  archive

echo "==> 打包 ipa"
APP_PATH="$BUILD_DIR/LxMusicMobile.xcarchive/Products/Applications/LxMusicMobile.app"
if [ ! -d "$APP_PATH" ]; then
  echo "未找到 .app，archive 可能失败"; exit 1
fi

mkdir -p "$BUILD_DIR/Payload"
cp -R "$APP_PATH" "$BUILD_DIR/Payload/"
(cd "$BUILD_DIR" && zip -qry LxMusicMobile-unsigned.ipa Payload)

IPA="$BUILD_DIR/LxMusicMobile-unsigned.ipa"
echo ""
echo "==> 完成"
ls -lh "$IPA"

if [ "$KEEP_ARCHIVE" -eq 0 ]; then
  rm -rf "$BUILD_DIR/Payload"
fi

cat <<EOF

产物：$IPA

下一步（在 Windows 上）：
  1. 安装 Sideloadly（https://sideloadly.io）
  2. 用你的 Apple ID 登录，把 ipa 拖进去
  3. 连接 iPhone，点 Start 重签安装
  4. 首次运行需在「设置 → 通用 → VPN与设备管理」里信任你的开发者证书

注意：免费 Apple ID 签名的 App 有效期 7 天，到期后需重新签名安装。
      App 内的播放列表等数据保存在沙盒中，重签通常不会丢失，
      但建议定期使用 App 的「备份」功能导出到「文件」App。
EOF
