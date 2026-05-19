# GJ-Link AX3000 OpenWrt 固件

> **版本**: OpenWrt 23.05.3 | **适用设备**: GJ-Link AX3000 (MT7981B)

## 硬件规格

| 组件 | 规格 |
|------|------|
| CPU | MediaTek MT7981B 双核 1.3GHz (ARM Cortex-A53) |
| 内存 | 256MB DDR3 |
| 闪存 | 128MB SPI NAND |
| 2.4G WiFi | MT7976GN |
| 5G WiFi | MT7976AN |
| 有线网口 | 1 WAN + 3 LAN (千兆自适应) |
| 无线规格 | AX3000 (2.4G 574Mbps + 5G 2402Mbps) |
| LED | 电源/状态、WAN、2.4G WiFi、5G WiFi |
| 按键 | Reset、WPS |

## 预装功能

| 功能 | 说明 | 状态 |
|------|------|------|
| LuCI Web 管理 | 中文界面，Bootstrap 主题 | 预装 |
| WireGuard VPN | VPN 服务端/客户端 | 预装 |
| DDNS | 动态域名解析 | 预装 |
| UPnP | 端口自动映射 | 预装 |
| SQM QoS | 智能流控/CAKE | 预装 |
| zram-swap | 内存压缩交换 | 预装 |

## 默认配置

| 项目 | 默认值 | 说明 |
|------|--------|------|
| 管理地址 | http://192.168.5.1 | 可通过 LAN 口访问 |
| SSH 端口 | 5867 | **仅 LAN 侧可访问** |
| root 初始密码 | `admin123` | **首次登录后必须修改** |
| 主机名 | GJ-Link | |
| 时区 | Asia/Shanghai (CST-8) | |
| WiFi 2.4G | `GJ-Link-2.4G` / `GJLinkWiFi24G` | WPA2-PSK/CCMP |
| WiFi 5G | `GJ-Link-5G` / `GJLinkWiFi5G` | WPA2-PSK/CCMP, 802.11r |
| 软件源 | 清华大学开源软件镜像站 | |

### 首次使用步骤

1. 将电脑通过网线连接到路由器 LAN 口
2. 电脑自动获取 IP（或手动设置 192.168.5.x/24）
3. 访问 http://192.168.5.1
4. 使用 root / `admin123` 登录
5. **立即修改 root 密码**（系统设置 → 管理权）
6. 根据需要修改 WiFi 名称和密码

## 安全说明

- **SSH 仅允许 LAN 侧访问**：WAN 侧无法通过 SSH 连接，防止公网扫描攻击
- **首次启动强制初始化**：root 密码在首次启动时自动设置，登录后必须修改
- **WiFi 使用 WPA2-PSK + CCMP 加密**：避免使用已不安全的 TKIP
- **建议进一步加固**：
  - 修改 SSH 为密钥认证（系统 → 管理权 → SSH 密钥）
  - 关闭不必要的 Web 管理访问
  - 定期更新固件

## 文件说明

| 文件 | 路径 | 说明 |
|------|------|------|
| `mt7981b-ax3000.dts` | `dts/` | 设备树源文件（硬件定义） |
| `mt7981b-ax3000.config` | `configs/` | OpenWrt 编译配置 |
| `diy.sh` | `scripts/` | 自定义配置脚本 |
| `build-mt7981b-ax3000.yml` | `.github/workflows/` | GitHub Actions 云编译 |

## 编译方法

### 方法一：GitHub Actions 云编译（推荐）

1. Fork 本仓库到自己的 GitHub 账号
2. 确认文件目录结构正确
3. 进入 Actions 页面，选择 "Build GJ-Link AX3000 OpenWrt"
4. 点击 "Run workflow" 开始编译
5. 等待 1.5~3 小时，在 Releases 页面下载固件

### 方法二：本地编译

```bash
# 1. 克隆 OpenWrt 源码
git clone https://github.com/openwrt/openwrt.git -b openwrt-23.05
cd openwrt

# 2. 复制配置和设备树文件
cp ../configs/mt7981b-ax3000.config .config
cp ../dts/mt7981b-ax3000.dts target/linux/mediatek/dts/

# 3. 执行 DIY 脚本
chmod +x ../scripts/diy.sh
env bash ../scripts/diy.sh

# 4. 更新 feeds
./scripts/feeds update -a
./scripts/feeds install -a

# 5. 配置
make defconfig

# 6. 下载依赖
make download -j$(nproc)

# 7. 编译
make -j$(nproc) || make -j1 V=s
```

## 刷机方法

### 首次刷机（U-Boot 恢复模式）

1. 电脑设置静态 IP: `192.168.1.2/24`
2. 路由器断电，按住 Reset 键，通电开机
3. LED 开始闪烁后松开 Reset 键
4. 访问 http://192.168.1.1
5. 上传 `factory.bin` 固件，等待刷入完成

### 系统内升级（推荐）

```bash
# 通过 SSH 登录（端口 5867，仅限 LAN）
ssh -p 5867 root@192.168.5.1

# 上传 sysupgrade.bin 后执行
sysupgrade -n /tmp/openwrt-*.bin
```

> **注意**: 使用 `-n` 参数将不保留配置，首次刷机建议清空配置避免冲突。

## 许可证

本项目基于 [OpenWrt](https://openwrt.org/)，遵循 GPL-2.0 许可证。
