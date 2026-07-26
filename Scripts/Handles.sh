#!/usr/bin/env bash
# Handles.sh — 加固：固定工作目录 / 稳健预置资源 / 常见补丁
set -euo pipefail

PKG_PATH="$GITHUB_WORKSPACE/wrt/package"
mkdir -p "$PKG_PATH"
cd "$PKG_PATH"

# -------- 预置 homeproxy 资源（可选，不影响编译，失败也不让构建失败）--------
if [ -d "./luci-app-homeproxy" ] || [ -d "./homeproxy" ]; then
  echo "[homeproxy] preload rules…"
  HP_PATH="./homeproxy/root/etc/homeproxy"
  [ -d "$HP_PATH" ] || HP_PATH="./luci-app-homeproxy/root/etc/homeproxy"
  if [ -d "$HP_PATH" ]; then
    rm -rf "$HP_PATH/resources"/* || true
    tmpdir="$(mktemp -d)"
    if git clone -q --depth=1 --single-branch --branch release https://github.com/Loyalsoldier/surge-rules.git "$tmpdir"; then
      pushd "$tmpdir" >/dev/null
      RES_VER="$(git log -1 --pretty=format:'%s' | grep -o '[0-9]*' || true)"
      [ -n "$RES_VER" ] && printf '%s' "$RES_VER" | tee china_ip4.ver china_ip6.ver china_list.ver gfw_list.ver >/dev/null
      awk -F, '/^IP-CIDR,/{print $2 > "china_ip4.txt"} /^IP-CIDR6,/{print $2 > "china_ip6.txt"}' cncidr.txt || true
      sed 's/^\.//g' direct.txt > china_list.txt || true
      sed 's/^\.//g' gfw.txt > gfw_list.txt || true
      mkdir -p "$PKG_PATH/$HP_PATH/resources"
      mv -f china_*.* gfw_list.* "$PKG_PATH/$HP_PATH/resources/" || true
      popd >/dev/null
      rm -rf "$tmpdir"
      echo "[homeproxy] rules prepared."
    else
      echo "[homeproxy] WARN: preload rules failed (network?), skip."
    fi
  else
    echo "[homeproxy] WARN: rules path not found, skip."
  fi
fi

# -------- 主题 / NSS / Rust / DiskMan 等补丁（保留原有逻辑，健壮化）--------
# argon 样式（可选）
if [ -d "./luci-theme-argon" ]; then
  find ./luci-theme-argon -type f -name '*.css' -print0 | xargs -0 -r \
    sed -i "/font-weight:/ { /important/! { /\/\*/! s/:.*/: var(--font-weight);/ } }"
fi

# qca-nss-drv/pbuf 的启动顺序
[ -f "../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init" ] && sed -i 's/START=.*/START=85/g' ../feeds/nss_packages/qca-nss-drv/files/qca-nss-drv.init || true
[ -f "./kernel/mac80211/files/qca-nss-pbuf.init" ] && sed -i 's/START=.*/START=86/g' ./kernel/mac80211/files/qca-nss-pbuf.init || true

# tailscale Makefile 去掉 files（避免冲突）
TS_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/tailscale/Makefile" | head -n1)
[ -n "$TS_FILE" ] && sed -i '/\/files/d' "$TS_FILE" || true

# rust 关闭 ci-llvm (常见失败点)
RUST_FILE=$(find ../feeds/packages/ -maxdepth 3 -type f -wholename "*/rust/Makefile" | head -n1)
[ -n "$RUST_FILE" ] && sed -i 's/ci-llvm=true/ci-llvm=false/g' "$RUST_FILE" || true

# diskman 依赖名修正
[ -f "./luci-app-diskman/applications/luci-app-diskman/Makefile" ] && sed -i 's/fs-ntfs/fs-ntfs3/g' ./luci-app-diskman/applications/luci-app-diskman/Makefile || true

echo ">> Handles.sh done"
