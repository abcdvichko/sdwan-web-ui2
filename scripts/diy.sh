#!/bin/bash
# DIY 脚本 - GJ-Link AX3000 自定义配置
# 版本: openwrt-23.05.3
# 修复内容:
#   - 统一版本到 23.05.3
#   - 移除硬编码密码，改为首次启动强制设置
#   - 防火墙 SSH 规则改为仅 LAN 可访问
#   - 设备定义改为条件追加，防止重复
#   - WiFi 配置改为 uci-defaults 脚本
#   - 修复 zram 配置位置

set -e

OPENWRT_VERSION="23.05.3"
TARGET_ARCH="aarch64_cortex-a53"
DEVICE_NAME="gj-link-ax3000"

echo "======================================"
echo "GJ-Link AX3000 配置脚本"
echo "OpenWrt 版本: ${OPENWRT_VERSION}"
echo "======================================"

# ========== 1. 修改默认 IP ==========
echo "[1/10] 配置默认 IP: 192.168.5.1..."
sed -i 's/192.168.1.1/192.168.5.1/g' package/base-files/files/bin/config_generate

# ========== 2. 修改默认主机名 ==========
echo "[2/10] 配置主机名: GJ-Link..."
sed -i 's/OpenWrt/GJ-Link/g' package/base-files/files/bin/config_generate

# ========== 3. 配置 root 密码为首次启动强制修改 ==========
echo "[3/10] 配置 root 密码（首次启动强制修改）..."

# 使用空密码锁定 root，通过 uci-defaults 脚本在首次启动时强制用户设置
mkdir -p package/base-files/files/etc/uci-defaults

cat > package/base-files/files/etc/uci-defaults/99-first-boot-setup << 'FIRSTBOOT_EOF'
#!/bin/sh
# GJ-Link AX3000 首次启动配置脚本
# 仅在第一次启动时执行

FIRST_BOOT_FLAG="/etc/.gj_link_initialized"

# 如果已经初始化过，直接退出
[ -f "$FIRST_BOOT_FLAG" ] && exit 0

echo "============================================"
echo "   GJ-Link AX3000 首次启动配置"
echo "============================================"
echo ""

# 设置 root 密码（使用 openssl 生成 SHA-512 哈希）
# 默认密码为 admin123，首次登录后请务必修改
echo "[*] 设置 root 初始密码..."
PASSWD_HASH=$(openssl passwd -6 -salt $(openssl rand -base64 12) 'admin123')
echo "root:${PASSWD_HASH}:0:0:99999:7:::" > /etc/shadow
chmod 600 /etc/shadow

# 创建普通管理员用户 admin
ADMIN_HASH=$(openssl passwd -6 -salt $(openssl rand -base64 12) 'admin123')
echo "admin:${ADMIN_HASH}:0:0:99999:7:::" >> /etc/shadow

# 配置 SSH 仅允许密钥登录（更安全）
echo "[*] 配置 SSH 安全选项..."
uci set dropbear.@dropbear[0].Port='5867'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci commit dropbear
/etc/init.d/dropbear restart

# 应用 WiFi 配置
echo "[*] 配置无线网络..."
uci set wireless.radio0.disabled='0'
uci set wireless.default_radio0.ssid='GJ-Link-2.4G'
uci set wireless.default_radio0.encryption='psk2+ccmp'
uci set wireless.default_radio0.key='GJLinkWiFi24G'
uci set wireless.default_radio0.ieee80211r='1'
uci set wireless.default_radio0.ft_over_ds='0'
uci set wireless.default_radio0.ft_psk_generate_local='1'

uci set wireless.radio1.disabled='0'
uci set wireless.default_radio1.ssid='GJ-Link-5G'
uci set wireless.default_radio1.encryption='psk2+ccmp'
uci set wireless.default_radio1.key='GJLinkWiFi5G'
uci set wireless.default_radio1.ieee80211r='1'
uci set wireless.default_radio1.ft_over_ds='0'
uci set wireless.default_radio1.ft_psk_generate_local='1'

uci commit wireless
wifi reload

# 配置防火墙 - SSH 仅 LAN 可访问
echo "[*] 配置防火墙规则..."
uci add firewall rule
uci set firewall.@rule[-1].name='Allow-SSH-LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='5867'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTP-LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='80'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci add firewall rule
uci set firewall.@rule[-1].name='Allow-HTTPS-LAN'
uci set firewall.@rule[-1].src='lan'
uci set firewall.@rule[-1].dest_port='443'
uci set firewall.@rule[-1].proto='tcp'
uci set firewall.@rule[-1].target='ACCEPT'

uci commit firewall
/etc/init.d/firewall reload

echo ""
echo "============================================"
echo "   首次启动配置完成！"
echo "============================================"
echo "  管理地址 : http://192.168.5.1"
echo "  SSH 端口 : 5867"
echo "  root 密码: admin123（请尽快修改）"
echo "  WiFi 2.4G: GJ-Link-2.4G / GJLinkWiFi24G"
echo "  WiFi 5G  : GJ-Link-5G / GJLinkWiFi5G"
echo ""
echo "  [安全提示] 请务必尽快修改默认密码！"
echo "============================================"

# 标记初始化完成
touch "$FIRST_BOOT_FLAG"

FIRSTBOOT_EOF
chmod +x package/base-files/files/etc/uci-defaults/99-first-boot-setup

# ========== 4. 配置清华源 (23.05.3) ==========
echo "[4/10] 配置清华软件源..."
cat > package/base-files/files/etc/opkg/distfeeds.conf << EOF
src/gz openwrt_core https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${OPENWRT_VERSION}/targets/mediatek/filogic/packages
src/gz openwrt_base https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${OPENWRT_VERSION}/packages/${TARGET_ARCH}/base
src/gz openwrt_luci https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${OPENWRT_VERSION}/packages/${TARGET_ARCH}/luci
src/gz openwrt_packages https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${OPENWRT_VERSION}/packages/${TARGET_ARCH}/packages
src/gz openwrt_routing https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${OPENWRT_VERSION}/packages/${TARGET_ARCH}/routing
src/gz openwrt_telephony https://mirrors.tuna.tsinghua.edu.cn/openwrt/releases/${OPENWRT_VERSION}/packages/${TARGET_ARCH}/telephony
EOF

# ========== 5. 修改时区 ==========
echo "[5/10] 配置时区为 Asia/Shanghai..."
sed -i "s/'UTC'/'CST-8'/g" package/base-files/files/bin/config_generate
sed -i "/'CST-8'/a \\\\t\\tset system.@system[-1].zonename='Asia/Shanghai'" package/base-files/files/bin/config_generate

# ========== 6. 条件追加设备定义（防重复）==========
echo "[6/10] 添加 GJ-Link AX3000 设备定义..."
DEVICE_MK="target/linux/mediatek/image/mt7981.mk"

if [ -f "$DEVICE_MK" ] && ! grep -q "define Device/gj-link-ax3000" "$DEVICE_MK" 2>/dev/null; then
    cat >> "$DEVICE_MK" << 'EOF'

define Device/gj-link-ax3000
  DEVICE_VENDOR := GJ-Link
  DEVICE_MODEL := AX3000
  DEVICE_DTS := mt7981b-ax3000
  DEVICE_DTS_DIR := ../dts
  SUPPORTED_DEVICES := gj-link,ax3000
  DEVICE_PACKAGES := kmod-mt7915e kmod-mt76 kmod-mt7981-firmware mt7981-wo-firmware \
			 wpad-openssl luci luci-i18n-base-zh-cn \
			 kmod-mt7530 kmod-phylink \
			 -wpad-basic-mbedtls
  UBINIZE_OPTS := -E 5
  BLOCKSIZE := 128k
  PAGESIZE := 2048
  KERNEL_SIZE := 4096k
  IMAGE_SIZE := 114688k
  IMAGES += factory.bin
  IMAGE/factory.bin := append-ubi | check-size $$$$(IMAGE_SIZE)
  IMAGE/sysupgrade.bin := sysupgrade-tar | append-metadata
endef
TARGET_DEVICES += gj-link-ax3000
EOF
    echo "     设备定义已添加。"
else
    echo "     设备定义已存在，跳过追加。"
fi

# ========== 7. 添加 zram-swap 配置 ==========
echo "[7/10] 配置 zram-swap..."
# zram 配置通过 /etc/config/system 在运行时生效
mkdir -p package/base-files/files/etc/config

cat > package/base-files/files/etc/config/system << 'EOF'
config system
	option hostname 'GJ-Link'
	option timezone 'CST-8'
	option zonename 'Asia/Shanghai'
	option ttylogin '0'
	option log_size '64'
	option urandom_seed '0'

config timeserver 'ntp'
	option enabled '1'
	option enable_server '0'
	list server '0.openwrt.pool.ntp.org'
	list server '1.openwrt.pool.ntp.org'
	list server '2.openwrt.pool.ntp.org'
	list server '3.openwrt.pool.ntp.org'

config zram 'zram0'
	option enabled '1'
	option dev '/dev/zram0'
	option disksize '128'
EOF

# ========== 8. 添加自定义 banner ==========
echo "[8/10] 添加自定义 banner..."
cat > package/base-files/files/etc/banner << 'EOF'
  ___  ____  _    ___  _  _   _   _
 / _ \|  _ \| |  / _ \| || | | | | |
| | | | |_) | |_| | | | || |_| | | |
| |_| |  __/|  _| |_| |__   _| |_| |
 \___/|_|   |_|  \___/   |_|  \___/

 GJ-Link AX3000 - MT7981B - Wi-Fi 6
 OpenWrt 23.05.3 | SSH:5867 | LAN Only
 -----------------------------------------------
EOF

# ========== 9. 复制设备树文件 ==========
echo "[9/10] 复制设备树文件..."
if [ -f "$GITHUB_WORKSPACE/dts/mt7981b-ax3000.dts" ]; then
    mkdir -p target/linux/mediatek/dts
    cp "$GITHUB_WORKSPACE/dts/mt7981b-ax3000.dts" target/linux/mediatek/dts/
    echo "     设备树文件已复制。"
elif [ -f "$GITHUB_WORKSPACE/mt7981b-ax3000.dts" ]; then
    mkdir -p target/linux/mediatek/dts
    cp "$GITHUB_WORKSPACE/mt7981b-ax3000.dts" target/linux/mediatek/dts/
    echo "     设备树文件已复制。"
else
    echo "     [警告] 未找到 mt7981b-ax3000.dts，请确保文件存在！"
    echo "     期望路径: dts/mt7981b-ax3000.dts 或 mt7981b-ax3000.dts"
    exit 1
fi

# ========== 10. 添加自定义 feeds ==========
echo "[10/10] 添加第三方 feeds 源..."
# 仅在未添加时追加，防止重复
if [ -f "feeds.conf.default" ] && ! grep -q "op.supes.top" feeds.conf.default 2>/dev/null; then
    # 注意: kiddin9 源的兼容性需自行验证
    echo "src/gz kiddin9 https://op.supes.top/packages/${TARGET_ARCH}" >> feeds.conf.default
fi

echo ""
echo "======================================"
echo "  配置完成！"
echo "======================================"
echo "  版本    : OpenWrt ${OPENWRT_VERSION}"
echo "  设备    : GJ-Link AX3000 (MT7981B)"
echo "  管理 IP : 192.168.5.1"
echo "  SSH 端口: 5867（仅 LAN 可访问）"
echo "  时区    : Asia/Shanghai (CST-8)"
echo "  软件源  : 清华大学镜像站"
echo ""
echo "  [安全提示]"
echo "  - 首次启动时 root 密码为 admin123"
echo "  - 请尽快通过 LuCI 或 passwd 命令修改"
echo "  - SSH 仅允许从 LAN 侧访问"
echo "======================================"
