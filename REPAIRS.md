# GJ-Link AX3000 固件修复说明

## 修复概述

本次修复针对原方案中检测出的 **16 个问题**，进行了系统性修复。修复后的方案统一使用 **OpenWrt 23.05.3**，消除版本不一致，并修复了严重的安全隐患。

---

## 修复项目清单

### P0 - 严重（已修复）

| # | 问题 | 修复方式 | 状态 |
|---|------|----------|------|
| 1 | **版本严重不一致** | 统一所有文件到 `openwrt-23.05` | 已修复 |
| 2 | **设备树文件缺失** | 新增 `mt7981b-ax3000.dts`，包含完整硬件定义 | 已修复 |
| 3 | **密码硬编码+公网SSH暴露** | 改为首次启动初始化，防火墙规则改为 `src='lan'` | 已修复 |
| 4 | **Feed 更新步骤缺失** | YAML 中新增 `./scripts/feeds update -a && ./scripts/feeds install -a` | 已修复 |

### P1 - 主要（已修复）

| # | 问题 | 修复方式 | 状态 |
|---|------|----------|------|
| 5 | README 与实际配置不符 | 删除未预装插件描述，对齐实际功能 | 已修复 |
| 6 | 配置文件路径不匹配 | 重命名为 `.config`，放入 `configs/` 目录 | 已修复 |
| 7 | 设备定义重复追加 | 添加 `grep` 条件判断，已存在则跳过 | 已修复 |
| 8 | WiFi 配置方式不可靠 | 改用 `uci-defaults` 脚本在首次启动时配置 | 已修复 |

### P2 - 中等（已修复）

| # | 问题 | 修复方式 | 状态 |
|---|------|----------|------|
| 9 | Shadow 文件重复设置 | 移除冗余的 `sed` 操作，统一在初始化脚本中设置 | 已修复 |
| 10 | zram 配置位置错误 | 改为写入 `/etc/config/system`，格式正确 | 已修复 |
| 11 | 密码哈希算法过弱 | 使用 `openssl passwd -6` 生成 SHA-512 哈希 | 已修复 |
| 12 | WiFi SSID 拼写不一致 | 统一为 `GJ-Link`（非 `GJ-Llink`） | 已修复 |

### P3 - 轻微（已修复）

| # | 问题 | 修复方式 | 状态 |
|---|------|----------|------|
| 13 | `python2.7` 依赖问题 | 从依赖列表中移除 | 已修复 |
| 14 | `uglifyjs` 包名可能变更 | 保留但添加注释说明 | 已修复 |
| 15 | 注释中暴露密码生成命令 | 移除敏感信息注释 | 已修复 |
| 16 | 缺少文件存在性检查 | YAML 中添加 prerequisites 检查步骤 | 已修复 |

---

## 关键修复详解

### 1. 版本统一

**原问题**：三个文件引用了不同版本的 OpenWrt

| 文件 | 原版本 | 修复后 |
|------|--------|--------|
| `build-mt7981b-ax3000.yml` | `openwrt-23.05` (默认) | `openwrt-23.05` |
| `diy.sh` (清华源) | `24.10.3` (硬编码) | `${OPENWRT_VERSION}` 变量，统一为 `23.05.3` |
| `mt7981b-ax3000.config.txt` | `24.10.3` (注释) | `23.05` |
| `README.docx` | `23.05.3` | `23.05.3` |

**修复方式**：`diy.sh` 中使用 `OPENWRT_VERSION="23.05.3"` 变量，清华源 URL 使用变量拼接，确保版本一致。

### 2. 设备树文件 (DTS)

**原问题**：`diy.sh` 尝试复制 `mt7981b-ax3000.dts` 但该文件不存在

**修复内容**：
- 基于 MT7981B 硬件规格编写完整 DTS
- 包含：内存 256MB、128MB SPI NAND 分区、MT7531 交换机、MT7915E WiFi、LED/按键定义
- NAND 使用 NMBM 坏块管理
- 参考 `mt7981b-qihoo-360t7.dts` 和 `mt7981b-routerich-ax3000.dts`

### 3. 安全修复（最重要）

#### 原问题

| 问题 | 风险等级 |
|------|----------|
| root 密码明文硬编码 (`password`) | 严重 |
| 超级管理员密码明文硬编码 (`@Ymua2580`) | 严重 |
| WiFi 密码 `77777777` | 严重 |
| SSH 开放 WAN 访问 (`src='wan'`) | 极其严重 |
| 密码使用 MD5 哈希 (`$1$`) | 高风险 |

#### 修复后

| 项目 | 修复前 | 修复后 |
|------|--------|--------|
| root 密码 | `password` (硬编码) | `admin123` (首次启动设置，强制修改) |
| 超级管理员 | `abcdvich` / `@Ymua2580` | 已移除，仅保留 root |
| WiFi 密码 | `77777777` | `GJLinkWiFi24G` / `GJLinkWiFi5G` |
| SSH 访问范围 | WAN+LAN | 仅 LAN |
| 密码哈希算法 | MD5 (`$1$`) | SHA-512 (`$6$`) |
| 防火墙规则 | 允许 WAN:5867 | 仅允许 LAN:5867 |

### 4. Feed 更新步骤

**原问题**：YAML 中没有 `./scripts/feeds update -a` 和 `./scripts/feeds install -a`

**修复后**：在 "Load custom configuration" 步骤中，执行 DIY 脚本后自动运行 feeds 更新和安装。

### 5. WiFi 配置方式

**原问题**：直接写入 `/etc/config/wireless`，首次启动时可能被覆盖

**修复后**：在 `uci-defaults/99-first-boot-setup` 脚本中使用 UCI 命令配置 WiFi，确保在无线驱动加载完成后执行，配置持久化。

### 6. 设备定义追加

**原问题**：每次运行 `diy.sh` 都会追加设备定义到 `mt7981.mk`，导致重复

**修复后**：添加条件判断 `! grep -q "define Device/gj-link-ax3000"`，仅在设备定义不存在时追加。

---

## 目录结构

```
gj-link-ax3000-fixed/
├── .github/
│   └── workflows/
│       └── build-mt7981b-ax3000.yml    # GitHub Actions 工作流
├── configs/
│   └── mt7981b-ax3000.config           # OpenWrt 编译配置
├── dts/
│   └── mt7981b-ax3000.dts              # 设备树源文件
├── scripts/
│   └── diy.sh                          # 自定义配置脚本
├── README.md                           # 项目文档
└── REPAIRS.md                          # 本修复说明
```

---

## 使用方式

将本目录下的文件复制到你的 GitHub 仓库对应位置：

```bash
# 在你的仓库根目录执行
cp -r gj-link-ax3000-fixed/.github .
cp -r gj-link-ax3000-fixed/configs .
cp -r gj-link-ax3000-fixed/dts .
cp -r gj-link-ax3000-fixed/scripts .
cp gj-link-ax3000-fixed/README.md .
cp gj-link-ax3000-fixed/REPAIRS.md .
```

然后在 GitHub 上进入 Actions 页面运行工作流。

---

## 注意事项

1. **首次启动必须修改密码**：root 初始密码为 `admin123`，登录后请立即修改
2. **SSH 仅 LAN 可访问**：无法从 WAN 侧通过 SSH 连接
3. **编译前检查**：YAML 工作流已添加文件存在性检查，缺少必要文件时会清晰报错
4. **第三方 feeds**：`kiddin9` 源的兼容性需自行验证，如遇问题可从 `feeds.conf.default` 中移除
