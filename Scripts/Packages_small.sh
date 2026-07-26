#!/usr/bin/env bash
# SMALL 场景：尽量轻量，同时稳定 vendor 比较容易漂移/下架的三方 LuCI（momo/nikki/tailscale）
# 只放源码，不在这里强制启用；启用与否由 Settings.sh 里写 .config 决定
set -e

echo "== Packages_small.sh (lightweight + vendored apps) =="

PKGDIR="package"
mkdir -p "${PKGDIR}"

# -------- Helpers --------
safe_clone_into_package() {
  # 用于把一个 repo 克隆为 package/<name>
  # 用法: safe_clone_into_package <repo_url> <dir_name_under_package>
  local repo="$1" name="$2"
  if [ -z "${name}" ]; then
    name="$(basename "${repo%%.git}")"
  fi
  echo ">> vendor ${name} from ${repo}"
  rm -rf "${PKGDIR:?}/${name}"
  # 容错：若 clone 失败不退出（SMALL 要求稳）
  git clone --depth 1 --single-branch "${repo}" "${PKGDIR}/${name}" || {
    echo "!! WARN: clone ${repo} failed, skip (keep going)"; return 0; }
}

have_makefile() {
  # 检查 package/ 和 feeds/ 下是否存在某包的 Makefile（最多 3 层）
  # 用法: have_makefile "*/luci-app-xxx/Makefile"
  local glob="$1"
  find package feeds -maxdepth 3 -type f -path "${glob}" | grep -q .
}

# -------- Lucky（保留源码，默认不启用）--------
# 备注：有的仓库把 UI 和二进制分离；这里仅拉 UI，是否启用由 Settings.sh 控制
if ! have_makefile "*/luci-app-lucky/Makefile"; then
  safe_clone_into_package "https://github.com/sirpdboy/luci-app-lucky" "luci-app-lucky"
fi
# 如需 lucky 二进制包（可选），解开下一行：
# if ! have_makefile "*/lucky/Makefile"; then safe_clone_into_package "https://github.com/sirpdboy/lucky" "lucky"; fi

# -------- momo / nikki / luci-app-tailscale（稳定 vendor）--------
# 这些包上游经常迁移/改名/下架，直接 vendor 到 package/ 最稳
if ! have_makefile "*/luci-app-momo/Makefile"; then
  safe_clone_into_package "https://github.com/nikkinikki-org/OpenWrt-momo" "luci-app-momo"
fi
if ! have_makefile "*/luci-app-nikki/Makefile"; then
  safe_clone_into_package "https://github.com/nikkinikki-org/OpenWrt-nikki" "luci-app-nikki"
fi
# tailscale 的 LuCI（核心 tailscale 一般在 feeds/packages 里）
if ! have_makefile "*/luci-app-tailscale/Makefile"; then
  safe_clone_into_package "https://github.com/asvow/luci-app-tailscale" "luci-app-tailscale"
fi

# -------- sing-box（仅在缺失时补齐，供 homeproxy 依赖；SMALL 默认可以不开 homeproxy）--------
if ! have_makefile "*/sing-box/Makefile"; then
  echo ">> sing-box not found in feeds/package, vendor sbwml/sing-box (SMALL)"
  safe_clone_into_package "https://github.com/sbwml/sing-box" "sing-box"
fi

# -------- 轻量依赖修复：重新安装 feeds 里的索引（不更新 feeds）--------
# 注意：此脚本在 “Update Feeds(更新软件包源)” 之后执行，这里只做 install，保证依赖元数据可用。
if [ -x "./scripts/feeds" ]; then
  echo ">> feeds install -a (refresh indexes)"
  ./scripts/feeds install -a || true
fi

echo "== Packages_small.sh done =="
