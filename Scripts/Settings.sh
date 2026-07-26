#!/usr/bin/env bash
# Settings.sh — 自包含方案（无需依赖 WRT_TARGET），兼容大小内存与 qualcommax/NSS
# 说明：
# 1) 仅使用 set -e，避免未定义变量导致中断（set -u 会在某些 CI 环境下引发问题）
# 2) 从 .config 自行识别平台（qualcommax），写入 CONFIG_NSS_FIRMWARE_VERSION_*，保证发布页能抓到 NSS 版本
# 3) 大小内存均可按需启用 tailscale / momo / nikki；并做“缺包置 n”兜底，避免编译失败
# 4) 随身网卡（RNDIS/CDC）支持：大内存默认启用，小内存也启用“轻量集”，确保能识别 U 盘网卡/随身 WiFi/4G

set -e

# ---------- 基础系统项 ----------
CFG_FILE="./package/base-files/files/bin/config_generate"
if [ -f "$CFG_FILE" ]; then
  sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" "$CFG_FILE" || true
  sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" "$CFG_FILE" || true
fi

# ---------- 基础 LuCI ----------
{
  echo "CONFIG_PACKAGE_luci=y"
  echo "CONFIG_LUCI_LANG_zh_Hans=y"
  echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y"
  echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y"
  echo "CONFIG_PACKAGE_luci-theme-bootstrap=y"
} >> ./.config

# ---------- 额外手动追加 ----------
if [ -n "${WRT_PACKAGE:-}" ]; then
  printf "%s\n" "${WRT_PACKAGE}" >> ./.config
fi

# ---------- qualcommax / NSS（不依赖 WRT_TARGET） ----------
# 直接从 .config 判断是否为 qualcommax 目标
if grep -q '^CONFIG_TARGET_qualcommax=y' .config 2>/dev/null; then
  {
    echo "CONFIG_FEED_nss_packages=n"
    echo "CONFIG_FEED_sqm_scripts_nss=n"
    echo "CONFIG_PACKAGE_luci-app-sqm=y"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=y"
    echo "CONFIG_NSS_FIRMWARE_VERSION_11_4=n"
  } >> ./.config

  # IPQ50* 用 12.2，其余走 12.5（与之前约定一致）
  if [[ "${WRT_CONFIG,,}" == *"ipq50"* ]]; then
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_2=y" >> ./.config
  else
    echo "CONFIG_NSS_FIRMWARE_VERSION_12_5=y" >> ./.config
  fi

  # nowifi 机型 dtsi 替换
  DTS_PATH="./target/linux/qualcommax/files/arch/arm64/boot/dts/qcom/"
  if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]] && [ -d "$DTS_PATH" ]; then
    find "$DTS_PATH" -type f ! -iname '*nowifi*' -exec \
      sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} + || true
    echo "qualcommax set up nowifi successfully!"
  fi
fi

# ---------- dropbear 修正 ----------
sed -i "s/Interface/DirectInterface/" ./package/network/services/dropbear/files/dropbear.config 2>/dev/null || true

# ---------- 不建议带入的包（稳态） ----------
cat >> ./.config <<'EOF_BLOCK_BAD'
CONFIG_PACKAGE_luci-app-advancedplus=n
CONFIG_PACKAGE_luci-theme-kucat=n
CONFIG_PACKAGE_dae=n
CONFIG_PACKAGE_daed=n
CONFIG_PACKAGE_luci-app-v2raya=n
CONFIG_PACKAGE_v2raya=n
EOF_BLOCK_BAD

# ---------- 常用工具/应用（非 SMALL 默认启用） ----------
cat >> ./.config <<'EOF_TOOLS'
CONFIG_CGROUPS=y
CONFIG_CPUSETS=y
CONFIG_PACKAGE_openssh-sftp-server=y
CONFIG_PACKAGE_jq=y
CONFIG_PACKAGE_coreutils-base64=y
CONFIG_PACKAGE_coreutils=y
CONFIG_PACKAGE_btop=y
CONFIG_PACKAGE_luci-app-openlist2=y
CONFIG_PACKAGE_luci-app-lucky=y
CONFIG_PACKAGE_lucky=y
CONFIG_PACKAGE_curl=y
CONFIG_PACKAGE_tcping=y
CONFIG_PACKAGE_cfdisk=y
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=y
CONFIG_PACKAGE_luci-app-caddy=y
CONFIG_PACKAGE_luci-app-filemanager=y
CONFIG_PACKAGE_luci-app-gost=y
CONFIG_PACKAGE_git-http=y
CONFIG_PACKAGE_luci-app-nginx=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_zoneinfo-asia=y
CONFIG_PACKAGE_bind-dig=y
CONFIG_PACKAGE_ss=y
CONFIG_PACKAGE_luci-app-turboacc=y
CONFIG_PACKAGE_luci-app-package-manager=y
# tailscale（大小内存均会在下方启用；此处为大内存默认）
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
EOF_TOOLS

# ---------- SMALL 体积保护 + 白名单 ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL profile detected, applying minimal/safe package set"

    # SMALL：仍启用 momo / nikki / sing-box（homeproxy ~ 可选）
    cat >> ./.config << 'EOF_SM_MIN'
CONFIG_PACKAGE_luci-app-homeproxy=n
CONFIG_PACKAGE_luci-app-momo=y
CONFIG_PACKAGE_luci-app-nikki=y
CONFIG_PACKAGE_sing-box=y
EOF_SM_MIN

    # SMALL：常见轻量 LuCI 白名单 + tailscale（你要求两类都集成）
    cat >> ./.config << 'EOF_SM_WHITE'
CONFIG_PACKAGE_luci-app-autoreboot=y
CONFIG_PACKAGE_luci-app-gecoosac=y
CONFIG_PACKAGE_luci-app-netspeedtest=y
CONFIG_PACKAGE_luci-app-partexp=y
CONFIG_PACKAGE_luci-app-upnp=y
CONFIG_PACKAGE_luci-app-wolplus=y
CONFIG_PACKAGE_luci-app-adguardhome=y
CONFIG_PACKAGE_adguardhome=y
CONFIG_PACKAGE_luci-app-tailscale=y
CONFIG_PACKAGE_tailscale=y
EOF_SM_WHITE

    # SMALL：显式关闭重包/重依赖
    cat >> ./.config << 'EOF_SM_BLOCK'
CONFIG_PACKAGE_luci-app-openclash=n
CONFIG_PACKAGE_openclash=n
CONFIG_PACKAGE_luci-app-lucky=n
CONFIG_PACKAGE_lucky=n
CONFIG_PACKAGE_luci-app-dockerman=n
CONFIG_PACKAGE_dockerd=n
CONFIG_PACKAGE_containerd=n
CONFIG_PACKAGE_luci-app-podman=n
CONFIG_PACKAGE_podman=n
CONFIG_PACKAGE_luci-app-qbittorrent=n
CONFIG_PACKAGE_qbittorrent=n
CONFIG_PACKAGE_luci-app-gost=n
CONFIG_PACKAGE_gost=n
CONFIG_PACKAGE_luci-app-nginx=n
CONFIG_PACKAGE_nginx-mod-luci=n
CONFIG_PACKAGE_luci-app-filemanager=n
CONFIG_PACKAGE_btop=n
CONFIG_PACKAGE_bind-dig=n
CONFIG_PACKAGE_coreutils=n
CONFIG_PACKAGE_coreutils-base64=n
EOF_SM_BLOCK

    # SMALL：若 feeds 中没有 sing-box，则置 n 以免失败
    if ! find feeds -maxdepth 3 -type f -path "*/sing-box/Makefile" | grep -q . && [ ! -d package/sing-box ]; then
      echo "CONFIG_PACKAGE_sing-box=n" >> ./.config
      echo ">> WARNING: sing-box package not found, disabled for SMALL to avoid build failure."
    fi
  ;;
esac

# ---------- 大闪存机型：避免 SQM CONTROL 冲突 ----------
case "${WRT_CONFIG,,}" in
  *wifi-yes*|*wifi-no*)
    echo ">> Disable sqm-scripts-nss to prevent CONTROL conflict"
    echo "CONFIG_PACKAGE_sqm-scripts-nss=n" >> ./.config
    echo "CONFIG_PACKAGE_sqm-scripts=y" >> ./.config
    ;;
esac

# ---------- Podman 运行最优配置（非 SMALL） ----------
case "${WRT_CONFIG,,}" in
  *small*|*samll*)
    echo ">> SMALL build: skip heavy Podman stack auto-enable"
    ;;
  *)
    echo ">> Enable full Podman stack (packages + kernel features)"
    cat >> ./.config << 'EOF_POD_PKGS'
CONFIG_PACKAGE_luci-app-podman=y
CONFIG_PACKAGE_podman=y
CONFIG_PACKAGE_conmon=y
CONFIG_PACKAGE_crun=y
CONFIG_PACKAGE_catatonit=y
CONFIG_PACKAGE_slirp4netns=y
CONFIG_PACKAGE_fuse-overlayfs=y
CONFIG_PACKAGE_uidmap=y
CONFIG_PACKAGE_netavark=y
CONFIG_PACKAGE_aardvark-dns=y
CONFIG_PACKAGE_containers-storage=y
CONFIG_PACKAGE_podman-compose=y
EOF_POD_PKGS

    cat >> ./.config << 'EOF_POD_KCFG'
CONFIG_KERNEL_CGROUPS=y
CONFIG_KERNEL_CGROUP_PIDS=y
CONFIG_KERNEL_MEMCG=y
CONFIG_KERNEL_NAMESPACES=y
CONFIG_KERNEL_USER_NS=y
CONFIG_KERNEL_SECCOMP=y
CONFIG_KERNEL_SECCOMP_FILTER=y
CONFIG_KERNEL_KEYS=y
EOF_POD_KCFG

    mkdir -p ./files/etc/containers ./files/root/.config/containers ./files/root/.local/share/containers
    mkdir -p ./files/etc/sysctl.d
    cat > ./files/etc/sysctl.d/99-podman.conf << 'EOF_SYSCTL'
net.ipv4.ip_forward=1
net.ipv6.conf.all.forwarding=1
EOF_SYSCTL
    ;;
esac

# ---------- USB 随身网卡支持（大小内存均启用，SMALL 为轻量集） ----------
if [[ "${WRT_CONFIG,,}" == *"small"* || "${WRT_CONFIG,,}" == *"samll"* ]]; then
  # SMALL 轻量：保留 CDC/RNDIS + 基础工具
  cat >> ./.config <<'EOF_USB_SM'
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
EOF_USB_SM
else
  # 大内存：完整 CDC/RNDIS 集合（可按需再扩展 asix/rtl8152 等）
  cat >> ./.config <<'EOF_USB_BIG'
CONFIG_PACKAGE_kmod-usb-net=y
CONFIG_PACKAGE_kmod-usb-net-rndis=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ether=y
CONFIG_PACKAGE_kmod-usb-net-cdc-ncm=y
CONFIG_PACKAGE_kmod-usb-net-cdc-mbim=y
CONFIG_PACKAGE_usbutils=y
CONFIG_PACKAGE_usb-modeswitch=y
EOF_USB_BIG
fi

# ---------- 显式开启 momo / nikki（非 SMALL） ----------
if [[ "${WRT_CONFIG,,}" != *"small"* && "${WRT_CONFIG,,}" != *"samll"* ]]; then
  echo "CONFIG_PACKAGE_luci-app-momo=y"  >> ./.config
  echo "CONFIG_PACKAGE_luci-app-nikki=y" >> ./.config
fi

# ---------- 存在性检查：缺包自动置 n（避免编译失败） ----------
check_or_disable() {
  local pkg="$1"       # 例如：luci-app-xxx
  local path_glob="$2" # 例如：*/luci-app-xxx/Makefile
  if ! find package feeds -maxdepth 3 -type f -path "${path_glob}" | grep -q .; then
    echo "CONFIG_PACKAGE_${pkg}=n" >> ./.config
    echo ">> WARN: ${pkg} not found in sources, disabled to avoid build error."
  fi
}

check_or_disable "luci-app-momo"      "*/luci-app-momo/Makefile"
check_or_disable "luci-app-nikki"     "*/luci-app-nikki/Makefile"
check_or_disable "luci-app-tailscale" "*/luci-app-tailscale/Makefile"
# tailscale 核心包通常在 feeds/packages
if ! find package feeds -maxdepth 3 -type f -path "*/tailscale/Makefile" | grep -q .; then
  echo "CONFIG_PACKAGE_tailscale=n" >> ./.config
  echo ">> WARN: tailscale core not found, disabled to avoid build error."
fi

echo ">> Settings.sh finished."
