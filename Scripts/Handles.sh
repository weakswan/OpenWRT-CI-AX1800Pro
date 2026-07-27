#!/usr/bin/env bash
# Handles.sh — 加固：固定工作目录 / 稳健预置资源 / 常见补丁
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package"
mkdir -p "$PKG_PATH"
cd "$PKG_PATH"


# qca-nss-drv/pbuf 的启动顺序
[ -f "../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init" ] && sed -i 's/START=.*/START=85/g' ../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init || true
[ -f "./kernel/mac80211/files/qca-nss-pbuf.init" ] && sed -i 's/START=.*/START=86/g' ./kernel/mac80211/files/qca-nss-pbuf.init || true


# rust 关闭 ci-llvm (常见失败点)
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile" | head -n1)
[ -n "$RUST_FILE" ] && sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE" || true

# diskman 依赖名修正
[ -f "./luci-app-diskman/applications/luci-app-diskman/Makefile" ] && sed -i 's/fs-ntfs/fs-ntfs3/g' ./luci-app-diskman/applications/luci-app-diskman/Makefile || true

echo ">> Handles.sh done"
