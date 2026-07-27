#!/usr/bin/env bash
# Unified Packages.sh
# - 稳健 vendor 第三方包（缺失时自动拉取）
# - 兼容 SMALL_FALLBACK=1（当 Packages_small.sh 缺失时被工作流回退调用）
# - 保留你原先的第三方来源，并容错上游删改
set -e

echo ">> Using unified Packages.sh (safe clone + SMALL fallback support)"

PKGDIR="package"
mkdir -p "${PKGDIR}"

# -------- Helpers --------
safe_sparse_clone() {
  local branch="$1"; shift
  local repo="$1"; shift
  local paths=("$@")

  local tmpdir; tmpdir="$(mktemp -d)"
  echo ">> Sparse cloning ${repo} (${branch}) -> ${tmpdir}"
  git clone --depth=1 --filter=blob:none --sparse -b "${branch}" "${repo}" "${tmpdir}" || { echo "!! WARN: clone ${repo} failed, skip"; rm -rf "${tmpdir}"; return 0; }
  pushd "${tmpdir}" >/dev/null || { rm -rf "${tmpdir}"; return 0; }

  if [ "${#paths[@]}" -gt 0 ]; then
    git sparse-checkout set --no-cone "${paths[@]}" || true
  fi
  for p in "${paths[@]}"; do
    if [ -d "${p}" ] || [ -f "${p}" ]; then
      echo "   + bringing ${p}"
      mv -f "${p}" "../${PKGDIR}/" 2>/dev/null || cp -a "${p}" "../${PKGDIR}/"
    else
      echo "   ! WARN: path '${p}' not found in ${repo}, skipping"
    fi
  done

  popd >/dev/null || true
  rm -rf "${tmpdir}"
}

safe_clone_into_package() {
  local repo="$1"
  local name="$2"
  [ -z "${name}" ] && name="$(basename "${repo%%.git}")"
  echo ">> Cloning ${repo} -> ${PKGDIR}/${name}"
  rm -rf "${PKGDIR:?}/${name}"
  git clone --depth 1 --single-branch "${repo}" "${PKGDIR}/${name}" || { echo "!! WARN: clone ${repo} failed, skip"; return 0; }
}

have_makefile() {
  # $1: glob like */luci-app-xxx/Makefile
  find package feeds -maxdepth 3 -type f -path "$1" | grep -q .
}

# -------- Your third-party sources (容错) --------


# -------- SMALL_FALLBACK 兼容（当 Packages_small.sh 缺失时由工作流触发） --------
if [ "${SMALL_FALLBACK:-0}" = "1" ]; then
  echo ">> SMALL_FALLBACK enabled: ensured momo/nikki/tailscale/sing-box are vendored (done above)"
  # 如果你还想在 fallback 情况下再拉 Lucky（但默认 SMALL 里是关的，仅保留源码），可按需追加：
  # [ -d "${PKGDIR}/lucky" ] || safe_clone_into_package https://github.com/sirpdboy/lucky lucky
fi

echo ">> Third-party packages fetched successfully."
